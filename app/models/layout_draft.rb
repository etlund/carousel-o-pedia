require "digest"

class LayoutDraft
  include ActiveModel::Model
  include ActiveModel::Attributes
  include SeatingPreview

  class Conflict < StandardError; end
  Proposal = Data.define(:section, :row, :rows_spanned, :state, :figure_type, :mount) do
    def code = "#{section}#{row}"
    def rows_covered = (row...(row.ord + rows_spanned).chr).to_a
  end

  attribute :sections_count, :string
  attribute :rows_count, :string
  attribute :figure_type_id, :string
  attribute :mount, :string
  attribute :chariot_type_id, :string
  attribute :chariot_seats, :string
  attribute :chariot_rows_spanned, :string, default: "2"
  attribute :empty_seats, :string
  attribute :source_notes, :string

  validates :sections_count, numericality: { only_integer: true, greater_than: 0 }
  validates :rows_count, :chariot_rows_spanned,
    numericality: { only_integer: true, in: 1..Carousel::MAX_ROWS }
  validates :figure_type, presence: { message: "must be an existing figure type" }
  validates :mount, inclusion: { in: Figure::MOUNTS }, allow_blank: true
  validates :source_notes, presence: true
  validate :no_existing_layout
  validate :chariot_type_is_valid
  validate :positions_are_valid

  def initialize(carousel, attributes = {})
    @carousel = carousel
    super(attributes)
  end

  def self.defaults_for(carousel)
    rows = carousel.rows_count
    counts = carousel.published_category_totals.values
    sections = carousel.sections_count
    if sections.nil? && rows && counts.none?(&:nil?)
      spaces = carousel.published_horses_count + carousel.published_other_animals_count + carousel.published_chariots_count * 2
      sections = spaces / rows if spaces.positive? && (spaces % rows).zero?
    end
    chariots = carousel.published_chariots_count
    positions = if sections && chariots && chariots.positive? && chariots <= sections
      chariots.times.map { "#{_1 * sections / chariots + 1}A" }.join(", ")
    end
    {
      sections_count: sections, rows_count: rows,
      figure_type_id: FigureType.find_by(name: "Horse")&.id, mount: "jumper",
      chariot_type_id: FigureType.find_by(name: "Chariot", category: "chariot")&.id,
      chariot_seats: positions, source_notes: carousel.summary_sources
    }
  end

  def figure_type
    FigureType.find_by(id: figure_type_id) if figure_type_id.to_s.match?(/\A[1-9]\d*\z/)
  end

  def chariot_type
    FigureType.find_by(id: chariot_type_id) if chariot_type_id.to_s.match?(/\A[1-9]\d*\z/)
  end

  def proposals
    type, vehicle_type = figure_type, chariot_type
    chariots = codes(:chariot_seats).map { Seat.parse_code(_1) }
    empty = codes(:empty_seats).map { Seat.parse_code(_1) }
    covered = chariots.flat_map do |position|
      (1...chariot_rows_spanned.to_i).map { [ position[:section], (position[:row].ord + _1).chr ] }
    end.to_set
    (1..sections_count.to_i).flat_map do |section|
      ("A"..).first(rows_count.to_i).filter_map do |row|
        next if covered.include?([ section, row ])

        position = { section:, row: }
        chariot = chariots.include?(position)
        is_empty = empty.include?(position)
        Proposal.new(section:, row:, rows_spanned: chariot ? chariot_rows_spanned.to_i : 1,
          state: is_empty ? "empty" : "filled", figure_type: is_empty ? nil : (chariot ? vehicle_type : type),
          mount: is_empty ? nil : (chariot ? "fixed" : mount.presence))
      end
    end
  end

  def category_totals
    FigureType::CATEGORIES.index_with { |category| proposals.count { _1.figure_type&.category == category } }
  end

  def assumptions
    [
      "Provisional #{sections_count}-section, #{rows_count}-row regular grid; equal spacing and cross-ring alignment are assumptions.",
      "Chariots start at #{codes(:chariot_seats).presence&.join(', ') || 'no seats'} and each spans #{chariot_rows_spanned} adjacent rows inward. Their positions, fixed motion, and footprints are drafting assumptions, not verified observations.",
      "Empty positions: #{codes(:empty_seats).presence&.join(', ') || 'none'}. All remaining positions use #{figure_type.name} with #{mount.presence || 'unknown'} motion.",
      "Figure names and section 1 are editorial references. Every placement is a best reading, not confirmed."
    ].join("\n\n")
  end

  def preview_carousel
    @preview_carousel ||= Carousel.new(name: @carousel.name, sections_count:, rows_count:, rotation: @carousel.rotation)
  end

  def preview_seats
    proposals.map do |proposal|
      Seat.new(carousel: preview_carousel, section: proposal.section, row: proposal.row,
        rows_spanned: proposal.rows_spanned, state: proposal.state, confidence: "best_reading").tap do |seat|
        if proposal.figure_type
          seat.build_current_placement(figure: Figure.new(carousel: preview_carousel, figure_type: proposal.figure_type,
            name: "#{proposal.figure_type.name} #{proposal.code}", mount: proposal.mount))
        end
      end
    end
  end

  def apply!(expected_snapshot:)
    @carousel.with_lock do
      unless snapshot == expected_snapshot
        raise Conflict, "The carousel or figure types changed since your preview. Nothing was saved. Preview the draft again."
      end
      validate!
      notes = [ source_notes.strip, assumptions ].join("\n\n")
      summary = [ @carousel.summary_sources, "## Provisional seating draft",
        source_notes.strip == @carousel.summary_sources.to_s.strip ? nil : source_notes.strip, assumptions ].compact_blank.join("\n\n")
      @carousel.update!(sections_count:, rows_count:, layout_provisional: true, summary_sources: summary)
      proposals.each do |proposal|
        seat = @carousel.seat(proposal.code)
        seat.update!(rows_spanned: proposal.rows_spanned, confidence: "best_reading")
        if proposal.state == "empty"
          SeatAssignment.new(seat, nil, empty: true).save!
        else
          DraftSeatAssignment.create!(seat, figure_type: proposal.figure_type, mount: proposal.mount, source_notes: notes)
        end
      end
    end
    category_totals.values.sum
  end

  private
    def snapshot
      Digest::SHA256.hexdigest([
        @carousel.cache_key_with_version, figure_type&.cache_key_with_version, chariot_type&.cache_key_with_version,
        @carousel.seats.order(:id).pluck(:id, :updated_at)
      ].to_json)
    end

    def codes(attribute) = public_send(attribute).to_s.split(/[,\s]+/).map(&:upcase)

    def no_existing_layout
      if @carousel.layout_known? || @carousel.seats.exists?
        errors.add(:base, "A seating layout already exists. Use Fill unknown seats or edit individual placements instead.")
      end
    end

    def chariot_type_is_valid
      if codes(:chariot_seats).any? && chariot_type&.category != "chariot"
        errors.add(:chariot_type, "must be an existing chariot or tub type")
      end
    end

    def positions_are_valid
      return if errors[:sections_count].any? || errors[:rows_count].any? || errors[:chariot_rows_spanned].any?

      covered = Set.new
      [ :chariot_seats, :empty_seats ].each do |attribute|
        codes(attribute).each do |code|
          position = Seat.parse_code(code)
          span = attribute == :chariot_seats ? chariot_rows_spanned.to_i : 1
          unless position && position[:section].between?(1, sections_count.to_i) &&
              position[:row].ord >= "A".ord && position[:row].ord + span <= "A".ord + rows_count.to_i
            errors.add(attribute, "#{code} does not fit the proposed layout and row span")
            next
          end
          span.times do |offset|
            cell = [ position[:section], (position[:row].ord + offset).chr ]
            errors.add(attribute, "#{code} overlaps another chariot or empty position") unless covered.add?(cell)
          end
        end
      end
    end
end
