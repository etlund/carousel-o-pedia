namespace :backups do
  desc "Upload a consistent primary SQLite snapshot and expire backups older than 30 days"
  task create: :environment do
    puts "Uploaded backup: #{DatabaseBackup.new.call}"
  end

  desc "Download a backup into temporary storage and check its checksum, SQLite integrity, and catalog counts"
  task verify: :environment do
    puts JSON.pretty_generate(DatabaseBackup.new.verify(ENV.fetch("KEY")))
  end

  desc "Replace the local development database with a sanitized snapshot (stop local servers first)"
  task restore_development: :environment do
    backup = DevelopmentDatabaseRestore.call(source_path: ENV.fetch("FILE"), confirmation: ENV["CONFIRM"])
    puts "Development database restored. Previous database saved to #{backup}."
    puts "Copied sessions and pending invitations were removed; all copied passwords were disabled."
    puts "Set a local password using bin/rails users:reset_password EMAIL=your-admin-email."
  end
end
