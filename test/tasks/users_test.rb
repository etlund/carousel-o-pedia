require "test_helper"
require "rake"

class UsersTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("users:reset_password")
    @task = Rake::Task["users:reset_password"]
    @task.reenable
    @email = ENV["EMAIL"]
    @password = ENV["PASSWORD"]
    ENV["EMAIL"] = users(:admin).email_address
  end

  teardown do
    ENV["EMAIL"] = @email
    ENV["PASSWORD"] = @password
  end

  test "resets the password and revokes only that user's sessions" do
    admin = users(:admin)
    admin.sessions.create!
    editor_session = users(:editor).sessions.create!
    ENV["PASSWORD"] = "a-new-long-password"

    assert_output(/Password reset and sessions revoked/) { @task.invoke }

    assert admin.reload.authenticate("a-new-long-password")
    assert_not admin.authenticate("password")
    assert_empty admin.sessions
    assert Session.exists?(editor_session.id)
  end

  test "rejects a short password without changing the user or sessions" do
    admin = users(:admin)
    session = admin.sessions.create!
    ENV["PASSWORD"] = "short"

    assert_raises(ArgumentError) { @task.invoke }

    assert admin.reload.authenticate("password")
    assert Session.exists?(session.id)
  end
end
