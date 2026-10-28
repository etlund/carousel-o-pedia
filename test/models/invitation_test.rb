require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  test "a stale invitation instance cannot create a second account with another email" do
    invitation = users(:admin).invitations.create!
    stale_invitation = Invitation.find(invitation.id)
    user = invitation.accept!(**acceptance_attributes(email_address: "first@example.com"))
    assert_equal "first@example.com", user.email_address

    assert_no_difference "User.count" do
      assert_raises ActiveRecord::RecordNotFound do
        stale_invitation.accept!(**acceptance_attributes(email_address: "second@example.com"))
      end
    end
  end

  test "expiration is rechecked when accepting an already loaded invitation" do
    invitation = users(:admin).invitations.create!
    travel Invitation::EXPIRES_IN + 1.second do
      assert_no_difference "User.count" do
        assert_raises ActiveRecord::RecordNotFound do
          invitation.accept!(**acceptance_attributes(email_address: "friend@example.com"))
        end
      end
    end
  end

  test "a withdrawn invitation cannot be accepted by a stale instance" do
    invitation = users(:admin).invitations.create!
    Invitation.find(invitation.id).destroy!
    assert_no_difference "User.count" do
      assert_raises ActiveRecord::RecordNotFound do
        invitation.accept!(**acceptance_attributes(email_address: "friend@example.com"))
      end
    end
  end

  private
    def acceptance_attributes(email_address:)
      {
        email_address:, name: "Friend", password: "secret123", password_confirmation: "secret123",
        contribution_terms: "1", contribution_terms_version: User::CONTRIBUTION_TERMS_VERSION
      }
    end
end
