require "test_helper"
require "open3"
require "sqlite3"
require "tmpdir"

class DevelopmentDatabaseRestoreTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir("development-restore-test-")
    @source = File.join(@directory, "source.sqlite3")
    @target = File.join(@directory, "target.sqlite3")
    @backup = File.join(@directory, "backup.sqlite3")
    SQLite3::Database.new(@source) do |db|
      db.execute("CREATE TABLE schema_migrations (version TEXT PRIMARY KEY)")
      db.execute("INSERT INTO schema_migrations VALUES ('1')")
      db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, password_digest TEXT NOT NULL)")
      db.execute("INSERT INTO users VALUES (1, 'production-hash')")
      db.execute("CREATE TABLE sessions (id INTEGER PRIMARY KEY)")
      db.execute("INSERT INTO sessions VALUES (1)")
      db.execute("CREATE TABLE invitations (id INTEGER PRIMARY KEY, accepted_at TEXT)")
      db.execute("INSERT INTO invitations VALUES (1, NULL), (2, '2026-01-01')")
      db.execute("CREATE TABLE carousels (id INTEGER PRIMARY KEY, name TEXT)")
      db.execute("INSERT INTO carousels VALUES (1, 'Production')")
    end
    SQLite3::Database.new(@target) do |db|
      db.execute("CREATE TABLE carousels (id INTEGER PRIMARY KEY, name TEXT)")
      db.execute("INSERT INTO carousels VALUES (1, 'Development')")
    end
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  test "restores a sanitized copy and retains the old database and original source" do
    DevelopmentDatabaseRestore.send(:restore_files, @source, @target, @backup, [ "1" ])
    SQLite3::Database.new(@target, readonly: true) do |db|
      assert_equal "Production", db.get_first_value("SELECT name FROM carousels")
      assert_equal 0, db.get_first_value("SELECT COUNT(*) FROM sessions")
      assert_equal [ [ 2 ] ], db.execute("SELECT id FROM invitations")
      assert_not_equal "production-hash", db.get_first_value("SELECT password_digest FROM users")
      assert_equal [ [ "ok" ] ], db.execute("PRAGMA integrity_check")
    end
    SQLite3::Database.new(@backup, readonly: true) do |db|
      assert_equal "Development", db.get_first_value("SELECT name FROM carousels")
    end
    SQLite3::Database.new(@source, readonly: true) do |db|
      assert_equal "production-hash", db.get_first_value("SELECT password_digest FROM users")
      assert_equal 1, db.get_first_value("SELECT COUNT(*) FROM sessions")
      assert_equal 2, db.get_first_value("SELECT COUNT(*) FROM invitations")
    end
    assert_equal 0, File.stat(@backup).mode & 0o077
  end

  test "public restore uses checkout migrations and returns the saved backup path" do
    versions = ActiveRecord::Base.connection_pool.migration_context.migrations.map(&:version).map(&:to_s).sort
    SQLite3::Database.new(@source) do |db|
      db.execute("DELETE FROM schema_migrations")
      versions.each { |version| db.execute("INSERT INTO schema_migrations VALUES (?)", [ version ]) }
    end
    target = File.join(@directory, "storage/development.sqlite3")
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(@target, target)

    script = <<~RUBY
      migrations_paths = ActiveRecord::Base.connection_pool.migrations_paths
      Rails.env = "development"
      Rails.application.config.root = ENV.fetch("RESTORE_ROOT")
      ActiveRecord::Base.establish_connection(
        adapter: "sqlite3",
        database: Rails.root.join("storage/development.sqlite3").to_s,
        migrations_paths: migrations_paths
      )
      puts DevelopmentDatabaseRestore.call(
        source_path: ENV.fetch("RESTORE_SOURCE"),
        confirmation: "replace-development"
      )
    RUBY
    output, error, status = Open3.capture3(
      { "RAILS_ENV" => "test", "DATABASE_URL" => nil, "RESTORE_ROOT" => @directory, "RESTORE_SOURCE" => @source },
      Rails.root.join("bin/rails").to_s, "runner", script
    )
    assert status.success?, "#{output}\n#{error}"
    backup = output.strip
    assert File.file?(backup), output
    SQLite3::Database.new(backup, readonly: true) { |db| assert_equal "Development", db.get_first_value("SELECT name FROM carousels") }
    SQLite3::Database.new(target, readonly: true) do |db|
      assert_equal "Production", db.get_first_value("SELECT name FROM carousels")
      assert_equal 0, db.get_first_value("SELECT COUNT(*) FROM sessions")
      assert_equal versions, db.execute("SELECT version FROM schema_migrations").flatten.sort
    end
  end

  test "schema mismatch and invalid source leave the development database untouched" do
    assert_raises(ArgumentError) do
      DevelopmentDatabaseRestore.send(:restore_files, @source, @target, @backup, [ "different" ])
    end
    assert_not File.exist?(@backup)
    SQLite3::Database.new(@target, readonly: true) { |db| assert_equal "Development", db.get_first_value("SELECT name FROM carousels") }
    assert_raises(SQLite3::CantOpenException) do
      DevelopmentDatabaseRestore.send(:restore_files, File.join(@directory, "missing"), @target, @backup, [ "1" ])
    end
    assert_not File.exist?(@backup)
    SQLite3::Database.new(@target, readonly: true) { |db| assert_equal "Development", db.get_first_value("SELECT name FROM carousels") }
  end

  test "a preexisting backup is never overwritten" do
    File.write(@backup, "existing backup")
    assert_raises(Errno::EEXIST) do
      DevelopmentDatabaseRestore.send(:restore_files, @source, @target, @backup, [ "1" ])
    end
    assert_equal "existing backup", File.read(@backup)
    SQLite3::Database.new(@target, readonly: true) { |db| assert_equal "Development", db.get_first_value("SELECT name FROM carousels") }
  end

  test "public restore refuses to operate outside development" do
    error = assert_raises(ArgumentError) do
      DevelopmentDatabaseRestore.call(source_path: @source, confirmation: "replace-development")
    end
    assert_match(/only in development/, error.message)
  end
end
