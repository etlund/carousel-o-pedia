require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds the Great Northern Carousel from the seating chart" do
    carousel = load_seeds

    assert_equal 14, carousel.sections_count
    assert_equal 3, carousel.rows_count
    assert_equal({ "horse" => 18, "menagerie" => 18, "chariot" => 2 }, carousel.category_totals)
    assert_equal "Cutty the Trout", carousel.seat("1A").figure.name
    assert_equal "Gulliver", carousel.seat("7A").figure.name
    assert_equal %w[ A B C ], carousel.seat("2A").rows_covered
    assert_equal "unknown", carousel.seat("7C").state
    assert carousel.seat("6C").confirmed?
    assert_not carousel.seat("6B").confirmed?
  end

  test "loading seeds twice changes nothing" do
    load_seeds
    assert_no_difference %w[ Seat.count Figure.count Placement.count FigureType.count ] do
      load_seeds
    end
  end
end
