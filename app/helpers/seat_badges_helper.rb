# A small wedge showing where a seat sits, read like an airplane seat map: one slice of
# the platform with the rail on the left and the hub on the right, every row letter
# inside it, the seat's own row highlighted, and the section number before the wedge.
module SeatBadgesHelper
  BADGE_CENTER_X = -40.0  # Hub of the unreflected geometry.
  BADGE_CENTER_Y = 12.0
  BADGE_INNER_RADIUS = 48.0
  BADGE_ROW_DEPTH = 14.0
  BADGE_HALF_ANGLE = 7 * Math::PI / 180

  def seat_badge(seat, size: :small)
    letters = seat.carousel.row_letters
    covered = seat.rows_covered
    outer = BADGE_INNER_RADIUS + letters.size * BADGE_ROW_DEPTH
    # Room for the carousel's widest section number, so badges line up in lists.
    number_width = 10 * seat.carousel.sections_count.to_s.size
    wedge_offset = number_width + 2
    width = (BADGE_CENTER_X + outer + wedge_offset + 4).round
    kind = seat.category || seat.state
    reflection = 2 * BADGE_CENTER_X + outer + BADGE_INNER_RADIUS

    # Reflect only the bands; position the upright labels from the outer row inward.
    bands = letters.each_with_index.map do |letter, index|
      inner = outer - (index + 1) * BADGE_ROW_DEPTH
      on = covered.include?(letter)
      safe_join([
        tag.path(d: wedge_path(inner, inner + BADGE_ROW_DEPTH), transform: "translate(#{reflection} 0) scale(-1 1)", class: [ "band", ("on" if on) ]),
        tag.text(on ? letter : letter.downcase, x: (reflection - BADGE_CENTER_X - inner - BADGE_ROW_DEPTH / 2).round(1), y: 15.5, class: [ "row", ("on" if on) ])
      ])
    end

    tag.svg(class: [ "seat-badge", size, kind ], viewBox: "0 0 #{width} 24", width: width * (size == :large ? 2 : 1), height: 24 * (size == :large ? 2 : 1),
            role: "img", "aria-label": "Seat #{seat.code}") do
      safe_join([
        tag.title("Seat #{seat.code}: section #{seat.section}, #{seat.rows_spanned > 1 ? "rows #{covered.first} to #{covered.last}" : "row #{seat.row}"}"),
        tag.text(seat.section, x: wedge_offset, y: 16.5, class: "section", "text-anchor": "end"),
        tag.g(safe_join(bands), transform: "translate(#{wedge_offset} 0)")
      ])
    end
  end

  private
    # One band of the wedge, an annular sector between two radii.
    def wedge_path(inner, outer, half_angle: BADGE_HALF_ANGLE, center_x: BADGE_CENTER_X, center_y: BADGE_CENTER_Y)
      point = ->(radius, angle) { "#{(center_x + radius * Math.cos(angle)).round(2)} #{(center_y + radius * Math.sin(angle)).round(2)}" }
      # Splitting the arcs also supports a single section covering the full circle.
      "M#{point[inner, -half_angle]} L#{point[outer, -half_angle]} " \
        "A#{outer} #{outer} 0 0 1 #{point[outer, 0]} A#{outer} #{outer} 0 0 1 #{point[outer, half_angle]} " \
        "L#{point[inner, half_angle]} A#{inner} #{inner} 0 0 0 #{point[inner, 0]} A#{inner} #{inner} 0 0 0 #{point[inner, -half_angle]} Z"
    end
end
