class Carousel < ApplicationRecord
  include Sluggable
  has_paper_trail

  STATUSES = %w[ operating stored lost ].freeze
  ROTATIONS = %w[ clockwise counterclockwise ].freeze
  MAX_ROWS = 6

  belongs_to :maker, optional: true
  has_many :seats, -> { order(:section, :row) }, dependent: :destroy
  has_many :placements, through: :seats
  has_many :figures, dependent: :restrict_with_error

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :rotation, inclusion: { in: ROTATIONS }
  validates :sections_count, numericality: { only_integer: true, greater_than: 0 }
  validates :rows_count, numericality: { only_integer: true, in: 1..MAX_ROWS }

  blank_as_nil :city, :region, :country, :venue, :body

  after_create :fill_missing_seats

  # Rows are lettered from the outside in: A is always the outer row.
  def row_letters = ("A"..).first(rows_count)

  def location = [ city, region, country ].compact_blank.join(", ")

  def seat(code) = seats.find_by(Seat.parse_code(code) || { id: nil })

  # The lead figure sits in the outer row of section 1. Numbering runs from it.
  def lead_seat = seat("1A")

  def lead_figure = lead_seat&.figure

  # Renumbers every section so the given seat's section becomes section 1, keeping the
  # order figures pass the rail. Each seat's change is kept in its history.
  def renumber_from!(seat)
    shift = seat.section - 1
    return if shift.zero?

    transaction do
      all = seats.reload.to_a
      # Park every section on a negative number first, so no two seats ever share a code.
      seats.update_all("section = -section")
      all.each { |each_seat| each_seat.update!(section: (each_seat.section - 1 - shift) % sections_count + 1) }
      seats.reset
    end
  end

  # One entry per section: its seats and how many figures of each category sit there.
  def section_breakdown
    by_section = seats.includes(current_placement: { figure: :figure_type }).group_by(&:section)
    (1..sections_count).map do |number|
      section_seats = by_section.fetch(number, [])
      counts = FigureType::CATEGORIES.index_with { 0 }
      section_seats.each { |seat| counts[seat.category] += 1 if seat.category }
      { number:, seats: section_seats.index_by(&:row), counts: }
    end
  end

  # Every spot on the platform not covered by a seat gets an "unknown" seat, so a new
  # carousel starts with a full chart to fill in.
  def fill_missing_seats
    covered = seats.reload.flat_map { |seat| seat.rows_covered.map { |row| [ seat.section, row ] } }.to_set
    (1..sections_count).each do |section|
      row_letters.each do |row|
        seats.create!(section:, row:, state: "unknown") unless covered.include?([ section, row ])
      end
    end
  end

  def category_totals(sections = section_breakdown)
    sections.each_with_object(FigureType::CATEGORIES.index_with { 0 }) do |section, totals|
      section[:counts].each { |category, count| totals[category] += count }
    end
  end
end
