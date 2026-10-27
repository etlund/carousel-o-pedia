require "test_helper"

class InvitationsTest < ActionDispatch::IntegrationTest
  test "only admins can invite" do
    sign_in_as users(:editor)
    get invitations_path
    assert_redirected_to root_path

    post invitations_path, params: { invitation: { email_address: "friend@example.com" } }
    assert_not Invitation.exists?
  end

  test "an admin invites someone, who picks a name and password and is signed in" do
    sign_in_as users(:admin)
    assert_enqueued_emails 1 do
      post invitations_path, params: { invitation: { email_address: "Friend@Example.com" } }
    end
    invitation = Invitation.last
    assert_equal "friend@example.com", invitation.email_address
    sign_out

    get edit_invitation_acceptance_path(invitation.token)
    assert_response :success
    assert_select "label[for='user_name']", text: "Public display name"
    assert_select "input[name='user[contribution_terms]'][type=checkbox][required]:not([checked])", 1
    assert_select "a[href=?]", contribution_terms_path
    assert_select "#display-name-hint", /public history/

    patch invitation_acceptance_path(invitation.token), params: { user: {
      name: "Friend", password: "secret123", password_confirmation: "secret123",
      contribution_terms: "1", contribution_terms_version: User::CONTRIBUTION_TERMS_VERSION,
      role: "admin", suspended_at: Time.current
    } }
    assert_redirected_to root_path
    user = User.find_by!(email_address: "friend@example.com")
    assert_equal "editor", user.role
    assert_not user.suspended?
    assert user.contribution_terms_accepted?
    assert_equal User::CONTRIBUTION_TERMS_VERSION, user.contribution_terms_version
    assert_in_delta Time.current.to_f, user.contribution_terms_accepted_at.to_f, 5
    assert cookies[:session_id].present?

    get edit_invitation_acceptance_path(invitation.token)
    assert_redirected_to new_session_path
  end

  test "mismatched passwords show the form again" do
    invitation = users(:admin).invitations.create!(email_address: "friend@example.com")
    patch invitation_acceptance_path(invitation.token), params: { user: {
      name: "Friend", password: "secret123", password_confirmation: "nope",
      contribution_terms: "1", contribution_terms_version: User::CONTRIBUTION_TERMS_VERSION
    } }
    assert_response :unprocessable_entity
    assert_nil invitation.reload.accepted_at
    assert_not User.exists?(email_address: "friend@example.com")
  end

  test "invitations expire" do
    invitation = users(:admin).invitations.create!(email_address: "friend@example.com")
    travel Invitation::EXPIRES_IN + 1.day do
      get edit_invitation_acceptance_path(invitation.token)
      assert_redirected_to new_session_path
    end
  end

  test "an existing user can't be invited again" do
    invitation = users(:admin).invitations.build(email_address: users(:editor).email_address)
    assert_not invitation.valid?
  end

  test "an invitation cannot be accepted without explicit agreement to the current terms" do
    invitation = users(:admin).invitations.create!(email_address: "friend@example.com")
    [
      {},
      { contribution_terms: "0", contribution_terms_version: User::CONTRIBUTION_TERMS_VERSION },
      { contribution_terms: "1", contribution_terms_version: "older-terms" }
    ].each do |agreement|
      assert_no_difference [ "User.count", "Session.count" ] do
        patch invitation_acceptance_path(invitation.token), params: {
          user: { name: "Friend", password: "secret123", password_confirmation: "secret123" }.merge(agreement)
        }
      end
      assert_response :unprocessable_entity
      assert_select ".flash", /Contribution terms/
      assert_nil invitation.reload.accepted_at
    end
  end
end
