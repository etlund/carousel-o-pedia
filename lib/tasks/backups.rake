namespace :backups do
  desc "Upload a consistent primary SQLite snapshot and expire backups older than 30 days"
  task create: :environment do
    puts "Uploaded backup: #{DatabaseBackup.new.call}"
  end

  desc "Download a backup into temporary storage and check its checksum, SQLite integrity, and catalog counts"
  task verify: :environment do
    puts JSON.pretty_generate(DatabaseBackup.new.verify(ENV.fetch("KEY")))
  end
end
