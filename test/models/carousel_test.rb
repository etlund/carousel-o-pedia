require "test_helper"

class CarouselTest < ActiveSupport::TestCase
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
end
