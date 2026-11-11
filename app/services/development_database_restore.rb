require "bcrypt"
require "tmpdir"

class DevelopmentDatabaseRestore
  def self.call(source_path:, confirmation:)
    raise ArgumentError, "Restore is allowed only in development." unless Rails.env.development?
    raise ArgumentError, "Set CONFIRM=replace-development to confirm replacement." unless confirmation == "replace-development"
    raise ArgumentError, "Unset DATABASE_URL before restoring." if ENV["DATABASE_URL"].present?

    target = Rails.root.join("storage/development.sqlite3").to_s
    configured = File.expand_path(ActiveRecord::Base.connection_db_config.database, Rails.root)
    raise ArgumentError, "Development database must be storage/development.sqlite3." unless configured == target
    raise ArgumentError, "Development database must be an existing regular file, not a symlink." unless File.file?(target) && !File.symlink?(target)
    raise ArgumentError, "Source must be a different existing file." unless File.file?(source_path) && File.realpath(source_path) != File.realpath(target)

    expected = ActiveRecord::Base.connection_pool.migration_context.migrations.map(&:version).map(&:to_s).sort
    backup_path = Rails.root.join("storage", "development-before-restore-#{Time.current.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(4)}.sqlite3").to_s
    ActiveRecord::Base.connection_pool.disconnect!
    restore_files(source_path, target, backup_path, expected)
    backup_path
  end

  def self.restore_files(source_path, target, backup_path, expected)
    Dir.mktmpdir("carousel-dev-restore-") do |dir|
      staged = File.join(dir, "staged.sqlite3")
      SqliteSnapshot.create(source_path, staged)
      SQLite3::Database.new(staged) do |database|
        versions = database.execute("SELECT version FROM schema_migrations").flatten.sort
        raise ArgumentError, "Snapshot schema does not match this checkout. Deploy or update and migrate before restoring." unless versions == expected

        database.transaction do
          database.execute("DELETE FROM sessions")
          database.execute("DELETE FROM invitations WHERE accepted_at IS NULL")
          digest = BCrypt::Password.create(SecureRandom.urlsafe_base64(48)).to_s
          database.execute("UPDATE users SET password_digest = ?", [ digest ])
        end
        SqliteSnapshot.validate!(database)
      end

      SqliteSnapshot.create(target, backup_path)
      SQLite3::Database.new(staged, readonly: true) do |source|
        SQLite3::Database.new(target) do |destination|
          SqliteSnapshot.copy(source, destination)
          SqliteSnapshot.validate!(destination)
        end
      end
    end
  end
  private_class_method :restore_files
end
