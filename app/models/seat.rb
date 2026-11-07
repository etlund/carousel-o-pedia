class Seat < ApplicationRecord
  has_paper_trail on: %i[ create update destroy ]

  STATES = %w[ filled empty unknown ].freeze
  CONFIDENCES = %w[ confirmed best_reading ].freeze
  CODE_FORMAT = /\A(\d+)([A-Z])\z/

  belongs_to :carousel, touch: true
  belongs_to :carousel_deck, optional: true, touch: true
  has_many :placements, -> { order(started_on: :desc) }, dependent: :destroy
  has_one :current_placement, -> { where(ended_on: nil) }, class_name: "Placement", inverse_of: :seat

  scope :unknown, -> { where(state: "unknown").where.missing(:current_placement) }

  validates :row, format: { with: /\A[A-Z]\z/ }, uniqueness: { scope: [ :carousel_id, :carousel_deck_id, :section ] }
  validates :state, inclusion: { in: STATES }
  validates :confidence, inclusion: { in: CONFIDENCES }
  validates :rows_spanned, numericality: { only_integer: true, greater_than: 0 }
  validate :fits_on_carousel
  validate :covered_seats_are_free
  validate :deck_belongs_to_carousel
  before_validation :assign_deck_carousel

  after_save :reshape_neighbours, if: :saved_change_to_rows_spanned?

  # "5A" => { section: 5, row: "A" }
  def self.parse_code(code)
    match = CODE_FORMAT.match(code.to_s.upcase)
    { section: match[1].to_i, row: match[2] } if match
  end

  # Section number plus row letter. A figure that spans rows uses its outermost row.
  def code = "#{section}#{row}"
  def layout = carousel_deck || carousel
  def display_code = carousel_deck ? "#{carousel_deck.name} - #{code}" : code

  def to_param = code

  def row_index = row.ord - "A".ord

  def rows_covered = layout.row_letters.slice(row_index, rows_spanned)

  def figure = current_placement&.figure

  def category = figure&.category

  def confirmed? = confidence == "confirmed"

  private
    # Other seats in this section that a spanning figure now covers.
    def covered_seats
      layout.seats.where(section:, row: rows_covered.drop(1)).where.not(id:)
    end

    def covered_seats_are_free
      return unless carousel && rows_spanned.to_i > 1 && errors.none?

      taken = covered_seats.select(&:figure).map(&:code)
      errors.add(:rows_spanned, "would cover #{taken.to_sentence}, which already have figures") if taken.any?
    end

    def reshape_neighbours
      covered_seats.destroy_all
      layout.fill_missing_seats
    end

    def fits_on_carousel
      return unless carousel && section && row

      unless layout.layout_known?
        errors.add(:carousel, "needs a known layout before seats can be added")
        return
      end

      errors.add(:section, "must be between 1 and #{layout.sections_count}") unless section.between?(1, layout.sections_count)
      errors.add(:row, "is past the carousel's #{layout.rows_count} rows") if row_index + rows_spanned > layout.rows_count
    end

    def assign_deck_carousel
      self.carousel ||= carousel_deck.carousel if carousel_deck
    end

    def deck_belongs_to_carousel
      if carousel_deck && carousel_deck.carousel_id != carousel_id
        errors.add(:carousel_deck, "must belong to the seat's carousel")
      end
      if persisted? && (will_save_change_to_carousel_deck_id? || will_save_change_to_carousel_id?)
        errors.add(:base, "A seat cannot move between platforms; move its figure instead")
      end
    end
end
