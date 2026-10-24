require "test_helper"

class FigureTest < ActiveSupport::TestCase
  setup { @carousel = build_carousel }

  test "a figure requires a carousel even without a seat" do
    figure = create_figure("Unseated figure")
    assert_equal @carousel, figure.carousel
    assert_nil figure.seat
    assert_includes @carousel.figures, figure
    figure.carousel = nil
    assert_not figure.valid?
    assert_includes figure.errors[:carousel], "must exist"
  end

  test "an unseated figure can change carousel" do
    figure = create_figure("Traveling figure")
    other = build_carousel
    figure.update!(carousel: other)
    assert_equal other, figure.reload.carousel
    assert_not_includes @carousel.figures, figure
    assert_includes other.figures, figure
  end

  test "a seated figure cannot be reassigned without moving or clearing its seat" do
    figure = create_figure("Seated figure")
    SeatAssignment.new(@carousel.seat("1A"), figure).save!
    assert_not figure.update(carousel: build_carousel)
    assert_includes figure.errors[:carousel].join, "must match the current seat"
    assert_equal @carousel, figure.reload.carousel
    assert_equal figure, @carousel.seat("1A").figure
  end

  test "a current placement cannot bypass carousel ownership" do
    figure = create_figure("Local figure")
    placement = Placement.new(figure:, seat: build_carousel.seat("1A"))
    assert_not placement.valid?
    assert_includes placement.errors[:figure], "must belong to the seat's carousel"
  end

  test "a carousel with unseated inventory cannot be deleted" do
    figure = create_figure("Reserve")
    assert_not @carousel.destroy
    assert_not @carousel.destroyed?
    assert_equal @carousel, figure.reload.carousel
    assert_equal 8, @carousel.seats.count
  end
end
