require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  setup { @carousel = load_seeds }

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

  test "Missoula pages show the lead and unplaced inventory without invented seating" do
    carousel = Carousel.find_by!(slug: "a-carousel-for-missoula")
    get carousel_path(carousel)
    assert_response :success
    assert_select "svg.seat-chart a.seat", 42
    assert_select ".prose", text: /Scaffi/
    assert_select ".prose", text: /provisional values, not verified facts/
    assert_select ".prose h2", text: "Seating information"
    assert_select ".prose h2", text: "Sources"
    assert_select ".prose ul li a[href=?]", "https://www.missoulacarousel.org/building-a-community-dream-a-carousel-for-missoula/", text: "A Community Dream: The Carousel"
    assert_select "a", text: "Columbia Belle"

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
end
