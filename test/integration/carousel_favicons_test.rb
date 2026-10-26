require "test_helper"

class CarouselFaviconsTest < ActionDispatch::IntegrationTest
  test "carousel favicons reuse spanning wedges and preserve placement confidence" do
    carousel = build_carousel(sections: 2, rows: 3)
    carousel.seat("1A").update!(rows_spanned: 2)
    SeatAssignment.new(carousel.seat("1A"), create_figure("Chariot", category: "chariot", carousel:)).save!
    carousel.seat("1A").update!(confidence: "confirmed")
    SeatAssignment.new(carousel.seat("2A"), create_figure("Horse", carousel:)).save!

    get carousel_path(carousel)
    assert_response :success
    svg = decoded_favicon
    assert_equal 5, svg.css("path.mini-seat-wedge").size
    assert_equal 1, svg.css("path.chariot:not(.unsure)[data-seat-code='1A']").size
    assert_empty svg.css("path[data-seat-code='1B']")
    assert_equal 1, svg.css("path.horse.unsure[data-seat-code='2A']").size
    assert_equal 3, svg.css("path.unknown").size
    assert_empty svg.css("circle, script, image")
    assert_select "link[rel='icon'][type='image/png'][href='/icon.png']", 1
  end

  test "a carousel without a layout uses a gray ring" do
    get carousel_path(Carousel.create!(name: "No recorded layout"))
    assert_response :success
    assert_gray_ring
  end

  test "unknown and empty seats without mapped figures use a gray ring" do
    carousel = build_carousel
    get carousel_path(carousel)
    assert_gray_ring

    SeatAssignment.new(carousel.seat("1A"), nil, empty: true).save!
    get carousel_path(carousel)
    assert_gray_ring
  end

  test "favicon category colors ignore confidence but follow figure category changes" do
    carousel = build_carousel
    figure = create_figure("Horse", carousel:)
    SeatAssignment.new(carousel.seat("1A"), figure).save!
    get carousel_path(carousel)
    original_colors = decoded_favicon.at_css("style").text
    assert_includes original_colors, ".horse { fill: #9fd3f2; }"
    assert_not_includes original_colors, ".unsure"
    assert_equal 1, decoded_favicon.css("path.horse.unsure").size

    carousel.seat("1A").update!(confidence: "confirmed")
    get carousel_path(carousel)
    confirmed_uri = svg_icon["href"]
    assert_equal original_colors, decoded_favicon.at_css("style").text
    assert_equal 1, decoded_favicon.css("path.horse:not(.unsure)").size

    figure.update!(figure_type: FigureType.create!(name: "Lion", category: "menagerie"))
    get carousel_path(carousel)
    assert_not_equal confirmed_uri, svg_icon["href"]
    assert_equal 1, decoded_favicon.css("path.menagerie:not(.unsure)").size
  end

  test "favicon titles escape carousel and figure names as valid SVG" do
    carousel = build_carousel
    carousel.update!(name: 'Ride & </title><script>alert("name")</script>')
    figure = create_figure('Horse & <script>alert("figure")</script>', carousel:)
    SeatAssignment.new(carousel.seat("1A"), figure).save!
    get carousel_path(carousel)
    svg = decoded_favicon
    assert_includes svg.at_css("svg > title").text, carousel.name
    assert_equal "1A: #{figure.name}", svg.at_css("path[data-seat-code='1A'] title").text
    assert_empty svg.css("script")
  end

  test "home directory and other site pages retain the red site icon" do
    [ root_path, carousels_path, figures_path ].each do |path|
      get path
      assert_response :success
      assert_select "head link[rel='icon'][type='image/svg+xml'][href='/icon.svg'][data-turbo-track='dynamic']", 1
      assert_select "head link[rel='icon'][type='image/svg+xml']", 1
    end
  end

  private
    def svg_icon
      css_select("head link[rel='icon'][type='image/svg+xml']").sole
    end

    def decoded_favicon
      assert_equal "dynamic", svg_icon["data-turbo-track"]
      assert_match %r{\Adata:image/svg\+xml;base64,}, svg_icon["href"]
      source = Base64.strict_decode64(svg_icon["href"].split(",", 2).last)
      svg = Nokogiri::XML(source) { |config| config.strict.nonet }
      assert_equal "http://www.w3.org/2000/svg", svg.root.namespace.href
      svg.remove_namespaces!
    end

    def assert_gray_ring
      svg = decoded_favicon
      assert_empty svg.css("path.mini-seat-wedge, circle")
      assert_equal "#a9b4c6", svg.css("path.empty-favicon").sole["fill"]
    end
end
