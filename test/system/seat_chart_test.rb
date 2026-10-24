require "application_system_test_case"

class SeatChartTest < ApplicationSystemTestCase
  setup { load_seeds }

  test "clicking a seat on the chart opens its seat page" do
    visit carousel_path("great-northern-carousel")
    assert_selector "h1", text: "Great Northern Carousel"

    find("svg.seat-chart a.seat", text: "Gulliver").click

    assert_selector "h1", text: "Seat 9A"
    click_on "Gulliver"
    assert_selector "h1", text: "Gulliver"
  end
end
