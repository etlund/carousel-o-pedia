require "test_helper"

class ContributionAgreementsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:editor)
    @user.update!(contribution_terms_version: nil, contribution_terms_accepted_at: nil)
    @carousel = build_carousel
    sign_in_as @user
  end

  test "existing editors can browse but must agree before opening editing forms or submitting edits" do
    [ root_path, carousel_path(@carousel), history_carousel_path(@carousel), recent_changes_path,
      about_path, editor_guide_path, contribution_terms_path ].each do |path|
      get path
      assert_response :success
    end

    [ new_carousel_path, edit_carousel_path(@carousel), new_figure_path, new_figure_type_path, new_maker_path,
      edit_carousel_seat_path(@carousel, @carousel.seat("1A")) ].each do |path|
      get path
      assert_redirected_to edit_contribution_agreement_path
    end

    original_name = @carousel.name
    patch carousel_path(@carousel), params: { carousel: { name: "Unagreed edit" } }
    assert_redirected_to edit_contribution_agreement_path
    assert_equal original_name, @carousel.reload.name
    assert_no_difference [ "Carousel.count", "Figure.count", "FigureType.count", "Maker.count" ] do
      [ carousels_path, figures_path, figure_types_path, makers_path ].each do |path|
        post path
        assert_redirected_to edit_contribution_agreement_path
      end
    end
  end

  test "agreeing records the current version and server time and enables editing" do
    get edit_contribution_agreement_path
    assert_response :success
    assert_select "input[name='user[contribution_terms]'][type=checkbox][required]:not([checked])", 1
    assert_select "input[name='user[contribution_terms_version]'][value=?]", User::CONTRIBUTION_TERMS_VERSION

    freeze_time do
      patch contribution_agreement_path, params: { user: {
        contribution_terms: "1", contribution_terms_version: User::CONTRIBUTION_TERMS_VERSION,
        contribution_terms_accepted_at: 1.year.ago, role: "admin", name: "Changed name"
      } }
      assert_redirected_to root_path
      assert @user.reload.contribution_terms_accepted?
      assert_equal Time.current, @user.contribution_terms_accepted_at
      assert_equal "editor", @user.role
      assert_equal "Ed Editor", @user.name
    end

    get edit_carousel_path(@carousel)
    assert_response :success
    patch carousel_path(@carousel), params: { carousel: { name: "Agreed edit" } }
    assert_redirected_to carousel_path(@carousel)
    assert_equal "Agreed edit", @carousel.reload.name
  end

  test "omitted unchecked and stale agreements are rejected without persisting acceptance" do
    [
      { contribution_terms_version: User::CONTRIBUTION_TERMS_VERSION },
      { contribution_terms: "0", contribution_terms_version: User::CONTRIBUTION_TERMS_VERSION },
      { contribution_terms: "1", contribution_terms_version: "older-terms" }
    ].each do |agreement|
      patch contribution_agreement_path, params: { user: agreement }
      assert_response :unprocessable_entity
      assert_select ".flash", /Contribution terms/
      assert_not @user.reload.contribution_terms_accepted?
      assert_nil @user.contribution_terms_accepted_at
      assert_nil @user.contribution_terms_version
    end
  end

  test "a previous agreement does not satisfy the current version" do
    @user.update!(contribution_terms_version: "older-terms", contribution_terms_accepted_at: 1.day.ago)
    get edit_carousel_path(@carousel)
    assert_redirected_to edit_contribution_agreement_path
    get root_path
    assert_select "a[href=?]", edit_contribution_agreement_path, text: "Review contribution terms"
  end

  test "admins also need to agree before invitations suspension or reverts" do
    admin = users(:admin)
    admin.update!(contribution_terms_version: nil, contribution_terms_accepted_at: nil)
    sign_in_as admin
    get invitations_path
    assert_redirected_to edit_contribution_agreement_path
    post editor_suspension_path(@user)
    assert_redirected_to edit_contribution_agreement_path
    assert_not @user.reload.suspended?
    post revert_version_path(@carousel.versions.last)
    assert_redirected_to edit_contribution_agreement_path
  end

  test "editors can sign out without accepting and anonymous visitors cannot record agreement" do
    delete session_path
    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]

    get edit_contribution_agreement_path
    assert_redirected_to new_session_path
    patch contribution_agreement_path, params: {
      user: { contribution_terms: "1", contribution_terms_version: User::CONTRIBUTION_TERMS_VERSION }
    }
    assert_redirected_to new_session_path
    assert_not @user.reload.contribution_terms_accepted?
  end

  test "sign in does not bypass the agreement requirement" do
    delete session_path
    post session_path, params: { email_address: @user.email_address, password: "password" }
    assert_redirected_to root_path
    get edit_carousel_path(@carousel)
    assert_redirected_to edit_contribution_agreement_path
  end
end
