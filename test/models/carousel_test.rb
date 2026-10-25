require "test_helper"

class CarouselTest < ActiveSupport::TestCase
  test "data first includes unseated inventory or known layouts without duplicating carousels" do
    directory = Carousel.create!(name: "AAA Directory")
    notes_only = Carousel.create!(name: "BBB Notes", body: "Some history", official_url: "https://example.com/")
    inventory = Carousel.create!(name: "ZZZ Inventory")
    reserve = create_figure("Unseated reserve", carousel: inventory)
    layout = Carousel.create!(name: "YYY Layout", sections_count: 2, rows_count: 2)
    both = Carousel.create!(name: "MMM Both", sections_count: 2, rows_count: 2)
    2.times { |number| create_figure("Figure #{number}", carousel: both) }
    ids = [ directory, notes_only, inventory, layout, both ].map(&:id)

    ordered = Carousel.where(id: ids).with_data_first.order(:name, :id)
    assert_equal [ both.id, layout.id, inventory.id, directory.id, notes_only.id ], ordered.ids
    assert_nil reserve.seat

    reserve.destroy!
    assert_equal [ both.id, layout.id, directory.id, notes_only.id, inventory.id ], ordered.ids
  end

  test "directory records have unknown layouts and create no seats" do
    carousel = Carousel.create!(name: "Directory carousel")
    assert_not carousel.layout_known?
    assert_nil carousel.sections_count
    assert_nil carousel.rows_count
    assert_nil carousel.rotation
    assert_empty carousel.seats
    assert_empty carousel.row_letters
    assert_empty carousel.section_breakdown
    carousel.fill_missing_seats
    assert_empty carousel.seats.reload
    assert_raises(ArgumentError) { SeatChart.new(carousel) }
  end

  test "recording a directory layout creates unknown seats once and retains inventory" do
    carousel = Carousel.create!(name: "Directory carousel")
    figure = create_figure("Unplaced", carousel:)
    assert_difference "Seat.count", 6 do
      carousel.update!(sections_count: 3, rows_count: 2)
    end
    assert carousel.layout_known?
    assert_equal %w[ 1A 1B 2A 2B 3A 3B ], carousel.seats.map(&:code)
    assert carousel.seats.all? { _1.state == "unknown" }
    assert_equal carousel, figure.reload.carousel
    assert_nil figure.seat
    assert_no_difference "Seat.count" do
      carousel.update!(name: "Renamed directory carousel")
    end
  end

  test "layout dimensions must be paired and valid" do
    [
      { sections_count: 2 }, { rows_count: 2 },
      { sections_count: 0, rows_count: 2 }, { sections_count: 1, rows_count: 0 },
      { sections_count: -1, rows_count: 2 }, { sections_count: 1.5, rows_count: 2 },
      { sections_count: 1, rows_count: Carousel::MAX_ROWS + 1 }
    ].each do |dimensions|
      carousel = Carousel.new(name: "Invalid layout", **dimensions)
      assert_not carousel.valid?, dimensions.inspect
    end
  end

  test "a layout cannot be cleared while seats exist" do
    carousel = build_carousel
    seat_ids = carousel.seats.ids
    assert_not carousel.update(sections_count: nil, rows_count: nil)
    assert_includes carousel.errors[:base], "The layout cannot be cleared while seats exist"
    assert_equal seat_ids, carousel.seats.reload.ids
    assert carousel.reload.layout_known?
  end

  test "rotation can remain unknown but cannot use an invalid value" do
    carousel = build_carousel
    assert carousel.update(rotation: "")
    assert_nil carousel.rotation
    assert_not carousel.update(rotation: "sideways")
  end

  test "rows are lettered from the outside in" do
    assert_equal %w[ A B C D ], build_carousel(rows: 4).row_letters
  end

  test "a new carousel starts with an unknown seat in every spot" do
    carousel = build_carousel(sections: 4, rows: 2)
    assert_equal %w[ 1A 1B 2A 2B 3A 3B 4A 4B ], carousel.seats.map(&:code)
    assert carousel.seats.all? { _1.state == "unknown" }
  end

  test "finds a seat by code" do
    carousel = build_carousel
    assert_equal "2B", carousel.seat("2b").code
    assert_nil carousel.seat("9Z")
    assert_nil carousel.seat("nonsense")
  end

  test "section breakdown counts figures by category" do
    carousel = build_carousel(sections: 2, rows: 2)
    [ [ "1A", "horse" ], [ "1B", "menagerie" ], [ "2A", "horse" ] ].each do |code, category|
      SeatAssignment.new(carousel.seat(code), create_figure("Figure #{code}", category:)).save!
    end

    sections = carousel.section_breakdown
    assert_equal [ 1, 2 ], sections.map { _1[:number] }
    assert_equal({ "horse" => 1, "menagerie" => 1, "chariot" => 0 }, sections.first[:counts])
    assert_equal({ "horse" => 1, "menagerie" => 0, "chariot" => 0 }, sections.last[:counts])
    assert_equal({ "horse" => 2, "menagerie" => 1, "chariot" => 0 }, carousel.category_totals)
  end

  test "slugs come from the name and stay unique" do
    horse = FigureType.create!(name: "Horse", category: "horse")
    carousel = build_carousel
    assert_equal "horse-1", Figure.create!(name: "Horse 1", figure_type: horse, carousel:).slug
    assert_equal "horse-1-2", Figure.create!(name: "Horse 1", figure_type: horse, carousel:).slug
  end

  test "edits are kept as versions" do
    carousel = build_carousel
    carousel.update!(city: "Helena")
    assert_equal 2, carousel.versions.count
  end

  test "choosing a lead figure renumbers sections from it" do
    carousel = build_carousel(sections: 4, rows: 2)
    lead = create_figure("Titan", category: "menagerie")
    SeatAssignment.new(carousel.seat("3A"), lead).save!
    SeatAssignment.new(carousel.seat("2B"), create_figure("Moon Wind")).save!

    carousel.renumber_from!(carousel.seat("3A"))

    assert_equal lead, carousel.lead_figure
    assert_equal "Moon Wind", carousel.seat("4B").figure.name
    assert_equal %w[ 1A 1B 2A 2B 3A 3B 4A 4B ], carousel.seats.reload.map(&:code)
    assert_equal [ 3, 1 ], carousel.seat("1A").versions.last.changeset["section"]
  end

  test "renumbering keeps the order and turns a full circle" do
    carousel = load_seeds
    carousel.renumber_from!(carousel.seat("3A"))
    assert_equal "Cutty the Trout", carousel.lead_figure.name
    assert_equal "Titan the Hippocampus", carousel.seat("13A").figure.name

    carousel.renumber_from!(carousel.seat("13A"))
    assert_equal "Titan the Hippocampus", carousel.lead_figure.name
    assert_equal %w[ A B C ], carousel.seat("4A").rows_covered
  end

  test "website fields are optional and URL whitespace is normalized" do
    carousel = build_carousel
    carousel.update!(
      official_url: " https://example.com/carousel?visit=yes#hours ",
      wikipedia_url: "http://en.wikipedia.org/wiki/Example",
      other_links: "[NCA gallery](https://carousels.org/)"
    )
    assert_equal "https://example.com/carousel?visit=yes#hours", carousel.official_url
    assert_equal "http://en.wikipedia.org/wiki/Example", carousel.wikipedia_url
    assert_includes carousel.versions.last.changeset, "official_url"
    assert_includes carousel.versions.last.changeset, "other_links"

    carousel.update!(official_url: " ", wikipedia_url: "", other_links: " ")
    assert_nil carousel.official_url
    assert_nil carousel.wikipedia_url
    assert_nil carousel.other_links
  end

  test "website URLs reject unsupported schemes malformed URLs and login credentials" do
    carousel = build_carousel
    invalid_urls = [
      "javascript:alert(1)", "data:text/html,hello", "ftp://example.com/",
      "/relative", "//example.com/", "example.com", "https://",
      "https://exa mple.com/", "https://example.com/\nextra",
      "https://user:password@example.com/"
    ]
    %i[ official_url wikipedia_url ].each do |attribute|
      invalid_urls.each do |value|
        carousel.assign_attributes(official_url: nil, wikipedia_url: nil)
        carousel.public_send("#{attribute}=", value)
        assert_not carousel.valid?, "#{attribute}: #{value.inspect}"
        assert_includes carousel.errors[attribute], "must be an http:// or https:// URL without login credentials"
      end
    end
  end
end
