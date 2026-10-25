require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  setup { @carousel = load_seeds }

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
    assert_select "table.sections tbody tr", 14
    assert_select "a[href=?]", "/carousels/great-northern-carousel/9A"
  end

  test "seat codes work as URLs in either case" do
    get "/carousels/great-northern-carousel/1a"
    assert_response :success
    assert_select "h1", "Seat 1A"
    assert_select "a", "Titan the Hippocampus"
  end

  test "unknown seats and carousels are not found" do
    get "/carousels/great-northern-carousel/20A"
    assert_response :not_found
    get "/carousels/nowhere"
    assert_response :not_found
  end

  test "seat and figure pages share the current figure details and rendered sources" do
    figure = @carousel.seat("1A").figure
    carver = Maker.create!(name: "Detail Test Carver", kind: "person")
    figure.update!(
      mount: "jumper", carver:, year_carved: 2001, sponsor: "Detail Test Sponsor",
      description: "A distinctive carved figure.",
      body: "## Sources\n\n[Figure reference](https://example.com/figure)\n\n<script>alert('unsafe')</script>"
    )

    [ carousel_seat_path(@carousel, "1A"), figure_path(figure) ].each do |path|
      get path
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
    end

    get carousel_seat_path(@carousel, "1A")
    assert_select ".figure-details h2 a[href=?]", figure_path(figure), text: figure.name
    assert_select ".figure-details a[href=?]", figure_type_path(figure.figure_type), text: figure.figure_type.name
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
    assert_response :success
    assert_select ".figure-details h2", current.name
    assert_select ".figure-details .facts dt", count: 1, text: "Category"
    assert_select ".figure-details .lede", 0
    assert_select ".figure-details", text: /Former/, count: 0
    assert_select "h2", "Earlier figures"
    assert_select "li a[href=?]", figure_path(former), text: former.name
  end

  test "empty and unknown seats do not show details from earlier figures" do
    carousel = build_carousel
    seat = carousel.seat("1A")
    SeatAssignment.new(seat, create_figure("Earlier figure")).save!

    [ true, false ].each do |empty|
      SeatAssignment.new(seat, nil, empty:).save!
      get carousel_seat_path(carousel, seat)
      assert_response :success
      assert_select ".facts dd", text: empty ? "Empty" : "Unknown"
      assert_select ".figure-details", 0
      assert_select "h2", "Earlier figures"
      assert_select "li a", "Earlier figure"
    end
  end

  test "figure, type and index pages render" do
    get figure_path(Figure.find_by!(name: "Gulliver"))
    assert_response :success
    assert_select "a.seat-link[href=?]", "/carousels/great-northern-carousel/9A" do
      assert_select "svg.seat-badge[aria-label=?]", "Seat 9A"
    end

    get figure_type_path(FigureType.find_by!(name: "Bobcat"))
    assert_response :success
    assert_select "main li", 2

    [ root_path, figures_path, figure_types_path ].each do |path|
      get path
      assert_response :success
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
    assert_select "table tbody tr", 206

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
    assert_select "a[href=?]", carousel_seat_path(carousel, "13A"), text: /Scaffi/
    assert_select ".prose a[href=?]", "https://www.youtube.com/watch?v=8E3DemQtIis&t=100s"

    get figure_path(Figure.find_by!(slug: "a-carousel-for-missoula-scaffi"))
    assert_response :success
    assert_select "a.seat-link[href=?]", carousel_seat_path(carousel, "13A")
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
    assert_select "a[href=?]", carousel_seat_path(carousel, "1A"), text: /Geri/
    assert_select "a[href=?]", carousel_seat_path(carousel, "11A"), text: /Sneaky/
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
