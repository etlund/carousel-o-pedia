require "test_helper"

class EditorSuspensionsTest < ActionDispatch::IntegrationTest
  setup do
    @editor = users(:editor)
    @carousel = build_carousel
  end

  test "an admin can suspend an editor revoke all sessions and preserve public attribution" do
    sign_in_as @editor
    patch carousel_path(@carousel), params: { carousel: { body: "A sourced contribution" } }
    @editor.sessions.create!
    @editor.sessions.create!
    original_versions = @carousel.versions.count
    sign_in_as users(:admin)

    get invitations_path
    assert_select "form[action=?][method=post]", editor_suspension_path(@editor)
    assert_select "form[action=?]", editor_suspension_path(users(:admin)), count: 0

    assert_no_difference "User.count" do
      post editor_suspension_path(@editor)
    end
    assert_redirected_to invitations_path
    assert @editor.reload.suspended?
    assert_empty @editor.sessions
    assert_equal original_versions, @carousel.versions.count
    get history_carousel_path(@carousel)
    assert_select ".version-line", /Ed Editor\s+edited/

    get invitations_path
    assert_select "strong", text: "Suspended"
    assert_select "button", text: "Restore access for Ed Editor"
  end

  test "a revoked cookie cannot edit even after access is restored" do
    sign_in_as @editor
    editor_cookie = cookies[:session_id]
    sign_in_as users(:admin)
    post editor_suspension_path(@editor)
    delete editor_suspension_path(@editor)
    assert_redirected_to invitations_path
    assert_not @editor.reload.suspended?
    assert_empty @editor.sessions
    delete session_path
    cookies[:session_id] = editor_cookie

    patch carousel_path(@carousel), params: { carousel: { body: "Revoked session edit" } }
    assert_redirected_to new_session_path
    assert_nil @carousel.reload.body
    assert_empty cookies[:session_id]

    post session_path, params: { email_address: @editor.email_address, password: "password" }
    assert_redirected_to carousel_path(@carousel)
    get edit_carousel_path(@carousel)
    assert_response :success
  end

  test "suspended editors cannot sign in but can still browse" do
    @editor.suspend!
    assert_no_difference "Session.count" do
      post session_path, params: { email_address: @editor.email_address, password: "password" }
    end
    assert_redirected_to new_session_path
    follow_redirect!
    assert_select ".flash", /account is suspended/
    assert_not cookies[:session_id].present?
    get carousel_path(@carousel)
    assert_response :success
    assert_select "a", text: "Edit", count: 0
  end

  test "a session on a suspended account is rejected even if the session record still exists" do
    @editor.update!(suspended_at: Time.current)
    sign_in_as @editor
    patch carousel_path(@carousel), params: { carousel: { body: "Suspended session edit" } }
    assert_redirected_to new_session_path
    assert_nil @carousel.reload.body
    assert_empty cookies[:session_id]
  end

  test "only admins can suspend or restore and admins cannot be targeted" do
    [ :post, :delete ].each do |method|
      public_send(method, editor_suspension_path(@editor))
      assert_redirected_to new_session_path
    end
    sign_in_as @editor
    [ :post, :delete ].each do |method|
      public_send(method, editor_suspension_path(@editor))
      assert_redirected_to root_path
      assert_equal "Only admins can do that.", flash[:alert]
    end
    assert_not @editor.reload.suspended?

    sign_in_as users(:admin)
    [ :post, :delete ].each do |method|
      public_send(method, editor_suspension_path(users(:admin)))
      assert_response :not_found
    end
    assert_not users(:admin).reload.suspended?
  end

  test "password recovery does not lift a suspension" do
    @editor.suspend!
    put password_path(@editor.password_reset_token), params: { password: "replacement", password_confirmation: "replacement" }
    assert_redirected_to new_session_path
    assert @editor.reload.suspended?
    post session_path, params: { email_address: @editor.email_address, password: "replacement" }
    assert_redirected_to new_session_path
    assert_not cookies[:session_id].present?
  end
end
