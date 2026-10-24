require "test_helper"

class SeatAssignmentTest < ActiveSupport::TestCase
  setup { @carousel = build_carousel(sections: 3, rows: 1) }

  test "puts a figure in a seat" do
    figure = create_figure("Gulliver")
    SeatAssignment.new(@carousel.seat("1A"), figure).save!

    assert_equal figure, @carousel.seat("1A").figure
    assert_equal "filled", @carousel.seat("1A").state
  end

  test "moving a figure ends its old placement and leaves its old seat empty" do
    figure = create_figure("Gulliver")
    SeatAssignment.new(@carousel.seat("1A"), figure, on: Date.new(2020, 1, 1)).save!
    SeatAssignment.new(@carousel.seat("2A"), figure, on: Date.new(2026, 1, 1)).save!

    assert_equal figure, @carousel.seat("2A").figure
    assert_nil @carousel.seat("1A").figure
    assert_equal "empty", @carousel.seat("1A").state
    assert_equal [ nil, Date.new(2026, 1, 1) ], figure.placements.map(&:ended_on)
  end

  test "replacing a figure keeps the old one's history" do
    old_figure, new_figure = create_figure("Horse 1"), create_figure("Rocky")
    seat = @carousel.seat("3A")
    SeatAssignment.new(seat, old_figure).save!
    SeatAssignment.new(seat.reload, new_figure).save!

    assert_equal new_figure, seat.reload.figure
    assert_equal 2, seat.placements.count
    assert_nil old_figure.reload.seat
    assert_equal @carousel, old_figure.carousel
  end

  test "clears a seat as empty or unknown" do
    seat = @carousel.seat("1A")
    SeatAssignment.new(seat, create_figure("Gulliver")).save!

    SeatAssignment.new(seat.reload, nil, empty: true).save!
    assert_equal "empty", seat.reload.state
    assert_nil seat.figure
    assert_equal @carousel, Figure.find_by!(name: "Gulliver").carousel

    SeatAssignment.new(seat, nil).save!
    assert_equal "unknown", seat.reload.state
  end

  test "moving to another carousel transfers ownership and preserves placement history" do
    figure = create_figure("Transferred figure")
    old_seat = @carousel.seat("1A")
    SeatAssignment.new(old_seat, figure).save!
    assert_equal old_seat, figure.seat
    destination = build_carousel

    SeatAssignment.new(destination.seat("1A"), figure).save!

    assert_equal destination, figure.carousel
    assert_equal destination.seat("1A"), figure.seat
    assert_equal "empty", old_seat.reload.state
    assert_equal 2, figure.placements.count
    assert_equal 1, figure.placements.where.not(ended_on: nil).count
    assert_not_includes @carousel.figures, figure
    assert_includes destination.figures, figure
    assert_equal [ @carousel.id, destination.id ], figure.versions.last.changeset["carousel_id"]

    SeatAssignment.new(destination.seat("1A"), nil).save!
    assert_nil figure.reload.seat
    assert_equal destination, figure.carousel
  end

  test "a failed cross-carousel move rolls back ownership and placement changes" do
    figure = create_figure("Unmoved figure")
    SeatAssignment.new(@carousel.seat("1A"), figure).save!
    destination = build_carousel(rows: 1)
    invalid_seat = destination.seat("1A")
    invalid_seat.rows_spanned = 2

    assert_raises ActiveRecord::RecordInvalid do
      SeatAssignment.new(invalid_seat, figure).save!
    end

    assert_equal @carousel, figure.reload.carousel
    assert_equal @carousel.seat("1A"), figure.seat
    assert_nil destination.seat("1A").figure
    assert_equal 1, figure.placements.count
    assert_nil figure.current_placement.ended_on
  end
end
