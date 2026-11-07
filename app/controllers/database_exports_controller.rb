require "tmpdir"

class DatabaseExportsController < ApplicationController
  before_action :require_admin

  def show
    directory = Dir.mktmpdir("carousel-db-download-")
    path = File.join(directory, "database.sqlite3")
    streaming = false
    begin
      SqliteSnapshot.create(ActiveRecord::Base.connection_db_config.database, path)
      response.headers["Cache-Control"] = "no-store, private"
      send_file path, filename: "carousel-database-#{Time.current.utc.strftime('%Y%m%dT%H%M%SZ')}.sqlite3",
        type: "application/vnd.sqlite3", disposition: "attachment"
      chunks = Enumerator.new do |output|
        File.open(path, "rb") do |file|
          while (chunk = file.read(64.kilobytes))
            output << chunk
          end
        end
      end
      response.body = Rack::BodyProxy.new(chunks) { FileUtils.remove_entry(directory) }
      streaming = true
    ensure
      FileUtils.remove_entry(directory) unless streaming
    end
  end
end
