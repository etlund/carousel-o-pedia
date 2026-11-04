require "application_system_test_case"

class CarouselCsvSystemTest < ApplicationSystemTestCase
  setup do
    visit new_session_path
    fill_in "Email", with: users(:admin).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Sign out"
  end

  test "an admin uploads a CSV, reviews the preview, and applies it" do
    visit carousel_csv_path
    attach_file "Upload CSV", Rails.root.join("test/fixtures/files/carousel_import.csv")
    click_button "Preview import"

    assert_selector "h1", text: "Preview carousel CSV import"
    assert_text "Uploaded carousel"
    assert_text "unknown"
    assert_not Carousel.exists?(name: "Uploaded carousel")

    click_button "Apply all changes"
    assert_text "Import complete: 1 created"
    assert_equal "unknown", Carousel.find_by!(name: "Uploaded carousel").status
  end

  test "an admin can correct an invalid pasted CSV and preview it" do
    visit carousel_csv_path
    fill_in "Or paste CSV", with: "name,official_url\nExample,javascript:alert(1)\n"
    click_button "Preview import"
    assert_text "Fix the errors"

    fill_in "Or paste CSV", with: "name,official_url\nExample,https://example.com/\n"
    click_button "Preview import"
    assert_selector "h1", text: "Preview carousel CSV import"
    assert_text "Example"
    assert_button "Apply all changes"
    assert_not Carousel.exists?(name: "Example")
  end
end
