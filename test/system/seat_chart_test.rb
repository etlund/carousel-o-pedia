require "application_system_test_case"

class SeatChartTest < ApplicationSystemTestCase
  setup { load_seeds }

  test "mini seat charts use ten pixel category dots and open the full chart" do
    visit carousels_path
    assert_selector "svg.mini-seat-chart", count: 5
    within("li.card", text: "Great Northern Carousel") do
      assert_selector "circle.mini-seat-dot", count: 39
      measurements = find("svg.mini-seat-chart").evaluate_script(<<~JS)
        (() => {
          const svg = this;
          const dot = svg.querySelector(".mini-seat-dot.horse");
          return {
            width: svg.getBoundingClientRect().width,
            diameter: dot.getBoundingClientRect().width,
            horse: getComputedStyle(dot).fill,
            other: getComputedStyle(svg.querySelector(".mini-seat-dot.menagerie")).fill,
            chariot: getComputedStyle(svg.querySelector(".mini-seat-dot.chariot")).fill
          };
        })()
      JS
      assert_in_delta 160, measurements.fetch("width"), 1
      assert_in_delta 10, measurements.fetch("diameter"), 1
      assert_equal "rgb(159, 211, 242)", measurements.fetch("horse")
      assert_equal "rgb(247, 184, 102)", measurements.fetch("other")
      assert_equal "rgb(224, 40, 42)", measurements.fetch("chariot")
      find("a.mini-seat-chart-link").click
    end
    assert_selector "h1", text: "Great Northern Carousel"
    assert_selector "svg.seat-chart a.seat", count: 39
    assert_equal "rgb(159, 211, 242)", find("svg.seat-chart .seat.horse", match: :first)
      .evaluate_script("getComputedStyle(this.querySelector('rect, circle')).fill")
    assert_equal "rgb(247, 184, 102)", find("svg.seat-chart .seat.menagerie", match: :first)
      .evaluate_script("getComputedStyle(this.querySelector('rect, circle')).fill")
  end

  test "Glen Echo historical seating is visibly best reading on both charts" do
    visit carousels_path(q: "Glen Echo")
    assert_selector "svg.mini-seat-chart .mini-seat-dot.unsure", count: 54
    assert_selector "svg.mini-seat-chart .chariot.unsure", count: 2
    find("a.mini-seat-chart-link").click
    assert_selector "h1", text: "Glen Echo Park Dentzel Carousel"
    assert_selector "svg.seat-chart a.seat.unsure", count: 54
    assert_text "1994 reference arrangement, not a verified current survey"
    within("table.sections") do
      assert_link "Chariot at 8A"
      assert_link "Chariot at 17A"
      assert_link "Ostrich at 8B"
      assert_link "Ostrich at 8C"
      assert_link "Unidentified horse at 2A"
    end
  end

  test "published counts appear in a single category list with sources retained" do
    visit carousels_path
    within("li.card", text: "Oaks Park Carousel") do
      assert_text "Sections unknown, 3 rows"
      assert_equal [ "24", "26", "4" ], all(".figure-count").map(&:text)
      assert_selector "dl.facts", count: 1
      click_on "Summary sources"
    end
    assert_selector "h1", text: "Oaks Park Carousel"
    assert_no_selector "svg.seat-chart"
    assert_no_selector "table.sections"
    assert_equal [ "24", "26", "4" ], all(".figure-count").map(&:text)
    within("#summary-sources") do
      assert_link "NCA classic wood carousel census", href: "https://carousels.org/USACensus/stdqueries/census-cCLA.html"
      assert_text "two chariots, two tubs"
      assert_text "tagged 2020"
    end
  end

  test "carousel sorting puts researched entries first and works with filters" do
    visit carousels_path
    assert_selector :select, "Sort", selected: "With data first"
    assert_equal [ "A Carousel for Missoula", "Bushnell Park Carousel", "Cafesjian's Carousel", "Dorothea Laub Balboa Park Carousel" ],
      all(".cards h2 a").first(4).map(&:text)

    select "Name (A-Z)", from: "Sort"
    click_on "Filter"
    assert_selector :select, "Sort", selected: "Name (A-Z)"
    assert_equal Carousel.order(:name, :id).pluck(:name), all(".cards h2 a").map(&:text)

    fill_in "Name", with: "looff"
    select "California", from: "State"
    click_on "Filter"
    assert_selector ".cards > li.card", count: 1
    assert_field "Name", with: "looff"
    assert_selector :select, "State", selected: "California"
    assert_selector :select, "Sort", selected: "Name (A-Z)"

    click_on "Clear filters"
    assert_selector ".cards > li.card", count: 54
    assert_selector :select, "Sort", selected: "With data first"
    assert_equal [ "A Carousel for Missoula", "Bushnell Park Carousel", "Cafesjian's Carousel", "Dorothea Laub Balboa Park Carousel" ],
      all(".cards h2 a").first(4).map(&:text)
  end

  test "carousel name and state filters combine retain selections and clear" do
    visit carousels_path
    assert_selector ".cards > li.card", count: 54
    fill_in "Name", with: "lOoFf"
    click_on "Filter"
    assert_selector ".cards > li.card", count: 2
    assert_field "Name", with: "lOoFf"
    assert_selector :select, "State", selected: "All states"

    select "California", from: "State"
    click_on "Filter"
    assert_selector ".cards > li.card", count: 1
    assert_selector ".cards h2", text: "Santa Cruz Beach Boardwalk Looff Carousel"
    assert_field "Name", with: "lOoFf"
    assert_selector :select, "State", selected: "California"

    select "Montana", from: "State"
    click_on "Filter"
    assert_text "No carousels match these filters."
    assert_no_selector ".cards > li.card"
    assert_field "Name", with: "lOoFf"
    assert_selector :select, "State", selected: "Montana"

    click_on "Clear filters"
    assert_selector ".cards > li.card", count: 54
    assert_field "Name", with: ""
    assert_selector :select, "State", selected: "All states"
  end

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
    assert_selector "table tbody tr", count: 260
  end
end
