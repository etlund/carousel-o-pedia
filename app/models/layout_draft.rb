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
  attribute :input_mode, :string, default: "layout"
  attribute :horses_count, :string
  attribute :other_animals_count, :string
  attribute :chariots_count, :string

  validate :build_sketch, if: :sketch?
  validates :input_mode, inclusion: { in: %w[ layout sketch ] }
  validates :horses_count, :other_animals_count, :chariots_count,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, if: :sketch?
  validates :sections_count, numericality: { only_integer: true, greater_than: 0 }
  validates :rows_count, :chariot_rows_spanned,
    numericality: { only_integer: true, in: 1..Carousel::MAX_ROWS }
  validates :figure_type, presence: { message: "must be an existing figure type" }, unless: :mixed_animals?
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

  def self.sketch_defaults_for(carousel)
    defaults_for(carousel).merge(input_mode: "sketch", horses_count: carousel.published_horses_count,
      other_animals_count: carousel.published_other_animals_count,
      chariots_count: carousel.published_chariots_count,
      chariot_rows_spanned: carousel.rows_count == 1 ? 1 : 2, mount: nil)
  end

  def sketch? = input_mode == "sketch"
  def mixed_animals? = sketch? && other_animals_count.to_i.positive?
  def animals_count = horses_count.to_i + other_animals_count.to_i

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
        unclassified = !chariot && mixed_animals?
        Proposal.new(section:, row:, rows_spanned: chariot ? chariot_rows_spanned.to_i : 1,
          state: is_empty ? "empty" : (unclassified ? "unknown" : "filled"),
          figure_type: is_empty || unclassified ? nil : (chariot ? vehicle_type : type),
          mount: is_empty || unclassified ? nil : (chariot ? "fixed" : mount.presence))
      end
    end
  end

  def category_totals
    FigureType::CATEGORIES.index_with { |category| proposals.count { _1.figure_type&.category == category } }
  end

  def assumptions
    animals = if mixed_animals?
      "#{animals_count} animal positions remain unclassified: #{horses_count} horses and #{other_animals_count} other animals are reported, but their individual locations and species are unknown. No animal figures are invented."
    else
      "All remaining positions use #{figure_type.name} with #{mount.presence || 'unknown'} motion."
    end
    [
      "Provisional #{sections_count}-section, #{rows_count}-row regular grid#{@carousel.is_a?(CarouselDeck) ? " on #{@carousel.name}" : ''}; equal spacing and cross-ring alignment are assumptions.",
      "Chariots start at #{codes(:chariot_seats).presence&.join(', ') || 'no seats'} and each spans #{chariot_rows_spanned} adjacent rows inward. Their positions, fixed motion, and footprints are drafting assumptions, not verified observations.",
      "Empty positions: #{codes(:empty_seats).presence&.join(', ') || 'none'}. #{sketch? ? 'These are assumed gaps to fit the requested counts into a regular grid, not observed empty seats. Gaps are placed immediately inward of chariots in the same section, distributed across chariots first; any remaining gaps use the last available positions. ' : ''}#{animals}",
      "Figure names and section 1 are editorial references. Every placement is a best reading, not confirmed."
    ].join("\n\n")
  end

  def preview_carousel
    @preview_carousel ||= Carousel.new(name: @carousel.display_name, sections_count:, rows_count:, rotation: @carousel.rotation)
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
        if proposal.state == "unknown"
          seat.update!(state: "unknown")
        elsif proposal.state == "empty"
          SeatAssignment.new(seat, nil, empty: true).save!
        else
          DraftSeatAssignment.create!(seat, figure_type: proposal.figure_type, mount: proposal.mount, source_notes: notes)
        end
      end
    end
    category_totals.values.sum
  end

  def snapshot
    Digest::SHA256.hexdigest([
      @carousel.cache_key_with_version, figure_type&.cache_key_with_version, chariot_type&.cache_key_with_version,
      @carousel.seats.order(:id).pluck(:id, :updated_at)
    ].to_json)
  end

  private
    def build_sketch
      self.sections_count = nil
      self.chariot_seats = nil
      self.empty_seats = nil
      self.figure_type_id = FigureType.find_by(name: "Horse", category: "horse")&.id
      self.chariot_type_id = FigureType.find_by(name: "Chariot", category: "chariot")&.id
      self.mount = nil
      return unless [ horses_count, other_animals_count, chariots_count, rows_count, chariot_rows_spanned ].all? { _1.to_s.match?(/\A\d+\z/) }

      chariots, rows, span = [ chariots_count, rows_count, chariot_rows_spanned ].map(&:to_i)
      return unless rows.between?(1, Carousel::MAX_ROWS) && span.between?(1, Carousel::MAX_ROWS)
      if chariots.positive? && span > rows
        errors.add(:chariot_rows_spanned, "cannot exceed the number of rows")
        return
      end

      spaces = animals_count + chariots * span
      if spaces.zero?
        errors.add(:base, "Enter at least one animal or chariot to sketch a layout.")
        return
      end
      sections = (spaces + rows - 1) / rows
      if chariots > sections
        errors.add(:chariots_count, "cannot fit with one chariot per section; increase the animals or rows per chariot, or use the detailed layout.")
        return
      end
      self.sections_count = sections
      starts = chariots.times.map { _1 * sections / chariots + 1 }
      self.chariot_seats = starts.map { "#{_1}A" }.join(", ")
      covered = starts.flat_map { |section| span.times.map { [ section, _1 ] } }.to_set
      positions = (1..sections).flat_map do |section|
        rows.times.filter_map { |row| "#{section}#{('A'.ord + row).chr}" unless covered.include?([ section, row ]) }
      end
      gaps = sections * rows - spaces
      inward_positions = (span...rows).flat_map do |row|
        starts.map { |section| "#{section}#{('A'.ord + row).chr}" }
      end
      preferred = inward_positions.first(gaps)
      remaining = (positions - preferred).last(gaps - preferred.size)
      self.empty_seats = (preferred + remaining).join(", ")
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
