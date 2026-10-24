require "test_helper"

class SeatTest < ActiveSupport::TestCase
  test "parses seat codes in either case" do
    assert_equal({ section: 12, row: "C" }, Seat.parse_code("12c"))
    assert_equal({ section: 5, row: "A" }, Seat.parse_code("5A"))
    assert_nil Seat.parse_code("A5")
    assert_nil Seat.parse_code("")
  end

  test "code is section number plus row letter" do
    seat = build_carousel.seats.create!(section: 3, row: "B")
    assert_equal "3B", seat.code
    assert_equal "3B", seat.to_param
  end

  test "a spanning seat covers rows from its outermost row inward" do
    seat = build_carousel(rows: 3).seats.create!(section: 2, row: "A", rows_spanned: 3)
    assert_equal %w[ A B C ], seat.rows_covered
  end

  test "seat must fit on its carousel" do
    carousel = build_carousel(sections: 4, rows: 2)

    assert_not carousel.seats.build(section: 5, row: "A").valid?
    assert_not carousel.seats.build(section: 1, row: "C").valid?
    assert_not carousel.seats.build(section: 1, row: "B", rows_spanned: 2).valid?
    assert carousel.seats.build(section: 4, row: "A", rows_spanned: 2).valid?
  end

  test "a seat code is unique on its carousel" do
    carousel = build_carousel
    carousel.seats.create!(section: 1, row: "A")
    assert_not carousel.seats.build(section: 1, row: "A").valid?
  end

  test "only one figure sits in a seat at a time" do
    seat = build_carousel.seats.create!(section: 1, row: "A")
    horse = FigureType.create!(name: "Horse", category: "horse")
    seat.placements.create!(figure: Figure.create!(name: "First", figure_type: horse))

    second = seat.placements.build(figure: Figure.create!(name: "Second", figure_type: horse))
    assert_not second.valid?

    second.ended_on = Date.new(1990, 1, 1)
    assert second.valid?
  end
end
