require "test_helper"

class SeatChartGeometryTest < ActiveSupport::TestCase
  test "wedges meet at every row boundary and keep section one at the top" do
    carousel = build_carousel(sections: 4, rows: 3)
    wedges = SeatChart.new(carousel).seat_wedges(carousel.seats)

    assert_equal 12, wedges.size
    (1..4).each do |section|
      rows = wedges.select { |wedge| wedge.seat.section == section }.sort_by { |wedge| wedge.seat.row_index }
      assert_equal [ 370, 280, 190 ], rows.map(&:outer_radius)
      assert_equal [ 280, 190, 100 ], rows.map(&:inner_radius)
      rows.each { |wedge| assert_in_delta(-90 + (section - 1) * 90, wedge.rotation, 0.0001) }
    end
  end

  test "a spanning vehicle is a single wedge across its covered rows" do
    carousel = build_carousel(sections: 4, rows: 3)
    carousel.seat("1A").update!(rows_spanned: 2)
    wedges = SeatChart.new(carousel).seat_wedges(carousel.seats)

    assert_equal 11, wedges.size
    spanning = wedges.find { |wedge| wedge.seat.code == "1A" }
    assert_equal 370, spanning.outer_radius
    assert_equal 190, spanning.inner_radius
    assert_nil wedges.find { |wedge| wedge.seat.code == "1B" }
    assert_equal spanning.inner_radius, wedges.find { |wedge| wedge.seat.code == "1C" }.outer_radius
  end

  test "single rows and fractional row depths still cover the whole annulus" do
    [ 1, 4 ].each do |rows|
      carousel = build_carousel(sections: 1, rows:)
      wedges = SeatChart.new(carousel).seat_wedges(carousel.seats).sort_by { |wedge| wedge.seat.row_index }
      assert_equal rows, wedges.size
      assert_equal 370, wedges.first.outer_radius
      assert_equal 100, wedges.last.inner_radius
      wedges.each_cons(2) { |outer, inner| assert_equal outer.inner_radius, inner.outer_radius }
    end
  end
end
