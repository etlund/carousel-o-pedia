# Puts a figure in a seat, or marks the seat empty or unknown. Whatever was in the seat
# leaves it, and a figure moving from another seat leaves that seat empty, so every
# figure and seat keeps a dated history of placements.
class SeatAssignment
  def initialize(seat, figure, empty: false, on: Date.current)
    @seat, @figure, @on = seat, figure, on
    @state = if figure then "filled" elsif empty then "empty" else "unknown" end
  end

  def save!
    # Read placements fresh: cached associations go stale as figures move.
    seat_placement = Placement.current.find_by(seat: @seat)
    return if seat_placement&.figure == @figure && @seat.state == @state

    Placement.transaction do
      unless seat_placement&.figure == @figure
        seat_placement&.update!(ended_on: @on)
        move_figure_here if @figure
      end
      @seat.update!(state: @state)
    end
    @seat.reset_current_placement
    @figure&.reset_current_placement
  end

  private
    def move_figure_here
      if (previous = Placement.current.find_by(figure: @figure))
        previous.update!(ended_on: @on)
        previous.seat.update!(state: "empty")
      end
      @seat.placements.create!(figure: @figure, started_on: @on)
    end
end
