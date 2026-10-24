class Carousel < ApplicationRecord
  include Sluggable
  has_paper_trail

  STATUSES = %w[ operating stored lost ].freeze
  ROTATIONS = %w[ clockwise counterclockwise ].freeze
  MAX_ROWS = 6

  belongs_to :maker, optional: true
  has_many :seats, -> { order(:section, :row) }, dependent: :destroy
  has_many :placements, through: :seats
  has_many :figures, through: :placements

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :rotation, inclusion: { in: ROTATIONS }
  validates :sections_count, numericality: { only_integer: true, greater_than: 0 }
  validates :rows_count, numericality: { only_integer: true, in: 1..MAX_ROWS }

  # Rows are lettered from the outside in: A is always the outer row.
  def row_letters = ("A"..).first(rows_count)

  def location = [ city, region, country ].compact_blank.join(", ")

  def seat(code) = seats.find_by(Seat.parse_code(code) || { id: nil })

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

  def category_totals(sections = section_breakdown)
    sections.each_with_object(FigureType::CATEGORIES.index_with { 0 }) do |section, totals|
      section[:counts].each { |category, count| totals[category] += count }
    end
  end
end
