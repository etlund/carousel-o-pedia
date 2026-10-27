require "test_helper"

class CarouselTest < ActiveSupport::TestCase
  test "addresses normalize blanks preserve leading postal zeros and leave locations unchanged" do
    carousel = Carousel.create!(name: "Address test", street_address: "  1 Main Street  ",
      city: "Hull", region: "Massachusetts", postal_code: "  02045  ", country: "United States",
      address_sources: "[Operator](https://example.com/)")
    assert_equal "1 Main Street", carousel.street_address
    assert_equal "02045", carousel.postal_code
    assert_equal "1 Main Street, Hull, Massachusetts 02045, United States", carousel.address
    assert_equal "Hull, Massachusetts, United States", carousel.location
    carousel.update!(street_address: "  ", postal_code: "", address_sources: " ")
    assert_nil carousel.street_address
    assert_nil carousel.postal_code
    assert_nil carousel.address_sources
    assert_equal carousel.location, carousel.address
  end

  test "addresses handle partial and international locations without stray punctuation" do
    [
      [ {}, "" ],
      [ { street_address: "Visitor entrance" }, "Visitor entrance" ],
      [ { postal_code: "00123" }, "00123" ],
      [ { city: "Paris", postal_code: "75001", country: "France" }, "Paris, 75001, France" ],
      [ { region: "Ontario", postal_code: "M5V 3L9", country: "Canada" }, "Ontario M5V 3L9, Canada" ]
    ].each do |attributes, expected|
      assert_equal expected, Carousel.new(**attributes).address
    end
  end

  test "last updated includes existing child timestamps and orders ties by name and id" do
    directory = Carousel.create!(name: "AAA Directory")
    duplicate = Carousel.create!(name: "AAA Directory")
    notes = Carousel.create!(name: "BBB Notes")
    inventory = Carousel.create!(name: "Inventory")
    reserve = create_figure("Unseated reserve", carousel: inventory)
    layout = build_carousel
    placed = build_carousel
    figure = create_figure("Placed figure", carousel: placed)
    placement = Placement.create!(seat: placed.seat("1A"), figure:)
    carousels = [ directory, duplicate, notes, inventory, layout, placed ]
    baseline = Time.zone.local(2026, 1, 1)

    carousels.each { _1.update_columns(updated_at: baseline) }
    Seat.where(carousel: [ layout, placed ]).update_all(updated_at: baseline)
    figure.update_columns(updated_at: baseline)
    notes.update_columns(updated_at: baseline + 1.hour)
    reserve.update_columns(updated_at: baseline + 2.hours)
    layout.seat("1A").update_columns(updated_at: baseline + 3.hours)
    placement.update_columns(updated_at: baseline + 4.hours)

    ordered = Carousel.where(id: carousels).recently_updated.order(:name, :id)
    assert_equal [ placed.id, layout.id, inventory.id, notes.id, directory.id, duplicate.id ], ordered.ids
    assert_nil reserve.seat
  end

  test "seating completeness uses confidence counts and partial layouts before alphabetical and id ties" do
    directory = Carousel.create!(name: "Zero A Directory")
    unconfirmed = build_carousel
    unconfirmed.update!(name: "Zero Z Layout")
    rows_only = Carousel.create!(name: "Zero ZZ Rows", rows_count: 3)
    sections_only = Carousel.create!(name: "Zero ZZZ Sections", sections_count: 12)
    spanning = build_carousel(rows: 3)
    estimated = build_carousel(sections: 5)
    estimated.update!(name: "Z Estimated")
    estimated.seat("1A").update!(confidence: "confirmed")
    estimated.seat("1B").update!(confidence: "confirmed")
    twins = 3.times.map do |index|
      carousel = build_carousel
      carousel.update!(name: index.zero? ? "Alphabetical" : "Twin")
      carousel.seat("1A").update!(confidence: "confirmed", state: "empty")
      carousel.seat("1B").update!(confidence: "confirmed", state: "unknown")
      carousel
    end
    seat = spanning.seat("1A")
    seat.update!(rows_spanned: 3, confidence: "confirmed")
    2.times do |index|
      SeatAssignment.new(seat, create_figure("Vehicle #{index}", category: "chariot", carousel: spanning)).save!
    end
    carousels = [ directory, unconfirmed, rows_only, sections_only, spanning, estimated, *twins ]

    ordered = Carousel.where(id: carousels).most_complete.order(:name, :id)
    assert_equal [ estimated.id, *twins.map(&:id), spanning.id, unconfirmed.id, rows_only.id, sections_only.id, directory.id ], ordered.ids
    assert_equal 2, seat.placements.count
    assert_equal 3, seat.rows_spanned
    assert_equal Carousel::SeatingCompleteness.new(confirmed_seats: 1, best_reading_seats: 9,
      rows_count: 3, sections_count: 4), spanning.reload.seating_completeness
    assert_equal Carousel::SeatingCompleteness.new(confirmed_seats: 0, best_reading_seats: 0,
      rows_count: 3, sections_count: nil), rows_only.seating_completeness
    assert_equal Carousel::SeatingCompleteness.new(confirmed_seats: 0, best_reading_seats: 0,
      rows_count: nil, sections_count: nil), directory.seating_completeness

    twins.first.seat("1B").update!(confidence: "best_reading")
    assert_equal [ estimated.id, *twins.drop(1).map(&:id), spanning.id, twins.first.id, unconfirmed.id,
      rows_only.id, sections_only.id, directory.id ], ordered.ids
    assert_equal 1, twins.first.reload.seating_completeness.confirmed_seats
    assert_equal 7, twins.first.seating_completeness.best_reading_seats
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

  test "layout dimensions can be recorded independently without creating seats" do
    [ { sections_count: 2 }, { rows_count: 3 } ].each do |dimension|
      carousel = Carousel.create!(name: "Partial layout", **dimension)
      assert_not carousel.layout_known?
      assert_empty carousel.seats
      carousel.update!(sections_count: 2, rows_count: 3)
      assert carousel.layout_known?
      assert_equal 6, carousel.seats.count
    end
  end

  test "known layout dimensions must be valid" do
    [
      { sections_count: 0, rows_count: 2 }, { sections_count: 1, rows_count: 0 },
      { sections_count: -1, rows_count: 2 }, { sections_count: 1.5, rows_count: 2 },
      { sections_count: 1, rows_count: Carousel::MAX_ROWS + 1 }
    ].each do |dimensions|
      carousel = Carousel.new(name: "Invalid layout", **dimensions)
      assert_not carousel.valid?, dimensions.inspect
    end
  end

  test "published totals are separate from placements distinguish zero and require sources" do
    carousel = Carousel.new(name: "Published summary", published_horses_count: 48,
      published_other_animals_count: 0, published_chariots_count: 2)
    assert_not carousel.valid?
    assert_includes carousel.errors[:summary_sources], "can't be blank"
    carousel.summary_sources = "[Operator](https://example.com/) reports riding figures."
    carousel.save!
    assert_equal({ "horse" => 48, "menagerie" => 0, "chariot" => 2 }, carousel.published_category_totals)
    assert carousel.published_counts?
    assert_empty carousel.figures
    assert_empty carousel.seats

    [ -1, 1.5, "many" ].each do |invalid|
      carousel.published_horses_count = invalid
      assert_not carousel.valid?
      assert carousel.errors[:published_horses_count].any?
    end
    carousel.assign_attributes(published_horses_count: nil, published_other_animals_count: nil, published_chariots_count: nil)
    assert_not carousel.published_counts?
    assert carousel.valid?
  end

  test "figure activity touches both carousels on transfer without timestamp-only history" do
    freeze_time do
      carousel = Carousel.create!(name: "Figure activity")
      other = Carousel.create!(name: "Destination")
      assert_no_difference "carousel.versions.count + other.versions.count" do
        travel 1.hour
        figure = create_figure("Reserve figure", carousel:)
        assert_equal Time.current, carousel.reload.updated_at

        travel 1.hour
        figure.update!(description: "New research")
        assert_equal Time.current, carousel.reload.updated_at
        last_updated = carousel.updated_at

        travel 1.hour
        figure.save!
        assert_equal last_updated, carousel.reload.updated_at
        assert_not figure.update(name: "")
        assert_equal last_updated, carousel.reload.updated_at
        figure.reload

        travel 1.hour
        figure.update!(carousel: other)
        assert_equal Time.current, carousel.reload.updated_at
        assert_equal Time.current, other.reload.updated_at

        travel 1.hour
        figure.destroy!
        assert_equal Time.current, other.reload.updated_at
      end
    end
  end

  test "seat and placement activity updates the carousel without timestamp-only history" do
    freeze_time do
      carousel = build_carousel
      seat = carousel.seat("1A")
      figure = create_figure("Seated figure", carousel:)
      assert_no_difference "carousel.versions.count" do
        travel 1.hour
        seat.update!(confidence: "confirmed")
        assert_equal Time.current, carousel.reload.updated_at
        assert_includes seat.versions.last.changeset, "confidence"

        assert_no_difference "seat.versions.count" do
          travel 1.hour
          placement = Placement.create!(seat:, figure:)
          assert_equal Time.current, carousel.reload.updated_at

          travel 1.hour
          placement.update!(started_on: Date.yesterday)
          assert_equal Time.current, carousel.reload.updated_at

          travel 1.hour
          placement.destroy!
          assert_equal Time.current, carousel.reload.updated_at
        end

        travel 1.hour
        seat.destroy!
        assert_equal Time.current, carousel.reload.updated_at

        travel 1.hour
        carousel.fill_missing_seats
        assert_equal Time.current, carousel.reload.updated_at
      end
    end
  end

  test "rolled back activity does not change the carousel update time" do
    freeze_time do
      carousel = build_carousel
      figure = create_figure("Unchanged figure", carousel:)
      last_updated = carousel.reload.updated_at
      travel 1.hour

      Carousel.transaction do
        figure.update!(description: "Rolled back")
        carousel.seat("1A").update!(confidence: "confirmed")
        raise ActiveRecord::Rollback
      end

      assert_equal last_updated, carousel.reload.updated_at
      assert_nil figure.reload.description
      assert_equal "best_reading", carousel.seat("1A").confidence
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
