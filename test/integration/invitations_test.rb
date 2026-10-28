require "test_helper"

class InvitationsTest < ActionDispatch::IntegrationTest
  test "only admins can invite" do
    sign_in_as users(:editor)
    get invitations_path
    assert_redirected_to root_path

    post invitations_path, params: { invitation: { email_address: "friend@example.com" } }
    assert_not Invitation.exists?

    post invitations_path, params: { invitation: { email_address: "" } }
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
    assert_select "input[name='user[email_address]']", count: 0

    patch invitation_acceptance_path(invitation.token), params: { user: {
      name: "Friend", password: "secret123", password_confirmation: "secret123",
      contribution_terms: "1", contribution_terms_version: User::CONTRIBUTION_TERMS_VERSION,
      role: "admin", suspended_at: Time.current, email_address: "different@example.com"
    } }
    assert_redirected_to root_path
    user = User.find_by!(email_address: "friend@example.com")
    assert_equal "editor", user.role
    assert_not User.exists?(email_address: "different@example.com")
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

  test "an admin generates a shareable link without sending an email" do
    sign_in_as users(:admin)
    get invitations_path
    assert_select "input[name='invitation[email_address]']:not([required])"
    assert_no_enqueued_emails do
      assert_difference "Invitation.count", 2 do
        2.times do
          post invitations_path, params: { invitation: { email_address: "  " } }
          assert_redirected_to invitations_path
        end
      end
    end
    invitations = Invitation.order(:id).last(2)
    assert_nil invitations.first.email_address
    assert_nil invitations.last.email_address
    assert_not_equal invitations.first.token, invitations.last.token
    follow_redirect!
    assert_select "td", text: "Shareable link", count: 2
    invitations.each do |invitation|
      assert_select "input[readonly][value=?]", edit_invitation_acceptance_url(invitation.token)
    end
  end

  test "a shareable invitation collects an email creates one account and signs it in" do
    invitation = users(:admin).invitations.create!
    get edit_invitation_acceptance_path(invitation.token)
    assert_response :success
    assert_select "input[name='user[email_address]'][type=email][required][autocomplete=email]"

    assert_difference [ "User.count", "Session.count" ], 1 do
      patch invitation_acceptance_path(invitation.token), params: {
        user: acceptance_attributes(email_address: " Friend@Example.com ")
      }
    end
    assert_redirected_to root_path
    user = User.find_by!(email_address: "friend@example.com")
    assert user.contribution_terms_accepted?
    assert_equal "friend@example.com", invitation.reload.email_address
    assert invitation.accepted_at
    assert cookies[:session_id].present?
    sign_out

    assert_no_difference [ "User.count", "Session.count" ] do
      patch invitation_acceptance_path(invitation.token), params: {
        user: acceptance_attributes(email_address: "second@example.com")
      }
    end
    assert_redirected_to new_session_path
  end

  test "invalid shareable invitation submissions preserve the link and entered email" do
    invitation = users(:admin).invitations.create!
    [
      { email_address: "" },
      { email_address: "not-an-email" },
      { email_address: " EDITOR@EXAMPLE.COM " },
      { email_address: "friend@example.com", password_confirmation: "different" },
      { email_address: "friend@example.com", contribution_terms: "0" },
      { email_address: "friend@example.com", contribution_terms_version: "older-terms" }
    ].each do |attributes|
      assert_no_difference [ "User.count", "Session.count" ] do
        patch invitation_acceptance_path(invitation.token), params: {
          user: acceptance_attributes(**attributes)
        }
      end
      assert_response :unprocessable_entity
      assert_select ".flash"
      assert_select "input[name='user[email_address]'][required]"
      assert_equal attributes[:email_address].strip.downcase,
        css_select("input[name='user[email_address]']").first["value"].to_s.strip.downcase
      assert_nil invitation.reload.accepted_at
      assert_nil invitation.email_address
    end
    patch invitation_acceptance_path(invitation.token), params: {
      user: acceptance_attributes(email_address: "friend@example.com")
    }
    assert_redirected_to root_path
  end

  test "shareable links retain existing-carousel and new-carousel restrictions" do
    [ build_carousel, nil ].each_with_index do |carousel, index|
      invitation = users(:admin).invitations.create!(access_scope: "carousel", editable_carousel: carousel)
      patch invitation_acceptance_path(invitation.token), params: { user: acceptance_attributes(
        email_address: "limited#{index}@example.com", access_scope: "site_wide", role: "admin",
        editable_carousel_id: -1
      ) }
      assert_redirected_to carousel ? carousel_path(carousel) : new_carousel_path
      user = User.find_by!(email_address: "limited#{index}@example.com")
      assert_equal "editor", user.role
      assert_equal "carousel", user.access_scope
      if carousel
        assert_equal carousel, user.editable_carousel
        assert_not user.can_create_carousel?
      else
        assert_nil user.editable_carousel
        assert user.can_create_carousel?
      end
      sign_out
    end
  end

  test "shareable links can be withdrawn and expire before account creation" do
    withdrawn = users(:admin).invitations.create!
    sign_in_as users(:admin)
    delete invitation_path(withdrawn)
    assert_redirected_to invitations_path
    sign_out

    expired = users(:admin).invitations.create!(created_at: (Invitation::EXPIRES_IN + 1.day).ago)
    [ withdrawn, expired ].each do |invitation|
      get edit_invitation_acceptance_path(invitation.token)
      assert_redirected_to new_session_path
      assert_no_difference "User.count" do
        patch invitation_acceptance_path(invitation.token), params: {
          user: acceptance_attributes(email_address: "friend@example.com")
        }
      end
      assert_redirected_to new_session_path
    end
  end

  test "an invalid admin email address is not treated as a shareable link" do
    sign_in_as users(:admin)
    assert_no_enqueued_emails do
      assert_no_difference "Invitation.count" do
        post invitations_path, params: { invitation: { email_address: "invalid" } }
      end
    end
    assert_response :unprocessable_entity
  end

  private
    def acceptance_attributes(**attributes)
      {
        name: "Friend", password: "secret123", password_confirmation: "secret123",
        contribution_terms: "1", contribution_terms_version: User::CONTRIBUTION_TERMS_VERSION
      }.merge(attributes)
    end
end
