require "application_system_test_case"

class EditorAccessTest < ApplicationSystemTestCase
  test "an invitee can read the guidance and must explicitly agree before joining" do
    invitation = users(:admin).invitations.create!(email_address: "new-editor@example.com")
    visit edit_invitation_acceptance_path(invitation.token)
    assert_text "This name appears with your edits in public history."
    assert_unchecked_field "user_contribution_terms"
    click_link "editor guide"
    assert_selector "h1", text: "Editor guide"
    within ".site-footer" do
      click_link "Contribution terms & privacy"
    end
    assert_selector "h1", text: "Contribution terms & privacy"
    assert_text "does not automatically relicense earlier contributions"
    within ".site-footer" do
      click_link "About / Contribute"
    end
    assert_selector "h1", text: "About carousel-o-pedia"
    assert_text "A public contact route is not available yet."

    visit edit_invitation_acceptance_path(invitation.token)
    fill_in "Public display name", with: "Carousel Researcher"
    fill_in "Password", with: "a-unique-editor-password", exact: true
    fill_in "Password again", with: "a-unique-editor-password"
    check "user_contribution_terms"
    assert_checked_field "user_contribution_terms"
    click_button "Create my account"
    assert_text "Welcome, Carousel Researcher."
    assert User.find_by!(email_address: "new-editor@example.com").contribution_terms_accepted?
  end

  test "an existing editor agrees before editing and guidance remains usable on a narrow screen" do
    users(:editor).update!(contribution_terms_version: nil, contribution_terms_accepted_at: nil)
    carousel = build_carousel
    sign_in "editor@example.com"
    visit edit_carousel_path(carousel)
    assert_selector "h1", text: "Before you edit"
    assert_unchecked_field "user_contribution_terms"
    check "user_contribution_terms"
    assert_checked_field "user_contribution_terms"
    assert find("form[action='#{contribution_agreement_path}']").evaluate_script("this.checkValidity()")
    click_button "Agree and continue"
    assert_text "You can edit now."
    assert users(:editor).reload.contribution_terms_accepted?
    visit edit_carousel_path(carousel)
    assert_selector "form input[name='carousel[name]']"

    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit editor_guide_path
    assert_selector "h1", text: "Editor guide"
    assert_equal 390, page.evaluate_script("window.innerWidth")
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    assert_selector ".site-footer a[href='#{about_path}']", text: "About / Contribute"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "an admin can confirm suspension and restore access from Invitations" do
    sign_in "admin@example.com"
    click_link "Invitations"
    accept_confirm do
      click_button "Suspend Ed Editor"
    end
    assert_text "Access suspended for Ed Editor."
    assert users(:editor).reload.suspended?
    click_button "Restore access for Ed Editor"
    assert_text "Access restored for Ed Editor."
    assert_not users(:editor).reload.suspended?
  end

  private
    def sign_in(email)
      visit new_session_path
      fill_in "Email", with: email
      fill_in "Password", with: "password"
      click_button "Sign in"
      assert_button "Sign out"
    end
end
