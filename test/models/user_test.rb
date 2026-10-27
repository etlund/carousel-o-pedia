require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "current agreement requires both a timestamp and the exact terms version" do
    user = users(:editor)
    assert user.contribution_terms_accepted?
    user.contribution_terms_accepted_at = nil
    assert_not user.contribution_terms_accepted?
    user.contribution_terms_accepted_at = Time.current
    user.contribution_terms_version = "older-terms"
    assert_not user.contribution_terms_accepted?
  end

  test "suspension cannot disable an administrator or revoke their sessions" do
    admin = users(:admin)
    session = admin.sessions.create!
    assert_raises ActiveRecord::RecordInvalid do
      admin.suspend!
    end
    assert_not admin.reload.suspended?
    assert admin.sessions.exists?(session.id)
  end
end
