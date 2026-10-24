# A small wedge showing where a seat sits, read like an airplane seat map: one slice of
# the platform with the hub on the left and the rail on the right, every row letter
# inside it, the seat's own row highlighted, and the section number past the rail.
module SeatBadgesHelper
  BADGE_CENTER_X = -40.0  # the hub, off the left edge
  BADGE_CENTER_Y = 12.0
  BADGE_INNER_RADIUS = 48.0
  BADGE_ROW_DEPTH = 14.0
  BADGE_HALF_ANGLE = 7 * Math::PI / 180

  def seat_badge(seat, size: :small)
    letters = seat.carousel.row_letters
    covered = seat.rows_covered
    outer = BADGE_INNER_RADIUS + letters.size * BADGE_ROW_DEPTH
    # Room for the carousel's widest section number, so badges line up in lists.
    width = (BADGE_CENTER_X + outer + 6 + 8 * seat.carousel.sections_count.to_s.size + 4).round
    kind = seat.category || seat.state

    # Rows run from the outside in, so the innermost row is drawn first, at the narrow end.
    bands = letters.reverse.each_with_index.map do |letter, index|
      inner = BADGE_INNER_RADIUS + index * BADGE_ROW_DEPTH
      on = covered.include?(letter)
      safe_join([
        tag.path(d: wedge_path(inner, inner + BADGE_ROW_DEPTH), class: [ "band", ("on" if on) ]),
        tag.text(on ? letter : letter.downcase, x: (BADGE_CENTER_X + inner + BADGE_ROW_DEPTH / 2).round(1), y: 15.5, class: [ "row", ("on" if on) ])
      ])
    end

    tag.svg(class: [ "seat-badge", size, kind ], viewBox: "0 0 #{width} 24", width: width * (size == :large ? 2 : 1), height: 24 * (size == :large ? 2 : 1),
            role: "img", "aria-label": "Seat #{seat.code}") do
      safe_join([
        tag.title("Seat #{seat.code}: section #{seat.section}, #{seat.rows_spanned > 1 ? "rows #{covered.first} to #{covered.last}" : "row #{seat.row}"}"),
        *bands,
        tag.text(seat.section, x: (BADGE_CENTER_X + outer + 6).round(1), y: 16.5, class: "section")
      ])
    end
  end

  private
    # One band of the wedge, an annular sector between two radii.
    def wedge_path(inner, outer)
      cos, sin = Math.cos(BADGE_HALF_ANGLE), Math.sin(BADGE_HALF_ANGLE)
      point = ->(radius, sign) { "#{(BADGE_CENTER_X + radius * cos).round(2)} #{(BADGE_CENTER_Y + sign * radius * sin).round(2)}" }
      "M#{point[inner, -1]} L#{point[outer, -1]} A#{outer} #{outer} 0 0 1 #{point[outer, 1]} L#{point[inner, 1]} A#{inner} #{inner} 0 0 0 #{point[inner, -1]} Z"
    end
end
