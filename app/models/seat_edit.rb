class SeatEdit
  def initialize(seat, figure, attributes:, empty: false)
    @seat = seat
    @figure = figure
    @attributes = attributes
    @empty = empty
  end

  def save!
    Seat.transaction do
      remove_covered_draft_placeholders
      remove_replaced_draft_placeholder
      @seat.update!(@attributes)
      SeatAssignment.new(@seat, @figure, empty: @empty).save!
    end
  end

  private
    def remove_covered_draft_placeholders
      desired_rows.drop(1).each do |row|
        figure = @seat.layout.seats.find_by(section: @seat.section, row:)&.figure
        figure.destroy! if figure&.draft_placeholder?
      end
    end

    def remove_replaced_draft_placeholder
      current = @seat.figure
      current.destroy! if current&.draft_placeholder? && current != @figure
    end

    def desired_rows
      @seat.layout.row_letters.slice(@seat.row_index, @attributes[:rows_spanned].to_i) || []
    end
end
