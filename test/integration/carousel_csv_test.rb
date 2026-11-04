require "test_helper"
require "csv"

class CarouselCsvIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @carousel = Carousel.create!(name: "Existing carousel", city: "Old city")
  end

  test "only admins can export preview and apply, including direct requests" do
    get carousel_csv_path
    assert_redirected_to new_session_path
    sign_in_as users(:editor)
    [ carousel_csv_path, export_carousel_csv_path ].each do |path|
      get path
      assert_redirected_to root_path
    end
    post preview_carousel_csv_path, params: { csv_text: "name\nNew\n" }
    assert_redirected_to root_path
    post apply_carousel_csv_path, params: { preview_token: "invalid" }
    assert_redirected_to root_path
    assert_equal 1, Carousel.count
  end

  test "admin exports uploads previews and applies with version attribution" do
    sign_in_as users(:admin)
    get carousels_path
    assert_select "a[href=?]", carousel_csv_path
    get export_carousel_csv_path
    assert_response :success
    assert_match %r{text/csv}, response.media_type
    assert_equal "Existing carousel", CSV.parse(response.body, headers: true).first["name"]
    post preview_carousel_csv_path, params: { file: fixture_file_upload("carousel_import.csv", "text/csv") }
    assert_response :success
    assert_select "h2", /Uploaded carousel/
    token = css_select("input[name=preview_token]").first["value"]
    assert_difference "Carousel.count", 1 do
      post apply_carousel_csv_path, params: { preview_token: token }
    end
    assert_redirected_to carousel_csv_path
    carousel = Carousel.find_by!(name: "Uploaded carousel")
    assert_equal "Paris", carousel.city
    assert_equal users(:admin).id.to_s, carousel.versions.last.whodunnit
    post apply_carousel_csv_path, params: { preview_token: token }
    assert_redirected_to carousel_csv_path
    assert_equal 1, Carousel.where(name: "Uploaded carousel").count
  end

  test "invalid rows block the whole batch and tampered tokens do not save" do
    sign_in_as users(:admin)
    post preview_carousel_csv_path, params: { csv_text: "name,official_url\nGood,https://example.com\nBad,javascript:alert(1)\n" }
    assert_response :unprocessable_entity
    assert_select "input[name=preview_token]", count: 0
    assert_select ".alert", /http/
    assert_select "textarea[name=csv_text]", /Good/
    assert_no_difference "Carousel.count" do
      post apply_carousel_csv_path, params: { preview_token: "tampered" }
    end
    assert_redirected_to carousel_csv_path
  end

  test "admins with unaccepted terms cannot import or export" do
    admin = users(:admin)
    admin.update_columns(contribution_terms_version: nil, contribution_terms_accepted_at: nil)
    sign_in_as admin
    get export_carousel_csv_path
    assert_redirected_to edit_contribution_agreement_path
    post preview_carousel_csv_path, params: { csv_text: "name\nNew\n" }
    assert_redirected_to edit_contribution_agreement_path
  end
end
