class CarouselDeck < ApplicationRecord
  include SeatingLayout
  has_paper_trail on: %i[ create update destroy ]

  belongs_to :carousel, touch: true
  has_many :seats, -> { order(:section, :row) }, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: { scope: :carousel_id }
  validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :carousel_id }
  validates :published_horses_count, :published_other_animals_count, :published_chariots_count,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :summary_sources, presence: true, if: -> { published_counts? || layout_provisional? }
  blank_as_nil :summary_sources
  normalizes :name, with: ->(value) { value.strip }
  validate :carousel_cannot_change, on: :update

  delegate :rotation, to: :carousel
  def display_name = "#{carousel.name} - #{name}"
  def ring_details = {}
  def figures = carousel.figures
  def published_category_totals
    { "horse" => published_horses_count, "menagerie" => published_other_animals_count, "chariot" => published_chariots_count }
  end
  def published_counts? = published_category_totals.values.any? { !_1.nil? }

  def category_totals
    seats.includes(current_placement: { figure: :figure_type }).each_with_object(FigureType::CATEGORIES.index_with { 0 }) do |seat, totals|
      totals[seat.category] += 1 if seat.category
    end
  end

  private
    def carousel_cannot_change
      errors.add(:carousel, "cannot change for an existing deck") if will_save_change_to_carousel_id?
    end
end
