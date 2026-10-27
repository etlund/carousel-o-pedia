require "application_system_test_case"

class SeatChartTest < ApplicationSystemTestCase
  setup { load_seeds }

  test "browser-width chart preserves the chart and supports closing and seat navigation" do
    carousel = Carousel.find_by!(slug: "spokane-looff-carrousel")
    visit carousel_path(carousel)
    original_width = find("svg.seat-chart").evaluate_script("this.getBoundingClientRect().width")
    assert find(".chart-inline .mount-legend").evaluate_script("this.getBoundingClientRect().top >= this.previousElementSibling.getBoundingClientRect().bottom")
    click_button "Expand chart"
    assert_selector "dialog[open]"
    assert_button "Close expanded view", exact: true
    assert_selector "button[aria-expanded=true]"
    assert_text "Press Escape to close"
    assert_selector "dialog .legend", text: "Jumper"
    assert find("dialog .mount-legend").evaluate_script("this.getBoundingClientRect().top >= this.previousElementSibling.getBoundingClientRect().bottom")
    assert_selector "dialog a.seat", count: 58
    assert_operator find("svg.seat-chart").evaluate_script("this.getBoundingClientRect().width"), :>, original_width
    assert_in_delta page.evaluate_script("innerWidth"), find("dialog").evaluate_script("this.getBoundingClientRect().width"), 1
    assert_nil page.evaluate_script("document.fullscreenElement")
    page.send_keys [ :shift, :tab ]
    assert page.evaluate_script("document.activeElement.closest('dialog') !== null")
    page.send_keys :tab
    assert_equal "Close expanded view", page.evaluate_script("document.activeElement.textContent.trim()")

    click_button "Close expanded view"
    assert_no_selector "dialog[open]"
    assert_button "Expand chart", exact: true
    assert_equal "Expand chart", page.evaluate_script("document.activeElement.textContent.trim()")
    assert_in_delta original_width, find("svg.seat-chart").evaluate_script("this.getBoundingClientRect().width"), 1

    click_button "Expand chart"
    page.send_keys :escape
    assert_no_selector "dialog[open]"
    assert_button "Expand chart", exact: true

    click_button "Expand chart"
    figure = carousel.seat("1A").figure
    find("dialog a.seat[href='#{figure_path(figure)}']").click
    assert_selector "h1", text: figure.name
    assert_no_selector "dialog[open]"
    page.go_back
    assert_button "Expand chart", exact: true
    assert_no_selector "dialog[open]"
  end

  test "expand control follows the two-column breakpoint and expanded charts remain closable after resizing" do
    page.current_window.resize_to(861, 844)
    visit carousel_path("spokane-looff-carrousel")
    assert_equal 861, page.evaluate_script("innerWidth")
    assert_equal 2, find(".grid").evaluate_script("getComputedStyle(this).gridTemplateColumns.split(' ').length")
    assert_button "Expand chart", exact: true

    page.current_window.resize_to(860, 844)
    assert_equal 860, page.evaluate_script("innerWidth")
    assert_equal 1, find(".grid").evaluate_script("getComputedStyle(this).gridTemplateColumns.split(' ').length")
    assert_no_button "Expand chart"
    assert_selector "svg.seat-chart a.seat", count: 58

    page.current_window.resize_to(390, 844)
    assert_no_button "Expand chart"
    page.current_window.resize_to(861, 844)
    click_button "Expand chart"
    page.current_window.resize_to(390, 844)
    assert_selector "dialog[open]"
    assert_button "Close expanded view", exact: true
    assert_in_delta page.evaluate_script("innerWidth"), find("dialog").evaluate_script("this.getBoundingClientRect().width"), 1
    assert_operator find("svg.seat-chart").evaluate_script("this.getBoundingClientRect().right"), :<=, page.evaluate_script("innerWidth")
    click_button "Close expanded view"
    assert_no_selector "dialog[open]"
    assert_no_button "Expand chart"

    page.current_window.resize_to(1100, 650)
    click_button "Expand chart"
    assert find("dialog").evaluate_script("this.scrollHeight > this.clientHeight")
    page.execute_script("document.querySelector('dialog').scrollTop = 10000")
    close_button = find_button("Close expanded view")
    assert_operator close_button.evaluate_script("this.getBoundingClientRect().top"), :>=, 0
    close_button.click
    assert_no_selector "dialog[open]"
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "Elitch ring research stays separate from mapped seats and supports unequal ring counts" do
    carousel = Carousel.find_by!(slug: "elitch-gardens-carousel-denver")
    visit carousel_path(carousel)
    assert_selector "svg.ring-chart"
    within(".ring-details tr[data-ring=A]") do
      assert_text "18"
      assert_text "Stander"
      assert_text "Unknown"
    end
    assert_no_selector "a.seat, table.sections, .research-position"
    assert_text "not verified angular alignment"

    carousel.update!(ring_details: { "A" => { "positions_count" => 18 }, "B" => { "positions_count" => 16 } })
    visit carousels_path(q: carousel.name)
    within("li.card") do
      assert_selector ".research-ring[data-ring=A] .research-position", count: 18
      assert_selector ".research-ring[data-ring=B] .research-position", count: 16
      assert_no_selector ".research-ring[data-ring=C] .research-position"
      find("a.mini-seat-chart-link").click
    end
    assert_selector "h1", text: carousel.name
    assert_selector "svg.ring-chart .research-position", count: 34
    assert_empty carousel.seats
  end

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

    find("a.brand[aria-label='carousel-o-pedia']").click
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
    assert_selector "svg.mini-seat-chart", count: Carousel.count
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

  test "incomplete mini charts have a gray platform with an open hub and known row boundaries" do
    [ nil, 3 ].each do |rows_count|
      carousel = Carousel.create!(name: "Partial browser preview #{rows_count || 'unknown'}", rows_count:)
      visit carousels_path(q: carousel.name)
      assert_selector "svg.mini-seat-chart", count: 1
      assert_selector "circle.mini-seat-row-divider", count: (rows_count || 1) - 1
      platform = find("path.mini-seat-platform")
      geometry = platform.evaluate_script(<<~JS)
        (() => ({
          ring: [[600, 400], [200, 400], [400, 600], [400, 200]].every(([x, y]) => this.isPointInFill(new DOMPoint(x, y))),
          hub: this.isPointInFill(new DOMPoint(400, 400)),
          outside: this.isPointInFill(new DOMPoint(790, 400)),
          radialSeam: this.isPointInStroke(new DOMPoint(165, 400)),
          fill: getComputedStyle(this).fill,
          stroke: getComputedStyle(this).stroke,
          width: getComputedStyle(this).strokeWidth,
          scaling: getComputedStyle(this).vectorEffect
        }))()
      JS
      assert geometry.fetch("ring")
      assert_not geometry.fetch("hub")
      assert_not geometry.fetch("outside")
      assert_not geometry.fetch("radialSeam")
      assert_equal "rgb(215, 221, 232)", geometry.fetch("fill")
      assert_equal "rgb(128, 128, 128)", geometry.fetch("stroke")
      assert_equal "2px", geometry.fetch("width")
      assert_equal "non-scaling-stroke", geometry.fetch("scaling")
      all("circle.mini-seat-row-divider").each do |divider|
        assert_equal [ "none", "rgb(128, 128, 128)", "2px", "non-scaling-stroke" ],
          divider.evaluate_script("[getComputedStyle(this).fill, getComputedStyle(this).stroke, getComputedStyle(this).strokeWidth, getComputedStyle(this).vectorEffect]")
      end
      find("a.mini-seat-chart-link").click
      assert_selector "h1", text: carousel.name
      assert_no_selector "svg.seat-chart"
    end
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
        radialSeam: this.isPointInStroke(new DOMPoint(-235, 0)),
        fill: getComputedStyle(this).fill,
        stroke: getComputedStyle(this).stroke,
        width: getComputedStyle(this).strokeWidth
      }))()
    JS
    assert geometry.fetch("ring")
    assert_not geometry.fetch("hub")
    assert_not geometry.fetch("outside")
    assert_not geometry.fetch("radialSeam")
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

  test "carousel card charts sit left of facts without overflow at desktop and mobile widths" do
    visit carousels_path
    [ 1400, 940, 390, 320 ].each do |width|
      page.current_window.resize_to(width, 1000)
      # Chrome can clamp window resizing to 500px; enforce the actual viewport.
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
        width:, height: 1000, deviceScaleFactor: 1, mobile: false)
      assert_equal width, page.evaluate_script("innerWidth")
      measurements = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll(".card-seating"), seating => {
          const chart = seating.querySelector(".mini-seat-chart-link").getBoundingClientRect();
          const facts = seating.querySelector(".facts").getBoundingClientRect();
          const bounds = seating.getBoundingClientRect();
          return {
            chartWidth: chart.width,
            chartLeft: chart.left,
            chartRight: chart.right,
            factsLeft: facts.left,
            factsRight: facts.right,
            left: bounds.left,
            right: bounds.right,
            factsFit: Array.from(seating.querySelectorAll("dt, dd")).every(fact => {
              const rect = fact.getBoundingClientRect();
              return rect.left >= facts.left && rect.right <= facts.right && fact.scrollWidth <= fact.clientWidth + 1;
            })
          };
        })
      JS
      assert_equal Carousel.count, measurements.size
      measurements.each do |measurement|
        assert_in_delta 112, measurement.fetch("chartWidth"), 0.1
        assert_operator measurement.fetch("chartRight"), :<, measurement.fetch("factsLeft")
        assert_operator measurement.fetch("chartLeft"), :>=, measurement.fetch("left")
        assert_operator measurement.fetch("factsRight"), :<=, measurement.fetch("right") + 0.1
        assert measurement.fetch("factsFit"), "Facts overflow at #{width}px"
      end
      assert_not page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth"),
        "Page overflows at #{width}px"
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.current_window.resize_to(1400, 1400)
  end

  test "carousel directory does not overflow a mobile viewport with fallback fonts" do
    page.current_window.resize_to(320, 1000)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: 320, height: 1000, deviceScaleFactor: 1, mobile: false)
    visit carousels_path
    assert_equal 320, page.evaluate_script("innerWidth")
    page.execute_script("document.documentElement.style.setProperty('--body', 'system-ui')")

    assert_not page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth"),
      "Page overflows at 320px with fallback fonts"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.current_window.resize_to(1400, 1400)
  end

  test "carousel sorting defaults to most complete and works with filters" do
    latest = Carousel.find_by!(slug: "great-northern-carousel")
    travel_to 1.day.from_now do
      latest.update!(body: "Latest research")
    end
    expected = Carousel.includes(:seats).sort_by do |carousel|
      [ -carousel.seats.count(&:confirmed?), -carousel.seats.count { !_1.confirmed? },
        carousel.rows_count || carousel.sections_count ? 0 : 1, carousel.name, carousel.id ]
    end.map(&:name)
    visit carousels_path
    assert_selector :select, "Sort", selected: "Most complete"
    assert_carousel_order expected

    select "Last updated", from: "Sort"
    click_on "Filter"
    assert_carousel_filters sort: "updated"
    assert_selector :select, "Sort", selected: "Last updated"
    assert_selector ".cards > li:first-child h2 a", exact_text: latest.name

    select "Name (A-Z)", from: "Sort"
    click_on "Filter"
    assert_carousel_filters sort: "name"
    assert_selector :select, "Sort", selected: "Name (A-Z)"
    assert_carousel_order Carousel.order(:name, :id).pluck(:name)

    select "Most complete", from: "Sort"
    click_on "Filter"
    assert_carousel_filters sort: "completeness"
    assert_selector :select, "Sort", selected: "Most complete"
    assert_selector ".seating-completeness", count: Carousel.count
    assert_carousel_order expected

    fill_in "Name", with: "looff"
    california_option = "California (#{Carousel.where(region: 'California').count})"
    select california_option, from: "State"
    click_on "Filter"
    assert_carousel_filters q: "looff", region: "California", sort: "completeness"
    assert_selector ".cards > li.card", count: 1
    assert_field "Name", with: "looff"
    assert_selector :select, "State", selected: california_option
    assert_selector :select, "Sort", selected: "Most complete"

    select "Last updated", from: "Sort"
    click_on "Filter"
    assert_carousel_filters q: "looff", region: "California", sort: "updated"
    assert_selector ".cards > li.card", count: 1
    assert_field "Name", with: "looff"
    assert_selector :select, "State", selected: california_option
    assert_selector :select, "Sort", selected: "Last updated"

    click_on "Clear filters"
    assert_current_path carousels_path
    assert_selector ".cards > li.card", count: 54
    assert_selector :select, "Sort", selected: "Most complete"
    assert_carousel_order expected
  end

  test "carousel name and state filters combine retain selections and clear" do
    visit carousels_path
    assert_selector ".cards > li.card", count: 54
    fill_in "Name", with: "lOoFf"
    click_on "Filter"
    assert_selector ".cards > li.card", count: 2
    assert_field "Name", with: "lOoFf"
    assert_selector :select, "State", selected: "All states"

    california_option = "California (#{Carousel.where(region: 'California').count})"
    select california_option, from: "State"
    click_on "Filter"
    assert_selector ".cards > li.card", count: 1
    assert_selector ".cards h2", text: "Santa Cruz Beach Boardwalk Looff Carousel"
    assert_field "Name", with: "lOoFf"
    assert_selector :select, "State", selected: california_option

    select "Montana (2)", from: "State"
    click_on "Filter"
    assert_text "No carousels match these filters."
    assert_no_selector ".cards > li.card"
    assert_field "Name", with: "lOoFf"
    assert_selector :select, "State", selected: "Montana (2)"

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

  test "clicking an occupied seat opens its canonical figure page directly" do
    visit carousel_path("great-northern-carousel")
    assert_selector "h1", text: "Great Northern Carousel"

    find("svg.seat-chart a.seat", text: "Gulliver").click

    assert_selector "h1", text: "Gulliver"
    assert_current_path figure_path(Figure.find_by!(name: "Gulliver"))
    assert_selector ".seat-context h2", text: "Current seat"
    assert_selector ".seat-context svg.seat-badge[aria-label='Seat 9A']"
    assert_selector ".seat-context dd", text: "Section 9, row A", exact_text: true
    assert_no_selector ".seat-context dt", text: "Seat", exact_text: true
  end

  test "all seat badge wedges have gray outlines regardless of category or state" do
    carousel = Carousel.find_by!(slug: "great-northern-carousel")
    categories = %w[ horse menagerie chariot ]
    visit figures_path(carousel_id: carousel.id)
    categories.each { |category| assert_selector "svg.seat-badge.small.#{category}" }
    assert_equal [ "rgb(128, 128, 128)" ], page.evaluate_script(<<~JS)
      Array.from(new Set(Array.from(document.querySelectorAll(".seat-badge .band"),
        band => getComputedStyle(band).stroke)))
    JS

    unassigned = build_carousel(rows: 3)
    unassigned.seat("1A").update!(state: "empty")
    paths = categories.map do |category|
      figure = carousel.seats.find { |seat| seat.category == category }.figure
      [ figure_path(figure), category ]
    end
    paths += [ [ carousel_seat_path(unassigned, unassigned.seat("1A")), "empty" ],
      [ carousel_seat_path(unassigned, unassigned.seat("1B")), "unknown" ] ]

    paths.each do |path, kind|
      visit path
      badge = find("svg.seat-badge.large.#{kind}")
      strokes = badge.evaluate_script(<<~JS)
        Array.from(this.querySelectorAll(".band"), band => {
          const style = getComputedStyle(band);
          return { color: style.stroke, width: style.strokeWidth, dash: style.strokeDasharray,
            active: band.classList.contains("on") };
        })
      JS
      assert_equal [ "rgb(128, 128, 128)" ], strokes.map { |stroke| stroke.fetch("color") }.uniq
      assert_equal [ "0.75px" ], strokes.map { |stroke| stroke.fetch("width") }.uniq
      strokes.each do |stroke|
        dashed = %w[ empty unknown ].include?(kind) && stroke.fetch("active")
        assert_equal dashed ? "2px, 1.5px" : "none", stroke.fetch("dash")
      end
    end
  end

  test "seat numbers fit to the left of the wedge in large and small badges" do
    carousel = build_carousel(sections: 120, rows: 1)
    seat = carousel.seat("120A")
    figure = create_figure("Wide seat number", carousel:)
    SeatAssignment.new(seat, figure).save!

    [ figure_path(figure), figures_path(carousel_id: carousel.id) ].each do |path|
      visit path
      badge = find("svg.seat-badge[aria-label='Seat 120A']")
      positions = badge.evaluate_script(<<~JS)
        (() => {
          const number = this.querySelector("text.section").getBoundingClientRect();
          const wedge = this.querySelector("g").getBoundingClientRect();
          const badge = this.getBoundingClientRect();
          const band = this.querySelector("path.band");
          const points = band.getAttribute("d").match(/^M([^ ]+) ([^ ]+) L([^ ]+) ([^ ]+)/).slice(1).map(Number);
          const inner = new DOMPoint(points[0], points[1]).matrixTransform(band.getScreenCTM());
          const outer = new DOMPoint(points[2], points[3]).matrixTransform(band.getScreenCTM());
          return { numberLeft: number.left, numberRight: number.right,
            wedgeLeft: wedge.left, wedgeRight: wedge.right, left: badge.left, right: badge.right,
            innerX: inner.x, outerX: outer.x, innerY: inner.y, outerY: outer.y,
            textScale: this.querySelector("text.row").getScreenCTM().a };
        })()
      JS
      assert_operator positions.fetch("numberLeft"), :>=, positions.fetch("left")
      assert_operator positions.fetch("numberRight"), :<, positions.fetch("wedgeLeft")
      assert_operator positions.fetch("wedgeRight"), :<=, positions.fetch("right")
      assert_operator positions.fetch("outerX"), :<, positions.fetch("innerX")
      assert_operator positions.fetch("outerY"), :<, positions.fetch("innerY")
      assert_operator positions.fetch("textScale"), :>, 0
    end
  end

  test "occupied seat bookmarks open figure content and stack seat context on narrow screens" do
    seat = Carousel.find_by!(slug: "great-northern-carousel").seat("9A")
    seat.figure.update!(body: "## About Gulliver\n\nFigure notes stay ahead of the placement details.")
    visit carousel_seat_path(seat.carousel, seat)
    assert_current_path figure_path(seat.figure)
    assert_selector ".figure-details .prose h2", text: "About Gulliver"

    measurements = -> {
      page.evaluate_script(<<~JS)
        (() => {
          const figure = document.querySelector(".figure-details").getBoundingClientRect();
          const seat = document.querySelector(".seat-context").getBoundingClientRect();
          return { figureRight: figure.right, figureBottom: figure.bottom, figureWidth: figure.width,
            seatLeft: seat.left, seatTop: seat.top, seatWidth: seat.width,
            overflow: document.documentElement.scrollWidth > document.documentElement.clientWidth };
        })()
      JS
    }
    desktop = measurements.call
    assert_operator desktop.fetch("seatLeft"), :>, desktop.fetch("figureRight")
    assert_operator desktop.fetch("figureWidth"), :>, desktop.fetch("seatWidth") * 1.5

    page.driver.browser.manage.window.resize_to(390, 844)
    mobile = measurements.call
    assert_operator mobile.fetch("seatTop"), :>=, mobile.fetch("figureBottom")
    assert_not mobile.fetch("overflow")
    assert_selector ".seat-context svg.seat-badge[aria-label='Seat 9A']"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "Missoula chart links the riding dragon and spanning chariot" do
    visit carousel_path("a-carousel-for-missoula")
    assert_selector "svg.seat-chart a.seat", count: 40

    scaffi = Figure.find_by!(slug: "a-carousel-for-missoula-scaffi")
    find("svg.seat-chart a.seat[href='#{figure_path(scaffi)}']").click
    assert_selector "h1", text: "Scaffi"
    assert_selector ".seat-context svg.seat-badge[aria-label='Seat 13A']"
    assert_current_path figure_path(scaffi)
    assert_selector "a[href='https://www.youtube.com/watch?v=8E3DemQtIis&t=109s']", text: "View this section"

    visit carousel_path("a-carousel-for-missoula")
    seat = Carousel.find_by!(slug: "a-carousel-for-missoula").seat("7A")
    find("svg.seat-chart a.seat[href='#{figure_path(seat.figure)}']").click
    assert_selector "h1", text: "Altrusa Chariot"
    assert_selector ".seat-context svg.seat-badge[aria-label='Seat 7A']"
    assert_selector ".seat-context dd", text: "Section 7, rows #{seat.rows_covered.first} to #{seat.rows_covered.last}"
    assert_current_path figure_path(seat.figure)
  end

  test "Spokane chart links its giraffe and spanning chariot to their seats" do
    visit carousel_path("spokane-looff-carrousel")
    assert_selector "svg.seat-chart a.seat", count: 58

    carousel = Carousel.find_by!(slug: "spokane-looff-carrousel")
    chariot = carousel.seat("1B").figure
    find("svg.seat-chart a.seat[href='#{figure_path(chariot)}']").click
    assert_selector "h1", text: "Dragon Chariot 1"
    assert_selector ".seat-context svg.seat-badge[aria-label='Seat 1B']"
    assert_current_path figure_path(chariot)

    visit carousel_path("spokane-looff-carrousel")
    giraffe = carousel.seat("1A").figure
    find("svg.seat-chart a.seat[href='#{figure_path(giraffe)}']").click
    assert_selector "h1", text: "Geri Giraffe"
    assert_selector ".seat-context svg.seat-badge[aria-label='Seat 1A']"
    assert_current_path figure_path(giraffe)
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
    assert_selector "table tbody tr", count: Figure.count
  end

  private

  def assert_carousel_filters(sort:, q: "", region: "")
    assert_current_path carousels_path, ignore_query: true do |uri|
      Rack::Utils.parse_query(uri.query) == { "q" => q, "region" => region, "sort" => sort, "commit" => "Filter" }
    end
  end

  def assert_carousel_order(names)
    # Retry the whole comparison if Turbo replaces the list while it is being read.
    assert_selector ".cards" do |cards|
      cards.all("h2 a").map(&:text) == names
    end
  end
end
