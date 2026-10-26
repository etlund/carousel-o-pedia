require "test_helper"

class SeatBadgesHelperTest < ActionView::TestCase
  setup { @carousel = load_seeds }

  test "shows every row from the outer rail inward, with the seat's row highlighted" do
    render html: seat_badge(@carousel.seat("1B"))

    assert_select "svg.seat-badge.horse[aria-label=?]", "Seat 1B"
    assert_select "text.row", count: 3
    assert_equal %w[ a B c ], css_select("text.row").map(&:text)
    positions = css_select("text.row").map { |row| row["x"].to_f }
    assert_equal positions.sort, positions
    assert_select "path.band[transform='translate(58.0 0) scale(-1 1)']", count: 3
    assert_select "text.row[transform]", count: 0
    assert_select "text.row.on", "B"
    assert_select "text.section", "1"
  end

  test "a spanning seat highlights every row it fills" do
    render html: seat_badge(@carousel.seat("4A"))

    assert_select "svg.seat-badge.chariot"
    assert_equal %w[ A B C ], css_select("text.row.on").map(&:text)
  end

  test "an unknown seat is marked as unknown" do
    render html: seat_badge(build_carousel(rows: 3).seat("2C"))
    assert_select "svg.seat-badge.unknown text.row.on", "C"
  end

  test "the section number precedes the row wedge with space reserved for the widest number" do
    [ :small, :large ].each do |size|
      render html: seat_badge(@carousel.seat("1B"), size:)

      assert_select "svg > text.section[text-anchor=end] + g[transform='translate(22 0)']" do
        assert_select "path.band", count: 3
        assert_select "text.row", count: 3
      end
      assert_select "text.section[x='22']", "1"
    end
  end
end
