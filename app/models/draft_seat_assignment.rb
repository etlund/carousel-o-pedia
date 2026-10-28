class DraftSeatAssignment
  def self.create!(seat, figure_type:, mount:, source_notes:)
    figure = seat.carousel.figures.create!(name: "#{figure_type.name} #{seat.code}", short_name: figure_type.name,
      figure_type:, mount:,
      description: "Provisional seat-based name; individual identity and decoration have not been verified.",
      body: "## Draft seating sources\n\n#{source_notes.strip}")
    seat.update!(confidence: "best_reading")
    SeatAssignment.new(seat, figure).save!
    figure
  end
end
