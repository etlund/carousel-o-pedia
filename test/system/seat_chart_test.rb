require "application_system_test_case"

class SeatChartTest < ApplicationSystemTestCase
  setup { load_seeds }

  test "directory entries show unknown layout until a seating chart is recorded" do
    carousel = Carousel.create!(name: "Directory carousel", city: "Seattle", region: "Washington",
      country: "United States", official_url: "https://example.com/")
    visit carousels_path
    within("li.card", text: carousel.name) do
      assert_text "Layout unknown, operating"
      assert_selector "dl.facts dd", text: "Unknown", count: 3
      assert_link carousel.official_url, href: carousel.official_url
      click_on carousel.name
    end
    assert_selector ".layout-unknown", text: "No seating layout has been recorded yet."
    assert_no_selector "svg.seat-chart"
    assert_no_selector "table.sections"

    carousel.update!(sections_count: 4, rows_count: 2)
    visit carousel_path(carousel)
    assert_selector "svg.seat-chart a.seat.unknown", count: 8
    assert_selector "svg .hub-note", text: "rotation unknown"
    assert_selector "table.sections tbody tr", count: 4
  end

  test "carousel card displays the official URL as a link while the title opens the wiki" do
    carousel = Carousel.find_by!(slug: "great-northern-carousel")
    visit carousels_path
    within("li.card", text: carousel.name) do
      assert_selector "p.muted", text: carousel.location
      assert_no_selector "p.muted a"
      assert_selector "p.website a[href='https://www.greatnortherncarousel.com/']", text: carousel.official_url
      click_on carousel.name
    end
    assert_selector "h1", text: carousel.name
    within(".facts") { assert_link "Official website", href: carousel.official_url }

    visit carousel_path("a-carousel-for-missoula")
    within(".facts") do
      assert_link "Wikipedia", href: "https://en.wikipedia.org/wiki/A_Carousel_for_Missoula"
      assert_link "NCA photo gallery", href: "https://carousels.org/psp/Missoula/"
    end
  end

  test "clicking a seat on the chart opens its seat page" do
    visit carousel_path("great-northern-carousel")
    assert_selector "h1", text: "Great Northern Carousel"

    find("svg.seat-chart a.seat", text: "Gulliver").click

    assert_selector "h1", text: "Seat 9A"
    within(".figure-details") { click_on "Gulliver" }
    assert_selector "h1", text: "Gulliver"
  end

  test "Missoula chart links the riding dragon and spanning chariot" do
    visit carousel_path("a-carousel-for-missoula")
    assert_selector "svg.seat-chart a.seat", count: 40

    find("svg.seat-chart a.seat[href='/carousels/a-carousel-for-missoula/13A']").click
    assert_selector "h1", text: "Seat 13A"
    within(".figure-details") { click_on "Scaffi" }
    assert_selector "h1", text: "Scaffi"
    assert_selector "a[href='https://www.youtube.com/watch?v=8E3DemQtIis&t=109s']", text: "View this section"

    visit carousel_path("a-carousel-for-missoula")
    find("svg.seat-chart a.seat[href='/carousels/a-carousel-for-missoula/7A']").click
    assert_selector "h1", text: "Seat 7A"
    within(".figure-details") { click_on "Altrusa Chariot" }
    assert_selector "h1", text: "Altrusa Chariot"
  end

  test "Spokane chart links its giraffe and spanning chariot to their seats" do
    visit carousel_path("spokane-looff-carrousel")
    assert_selector "svg.seat-chart a.seat", count: 58

    find("svg.seat-chart a.seat[href='/carousels/spokane-looff-carrousel/1B']").click
    assert_selector "h1", text: "Seat 1B"
    within(".figure-details") { click_on "Dragon Chariot 1" }
    assert_selector "h1", text: "Dragon Chariot 1"

    visit carousel_path("spokane-looff-carrousel")
    find("svg.seat-chart a.seat[href='/carousels/spokane-looff-carrousel/1A']").click
    assert_selector "h1", text: "Seat 1A"
    within(".figure-details") { click_on "Geri Giraffe" }
    assert_selector "h1", text: "Geri Giraffe"
  end

  test "figure filters include unseated inventory and carousel inventory links retain the selection" do
    visit figures_path
    select "Salem's Riverfront Carousel", from: "Carousel"
    select "Unicorn", from: "Type"
    click_on "Filter"

    assert_selector "table tbody tr", count: 1
    assert_selector "table tbody tr", text: "Mr. Sprinkles"
    assert_selector "table tbody tr", text: "not currently seated"
    assert_selector :select, "Carousel", selected: "Salem's Riverfront Carousel"
    assert_selector :select, "Type", selected: "Unicorn"

    click_on "Mr. Sprinkles"
    assert_selector ".page-header", text: "Not currently seated"
    within(".page-header") { click_on "Salem's Riverfront Carousel" }
    click_on "View all figures"
    assert_selector "table tbody tr", count: 62
    assert_selector :select, "Carousel", selected: "Salem's Riverfront Carousel"
    assert_selector :select, "Type", selected: "All types"

    click_on "Clear filters"
    assert_selector "table tbody tr", count: 206
  end
end
