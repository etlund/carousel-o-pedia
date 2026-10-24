require "test_helper"

class SeatBadgesHelperTest < ActionView::TestCase
  setup { @carousel = load_seeds }

  test "shows every row from the hub out, with the seat's row highlighted" do
    render html: seat_badge(@carousel.seat("13B"))

    assert_select "svg.seat-badge.horse[aria-label=?]", "Seat 13B"
    assert_select "text.row", count: 3
    assert_equal %w[ c B a ], css_select("text.row").map(&:text)
    assert_select "text.row.on", "B"
    assert_select "text.section", "13"
  end

  test "a spanning seat highlights every row it fills" do
    render html: seat_badge(@carousel.seat("2A"))

    assert_select "svg.seat-badge.chariot"
    assert_equal %w[ C B A ], css_select("text.row.on").map(&:text)
  end

  test "an unknown seat is marked as unknown" do
    render html: seat_badge(@carousel.seat("7C"))
    assert_select "svg.seat-badge.unknown text.row.on", "C"
  end
end
