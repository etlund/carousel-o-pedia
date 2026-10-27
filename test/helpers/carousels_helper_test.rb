require "test_helper"

class CarouselsHelperTest < ActionView::TestCase
  test "seating completeness summarizes confirmed and best-reading seats including zero counts" do
    carousel = build_carousel(sections: 2, rows: 2)
    assert_equal "0 confirmed \u00b7 4 best reading", carousel_seating_completeness_label(carousel)

    carousel.seats.first(2).each { _1.update!(confidence: "confirmed") }
    assert_equal "2 confirmed \u00b7 2 best reading", carousel_seating_completeness_label(carousel)

    carousel.seats.each { _1.update!(confidence: "confirmed") }
    assert_equal "4 confirmed \u00b7 0 best reading", carousel_seating_completeness_label(carousel)
  end

  test "seating completeness counts spanning seats once" do
    carousel = build_carousel(sections: 2, rows: 2)
    carousel.seat("1A").update!(rows_spanned: 2, confidence: "confirmed")
    assert_equal "1 confirmed \u00b7 2 best reading", carousel_seating_completeness_label(carousel.reload)
  end

  test "seating completeness describes partial dimensions without inventing seats" do
    [
      [ { rows_count: 3 }, "3 rows recorded \u00b7 sections unknown" ],
      [ { rows_count: 1 }, "1 row recorded \u00b7 sections unknown" ],
      [ { sections_count: 12 }, "12 sections recorded \u00b7 rows unknown" ],
      [ { sections_count: 1 }, "1 section recorded \u00b7 rows unknown" ],
      [ { rows_count: 3, sections_count: 12 }, "3 rows recorded \u00b7 12 sections recorded" ],
      [ {}, "Layout unknown" ],
      [ { published_horses_count: 48 }, "Layout unknown" ]
    ].each do |attributes, expected|
      assert_equal expected, carousel_seating_completeness_label(Carousel.new(**attributes))
    end
  end
end
