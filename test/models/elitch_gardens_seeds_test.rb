require "test_helper"

class ElitchGardensSeedsTest < ActiveSupport::TestCase
  setup { load Rails.root.join("db/seeds/us_operating_carousels.rb") }

  test "photographs supply two descriptive figures without invented seating or a complete inventory" do
    assert_difference "Figure.count", 2 do
      assert_no_difference [ "Seat.count", "Placement.count" ] do
        load_research
      end
    end
    carousel = Carousel.find_by!(slug: "elitch-gardens-carousel-denver")
    assert_equal [ 62, 0, 4, 4, nil, nil ], carousel.attributes.values_at(
      "published_horses_count", "published_other_animals_count", "published_chariots_count",
      "rows_count", "sections_count", "rotation"
    )
    assert_empty carousel.seats
    assert_equal({ "horses_count" => 18, "mount" => "stander" }, carousel.ring_details["A"])
    assert_equal %w[ jumper jumper jumper ], %w[ B C D ].map { carousel.ring_details.dig(_1, "mount") }
    assert carousel.ring_details.values.all? { _1["positions_count"].nil? }
    assert_includes carousel.summary_sources, "https://www.youtube.com/watch?v=i7DB_NySglU"
    assert_includes carousel.summary_sources, "Full playback was unavailable"
    assert_equal [ "Angel and Cherubs chariot", "Miss Liberty and Bald Eagle chariot" ],
      carousel.figures.order(:name).pluck(:name)
    carousel.figures.each do |figure|
      assert_equal "chariot", figure.category
      assert_nil figure.seat
      assert_nil figure.mount
      assert_includes figure.body, "August 5, 2003"
      assert_includes figure.body, "https://carousels.org/psp/ElitchGardensPTC/"
    end
    assert_includes carousel.summary_sources, "partial photographic inventory"
    assert_not_includes carousel.body, "Individual figures and placements have not been researched"
    assert_empty Carousel.find_by!(slug: "kit-carson-county-carousel-burlington").figures
  end

  test "reloading preserves edited figures placements notes and timestamps" do
    load_research
    carousel = Carousel.find_by!(slug: "elitch-gardens-carousel-denver")
    carousel.update!(sections_count: 18, body: "Wiki history",
      summary_sources: "#{carousel.summary_sources}\n\nWiki research.")
    figure = carousel.figures.first
    figure.update!(name: "Wiki identity", body: "Wiki description")
    SeatAssignment.new(carousel.seat("2B"), figure).save!
    before = snapshot
    2.times { load_research }
    assert_equal before, snapshot
  end

  test "preexisting inventory is not supplemented with potentially duplicate identities" do
    carousel = Carousel.find_by!(slug: "elitch-gardens-carousel-denver")
    figure = create_figure("Previously researched chariot", carousel:, category: "chariot")
    assert_no_difference [ "Figure.count", "Seat.count", "Placement.count" ] do
      load_research
    end
    assert_equal [ figure.id ], carousel.figures.pluck(:id)
    assert_includes carousel.reload.summary_sources, "PTC #51 photographic inventory reference"
  end

  test "transferred source identities are not recreated on reimport" do
    load_research
    carousel = Carousel.find_by!(slug: "elitch-gardens-carousel-denver")
    destination = build_carousel
    carousel.figures.each { _1.update!(carousel: destination) }
    before = snapshot
    load_research
    assert_equal before, snapshot
    assert_empty carousel.figures.reload
  end

  test "video research preserves edited ring facts and conflicting row counts" do
    carousel = Carousel.find_by!(slug: "elitch-gardens-carousel-denver")
    carousel.update!(ring_details: { "A" => { "horses_count" => 19, "mount" => "jumper" } })
    load_research
    assert_equal({ "horses_count" => 19, "mount" => "jumper" }, carousel.reload.ring_details["A"])
    assert_equal "jumper", carousel.ring_details.dig("B", "mount")
    carousel.update!(ring_details: {}, rows_count: 3)
    load_research
    assert_empty carousel.reload.ring_details
    assert_equal 3, carousel.rows_count
  end

  private
    def load_research
      load Rails.root.join("db/seeds/us_researched_elitch_gardens.rb")
    end

    def snapshot
      [ Carousel, Seat, Figure, Placement, FigureType, PaperTrail::Version ].map { _1.order(:id).map(&:attributes) }
    end
end
