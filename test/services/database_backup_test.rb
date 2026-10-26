require "test_helper"
require "aws-sdk-s3"
require "sqlite3"

class DatabaseBackupTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir("backup-test-")
    @source_path = File.join(@directory, "source.sqlite3")
    @source = SQLite3::Database.new(@source_path)
    @source.execute("PRAGMA journal_mode = WAL")
    @source.execute("PRAGMA wal_autocheckpoint = 0")
    %w[carousels figures seats versions].each do |table|
      @source.execute("CREATE TABLE #{table} (id INTEGER PRIMARY KEY)")
      @source.execute("INSERT INTO #{table} (id) VALUES (1)")
    end
    @client = Aws::S3::Client.new(region: "us-east-1", stub_responses: true)
    @client.stub_responses(:put_object, ->(context) {
      @uploaded_bytes = context.params[:body].read
      @uploaded_metadata = context.params[:metadata]
      {}
    })
    @backup = DatabaseBackup.new(client: @client, bucket: "test-backups", database_path: @source_path)
  end

  teardown do
    @source.close
    FileUtils.remove_entry(@directory)
  end

  test "uploads a private consistent snapshot including committed WAL changes" do
    @source.execute("INSERT INTO carousels (id) VALUES (2)")

    key = @backup.call
    request = @client.api_requests.find { |request| request[:operation_name] == :put_object }
    parameters = request.fetch(:params)
    snapshot_path = parameters.fetch(:body).path
    assert_match %r{\Adatabase/production/\d{8}T\d{6}Z-[0-9a-f]{16}\.sqlite3\z}, key
    assert_equal "private", parameters.fetch(:acl)
    assert_equal "test-backups", parameters.fetch(:bucket)
    assert_equal Digest::SHA256.hexdigest(@uploaded_bytes), @uploaded_metadata.fetch("sha256")
    assert_not File.exist?(snapshot_path)

    @client.stub_responses(:get_object, body: @uploaded_bytes, metadata: @uploaded_metadata)
    result = @backup.verify(key)
    assert_equal({ "carousels" => 2, "figures" => 1, "seats" => 1, "versions" => 1 }, result.fetch(:counts))
    assert_equal 2, @source.get_first_value("SELECT COUNT(*) FROM carousels")
    assert_equal key, result.fetch(:key)
    assert_equal @uploaded_metadata.fetch("sha256"), result.fetch(:sha256)
  end

  test "retention paginates and deletes only matching backups strictly older than 30 days" do
    travel_to Time.utc(2026, 10, 26, 12) do
      old_key = "database/production/20260901T030000Z-1111111111111111.sqlite3"
      boundary_key = "database/production/20260926T120000Z-2222222222222222.sqlite3"
      recent_key = "database/production/20261025T030000Z-3333333333333333.sqlite3"
      other_key = "database/production/do-not-delete.sqlite3"
      @client.stub_responses(:list_objects_v2, [
        { contents: [ { key: old_key, last_modified: 31.days.ago } ], is_truncated: true, next_continuation_token: "next-page" },
        { contents: [
          { key: boundary_key, last_modified: 30.days.ago },
          { key: recent_key, last_modified: 1.day.ago },
          { key: other_key, last_modified: 90.days.ago }
        ], is_truncated: false }
      ])

      @backup.call

      deletions = @client.api_requests.select { |request| request[:operation_name] == :delete_object }
      assert_equal [ old_key ], deletions.map { |request| request.fetch(:params).fetch(:key) }
      listings = @client.api_requests.select { |request| request[:operation_name] == :list_objects_v2 }
      assert_equal 2, listings.size
      assert_equal "next-page", listings.last.fetch(:params).fetch(:continuation_token)
    end
  end

  test "failed uploads raise and do not prune existing backups" do
    @client.stub_responses(:put_object, "AccessDenied")

    assert_raises(Aws::S3::Errors::AccessDenied) { @backup.call }

    assert_not @client.api_requests.any? { |request| request[:operation_name] == :list_objects_v2 }
    assert_not @client.api_requests.any? { |request| request[:operation_name] == :delete_object }
  end

  test "missing source database fails instead of uploading an empty database" do
    backup = DatabaseBackup.new(
      client: @client, bucket: "test-backups", database_path: File.join(@directory, "missing.sqlite3")
    )

    assert_raises(SQLite3::CantOpenException) { backup.call }

    assert_empty @client.api_requests
  end

  test "restore rejects a checksum mismatch without changing the source" do
    key = @backup.call
    @client.stub_responses(:get_object, body: @uploaded_bytes, metadata: { "sha256" => "incorrect" })

    error = assert_raises(RuntimeError) { @backup.verify(key) }

    assert_match "checksum does not match", error.message
    assert_equal 1, @source.get_first_value("SELECT COUNT(*) FROM carousels")
  end

  test "restore rejects invalid SQLite data even with a matching checksum" do
    bytes = "not a SQLite database"
    @client.stub_responses(:get_object, body: bytes, metadata: { "sha256" => Digest::SHA256.hexdigest(bytes) })

    assert_raises(SQLite3::NotADatabaseException) do
      @backup.verify("database/production/20261026T030000Z-1111111111111111.sqlite3")
    end
  end

  test "restore refuses unrelated object keys" do
    assert_raises(ArgumentError) { @backup.verify("some-other-object") }

    assert_empty @client.api_requests
  end
end
