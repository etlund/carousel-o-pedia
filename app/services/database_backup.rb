require "aws-sdk-s3"
require "digest"
require "sqlite3"
require "tmpdir"

class DatabaseBackup
  PREFIX = "database/production/"
  RETENTION = 30.days

  def initialize(client: nil, bucket: ENV.fetch("BACKUP_BUCKET"),
    database_path: ActiveRecord::Base.connection_db_config.database)
    @client = client || Aws::S3::Client.new(
      endpoint: ENV.fetch("BACKUP_ENDPOINT"),
      region: "us-east-1",
      credentials: Aws::Credentials.new(
        ENV.fetch("BACKUP_ACCESS_KEY_ID"),
        ENV.fetch("BACKUP_SECRET_ACCESS_KEY")
      )
    )
    @bucket = bucket
    @database_path = database_path
  end

  def call
    key = "#{PREFIX}#{Time.current.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(8)}.sqlite3"

    Dir.mktmpdir("carousel-backup-") do |directory|
      path = File.join(directory, "production.sqlite3")
      SqliteSnapshot.create(@database_path, path)
      checksum = Digest::SHA256.file(path).hexdigest

      File.open(path, "rb") do |file|
        @client.put_object(
          bucket: @bucket, key: key, body: file, acl: "private",
          content_type: "application/vnd.sqlite3", metadata: { "sha256" => checksum }
        )
      end
      Rails.logger.info("Database backup uploaded: s3://#{@bucket}/#{key} sha256=#{checksum}")
    end

    prune
    key
  end

  def verify(key)
    raise ArgumentError, "Not a production database backup key" unless backup_key?(key)

    Dir.mktmpdir("carousel-restore-check-") do |directory|
      path = File.join(directory, "restored.sqlite3")
      response = @client.get_object(bucket: @bucket, key: key, response_target: path)
      checksum = Digest::SHA256.file(path).hexdigest
      raise "Downloaded backup checksum does not match" unless checksum == response.metadata.fetch("sha256")

      counts = {}
      SQLite3::Database.new(path, readonly: true) do |database|
        SqliteSnapshot.validate!(database)
        counts = %w[carousels figures seats versions].to_h do |table|
          [ table, database.get_first_value("SELECT COUNT(*) FROM #{table}") ]
        end
      end
      Rails.logger.info("Database backup restore verified: s3://#{@bucket}/#{key}")
      { key: key, sha256: checksum, counts: counts }
    end
  end

  private
    def backup_key?(key)
      /\Adatabase\/production\/\d{8}T\d{6}Z-[0-9a-f]{16}\.sqlite3\z/.match?(key)
    end

    def prune
      cutoff = RETENTION.ago
      @client.list_objects_v2(bucket: @bucket, prefix: PREFIX).each_page do |page|
        page.contents.each do |object|
          next unless backup_key?(object.key) && object.last_modified < cutoff

          @client.delete_object(bucket: @bucket, key: object.key)
          Rails.logger.info("Expired database backup deleted: s3://#{@bucket}/#{object.key}")
        end
      end
    end
end
