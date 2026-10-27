# Research schematic, not a seat map: ring counts do not establish angular alignment.
class RingChart
  Band = Data.define(:letter, :inner_radius, :outer_radius, :positions_count, :horses_count, :mount)

  def initialize(carousel)
    raise ArgumentError, "Ring research and a known row count are required" unless carousel.ring_details.present? && carousel.rows_count

    @carousel = carousel
  end

  def bands
    depth = (SeatChart::PLATFORM_RADIUS - SeatChart::HUB_RADIUS).to_f / @carousel.rows_count
    ("A"..).first(@carousel.rows_count).each_with_index.map do |letter, index|
      details = @carousel.ring_details.fetch(letter, {})
      Band.new(letter:, inner_radius: SeatChart::PLATFORM_RADIUS - (index + 1) * depth,
        outer_radius: SeatChart::PLATFORM_RADIUS - index * depth,
        positions_count: details["positions_count"], horses_count: details["horses_count"], mount: details["mount"])
    end
  end
end
