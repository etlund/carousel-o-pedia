require "test_helper"

class DatabaseBackupJobTest < ActiveJob::TestCase
  test "can be queued without including credentials in the job arguments" do
    assert_enqueued_with(job: DatabaseBackupJob, args: []) { DatabaseBackupJob.perform_later }
  end
end
