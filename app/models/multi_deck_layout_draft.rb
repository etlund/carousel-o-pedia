require "digest"

class MultiDeckLayoutDraft
  include ActiveModel::Model
  include SeatingPreview

  class Conflict < StandardError; end
  Entry = Data.define(:deck, :draft)
  attr_reader :entries

  validate :validate_decks

  def initialize(carousel, attributes = nil)
    @carousel = carousel
    recorded = carousel.carousel_decks.to_a
    next_position = (recorded.map(&:position).max || 0) + 1
    values = attributes ? attributes.fetch("decks") : default_attributes(recorded)
    @entries = values.map do |value|
      value = value.stringify_keys
      deck = if value["id"].present?
        carousel.carousel_decks.find(value["id"])
      else
        CarouselDeck.new(carousel:, position: next_position).tap { next_position += 1 }
      end
      deck.name = value["name"]
      draft = LayoutDraft.new(deck, value.except("id", "name").merge("input_mode" => "sketch"))
      Entry.new(deck:, draft:)
    end
  end

  def attributes
    { "decks" => entries.map { |entry| entry.draft.attributes.merge("id" => entry.deck.id, "name" => entry.deck.name) } }
  end

  def requested_totals
    { "horse" => :horses_count, "menagerie" => :other_animals_count, "chariot" => :chariots_count }.transform_values do |attribute|
      entries.sum { _1.draft.public_send(attribute).to_i }
    end
  end

  def apply!(expected_snapshot:)
    @carousel.with_lock do
      unless snapshot == expected_snapshot
        raise Conflict, "The carousel, decks, seats, or figure types changed since your preview. Nothing was saved. Preview the draft again."
      end
      validate!
      entries.sum do |entry|
        entry.deck.save!
        entry.draft.apply!(expected_snapshot: entry.draft.snapshot)
      end
    end
  end

  private
    def default_attributes(recorded)
      count = [ @carousel.decks_count.to_i, recorded.size, 2 ].max
      defaults = count.times.map do |index|
        deck = recorded[index]
        values = deck ? LayoutDraft.sketch_defaults_for(deck) : { source_notes: @carousel.summary_sources }
        values.merge(id: deck&.id, name: deck&.name || "Deck #{index + 1}")
      end
      assumptions = Array.new(count) { [] }
      { horse: :horses_count, menagerie: :other_animals_count, chariot: :chariots_count }.each do |category, attribute|
        total = @carousel.published_category_totals.fetch(category.to_s)
        missing = defaults.each_index.select { defaults[_1][attribute].nil? }
        next if total.nil? || missing.empty?

        remaining = total - defaults.sum { _1[attribute].to_i }
        next if remaining.negative?

        share, extra = remaining.divmod(missing.size)
        missing.each_with_index do |index, offset|
          defaults[index][attribute] = share + (offset < extra ? 1 : 0)
          assumptions[index] << "#{attribute.to_s.humanize}: provisional even split of the remaining carousel-wide inventory, with remainders assigned to lower decks first; not a verified deck allocation."
        end
      end
      defaults.each_with_index.map do |values, index|
        if values[:rows_count].nil?
          values[:rows_count] = 3
          assumptions[index] << "Three rows are an initial drafting assumption, not verified geometry. Change the row count to compare other layouts."
        end
        values[:chariot_rows_spanned] ||= values[:rows_count] == 1 ? 1 : 2
        values[:source_notes] = [ values[:source_notes], *assumptions[index] ].compact_blank.join("\n\n")
        values.stringify_keys
      end
    end

    def validate_decks
      expected = [ @carousel.decks_count.to_i, @carousel.carousel_decks.size, 2 ].max
      errors.add(:base, "Enter all #{expected} decks for a combined draft.") unless entries.size == expected
      ids = entries.filter_map { _1.deck.id }
      unless ids.sort == @carousel.carousel_decks.pluck(:id).sort
        errors.add(:base, "Include each existing deck exactly once.")
      end
      names = entries.map { _1.deck.name }
      errors.add(:base, "Deck names must be unique.") unless names.uniq.size == names.size
      entries.each_with_index do |entry, index|
        unless entry.deck.valid?
          entry.deck.errors.full_messages.each { errors.add(:base, "Deck #{index + 1}: #{_1}") }
        end
        unless entry.draft.valid?
          entry.draft.errors.full_messages.each { errors.add(:base, "Deck #{index + 1}: #{_1}") }
        end
      end
      if @carousel.layout_known? || @carousel.seats.exists?
        errors.add(:base, "A main-platform layout already exists. Draft individual decks instead; existing seats will not be moved.")
      end
    end

    def snapshot
      Digest::SHA256.hexdigest([
        @carousel.cache_key_with_version,
        @carousel.carousel_decks.order(:id).map(&:cache_key_with_version),
        @carousel.all_seats.order(:id).pluck(:id, :updated_at),
        FigureType.order(:id).pluck(:id, :updated_at)
      ].to_json)
    end
end
