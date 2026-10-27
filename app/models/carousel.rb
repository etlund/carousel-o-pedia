require "uri"

class Carousel < ApplicationRecord
  include Sluggable
  has_paper_trail

  STATUSES = %w[ operating stored lost ].freeze
  ROTATIONS = %w[ clockwise counterclockwise ].freeze
  MAX_ROWS = 6
  RING_FIELDS = %w[ positions_count horses_count mount ].freeze
  RING_MOUNTS = %w[ stander jumper ].freeze

  belongs_to :maker, optional: true
  has_many :seats, -> { order(:section, :row) }, dependent: :destroy
  has_many :placements, through: :seats
  has_many :figures, dependent: :restrict_with_error

  scope :with_data_first, -> {
    order(Arel.sql(<<~SQL))
      CASE WHEN carousels.sections_count IS NOT NULL OR carousels.rows_count IS NOT NULL
        OR carousels.published_horses_count IS NOT NULL
        OR carousels.published_other_animals_count IS NOT NULL
        OR carousels.published_chariots_count IS NOT NULL
        OR EXISTS (SELECT 1 FROM figures WHERE figures.carousel_id = carousels.id)
      THEN 0 ELSE 1 END
    SQL
  }

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :rotation, inclusion: { in: ROTATIONS }, allow_nil: true
  validates :sections_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :rows_count, numericality: { only_integer: true, in: 1..MAX_ROWS }, allow_nil: true
  validates :published_horses_count, :published_other_animals_count, :published_chariots_count,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :summary_sources, presence: true, if: :published_counts?
  validate :layout_dimensions_are_consistent
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
  validate :website_urls_are_http

  after_save :fill_missing_seats, if: :layout_added?

  def layout_known? = sections_count.present? && rows_count.present?

  def published_category_totals
    { "horse" => published_horses_count, "menagerie" => published_other_animals_count, "chariot" => published_chariots_count }
  end

  def published_counts? = published_category_totals.values.any? { !_1.nil? }

  # Rows are lettered from the outside in: A is always the outer row.
  def row_letters = layout_known? ? ("A"..).first(rows_count) : []

  def location = [ city, region, country ].compact_blank.join(", ")

  def address
    region_and_postal_code = [ region, postal_code ].compact_blank.join(" ")
    locality = [ city, region_and_postal_code ].compact_blank.join(", ")
    [ street_address, locality, country ].compact_blank.join(", ")
  end

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
    return [] unless layout_known?

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
    return unless layout_known?

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

  private
    def layout_added?
      layout_known? && (saved_change_to_sections_count?(from: nil) || saved_change_to_rows_count?(from: nil))
    end

    def layout_dimensions_are_consistent
      if !layout_known? && seats.exists?
        errors.add(:base, "The layout cannot be cleared while seats exist")
      end

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
