require "test_helper"

class SeatTest < ActiveSupport::TestCase
  test "parses seat codes in either case" do
    assert_equal({ section: 12, row: "C" }, Seat.parse_code("12c"))
    assert_equal({ section: 5, row: "A" }, Seat.parse_code("5A"))
    assert_nil Seat.parse_code("A5")
    assert_nil Seat.parse_code("")
  end

  test "code is section number plus row letter" do
    seat = build_carousel.seat("3B")
    assert_equal "3B", seat.code
    assert_equal "3B", seat.to_param
  end

  test "seat must fit on its carousel" do
    carousel = build_carousel(sections: 4, rows: 2)

    assert_not carousel.seats.build(section: 5, row: "A").valid?
    assert_not carousel.seats.build(section: 1, row: "C").valid?
    assert_not carousel.seat("1B").tap { _1.rows_spanned = 2 }.valid?
    assert carousel.seat("4A").tap { _1.rows_spanned = 2 }.valid?
  end

  test "a directory carousel needs a layout before seats can be added" do
    carousel = Carousel.create!(name: "No layout")
    seat = carousel.seats.build(section: 1, row: "A", rows_spanned: 2)
    assert_not seat.valid?
    assert_includes seat.errors[:carousel], "needs a known layout before seats can be added"
  end

  test "a seat code is unique on its carousel" do
    assert_not build_carousel.seats.build(section: 1, row: "A").valid?
  end

  test "spanning more rows absorbs the free seats it covers" do
    carousel = build_carousel(sections: 2, rows: 3)
    carousel.seat("2A").update!(rows_spanned: 3)

    assert_equal %w[ A B C ], carousel.seat("2A").rows_covered
    assert_nil carousel.seat("2B")
    assert_nil carousel.seat("2C")
  end

  test "spanning fewer rows gives back unknown seats" do
    carousel = build_carousel(sections: 2, rows: 3)
    carousel.seat("2A").update!(rows_spanned: 3)
    carousel.seat("2A").update!(rows_spanned: 1)

    assert_equal "unknown", carousel.seat("2B").state
    assert_equal "unknown", carousel.seat("2C").state
  end

  test "a seat can't span over a seat that has a figure" do
    carousel = build_carousel(sections: 2, rows: 2)
    SeatAssignment.new(carousel.seat("1B"), create_figure("Stormy")).save!

    seat = carousel.seat("1A")
    assert_not seat.update(rows_spanned: 2)
    assert_match "1B", seat.errors.full_messages.to_sentence
  end

  test "only one figure sits in a seat at a time" do
    seat = build_carousel.seat("1A")
    seat.placements.create!(figure: create_figure("First"))

    second = seat.placements.build(figure: create_figure("Second"))
    assert_not second.valid?

    second.ended_on = Date.new(1990, 1, 1)
    assert second.valid?
  end
end
