module SeatingLayout
  extend ActiveSupport::Concern

  included do
    validates :sections_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :rows_count, numericality: { only_integer: true, in: 1..Carousel::MAX_ROWS }, allow_nil: true
    validate :layout_dimensions_are_consistent
    validate :provisional_layout_has_dimensions
    after_save :resize_layout, if: :layout_changed?, unless: :skip_layout_resize
    attr_accessor :skip_layout_resize
  end

  def layout_known? = sections_count.present? && rows_count.present?
  def row_letters = layout_known? ? ("A"..).first(rows_count) : []
  def seat(code) = seats.find_by(Seat.parse_code(code) || { id: nil })
  def lead_seat = seat("1A")
  def lead_figure = lead_seat&.figure

  def renumber_from!(seat)
    raise ArgumentError, "Choose a seat on this platform" unless seats.exists?(id: seat.id)

    shift = seat.section - 1
    return if shift.zero?

    transaction do
      all = seats.reload.to_a
      seats.update_all("section = -section")
      all.each { |each_seat| each_seat.update!(section: (each_seat.section - 1 - shift) % sections_count + 1) }
      seats.reset
    end
  end

  def section_breakdown
    return [] unless layout_known?

    by_section = seats.includes(current_placement: { figure: :figure_type }).group_by(&:section)
    (1..sections_count).map do |number|
      section_seats = by_section.fetch(number, [])
      counts = FigureType::CATEGORIES.index_with { 0 }
      section_seats.each { |seat| counts[seat.category] += 1 if seat.category }
      { number:, seats: section_seats.index_by(&:row), counts: }
    end
  end

  def fill_missing_seats
    return unless layout_known?

    covered = seats.reload.flat_map { |seat| seat.rows_covered.map { |row| [ seat.section, row ] } }.to_set
    (1..sections_count).each do |section|
      row_letters.each do |row|
        seats.create!(section:, row:, state: "unknown") unless covered.include?([ section, row ])
      end
    end
  end

  private
    def provisional_layout_has_dimensions
      if layout_provisional? && !layout_known?
        errors.add(:layout_provisional, "requires recorded sections and rows")
      end
    end

    def layout_changed?
      layout_known? && (saved_change_to_sections_count? || saved_change_to_rows_count?)
    end

    def seats_outside_layout
      seats.where("section > ? OR row > ?", sections_count, row_letters.last)
    end

    def untouched_unknown_seat?(seat)
      seat.state == "unknown" && seat.confidence == "best_reading" && seat.rows_spanned == 1 &&
        seat.placements.empty? && !seat.versions.where(event: "update").exists?
    end

    def resize_layout
      seats_outside_layout.each(&:destroy!)
      fill_missing_seats
    end

    def layout_dimensions_are_consistent
      return if skip_layout_resize

      if !layout_known? && seats.exists?
        errors.add(:base, "The layout cannot be cleared while seats exist")
      end
      return unless layout_known? && errors[:sections_count].empty? && errors[:rows_count].empty?

      outside = seats_outside_layout.includes(:placements).to_a
      protected_codes = outside.reject { untouched_unknown_seat?(_1) }.map(&:code)
      if protected_codes.any?
        errors.add(:base, "The layout cannot remove #{protected_codes.to_sentence}: only untouched unknown seats can be removed")
      end
      spanning_codes = seats.where.not(id: outside.map(&:id)).select do |seat|
        seat.row_index + seat.rows_spanned > rows_count
      end.map(&:code)
      if spanning_codes.any?
        errors.add(:base, "The layout would cut off spanning seats #{spanning_codes.to_sentence}; edit their row spans first")
      end
    end
end
