require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  setup { @carousel = load_seeds }

  test "site header uses the red ring for the middle o and links home with the full accessible name" do
    get root_path
    assert_response :success
    assert_select "meta[name='application-name'][content='carousel-o-pedia']", 1
    assert_select ".site-header a.brand[href=?][aria-label='carousel-o-pedia']", root_path do
      assert_select "span:first-child", text: "carousel-"
      assert_select "img[src='/icon.svg'][alt=''][width='20'][height='20']", 1
      assert_select "span:last-child", text: "-pedia"
    end
  end

  test "carousel cards preview complete layouts using current figure categories" do
    get carousels_path
    assert_response :success
    assert_select "svg.mini-seat-chart", Carousel.count
    assert_select ".card-seating > a.mini-seat-chart-link + dl.facts", Carousel.count
    {
      "great-northern-carousel" => [ 18, 19, 2 ],
      "a-carousel-for-missoula" => [ 37, 1, 2 ],
      "spokane-looff-carrousel" => [ 54, 2, 2 ],
      "salems-riverfront-carousel" => [ 24, 8, 2 ],
      "glen-echo-dentzel-carousel" => [ 40, 12, 2 ]
    }.each do |slug, counts|
      assert_select "li.card:has(h2 a[href='#{carousel_path(slug)}'])" do
        assert_select "a.mini-seat-chart-link[href=?][aria-label=?]", carousel_path(slug),
          "View seating chart for #{Carousel.find_by!(slug:).name}"
        assert_select "svg.mini-seat-chart[role=img][width='112'][height='112']" do
          assert_select "path.mini-seat-wedge", counts.sum
          %w[ horse menagerie chariot ].zip(counts).each do |category, count|
            assert_select "path.mini-seat-wedge.#{category}", count
          end
          assert_select "text, rect, circle", 0
        end
      end
    end
    assert_select "li.card:has(h2 a[href='#{carousel_path('janes-carousel-brooklyn')}']) svg.mini-seat-chart", 1
    assert_select "li.card:has(h2 a[href='#{carousel_path('flying-horses-carousel-oak-bluffs')}']) svg.mini-seat-chart", 1

    assert_select "a.mini-seat-chart-link[href=?] path[data-seat-code='4A'] title", carousel_path(@carousel),
      text: "4A: #{@carousel.seat("4A").figure.name}"
    get carousel_path(@carousel)
    assert_select "svg.seat-chart a[href=?] > circle", figure_path(@carousel.seat("4A").figure), count: 1
  end

  test "mini charts show platform outlines for unknown layouts and evenly spaced rings for known rows" do
    layouts = [ {}, { sections_count: 12 } ] + (1..Carousel::MAX_ROWS).map { |rows_count| { rows_count: } }
    layouts.each_with_index do |layout, index|
      carousel = Carousel.create!(name: "Partial preview #{index}", **layout)

      get carousels_path, params: { q: carousel.name }
      assert_response :success
      assert_select "a.mini-seat-chart-link[href=?][aria-label=?]", carousel_path(carousel),
        "View carousel details for #{carousel.name}" do
        assert_select "svg.mini-seat-chart[role=img][width='112'][height='112']" do |charts|
          description = carousel.rows_count ? "#{carousel.rows_count} #{'row'.pluralize(carousel.rows_count)} shown as concentric rings" : "Layout unknown"
          assert_includes charts.first["aria-label"], description
          assert_select "path.mini-seat-platform", 1
          assert_select "path.mini-seat-wedge, text, rect", 0
          assert_select "circle.mini-seat-row-divider", (carousel.rows_count || 1) - 1
          css_select("circle.mini-seat-row-divider").each_with_index do |circle, row|
            assert_equal "400", circle["cx"]
            assert_equal "400", circle["cy"]
            assert_in_delta 100 + (row + 1) * 270.0 / carousel.rows_count, circle["r"].to_f
          end
        end
      end
      assert_empty carousel.seats
      get carousel_path(carousel)
      assert_response :success
      assert_select "svg.seat-chart", 0
    end
  end

  test "mini charts represent spanning vehicles once and retain unknown and empty positions" do
    carousel = build_carousel(sections: 2, rows: 3)
    carousel.seat("1A").update!(rows_spanned: 2)
    SeatAssignment.new(carousel.seat("1A"), create_figure("Preview vehicle", category: "chariot", carousel:)).save!
    SeatAssignment.new(carousel.seat("2C"), create_figure("Former horse", category: "horse", carousel:)).save!
    SeatAssignment.new(carousel.seat("2C"), nil, empty: true).save!

    get carousels_path
    assert_response :success
    assert_select "a.mini-seat-chart-link[href='#{carousel_path(carousel)}']" do
      assert_select "path.mini-seat-wedge", 5
      assert_select "path.chariot.unsure[data-seat-code='1A'][transform='translate(400 400) rotate(-90.0)']", 1
      assert_select "path[data-seat-code='1B']", 0
      assert_select "path.unknown", 3
      assert_select "path.empty[data-seat-code='2C']", 1
      assert_select "path.chariot title", "1A: Preview vehicle"
      assert_select "path.horse", 0
    end
  end

  test "carousel counts show each category once preferring published totals with mapped fallbacks" do
    carousel = Carousel.create!(name: "Summary facts", rows_count: 3,
      published_horses_count: 48, published_other_animals_count: 0,
      summary_sources: "[Operator](https://example.com/) reports 48 horses.\n<script>alert('summary')</script>")
    get carousels_path
    assert_response :success
    assert_select "li.card:has(h2 a[href='#{carousel_path(carousel)}'])" do |cards|
      assert_select "p", text: "Sections unknown, 3 rows, operating"
      assert_equal [ "48", "0", "Unknown" ], cards.first.css(".figure-count").map(&:text)
      assert_equal [ "Horses", "Other animals", "Chariots and tubs" ], cards.first.css(".facts dt").map(&:text)
      assert_select "a[href=?]", carousel_path(carousel, anchor: "summary-sources"), text: "Summary sources"
    end
    get carousel_path(carousel)
    assert_response :success
    assert_select "svg.seat-chart", 0
    assert_select ".facts dd", text: "Sections unknown, 3 rows"
    assert_equal [ "48", "0", "Unknown" ], css_select(".figure-count").map(&:text)
    assert_select "#summary-sources a[href=?]", "https://example.com/", text: "Operator"
    assert_select "#summary-sources script", 0

    carousel.update!(sections_count: 2)
    SeatAssignment.new(carousel.seat("1A"), create_figure("Mapped horse", carousel:)).save!
    SeatAssignment.new(carousel.seat("1B"), create_figure("Mapped animal", category: "menagerie", carousel:)).save!
    SeatAssignment.new(carousel.seat("2A"), create_figure("Mapped chariot", category: "chariot", carousel:)).save!
    get carousel_path(carousel)
    assert_select "svg.seat-chart", 1
    assert_equal [ "48", "0", "1" ], css_select(".figure-count").map(&:text)
    [ "Horses", "Other animals", "Chariots and tubs" ].each { |label| assert_select ".facts dt", text: label, count: 1 }
    assert_equal 1, carousel.category_totals["horse"]
    assert_equal 1, carousel.category_totals["menagerie"]

    get carousels_path, params: { q: carousel.name }
    assert_equal [ "48", "0", "1" ], css_select(".figure-count").map(&:text)
    carousel.update!(published_horses_count: nil)
    get carousel_path(carousel)
    assert_equal [ "1", "0", "1" ], css_select(".figure-count").map(&:text)
  end

  test "carousels default to last updated and support a retained alphabetical sort" do
    travel_to 1.day.from_now do
      @carousel.update!(body: "Recently researched carousel")
    end
    get carousels_path
    assert_response :success
    assert_equal @carousel.name, css_select(".cards h2 a").first.text
    assert_select "select[name=sort] option[selected][value=updated]"
    assert_equal %w[ name updated completeness ], css_select("select[name=sort] option").map { _1["value"] }

    get carousels_path, params: { sort: "name" }
    assert_response :success
    assert_equal Carousel.order(:name, :id).pluck(:name), css_select(".cards h2 a").map(&:text)
    assert_select "select[name=sort] option[selected][value=name]"
  end

  test "last updated and alphabetical sorts work with combined filters and unseated inventory" do
    directory = Carousel.create!(name: "Sort check A Directory", region: "Montana")
    inventory = Carousel.create!(name: "Sort check Z Inventory", region: "Montana")
    travel_to 1.day.from_now do
      create_figure("Unseated reserve", carousel: inventory)
    end
    Carousel.create!(name: "Sort check Another state", region: "California")

    [ [ "updated", [ inventory.name, directory.name ] ], [ "name", [ directory.name, inventory.name ] ] ].each do |sort, expected|
      get carousels_path, params: { q: "Sort check", region: "Montana", sort: }
      assert_response :success
      assert_equal expected, css_select(".cards h2 a").map(&:text)
      assert_select "input[name=q][value='Sort check']"
      assert_select "select[name=region] option[selected][value=Montana]"
      assert_select "select[name=sort] option[selected][value=?]", sort
    end

    %w[ name updated completeness ].each do |sort|
      get carousels_path, params: { q: "No matching carousel", sort: }
      assert_response :success
      assert_select "main p", "No carousels match these filters."
      assert_select "select[name=sort] option[selected][value=?]", sort
    end
  end

  test "completeness sort retains filters and cards describe each level of seating knowledge" do
    leader = build_carousel
    leader.update!(name: "Confirmed sort A Leader", region: "Montana")
    leader.seat("1A").update!(confidence: "confirmed")
    leader.seat("1B").update!(confidence: "confirmed", state: "empty")
    runner_up = build_carousel(sections: 5)
    runner_up.update!(name: "Confirmed sort ZZ Runner up", region: "Montana")
    runner_up.seat("1A").update!(confidence: "confirmed")
    estimated = build_carousel
    estimated.update!(name: "Confirmed sort Z Estimated", region: "Montana")
    partial = Carousel.create!(name: "Confirmed sort ZZ Partial", rows_count: 3, region: "Montana")
    directory = Carousel.create!(name: "Confirmed sort 0 Directory", region: "Montana")
    excluded = build_carousel
    excluded.update!(name: "Confirmed sort Another state", region: "California")
    excluded.seats.each { _1.update!(confidence: "confirmed") }

    get carousels_path, params: { q: "Confirmed sort", region: "Montana", sort: "completeness" }
    assert_response :success
    assert_equal [ leader.name, runner_up.name, estimated.name, partial.name, directory.name ], css_select(".cards h2 a").map(&:text)
    assert_select "input[name=q][value='Confirmed sort']"
    assert_select "select[name=region] option[selected][value=Montana]"
    assert_select "select[name=sort] option[selected][value=completeness]", text: "Most complete"
    {
      leader => "2 confirmed \u00b7 6 best reading",
      runner_up => "1 confirmed \u00b7 9 best reading",
      estimated => "0 confirmed \u00b7 8 best reading",
      partial => "3 rows recorded \u00b7 sections unknown",
      directory => "Layout unknown"
    }.each do |carousel, summary|
      assert_select "li.card:has(h2 a[href='#{carousel_path(carousel)}']) .seating-completeness",
        text: "Seating completeness: #{summary}"
    end

    leader.seat("1B").update!(confidence: "best_reading")
    get carousels_path, params: { q: "Confirmed sort", region: "Montana", sort: "completeness" }
    assert_response :success
    assert_equal [ runner_up.name, leader.name, estimated.name, partial.name, directory.name ], css_select(".cards h2 a").map(&:text)
    assert_select "li.card:has(h2 a[href='#{carousel_path(leader)}']) .seating-completeness",
      text: "Seating completeness: 1 confirmed \u00b7 7 best reading"
  end

  test "previous confirmed seat sort URLs select the renamed completeness sort" do
    get carousels_path, params: { sort: "confirmed_seats" }
    assert_response :success
    assert_select "select[name=sort] option[selected][value=completeness]", text: "Most complete"
    assert_select "select[name=sort] option[value=confirmed_seats]", 0
  end

  test "carousel sort defaults on blank input and rejects invalid selections" do
    get carousels_path, params: { sort: " " }
    assert_response :success
    assert_select "select[name=sort] option[selected][value=updated]"

    [ "unknown", "data_first", "name DESC", [ "name" ], { order: "name" } ].each do |sort|
      get carousels_path, params: { sort: }
      assert_response :bad_request
    end
  end

  test "carousel name search is case insensitive partial and retains its value" do
    get carousels_path, params: { q: "  lOoFf  ", sort: "name" }
    assert_response :success
    assert_equal [ "Looff Carrousel", "Santa Cruz Beach Boardwalk Looff Carousel" ], css_select(".cards h2 a").map(&:text)
    assert_select "input[type=search][name=q][value=?]", "lOoFf"
    assert_select "form[action=?][method=get]", carousels_path
    assert_select "a[href=?]", carousels_path, text: "Clear filters"

    get carousels_path, params: { q: "CAFESJIAN'S" }
    assert_response :success
    assert_equal [ "Cafesjian's Carousel" ], css_select(".cards h2 a").map(&:text)
  end

  test "carousel state filter combines with name and retains all state options" do
    get carousels_path, params: { region: "Montana", sort: "name" }
    assert_response :success
    assert_equal [ "A Carousel for Missoula", "Great Northern Carousel" ], css_select(".cards h2 a").map(&:text)
    assert_select "select[name=region] option[selected][value=Montana]"
    assert_select "select[name=region] option[value=Montana]", 1
    assert_select "select[name=region] option[value='New York']", text: "New York"
    assert_select "select[name=region] option[value='']", text: "All states"
    assert_equal [ 18, 19, 2 ].map(&:to_s), css_select("li.card:has(h2 a[href='#{carousel_path(@carousel)}']) .facts dd").map(&:text)

    get carousels_path, params: { q: "carousel", region: "New York", sort: "name" }
    assert_response :success
    expected = [ "Eldridge Park Carousel", "Greenport Carousel", "Jane's Carousel", "Seabreeze Carousel" ]
    assert_equal expected, css_select(".cards h2 a").map(&:text)
    assert_select "input[name=q][value=carousel]"
    assert_select "select[name=region] option[selected][value='New York']"
    assert_select "select[name=region] option[value=Montana]"
  end

  test "carousel filters support empty results and blank filters" do
    get carousels_path, params: { q: "looff", region: "Montana" }
    assert_response :success
    assert_select "main p", "No carousels match these filters."
    assert_select ".cards li", 0
    assert_select "input[name=q][value=looff]"
    assert_select "select[name=region] option[selected][value=Montana]"

    get carousels_path, params: { q: "   ", region: "" }
    assert_response :success
    assert_select ".cards li", 54
    assert_equal "", css_select("input[name=q]").first["value"].to_s
  end

  test "carousel search treats SQL wildcard characters literally" do
    special = Carousel.create!(name: "100% Fun_Ride! Carousel", slug: "literal-search-test")
    [ "100%", "Fun_", "Ride!" ].each do |query|
      get carousels_path, params: { q: query }
      assert_response :success
      assert_equal [ special.name ], css_select(".cards h2 a").map(&:text)
    end
    get carousels_path, params: { q: "' OR 1=1 --" }
    assert_response :success
    assert_select ".cards li", 0
  end

  test "invalid carousel filter shapes and unknown states return explicit errors" do
    get carousels_path, params: { region: "Not a state" }
    assert_response :not_found
    [ { q: [ "Carousel" ] }, { q: { name: "Carousel" } }, { region: [ "Montana" ] }, { region: { name: "Montana" } } ].each do |filters|
      get carousels_path, params: filters
      assert_response :bad_request
    end
  end

  test "page titles escape special characters once without allowing HTML" do
    carousel = Carousel.find_by!(slug: "janes-carousel-brooklyn")
    [ "Jane's Carousel", 'A & B <Carousel> "Ride"', "</title><script>alert('title')</script>" ].each do |name|
      carousel.update!(name:)
      get carousel_path(carousel)
      assert_response :success
      assert_select "head > title", count: 1, text: "#{name} · carousel-o-pedia"
      assert_select "script", text: "alert('title')", count: 0
    end
  end

  test "directory carousel pages and cards distinguish unknown layout and counts from zero" do
    carousel = Carousel.create!(name: "Directory carousel", city: "Seattle", region: "Washington",
      country: "United States", official_url: "https://example.com/")
    get carousels_path
    assert_response :success
    assert_select "li.card:has(h2 a[href='#{carousel_path(carousel)}'])" do |cards|
      assert_select "p", text: "Layout unknown, operating"
      assert_select "p.muted", text: carousel.location
      assert_select "p.website a.website-link[href=?]", carousel.official_url, text: carousel.official_url
      assert_equal [ "Unknown" ] * 3, cards.first.css("dl.facts dd").map(&:text)
    end

    get carousel_path(carousel)
    assert_response :success
    assert_select ".layout-unknown", "No seating layout has been recorded yet."
    assert_select "svg.seat-chart", 0
    assert_select "table.sections", 0
    assert_select ".facts dt", text: "Platform"
    assert_select ".facts dd", text: "Unknown", count: 5
    assert_select ".facts a.website-link[href=?]", carousel.official_url, text: "Official website"
    assert_select "a[href=?]", figures_path(carousel_id: carousel.id), text: "View all figures"

    get carousel_seat_path(carousel, "1A")
    assert_response :not_found
  end

  test "a known layout with unknown rotation does not invent a direction" do
    carousel = build_carousel
    get carousel_path(carousel)
    assert_response :success
    assert_select "svg .hub-note", "rotation unknown"
    assert_select ".facts dd", text: "Unknown", count: 1
  end

  test "carousel summary cards show category counts including zeros" do
    empty_carousel = build_carousel
    get carousels_path
    assert_response :success

    {
      "great-northern-carousel" => [ 18, 19, 2 ],
      "a-carousel-for-missoula" => [ 37, 1, 2 ],
      "spokane-looff-carrousel" => [ 54, 2, 2 ],
      "salems-riverfront-carousel" => [ 24, 8, 2 ],
      empty_carousel.slug => [ 0, 0, 0 ]
    }.each do |slug, counts|
      assert_select "li.card:has(h2 a[href='#{carousel_path(slug)}'])" do |cards|
        assert_equal [ "Horses", "Other animals", "Chariots and tubs" ], cards.first.css("dl.facts dt").map(&:text)
        assert_equal counts.map(&:to_s), cards.first.css("dl.facts dd").map(&:text)
      end
    end
  end

  test "carousel cards show linked official URLs separately from plain locations while titles stay internal" do
    plain = build_carousel
    plain.update!(city: "Plain City", region: "Oregon", country: "United States", wikipedia_url: "https://en.wikipedia.org/wiki/Example")
    no_location = build_carousel
    no_location.update!(official_url: "https://example.com/")

    get carousels_path
    assert_response :success
    Carousel.where.not(official_url: nil).each do |carousel|
      assert_select "li.card:has(h2 a[href='#{carousel_path(carousel)}'])" do
        assert_select "h2 a[href=?]", carousel_path(carousel), text: carousel.name
        assert_select "p.muted", text: carousel.location do
          assert_select "a", 0
        end
        assert_select "p.website a[href=?]", carousel.official_url, text: carousel.official_url
      end
    end
    assert_select "li.card:has(h2 a[href='#{carousel_path(plain)}']) p.muted" do
      assert_select "a", 0
      assert_select "p", text: plain.location
    end
    assert_select "li.card:has(h2 a[href='#{carousel_path(plain)}']) p.website", 0
  end

  test "carousel details show optional website links and sanitized named additional links" do
    carousel = build_carousel
    carousel.update!(
      official_url: "https://example.com/official",
      wikipedia_url: "https://en.wikipedia.org/wiki/Example",
      other_links: "[NCA gallery](https://carousels.org/)\n[Local history](https://example.com/history)\n[Unsafe](javascript:alert(1))\n<script>alert('unsafe')</script>"
    )
    get carousel_path(carousel)
    assert_response :success
    assert_select ".facts a[href=?]", carousel.official_url, text: "Official website"
    assert_select ".facts a[href=?]", carousel.wikipedia_url, text: "Wikipedia"
    assert_select ".facts .prose a[href=?]", "https://carousels.org/", text: "NCA gallery"
    assert_select ".facts .prose a[href=?]", "https://example.com/history", text: "Local history"
    assert_select ".facts .prose script", 0
    assert_select ".facts .prose a[href^='javascript:']", 0

    get carousel_path(build_carousel)
    assert_response :success
    [ "Website", "Wikipedia", "Other links" ].each { assert_select ".facts dt", text: _1, count: 0 }
  end

  test "carousel addresses display as escaped text with sanitized source notes" do
    carousel = build_carousel
    carousel.update!(street_address: '1 Main & <script>alert("address")</script>',
      city: "Hull", region: "Massachusetts", postal_code: "02045", country: "United States",
      address_sources: "[Visitor directions](https://example.com/directions)\n<script>alert('source')</script>")
    get carousels_path
    assert_response :success
    assert_select "li.card:has(h2 a[href='#{carousel_path(carousel)}']) p.muted", text: carousel.location do
      assert_select "script, a", 0
      assert_select "p", text: /1 Main|02045/, count: 0
    end
    get carousel_path(carousel)
    assert_response :success
    assert_select ".page-header p.address", text: carousel.address
    assert_select ".page-header script", 0
    assert_select "#address-sources a[href=?]", "https://example.com/directions", text: "Visitor directions"
    assert_select "#address-sources script", 0
    get carousel_path(build_carousel)
    assert_select "#address-sources", 0
  end

  test "carousel summary counts exclude ended and unplaced figures and count spanning figures once" do
    carousel = build_carousel(sections: 3, rows: 2)
    horse = create_figure("Moving horse")
    SeatAssignment.new(carousel.seat("2A"), horse).save!
    SeatAssignment.new(carousel.seat("3A"), horse).save!
    animal = create_figure("Removed animal", category: "menagerie")
    SeatAssignment.new(carousel.seat("2B"), animal).save!
    SeatAssignment.new(carousel.seat("2B"), nil).save!
    carousel.seat("1A").update!(rows_spanned: 2)
    SeatAssignment.new(carousel.seat("1A"), create_figure("Spanning tub", category: "chariot")).save!
    create_figure("Unplaced spare")

    get carousels_path
    assert_response :success
    assert_select "li.card:has(h2 a[href='#{carousel_path(carousel)}'])" do |cards|
      assert_equal [ "1", "0", "1" ], cards.first.css("dl.facts dd").map(&:text)
    end
  end

  test "Salem pages show saved video assignments and distinguish the full catalog" do
    carousel = Carousel.find_by!(slug: "salems-riverfront-carousel")
    get carousel_path(carousel)
    assert_response :success
    assert_select "svg.seat-chart a.seat", 34
    assert_select "svg.seat-chart a.seat.unknown", 0
    assert_select "table.sections tbody tr", 12
    assert_select "h2", "Seating evidence"
    assert_select "a[href=?]", "https://www.youtube.com/watch?v=rSIXxKsNcXA&t=87s"
    assert_select "a[href=?]", "https://www.youtube.com/watch?v=YGSPO9XFu-8"
    assert_select "table.sections td[colspan='2']", 2
    assert_select "a[href=?]", figure_path(carousel.lead_figure), text: "The General"

    get figure_path(Figure.find_by!(slug: "salems-riverfront-carousel-covered-wagon"))
    assert_response :success
    assert_select "a[href=?]", "https://www.salemcarousel.org/copy-of-chuck-wagon"
    assert_select "main", /Video-derived layout: wiki seat 10A/
    assert_select "main", /Rows spanned: 2/
    assert_select ".prose p", text: "false", count: 0
  end

  test "carousel page shows the seat chart and section table" do
    get carousel_path(@carousel)
    assert_response :success
    assert_select "svg.seat-chart a.seat", 39
    assert_equal [ "Section", *@carousel.row_letters ], css_select("table.sections thead th").map(&:text)
    assert_select "table.sections tbody tr", 14
    css_select("table.sections tbody tr").each do |row|
      assert_equal @carousel.row_letters.size, row.css("td").sum { |cell| (cell["colspan"] || 1).to_i }
    end
    assert_select "a[href=?]", figure_path(@carousel.seat("9A").figure)
  end

  test "seat codes work as URLs in either case" do
    %w[1a 1A].each do |code|
      get "/carousels/great-northern-carousel/#{code}"
      assert_response :found
      assert_redirected_to figure_path(@carousel.seat("1A").figure)
      follow_redirect!
      assert_response :success
      assert_select "h1", "Titan the Hippocampus"
      assert_select ".seat-context h2", "Current seat"
      assert_select ".seat-context svg.seat-badge[aria-label='Seat 1A']"
      assert_select ".seat-context dt", text: "Seat", count: 0
    end
  end

  test "occupied seat bookmarks follow reassignment without permanent redirects" do
    carousel = build_carousel
    seat = carousel.seat("1A")
    first = create_figure("First occupant", carousel:)
    second = create_figure("Second occupant", carousel:)

    [ first, second ].each do |figure|
      SeatAssignment.new(seat, figure).save!
      get carousel_seat_path(carousel, seat)
      assert_response :found
      assert_redirected_to figure_path(figure)
    end

    SeatAssignment.new(seat, nil).save!
    get carousel_seat_path(carousel, seat)
    assert_response :success
    assert_select "h1", "Seat 1A"
    assert_select ".facts dd", "Unknown"
  end

  test "charts and section tables link occupied seats to figures and vacant positions to seats" do
    carousel = build_carousel(sections: 3, rows: 1)
    figure = create_figure("Direct figure link", carousel:)
    SeatAssignment.new(carousel.seat("1A"), figure).save!
    SeatAssignment.new(carousel.seat("2A"), nil, empty: true).save!

    get carousel_path(carousel)
    assert_response :success
    [ "svg.seat-chart", "table.sections" ].each do |selector|
      assert_select "#{selector} a[href=?]", figure_path(figure), count: 1
      %w[2A 3A].each do |code|
        assert_select "#{selector} a[href=?]", carousel_seat_path(carousel, code), count: 1
      end
      assert_select "#{selector} a[href=?]", carousel_seat_path(carousel, "1A"), count: 0
    end
  end

  test "unknown seats and carousels are not found" do
    get "/carousels/great-northern-carousel/20A"
    assert_response :not_found
    get "/carousels/nowhere"
    assert_response :not_found
  end

  test "figure pages link their carousel above the figure name whether seated or unseated" do
    [ @carousel.seat("1A").figure, create_figure("Unseated navigation test") ].each do |figure|
      get figure_path(figure)
      assert_response :success
      assert_select ".page-header > p:first-child a[href=?]", carousel_path(figure.carousel), text: figure.carousel.name
      assert_select ".page-header > p:first-child + h1", figure.name
      assert_select ".page-header a[href=?]", carousel_path(figure.carousel), count: 1
    end
  end

  test "the canonical figure page renders figure details and sanitized sources" do
    figure = @carousel.seat("1A").figure
    carver = Maker.create!(name: "Detail Test Carver", kind: "person")
    figure.update!(
      mount: "jumper", carver:, year_carved: 2001, sponsor: "Detail Test Sponsor",
      description: "A distinctive carved figure.",
      body: "## Sources\n\n[Figure reference](https://example.com/figure)\n\n<script>alert('unsafe')</script>"
    )

    get figure_path(figure)
    assert_response :success
    assert_select ".lede", "A distinctive carved figure."
    assert_select ".facts dd", text: "Other animals"
    assert_select ".facts dd", text: "Jumper"
    assert_select ".facts a[href=?]", maker_path(carver), text: carver.name
    assert_select ".facts dd", text: "2001"
    assert_select ".facts dd", text: "Detail Test Sponsor"
    assert_select ".prose h2", "Sources"
    assert_select ".prose a[href=?]", "https://example.com/figure", text: "Figure reference"
    assert_select ".prose script", 0
    assert_select ".page-header h1", figure.name
    assert_select ".page-header a[href=?]", figure_type_path(figure.figure_type), text: figure.figure_type.name
    assert_select "title", "#{figure.name} · carousel-o-pedia"
  end

  test "seat details follow the current figure and omit missing optional fields" do
    carousel = build_carousel
    seat = carousel.seat("1A")
    former = create_figure("Former figure")
    former.update!(description: "Former description", sponsor: "Former sponsor")
    SeatAssignment.new(seat, former).save!
    current = create_figure("Current figure")
    SeatAssignment.new(seat, current).save!

    get carousel_seat_path(carousel, seat)
    assert_redirected_to figure_path(current)
    follow_redirect!
    assert_response :success
    assert_select "h1", current.name
    assert_select ".figure-details .facts dt", count: 1, text: "Category"
    assert_select ".figure-details .lede", 0
    assert_select ".figure-details", text: /Former/, count: 0
    assert_select "h2", "Earlier figures"
    assert_select "li a[href=?]", figure_path(former), text: former.name

    get figure_path(former)
    assert_response :success
    assert_select ".page-header", text: /Not currently seated/
    assert_select ".seat-context", 0
    assert_select ".figure-details h2", "Seats over time"
    assert_select ".figure-details a.seat-link[href=?]", carousel_seat_path(carousel, seat)
  end

  test "figure and unoccupied seat pages offer row links in their large badges" do
    get figure_path(@carousel.seat("1C").figure)
    assert_response :success
    @carousel.row_letters.each do |row|
      assert_select ".seat-context svg.seat-badge a[href=?] text.row",
        figure_path(@carousel.seat("1#{row}").figure), text: row == "C" ? row : row.downcase
    end

    carousel = build_carousel(rows: 3)
    figure = create_figure("Badge neighbour", carousel:)
    SeatAssignment.new(carousel.seat("1A"), figure).save!
    get carousel_seat_path(carousel, carousel.seat("1B"))
    assert_response :success
    assert_select ".page-header svg.seat-badge a[href=?] text.row", figure_path(figure), text: "a"
    assert_select ".page-header svg.seat-badge a[href=?] text.row",
      carousel_seat_path(carousel, carousel.seat("1C")), text: "c"
  end

  test "a figure's seats over time remain separate from its current seat's earlier occupants" do
    carousel = build_carousel(sections: 2, rows: 1)
    original_seat = carousel.seat("1A")
    current_seat = carousel.seat("2A")
    traveler = create_figure("Traveling figure", carousel:)
    earlier_occupant = create_figure("Earlier occupant", carousel:)
    SeatAssignment.new(original_seat, traveler).save!
    SeatAssignment.new(current_seat, earlier_occupant).save!
    SeatAssignment.new(current_seat, traveler).save!

    get figure_path(traveler)
    assert_response :success
    assert_select ".figure-details h2", "Seats over time"
    [ original_seat, current_seat ].each do |seat|
      assert_select ".figure-details a.seat-link[href=?]", carousel_seat_path(carousel, seat), count: 1
    end
    assert_select ".seat-context svg.seat-badge[aria-label='Seat 2A']"
    assert_select ".seat-context h2", "Earlier figures"
    assert_select ".seat-context a[href=?]", figure_path(earlier_occupant), text: earlier_occupant.name
    assert_select ".figure-details a[href=?]", figure_path(earlier_occupant), count: 0
  end

  test "empty and unknown seats do not show details from earlier figures" do
    carousel = build_carousel
    seat = carousel.seat("1A")
    SeatAssignment.new(seat, create_figure("Earlier figure")).save!

    [ true, false ].each do |empty|
      SeatAssignment.new(seat, nil, empty:).save!
      get carousel_seat_path(carousel, seat)
      assert_response :success
      assert_select "h1", "Seat 1A"
      assert_select "title", "#{carousel.name} seat 1A · carousel-o-pedia"
      assert_select ".facts dd", text: empty ? "Empty" : "Unknown"
      assert_select ".figure-details", 0
      assert_select "h2", "Earlier figures"
      assert_select "li a", "Earlier figure"
    end
  end

  test "figure pages separate figure and placement controls for readers and editors" do
    seat = @carousel.seat("1A")
    figure = seat.figure

    get figure_path(figure)
    assert_select ".page-header a[href=?]", history_figure_path(figure), text: "Figure history"
    assert_select ".seat-context a[href=?]", history_carousel_seat_path(@carousel, seat), text: "Seat history"
    assert_select "a[href=?]", edit_figure_path(figure), count: 0
    assert_select "a[href=?]", edit_carousel_seat_path(@carousel, seat), count: 0
    assert_select ".seat-context dt", text: "Figure now", count: 0

    sign_in_as users(:editor)
    get figure_path(figure)
    assert_select ".page-header a.button[href=?]", edit_figure_path(figure), text: "Edit figure"
    assert_select ".seat-context a.button[href=?]", edit_carousel_seat_path(@carousel, seat), text: "Edit placement"

    get edit_carousel_seat_path(@carousel, seat)
    assert_response :success
    assert_select "a[href=?]", figure_path(figure), text: "Cancel"
    get history_carousel_seat_path(@carousel, seat)
    assert_response :success

    SeatAssignment.new(seat, nil, empty: true).save!
    get carousel_seat_path(@carousel, seat)
    assert_select ".page-header .lede", "This seat is recorded as empty."
    assert_select ".seat-context a.button[href=?]", edit_carousel_seat_path(@carousel, seat), text: "Edit placement"
    assert_select ".page-header .page-actions", 0
  end

  test "figure, type and index pages render" do
    get figure_path(Figure.find_by!(name: "Gulliver"))
    assert_response :success
    assert_select ".seat-context" do
      assert_select "svg.seat-badge[aria-label=?]", "Seat 9A"
      assert_select "a[href=?]", carousel_path(@carousel), text: @carousel.name
    end

    get figure_type_path(FigureType.find_by!(name: "Bobcat"))
    assert_response :success
    assert_select "main li", 2

    [ root_path, figures_path, figure_types_path ].each do |path|
      get path
      assert_response :success
    end
  end

  test "figures table separates linked seat badges from carousel locations" do
    carousel = build_carousel
    seated = create_figure("Seated figure", carousel:)
    unseated = create_figure("Unseated figure", carousel:)
    seat = carousel.seat("1A")
    SeatAssignment.new(seat, seated).save!

    get figures_path, params: { carousel_id: carousel.id }
    assert_response :success
    assert_equal [ "Figure", "Type", "Where", "Seat" ], css_select("table thead th").map(&:text)

    [ seated, unseated ].each do |figure|
      assert_select "table tbody tr:has(td:first-child a[href='#{figure_path(figure)}'])" do
        assert_select "td", 4
        assert_select "td:nth-child(3) a[href=?]", carousel_path(carousel), text: carousel.name
        assert_select "td:nth-child(3) svg", 0
        if figure == seated
          assert_select "td:nth-child(4) a.seat-link[href=?]", carousel_seat_path(carousel, seat) do
            assert_select "svg.seat-badge[aria-label='Seat 1A']", 1
          end
        else
          assert_select "td:nth-child(3) .muted", "(not currently seated)"
          assert_select "td:nth-child(4)", text: "", count: 1
        end
      end
    end
  end

  test "figure filters include unseated inventory and combine carousel and type" do
    salem = Carousel.find_by!(slug: "salems-riverfront-carousel")
    dragon = FigureType.find_by!(slug: "dragon")
    get figures_path, params: { carousel_id: salem.id }
    assert_response :success
    assert_select "table tbody tr", 62
    assert_select "table a", "Serendipity Salmon"
    assert_select "table a", "Sweet Tart"
    assert_select "table a", text: "Titan the Hippocampus", count: 0
    assert_select "select[name=carousel_id] option[selected][value=?]", salem.id.to_s
    assert_select "form[action=?][method=get]", figures_path
    assert_select "a[href=?]", figures_path, text: "Clear filters"

    get figures_path, params: { figure_type_id: dragon.id }
    assert_response :success
    assert_equal [ "Emerald the Dragon", "Lucky Red Ringer", "Scaffi" ], css_select("table tbody tr td:first-child a").map(&:text)
    assert_select "select[name=figure_type_id] option[selected][value=?]", dragon.id.to_s

    unicorn = FigureType.find_by!(slug: "unicorn")
    get figures_path, params: { carousel_id: salem.id, figure_type_id: unicorn.id }
    assert_response :success
    assert_select "table tbody tr", 1
    assert_select "table a", "Mr. Sprinkles"
    assert_select "table a[href=?]", carousel_path(salem), text: salem.name
    assert_select "table .muted", "(not currently seated)"
    assert_select "select[name=carousel_id] option[selected][value=?]", salem.id.to_s
    assert_select "select[name=figure_type_id] option[selected][value=?]", unicorn.id.to_s
  end

  test "figure filters handle all figures, no matches, and invalid selections explicitly" do
    get figures_path, params: { carousel_id: "", figure_type_id: "" }
    assert_response :success
    assert_select "table tbody tr", Figure.count

    get figures_path, params: {
      carousel_id: Carousel.find_by!(slug: "salems-riverfront-carousel").id,
      figure_type_id: FigureType.find_by!(slug: "trout").id
    }
    assert_response :success
    assert_select "main p", "No figures match these filters."
    assert_select "table tbody tr", 0

    get figures_path, params: { carousel_id: Carousel.maximum(:id) + 1 }
    assert_response :not_found
    get figures_path, params: { figure_type_id: FigureType.maximum(:id) + 1 }
    assert_response :not_found
    get figures_path, params: { carousel_id: [ @carousel.id ] }
    assert_response :bad_request
    get figures_path, params: { figure_type_id: [ FigureType.first.id ] }
    assert_response :bad_request
  end

  test "unseated figures retain visible carousel links and carousel pages link to their inventory" do
    figure = Figure.find_by!(slug: "salems-riverfront-carousel-pancho")
    get figure_path(figure)
    assert_response :success
    assert_select ".page-header a[href=?]", carousel_path(figure.carousel), text: figure.carousel.name
    assert_select ".page-header", text: /Not currently seated/
    assert_select "a.seat-link", 0

    get figure_type_path(figure.figure_type)
    assert_response :success
    assert_select "li:has(a[href='#{figure_path(figure)}']) a[href=?]", carousel_path(figure.carousel)

    get carousel_path(figure.carousel)
    assert_response :success
    assert_select "a[href=?]", figures_path(carousel_id: figure.carousel_id), text: "View all figures"
  end

  test "Missoula pages show video seating, spanning chariots and unplaced spares" do
    carousel = Carousel.find_by!(slug: "a-carousel-for-missoula")
    get carousel_path(carousel)
    assert_response :success
    assert_select "svg.seat-chart a.seat", 40
    assert_select "svg.seat-chart a.seat.unknown", 0
    assert_select "table.sections td[colspan='2']", 2
    assert_select ".prose", text: /Scaffi/
    assert_select ".prose", text: /not a verified current survey/
    assert_select ".prose h2", text: "Seating information"
    assert_select ".prose h2", text: "Sources"
    assert_select ".prose ul li a[href=?]", "https://www.missoulacarousel.org/building-a-community-dream-a-carousel-for-missoula/", text: "A Community Dream: The Carousel"
    assert_select "a", text: "Columbia Belle"
    assert_select "a[href=?]", figure_path(carousel.seat("13A").figure), text: /Scaffi/
    assert_select ".prose a[href=?]", "https://www.youtube.com/watch?v=8E3DemQtIis&t=100s"

    get figure_path(Figure.find_by!(slug: "a-carousel-for-missoula-scaffi"))
    assert_response :success
    assert_select ".seat-context svg.seat-badge[aria-label='Seat 13A']"
    assert_select ".seat-context a[href=?]", history_carousel_seat_path(carousel, "13A")
    assert_select ".prose a[href=?]", "https://www.youtube.com/watch?v=8E3DemQtIis&t=109s"

    patches = Figure.find_by!(slug: "a-carousel-for-missoula-patches")
    get figure_path(patches)
    assert_response :success
    assert_select "h1", "Patches"
    assert_select ".facts dd", text: "Bertlin-Mostad Family"
    assert_select ".prose", text: /Middle-row replacement pony/
    assert_select ".prose a[href=?]", "https://carousels.org/psp/Missoula/Patches.html"
    assert_select "a.seat-link", 0

    get figures_path
    assert_response :success
    assert_select "a[href=?]", figure_path(patches), text: "Patches"
    assert_select "a", text: "Scaffi"
    assert_select "a", text: "Lucky Red Ringer"
    assert_select "a", text: "Titan the Hippocampus"
  end

  test "Spokane chart shows documented figures, spanning chariots and linked sources" do
    carousel = Carousel.find_by!(slug: "spokane-looff-carrousel")
    get carousel_path(carousel)
    assert_response :success
    assert_select "h1", "Looff Carrousel"
    assert_select "svg.seat-chart a.seat", 58
    assert_select "svg.seat-chart a.seat.unknown", 0
    assert_select "table.sections tbody tr", 20
    assert_select "table.sections td[colspan='2']", 2
    assert_select "a[href=?]", figure_path(carousel.seat("1A").figure), text: /Geri/
    assert_select "a[href=?]", figure_path(carousel.seat("11A").figure), text: /Sneaky/
    assert_select ".prose h2", text: "Documented collection"
    assert_select ".prose h2", text: "Sources"
    assert_select ".prose", text: /confirms twenty radial rows/
    assert_select ".prose a[href=?]", "https://carousels.org/USACensus/census.pl?NCANo=221"
    assert_select ".prose a[href=?]", "https://spokanecarrousel.org/figurepics.html"

    goat = Figure.find_by!(slug: "spokane-looff-carrousel-spare-goat")
    get figure_path(goat)
    assert_response :success
    assert_select "h1", "Billy Bob"
    assert_select ".prose", text: /not a permanent platform assignment/
    assert_select "a.seat-link", 0
  end
end
