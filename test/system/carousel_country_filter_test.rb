require "application_system_test_case"

class CarouselCountryFilterTest < ApplicationSystemTestCase
  test "visitors can filter by country and clear the selection" do
    Carousel.create!(name: "Paris Carousel", city: "Paris", country: "France")
    Carousel.create!(name: "London Carousel", city: "London", country: "United Kingdom")

    visit carousels_path
    select "France (1)", from: "Country"
    click_button "Filter"
    assert_selector "select[name=country] option[selected]", text: "France (1)"
    assert_selector ".carousel-count", text: "1 of 2 carousels listed"
    assert_text "Paris Carousel"
    assert_no_text "London Carousel"

    click_link "Clear filters"
    assert_selector :select, "Country", selected: "All countries"
    assert_text "Paris Carousel"
    assert_text "London Carousel"
  end
end
