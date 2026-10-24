require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds the Great Northern Carousel from the seating chart" do
    carousel = load_seeds

    assert_equal 14, carousel.sections_count
    assert_equal 3, carousel.rows_count
    assert_equal({ "horse" => 18, "menagerie" => 18, "chariot" => 2 }, carousel.category_totals)
    assert_equal "Titan the Hippocampus", carousel.lead_figure.name
    assert_equal "Cutty the Trout", carousel.seat("3A").figure.name
    assert_equal "Gulliver", carousel.seat("9A").figure.name
    assert_equal %w[ A B C ], carousel.seat("4A").rows_covered
    assert_equal "unknown", carousel.seat("9C").state
    assert carousel.seat("8C").confirmed?
    assert_not carousel.seat("8B").confirmed?
  end

  test "loading seeds again leaves wiki edits alone" do
    carousel = load_seeds
    carousel.seat("9A").figure.update!(description: "Edited on the wiki")
    assert_no_difference %w[ Seat.count Figure.count Placement.count FigureType.count ] do
      load_seeds
    end
    assert_equal "Edited on the wiki", carousel.seat("9A").figure.description
  end
end
