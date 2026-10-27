require "test_helper"

class ContributorPagesTest < ActionDispatch::IntegrationTest
  test "guidance and policy pages are public and linked in the footer" do
    {
      about_path => "About carousel-o-pedia",
      editor_guide_path => "Editor guide",
      contribution_terms_path => "Contribution terms & privacy"
    }.each do |path, title|
      get path
      assert_response :success
      assert_select "h1", title
      assert_select "footer nav[aria-label='About and contributing']" do
        assert_select "a[href=?]", about_path
        assert_select "a[href=?]", editor_guide_path
        assert_select "a[href=?]", contribution_terms_path
      end
    end
  end

  test "terms identify the version prospective license and public attribution" do
    get contribution_terms_path
    assert_select "strong", User::CONTRIBUTION_TERMS_VERSION
    assert_select "a[href='https://creativecommons.org/licenses/by-sa/4.0/']", /CC BY-SA 4.0/
    assert_select "p", /does not automatically relicense earlier contributions/
    assert_select "#privacy + p", /display name.*public/
    assert_select "a[href=?]", about_path(anchor: "contact")
  end

  test "about page honestly defers public contact without a fake address or request form" do
    get about_path
    assert_select "#contact + p", /public contact route is not available yet/
    assert_select "a[href^='mailto:'], form", count: 0
    assert_select "a[href=?]", editor_guide_path
    assert_select "a[href=?]", contribution_terms_path
  end
end
