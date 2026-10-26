require "application_system_test_case"

class SeatChartTest < ApplicationSystemTestCase
  setup { load_seeds }

  test "carousel favicons follow Turbo navigation and reset to the site icon" do
    icon_selector = "head link[rel='icon'][type='image/svg+xml']"
    visit carousels_path
    assert_selector "#{icon_selector}[href='/icon.svg']", visible: :all, count: 1
    within("li.card", text: "Great Northern Carousel") { click_on "Great Northern Carousel" }
    assert_selector "h1", text: "Great Northern Carousel"
    assert_selector icon_selector, visible: :all, count: 1
    first_icon = find(icon_selector, visible: :all)["href"]
    assert first_icon.start_with?("data:image/svg+xml;base64,")
    assert_includes Base64.strict_decode64(first_icon.split(",", 2).last), 'data-seat-code="4A"'

    click_on "Carousels", match: :first
    assert_selector "h1", text: "Carousels", exact_text: true
    assert_selector icon_selector, visible: :all, count: 1
    assert_selector "#{icon_selector}[href='/icon.svg']", visible: :all

    directory = Carousel.find_by!(slug: "janes-carousel-brooklyn")
    within("li.card", text: directory.name) { click_on directory.name }
    assert_selector "h1", text: directory.name
    assert_selector icon_selector, visible: :all, count: 1
    empty_icon = Base64.strict_decode64(find(icon_selector, visible: :all)["href"].split(",", 2).last)
    assert_includes empty_icon, 'fill="#a9b4c6"'
    assert_includes empty_icon, 'class="empty-favicon"'

    click_on "Carousel-pedia"
    assert_selector "h1", text: "Carousels", exact_text: true
    assert_selector icon_selector, visible: :all, count: 1
    assert_selector "#{icon_selector}[href='/icon.svg']", visible: :all
  end

  test "red SVG and PNG favicons and empty carousel favicons have transparent center holes" do
    visit carousel_path("janes-carousel-brooklyn")
    gray_icon = find("head link[rel='icon'][type='image/svg+xml']", visible: :all)["href"]
    [ [ "/icon.svg", [ 255, 0, 0, 255 ] ], [ "/icon.png", [ 255, 0, 0, 255 ] ], [ gray_icon, [ 169, 180, 198, 255 ] ] ].each do |source, color|
      pixels = page.evaluate_async_script(<<~JS, source)
        const done = arguments[arguments.length - 1];
        const image = new Image();
        image.onload = () => {
          const canvas = document.createElement("canvas");
          canvas.width = canvas.height = 32;
          const context = canvas.getContext("2d");
          context.drawImage(image, 0, 0, 32, 32);
          const pixel = (x, y) => Array.from(context.getImageData(x, y, 1, 1).data);
          done({ center: pixel(16, 16), hole: pixel(18, 16), rim: pixel(16, 6), corner: pixel(0, 0) });
        };
        image.onerror = () => done({ error: "Could not load favicon" });
        image.src = arguments[0];
      JS
      assert_not pixels.key?("error"), pixels["error"]
      assert_equal [ 0, 0, 0, 0 ], pixels.fetch("center")
      assert_equal [ 0, 0, 0, 0 ], pixels.fetch("hole")
      assert_equal color, pixels.fetch("rim")
      assert_equal [ 0, 0, 0, 0 ], pixels.fetch("corner")
    end
  end

  test "physical addresses retain postal zeros and explain venue precision" do
    carousel = Carousel.create!(name: "Address browser test", street_address: "1 Main Street",
      city: "Hull", region: "Massachusetts", postal_code: "02045", country: "United States",
      address_sources: "Visitor entrance, not an exact carousel coordinate.\n\n[Directions](https://example.com/directions)")
    visit carousels_path(q: carousel.name)
    within("li.card") do
      assert_selector "p.muted", text: carousel.location, exact_text: true
      assert_no_text carousel.street_address
      assert_no_text carousel.postal_code
      click_on carousel.name
    end
    assert_selector ".page-header p.address", text: carousel.address
    within("#address-sources") do
      assert_text "Visitor entrance, not an exact carousel coordinate."
      assert_link "Directions", href: "https://example.com/directions"
    end
  end

  test "mini seat charts use base and faded fills with uniform gray outlines and open the full chart" do
    visit carousels_path
    assert_selector "svg.mini-seat-chart", count: 5
    within("li.card", text: "Great Northern Carousel") do
      assert_selector "path.mini-seat-wedge", count: 39
      measurements = find("svg.mini-seat-chart").evaluate_script(<<~JS)
        (() => {
          const svg = this;
          const canvas = document.createElement("canvas");
          canvas.width = canvas.height = 1;
          const context = canvas.getContext("2d");
          const color = value => {
            context.fillStyle = value;
            context.fillRect(0, 0, 1, 1);
            return Array.from(context.getImageData(0, 0, 1, 1).data);
          };
          return {
            width: svg.getBoundingClientRect().width,
            wedges: [...svg.querySelectorAll(".mini-seat-wedge")].map(wedge => {
              const style = getComputedStyle(wedge);
              return {
                category: ["horse", "menagerie", "chariot"].find(category => wedge.classList.contains(category)),
                unsure: wedge.classList.contains("unsure"),
                fill: color(style.fill),
                stroke: color(style.stroke),
                width: style.strokeWidth,
                dash: style.strokeDasharray,
                scaling: style.vectorEffect
              };
            })
          };
        })()
      JS
      assert_in_delta 112, measurements.fetch("width"), 0.1
      fills = {
        "horse" => [ [ 159, 211, 242, 255 ], [ 207, 233, 248.5, 255 ] ],
        "menagerie" => [ [ 247, 184, 102, 255 ], [ 251, 219.5, 178.5, 255 ] ],
        "chariot" => [ [ 224, 40, 42, 255 ], [ 239.5, 147.5, 148.5, 255 ] ]
      }
      measurements.fetch("wedges").each do |wedge|
        expected_fill = fills.fetch(wedge.fetch("category"))[wedge.fetch("unsure") ? 1 : 0]
        expected_fill.zip(wedge.fetch("fill")).each { |expected, actual| assert_in_delta expected, actual, 0.5 }
        assert_equal [ 128, 128, 128, 255 ], wedge.fetch("stroke")
        assert_equal "2px", wedge.fetch("width")
        assert_equal "none", wedge.fetch("dash")
        assert_equal "non-scaling-stroke", wedge.fetch("scaling")
      end
      find("a.mini-seat-chart-link").click
    end
    assert_selector "h1", text: "Great Northern Carousel"
    assert_selector "svg.seat-chart a.seat", count: 39
    assert_equal "rgb(159, 211, 242)", find("svg.seat-chart .seat.horse", match: :first)
      .evaluate_script("getComputedStyle(this.querySelector('rect, circle')).fill")
    assert_equal "rgb(247, 184, 102)", find("svg.seat-chart .seat.menagerie", match: :first)
      .evaluate_script("getComputedStyle(this.querySelector('rect, circle')).fill")
  end

  test "a single section preview draws a complete ring and keeps unknown seats unfilled" do
    carousel = build_carousel(sections: 1, rows: 1)
    visit carousels_path(q: carousel.name)
    wedge = find("svg.mini-seat-chart path.unknown")
    geometry = wedge.evaluate_script(<<~JS)
      (() => ({
        ring: [[200, 0], [-200, 0], [0, 200], [0, -200]].every(([x, y]) => this.isPointInFill(new DOMPoint(x, y))),
        hub: this.isPointInFill(new DOMPoint(0, 0)),
        outside: this.isPointInFill(new DOMPoint(400, 0)),
        fill: getComputedStyle(this).fill,
        stroke: getComputedStyle(this).stroke,
        width: getComputedStyle(this).strokeWidth
      }))()
    JS
    assert geometry.fetch("ring")
    assert_not geometry.fetch("hub")
    assert_not geometry.fetch("outside")
    assert_equal "none", geometry.fetch("fill")
    assert_equal "rgb(128, 128, 128)", geometry.fetch("stroke")
    assert_equal "2px", geometry.fetch("width")
  end

  test "Glen Echo historical seating is visibly best reading on both charts" do
    visit carousels_path(q: "Glen Echo")
    assert_selector "svg.mini-seat-chart .mini-seat-wedge.unsure", count: 54
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
      assert_selector "p.muted", text: carousel.location, exact_text: true
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

    # Selected attributes arrive with Turbo's response, unlike live form values.
    assert_selector "select[name='carousel_id'] option[selected]", text: "Salem's Riverfront Carousel", visible: :all
    assert_selector "select[name='figure_type_id'] option[selected]", text: "Unicorn", visible: :all
    assert_selector "table tbody tr", count: 1
    assert_selector "table tbody tr", text: "Mr. Sprinkles"
    assert_selector "table tbody tr", text: "not currently seated"

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
