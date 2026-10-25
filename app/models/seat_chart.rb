# Geometry for the round seat chart: where each section and seat sits on an 800x800 SVG.
# Rows run from the outside in, and section 1 sits at the top, matching the Helena chart.
class SeatChart
  SIZE = 800
  CENTER = SIZE / 2
  PLATFORM_RADIUS = 370
  HUB_RADIUS = 100
  OUTER_ROW_RADIUS = 318
  INNER_ROW_RADIUS = 156
  OUTER_SEAT_WIDTH = 90
  INNER_SEAT_WIDTH = 62
  SEAT_HEIGHT = 34
  LABEL_RADIUS = 386

  Point = Data.define(:x, :y)
  SeatShape = Data.define(:seat, :center, :width, :height, :round)

  attr_reader :carousel

  def initialize(carousel)
    raise ArgumentError, "A known carousel layout is required for a seat chart" unless carousel.layout_known?

    @carousel = carousel
  end

  def section_count = carousel.sections_count

  def section_labels
    (1..section_count).map { |number| [ number, polar(LABEL_RADIUS, angle(number - 1)) ] }
  end

  def section_dividers
    section_count.times.map do |index|
      a = angle(index - 0.5)
      [ polar(HUB_RADIUS + 2, a), polar(PLATFORM_RADIUS, a) ]
    end
  end

  # Dashed rings drawn halfway between neighbouring rows.
  def row_dividers
    row_radii.each_cons(2).map { |outer, inner| (outer + inner) / 2.0 }
  end

  def seat_shapes(seats)
    seats.map do |seat|
      radii = row_radii.slice(seat.row_index, seat.rows_spanned)
      center = polar(radii.sum / radii.size, angle(seat.section - 1))
      if seat.rows_spanned > 1
        diameter = 2 * (34 + 9 * (seat.rows_spanned - 1))
        SeatShape.new(seat:, center:, width: diameter, height: diameter, round: true)
      else
        SeatShape.new(seat:, center:, width: seat_width(seat.row_index), height: SEAT_HEIGHT, round: false)
      end
    end
  end

  private
    def row_radii
      return [ (OUTER_ROW_RADIUS + INNER_ROW_RADIUS) / 2.0 ] if carousel.rows_count == 1

      step = (OUTER_ROW_RADIUS - INNER_ROW_RADIUS).to_f / (carousel.rows_count - 1)
      carousel.rows_count.times.map { |index| OUTER_ROW_RADIUS - index * step }
    end

    # Narrower rows toward the hub, and never wider than the arc a section has at that radius.
    def seat_width(row_index)
      fraction = carousel.rows_count == 1 ? 0 : row_index.to_f / (carousel.rows_count - 1)
      width = OUTER_SEAT_WIDTH - fraction * (OUTER_SEAT_WIDTH - INNER_SEAT_WIDTH)
      arc = 2 * Math::PI * row_radii[row_index] / section_count
      [ width, arc * 0.85 ].min.round(1)
    end

    def angle(index) = index.to_f / section_count * 2 * Math::PI - Math::PI / 2

    def polar(radius, theta)
      Point.new(x: (CENTER + radius * Math.cos(theta)).round(1), y: (CENTER + radius * Math.sin(theta)).round(1))
    end
end
