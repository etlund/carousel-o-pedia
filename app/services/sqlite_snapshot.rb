require "sqlite3"

class SqliteSnapshot
  def self.create(source_path, target_path)
    File.open(target_path, File::WRONLY | File::CREAT | File::EXCL, 0600) { }
    complete = false
    begin
      SQLite3::Database.new(source_path, readonly: true) do |source|
        source.busy_timeout = 5_000
        SQLite3::Database.new(target_path) do |target|
          copy(source, target)
          validate!(target)
        end
      end
      complete = true
    ensure
      File.delete(target_path) unless complete
    end
  end

  def self.copy(source, target)
    target.busy_timeout = 5_000
    backup = SQLite3::Backup.new(target, "main", source, "main")
    begin
      result = backup.step(-1)
      raise "SQLite backup failed with code #{result}" unless result == SQLite3::Constants::ErrorCode::DONE
    ensure
      backup.finish
    end
  end

  def self.validate!(database)
    raise "SQLite integrity check failed" unless database.execute("PRAGMA integrity_check") == [ [ "ok" ] ]
    raise "SQLite foreign-key check failed" unless database.execute("PRAGMA foreign_key_check").empty?
  end
end
