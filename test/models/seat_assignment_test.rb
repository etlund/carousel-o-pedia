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
  end

  test "clears a seat as empty or unknown" do
    seat = @carousel.seat("1A")
    SeatAssignment.new(seat, create_figure("Gulliver")).save!

    SeatAssignment.new(seat.reload, nil, empty: true).save!
    assert_equal "empty", seat.reload.state
    assert_nil seat.figure

    SeatAssignment.new(seat, nil).save!
    assert_equal "unknown", seat.reload.state
  end
end
