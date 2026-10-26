require "test_helper"

class ResearchedLayoutSeedsTest < ActiveSupport::TestCase
  setup { load Rails.root.join("db/seeds/us_operating_carousels.rb") }

  test "Glen Echo uses the numbered HABS catalog rather than inferred totals" do
    assert_difference [ "Seat.count", "Figure.count", "Placement.current.count" ], 54 do
      load_research
    end
    carousel = Carousel.find_by!(slug: "glen-echo-dentzel-carousel")
    assert_equal [ 18, 3, nil ], [ carousel.sections_count, carousel.rows_count, carousel.rotation ]
    assert_equal({ "horse" => 40, "menagerie" => 12, "chariot" => 2 }, carousel.category_totals)
    assert_equal 54, carousel.figures.count
    assert_equal 54, carousel.seats.count
    assert carousel.seats.all? { _1.state == "filled" && _1.confidence == "best_reading" && _1.rows_spanned == 1 }
    assert_equal [ 12, 14, 14 ], %w[ A B C ].map { |row| carousel.seats.where(row:).count { _1.category == "horse" } }
    assert_equal [ 4, 4, 4 ], %w[ A B C ].map { |row| carousel.seats.where(row:).count { _1.category == "menagerie" } }
    assert_equal [ 2, 0, 0 ], %w[ A B C ].map { |row| carousel.seats.where(row:).count { _1.category == "chariot" } }
    { "4A" => "Lion", "9A" => "Giraffe", "13A" => "Tiger", "18A" => "Deer",
      "4B" => "Rabbit", "13C" => "Rabbit", "8B" => "Ostrich", "17C" => "Ostrich",
      "8A" => "Chariot", "17A" => "Chariot" }.each do |code, type|
      assert_equal type, carousel.seat(code).figure.figure_type.name
    end
    assert_equal "Lead horse (HABS A-1)", carousel.lead_figure.name
    assert_equal "Unidentified horse at 2A", carousel.seat("2A").figure.name
    assert_equal "stander", carousel.seat("2A").figure.mount
    assert_equal "jumper", carousel.seat("2B").figure.mount
    carousel.figures.each do |figure|
      assert_includes figure.body, "1994 HABS"
      assert_includes figure.body, "best reading"
      assert_includes figure.body, "md1366data.pdf"
    end
    assert_includes carousel.summary_sources, "not a verified current survey"
    assert_not_includes carousel.body, "Individual figures and placements have not been researched"
  end

  test "unresolved layouts retain research notes without invented seats or figures" do
    load_research
    %w[ cafesjians-carousel-st-paul paragon-carousel-hull bushnell-park-carousel-hartford janes-carousel-brooklyn ].each do |slug|
      carousel = Carousel.find_by!(slug:)
      assert_nil carousel.sections_count
      assert_empty carousel.seats
      assert_empty carousel.figures
      assert_includes carousel.summary_sources, "October 25, 2026"
    end
    sources = Carousel.find_by!(slug: "cafesjians-carousel-st-paul").summary_sources
    assert_includes sources, "| A (outside) | 16 | 2 |"
    assert_includes sources, "| B (second) | 16 | 0 |"
    assert_includes sources, "| C (third) | 18 | 0 |"
    assert_includes sources, "| D (inside) | 18 | 0 |"
    assert_includes sources, "remains unverified"
  end

  test "reloading preserves edited metadata source notes placements inventory and timestamps" do
    load_research
    carousel = Carousel.find_by!(slug: "glen-echo-dentzel-carousel")
    carousel.update!(name: "Wiki name", body: "Wiki history",
      summary_sources: "#{carousel.summary_sources}\n\nAdditional wiki research.")
    seat = carousel.seat("8A")
    figure = seat.figure
    SeatAssignment.new(seat, nil, empty: true).save!
    SeatAssignment.new(carousel.seat("7B"), figure).save!
    figure.update!(name: "Verified chariot identity")
    carousel.seat("2A").update!(confidence: "confirmed")
    before = snapshot
    2.times { load_research }
    assert_equal before, snapshot
  end

  test "conflicting rows or existing inventory do not get a guessed layout" do
    carousel = Carousel.find_by!(slug: "glen-echo-dentzel-carousel")
    carousel.update!(rows_count: 4, body: "Wiki history", summary_sources: "Wiki source")
    load_research
    assert_nil carousel.reload.sections_count
    assert_empty carousel.seats
    assert_includes carousel.summary_sources, "Wiki source"
    assert_equal "Wiki history", carousel.body

    carousel.update!(rows_count: 3)
    figure = create_figure("Existing unplaced figure", carousel:)
    load_research
    assert_nil carousel.reload.sections_count
    assert_empty carousel.seats
    assert_equal [ figure.id ], carousel.figures.pluck(:id)
  end

  test "a preexisting wiki chart and inventory remain untouched" do
    carousel = Carousel.find_by!(slug: "glen-echo-dentzel-carousel")
    carousel.update!(sections_count: 12, rows_count: 3, rotation: "clockwise", body: "Wiki history")
    figure = create_figure("Wiki horse", carousel:)
    SeatAssignment.new(carousel.seat("1A"), figure).save!
    seats = Seat.order(:id).map(&:attributes)
    figures = Figure.order(:id).map(&:attributes)
    placements = Placement.order(:id).map(&:attributes)
    load_research
    assert_equal [ 12, 3, "clockwise", "Wiki history" ],
      carousel.reload.attributes.values_at("sections_count", "rows_count", "rotation", "body")
    assert_equal seats, Seat.order(:id).map(&:attributes)
    assert_equal figures, Figure.order(:id).map(&:attributes)
    assert_equal placements, Placement.order(:id).map(&:attributes)
  end

  private
    def load_research
      load Rails.root.join("db/seeds/us_researched_layouts.rb")
    end

    def snapshot
      [ Carousel, Seat, Figure, Placement, FigureType, PaperTrail::Version ].map { _1.order(:id).map(&:attributes) }
    end
end
