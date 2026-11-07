require "uri"

class Carousel < ApplicationRecord
  include Sluggable
  has_paper_trail on: %i[ create update destroy ]

  STATUSES = %w[ operating stored lost unknown ].freeze
  ROTATIONS = %w[ clockwise counterclockwise ].freeze
  MAX_ROWS = 6
  RING_FIELDS = %w[ positions_count horses_count mount ].freeze
  RING_MOUNTS = %w[ stander jumper ].freeze
  SeatingCompleteness = Data.define(:confirmed_seats, :best_reading_seats, :rows_count, :sections_count)
  include SeatingLayout

  belongs_to :maker, optional: true
  has_many :seats, -> { where(carousel_deck_id: nil).order(:section, :row) }, dependent: :destroy
  has_many :all_seats, class_name: "Seat", dependent: :destroy
  has_many :carousel_decks, -> { order(:position, :id) }, dependent: :destroy
  has_many :placements, through: :all_seats
  has_many :figures, dependent: :restrict_with_error
  has_many :video_analyses, dependent: :destroy

  # Include child timestamps recorded before association changes started touching the carousel.
  scope :recently_updated, -> {
    order(Arel.sql(<<~SQL))
      MAX(
        carousels.updated_at,
        COALESCE((SELECT MAX(figures.updated_at) FROM figures
          WHERE figures.carousel_id = carousels.id), carousels.updated_at),
        COALESCE((SELECT MAX(seats.updated_at) FROM seats
          WHERE seats.carousel_id = carousels.id), carousels.updated_at),
        COALESCE((SELECT MAX(placements.updated_at) FROM placements
          INNER JOIN seats ON seats.id = placements.seat_id
          WHERE seats.carousel_id = carousels.id), carousels.updated_at)
      ) DESC
    SQL
  }

  scope :most_complete, -> {
    order(Arel.sql(<<~SQL))
      (SELECT COUNT(*) FROM seats
        WHERE seats.carousel_id = carousels.id AND seats.confidence = 'confirmed') DESC,
      (SELECT COUNT(*) FROM seats
        WHERE seats.carousel_id = carousels.id AND seats.confidence = 'best_reading') DESC,
      CASE WHEN carousels.rows_count IS NOT NULL OR carousels.sections_count IS NOT NULL
        THEN 0 ELSE 1 END
    SQL
  }

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :rotation, inclusion: { in: ROTATIONS }, allow_nil: true
  validates :published_horses_count, :published_other_animals_count, :published_chariots_count,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :summary_sources, presence: true, if: -> { published_counts? || layout_provisional? }
  validate :ring_details_are_consistent
  validates :summary_sources, presence: true, if: -> { ring_details.present? }

  normalizes :ring_details, with: ->(value) {
    if value.is_a?(Hash)
      value.transform_values do |details|
        if details.is_a?(Hash)
          details.transform_values do |detail|
            detail = detail.strip if detail.is_a?(String)
            detail.presence
          end.compact.transform_values { |detail| detail.is_a?(String) && detail.match?(/\A\d+\z/) ? detail.to_i : detail }
        else
          details
        end
      end.reject { |_, details| details == {} }
    else
      value
    end
  }

  blank_as_nil :city, :region, :country, :venue, :body, :other_links, :rotation, :summary_sources, :address_sources
  normalizes :street_address, :postal_code, with: ->(value) { value.strip.presence }
  normalizes :official_url, :wikipedia_url, with: ->(value) { value.strip.presence }
  normalizes :other_names, with: ->(value) { value.lines.map(&:strip).compact_blank.uniq.join("\n").presence }
  validate :website_urls_are_http

  def any_layout_known? = layout_known? || carousel_decks.any?(&:layout_known?)
  def display_name = name

  def seating_completeness
    counts = (carousel_decks.empty? ? seats : all_seats).map(&:confidence).tally
    SeatingCompleteness.new(confirmed_seats: counts.fetch("confirmed", 0),
      best_reading_seats: counts.fetch("best_reading", 0), rows_count:, sections_count:)
  end

  def published_category_totals
    { "horse" => published_horses_count, "menagerie" => published_other_animals_count, "chariot" => published_chariots_count }
  end

  def published_counts? = published_category_totals.values.any? { !_1.nil? }

  def location = [ city, region, country ].compact_blank.join(", ")

  def address
    region_and_postal_code = [ region, postal_code ].compact_blank.join(" ")
    locality = [ city, region_and_postal_code ].compact_blank.join(", ")
    [ street_address, locality, country ].compact_blank.join(", ")
  end

  def category_totals(sections = section_breakdown)
    if carousel_decks.any?
      return all_seats.includes(current_placement: { figure: :figure_type }).each_with_object(FigureType::CATEGORIES.index_with { 0 }) do |seat, totals|
        totals[seat.category] += 1 if seat.category
      end
    end
    sections.each_with_object(FigureType::CATEGORIES.index_with { 0 }) do |section, totals|
      section[:counts].each { |category, count| totals[category] += count }
    end
  end

  private
    def ring_details_are_consistent
      unless ring_details.is_a?(Hash)
        errors.add(:ring_details, "must describe rows from the outside in")
        return
      end
      return if ring_details.empty?

      unless rows_count.is_a?(Integer) && rows_count.between?(1, MAX_ROWS)
        errors.add(:ring_details, "require a verified row count")
        return
      end

      letters = ("A"..).first(rows_count)
      ring_details.each do |letter, details|
        unless letters.include?(letter) && details.is_a?(Hash) && (details.keys - RING_FIELDS).empty?
          errors.add(:ring_details, "contain an invalid row or field")
          next
        end
        %w[ positions_count horses_count ].each do |field|
          value = details[field]
          if value && !(value.is_a?(Integer) && value >= 0)
            errors.add(:ring_details, "#{letter} #{field.humanize.downcase} must be a nonnegative integer")
          end
        end
        if details["mount"] && !RING_MOUNTS.include?(details["mount"])
          errors.add(:ring_details, "#{letter} horse motion must be stander or jumper")
        end
        positions, horses = details.values_at("positions_count", "horses_count")
        if positions.is_a?(Integer) && horses.is_a?(Integer) && horses > positions
          errors.add(:ring_details, "#{letter} cannot have more horses than positions")
        end
      end
    end

    def website_urls_are_http
      %i[ official_url wikipedia_url ].each do |attribute|
        value = public_send(attribute)
        next if value.blank? || valid_website_url?(value)

        errors.add(attribute, "must be an http:// or https:// URL without login credentials")
      end
    end

    def valid_website_url?(value)
      uri = URI.parse(value)
      uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
    rescue URI::InvalidURIError
      false
    end
end
