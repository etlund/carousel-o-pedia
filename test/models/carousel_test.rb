require "test_helper"

class CarouselTest < ActiveSupport::TestCase
  test "rows are lettered from the outside in" do
    assert_equal %w[ A B C D ], build_carousel(rows: 4).row_letters
  end

  test "finds a seat by code" do
    carousel = build_carousel
    seat = carousel.seats.create!(section: 2, row: "B")
    assert_equal seat, carousel.seat("2b")
    assert_nil carousel.seat("9Z")
    assert_nil carousel.seat("nonsense")
  end

  test "section breakdown counts figures by category" do
    carousel = build_carousel(sections: 2, rows: 2)
    horse = FigureType.create!(name: "Horse", category: "horse")
    bison = FigureType.create!(name: "Bison", category: "menagerie")
    [ [ "1A", horse ], [ "1B", bison ], [ "2A", horse ] ].each do |code, type|
      seat = carousel.seats.create!(Seat.parse_code(code))
      seat.placements.create!(figure: Figure.create!(name: "Figure #{code}", figure_type: type))
    end
    carousel.seats.create!(section: 2, row: "B", state: "unknown")

    sections = carousel.section_breakdown
    assert_equal [ 1, 2 ], sections.map { _1[:number] }
    assert_equal({ "horse" => 1, "menagerie" => 1, "chariot" => 0 }, sections.first[:counts])
    assert_equal({ "horse" => 1, "menagerie" => 0, "chariot" => 0 }, sections.last[:counts])
    assert_equal({ "horse" => 2, "menagerie" => 1, "chariot" => 0 }, carousel.category_totals)
  end

  test "slugs come from the name and stay unique" do
    horse = FigureType.create!(name: "Horse", category: "horse")
    assert_equal "horse-1", Figure.create!(name: "Horse 1", figure_type: horse).slug
    assert_equal "horse-1-2", Figure.create!(name: "Horse 1", figure_type: horse).slug
  end

  test "edits are kept as versions" do
    carousel = build_carousel
    carousel.update!(city: "Helena")
    assert_equal 2, carousel.versions.count
  end
end
