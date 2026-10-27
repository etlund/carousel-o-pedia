require "test_helper"

class SeatBadgesHelperTest < ActionView::TestCase
  include ApplicationHelper

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
    assert_select "svg[role=img]"
    assert_select "svg a", count: 0
  end

  test "linked badges open each row's current figure in the same section" do
    render html: seat_badge(@carousel.seat("1C"), size: :large, linked: true)

    assert_select "svg[role=group]"
    assert_select "svg a", count: 3
    @carousel.row_letters.each do |row|
      figure = @carousel.seat("1#{row}").figure
      assert_select "a[href=?][aria-label=?]", figure_path(figure), "1#{row}: #{figure.name}" do
        assert_select "path.band", count: 1
        assert_select "text.row", text: row == "C" ? row : row.downcase
      end
    end
  end

  test "linked badges resolve every covered row to its spanning figure" do
    seat = @carousel.seat("4A")
    render html: seat_badge(seat, linked: true)

    assert_select "svg a[href=?]", figure_path(seat.figure), count: 3
  end

  test "linked badges open seat details for empty and unknown rows" do
    carousel = build_carousel(rows: 3)
    carousel.seat("2B").update!(state: "empty")
    render html: seat_badge(carousel.seat("2C"), linked: true)

    assert_select "svg a", count: 3
    carousel.row_letters.each do |row|
      seat = carousel.seat("2#{row}")
      assert_select "a[href=?][aria-label=?]", carousel_seat_path(carousel, seat), "#{seat.code}: #{seat.state.capitalize}"
    end
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
