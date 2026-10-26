class DatabaseBackupJob < ApplicationJob
  def perform
    DatabaseBackup.new.call
  end
end
