require "csv"
require "digest"

class CarouselCsv
  class Error < StandardError; end
  class Conflict < Error; end

  MAX_BYTES = 1.megabyte
  MAX_ROWS = 5_000
  MAX_NEW_SEATS = 10_000
  CLEAR = "__CLEAR__"
  FORMAT = "carousel-csv-v1"
  FIELDS = %w[
    name other_names status maker_id year_built year_opened venue street_address city region
    postal_code country address_sources body official_url wikipedia_url other_links
    sections_count rows_count rotation layout_provisional published_horses_count
    published_other_animals_count published_chariots_count summary_sources
  ].freeze
  RING_FIELDS = ("A"..).first(Carousel::MAX_ROWS).flat_map do |letter|
    Carousel::RING_FIELDS.map { |field| "ring_#{letter}_#{field}" }
  end.freeze
  HEADERS = (%w[csv_format id updated_at slug] + FIELDS + RING_FIELDS).freeze
  INTEGERS = %w[
    maker_id year_built year_opened sections_count rows_count published_horses_count
    published_other_animals_count published_chariots_count
  ].freeze
  Item = Data.define(:number, :record, :changes, :warnings, :errors)

  attr_reader :items, :content

  def self.export
    CSV.generate do |csv|
      csv << HEADERS
      Carousel.order(:id).find_each do |carousel|
        values = [ FORMAT, carousel.id, carousel.updated_at.utc.iso8601(6), carousel.slug ]
        values += FIELDS.map { |field| carousel.public_send(field) }
        values += RING_FIELDS.map do |field|
          _, letter, *name = field.split("_")
          carousel.ring_details.dig(letter, name.join("_"))
        end
        csv << values.map { |value| export_cell(value) }
      end
    end
  end

  def self.export_cell(value)
    return nil if value.nil?

    text = value.to_s
    if text == CLEAR || text.start_with?("\\")
      text = "\\#{text}"
    end
    text.match?(/\A(?:[ \t\r\n]*[=+\-@]|\t|\r|\n|')/) ? "'#{text}" : text
  end

  def initialize(content)
    raise Error, "CSV is empty." if content.blank?
    raise Error, "CSV exceeds the 1 MB limit." if content.bytesize > MAX_BYTES
    raise Error, "CSV must be valid UTF-8." unless content.dup.force_encoding(Encoding::UTF_8).valid_encoding?

    @content = content.dup.force_encoding(Encoding::UTF_8).delete_prefix("\uFEFF")
    @items = []
    parse
  end

  def valid? = items.any? && items.all? { |item| item.errors.empty? }

  def fingerprint
    Digest::SHA256.hexdigest(Marshal.dump(items.map do |item|
      [ item.number, item.record.id, item.record.updated_at&.utc&.iso8601(6),
        item.changes, item.warnings, item.errors ]
    end))
  end

  def preview_token(user)
    Rails.application.message_verifier(:carousel_csv_import).generate(
      { user_id: user.id, content: @content, fingerprint: fingerprint }, expires_in: 30.minutes
    )
  end

  def self.apply!(token, user)
    payload = Rails.application.message_verifier(:carousel_csv_import).verified(token)
    raise Conflict, "This preview is invalid or expired. Please preview the CSV again." unless payload && payload["user_id"] == user.id

    counts = nil
    Carousel.transaction do
      import = new(payload.fetch("content"))
      unless import.valid? && ActiveSupport::SecurityUtils.secure_compare(import.fingerprint, payload.fetch("fingerprint"))
        raise Conflict, "The data or duplicate warnings changed since preview. Nothing was saved; preview the CSV again."
      end

      CarouselCsvImportReceipt.create!(token_digest: Digest::SHA256.hexdigest(token), user:)
      counts = { created: 0, updated: 0, unchanged: 0 }
      import.items.each do |item|
        if item.record.new_record?
          item.record.slug = nil
          item.record.save!
          counts[:created] += 1
        elsif item.record.changed?
          item.record.save!
          counts[:updated] += 1
        else
          counts[:unchanged] += 1
        end
      end
    end
    counts
  rescue ActiveRecord::RecordNotUnique
    raise Conflict, "This preview was already submitted or a conflicting record was created. Nothing was saved; preview the CSV again."
  end

  private
    def parse
      table = CSV.parse(@content, headers: true)
      headers = table.headers
      raise Error, "CSV must have a header row." if headers.blank?
      raise Error, "CSV has empty or duplicate column names." if headers.any?(&:blank?) || headers.uniq != headers
      unknown = headers - HEADERS
      raise Error, "Unknown columns: #{unknown.join(', ')}." if unknown.any?
      raise Error, "CSV must include a name column." unless headers.include?("name")
      raise Error, "CSV exceeds the #{MAX_ROWS} row limit." if table.size > MAX_ROWS

      existing = Carousel.includes(:maker).to_a
      seen_ids = Set.new
      seen_names = []
      table.each_with_index do |row, index|
        next if row.fields.all?(&:blank?)

        @items << build_item(row.to_h, index + 2, existing, seen_ids, seen_names)
      end
      raise Error, "CSV contains no data rows." if items.empty?
      new_seats = items.sum do |item|
        carousel = item.record
        creates_layout = carousel.layout_known? &&
          (carousel.new_record? || carousel.sections_count_in_database.nil? || carousel.rows_count_in_database.nil?)
        creates_layout ? carousel.sections_count * carousel.rows_count : 0
      end
      raise Error, "This import would create more than #{MAX_NEW_SEATS} seats." if new_seats > MAX_NEW_SEATS
    rescue CSV::MalformedCSVError => error
      raise Error, "Invalid CSV: #{error.message}"
    end

    def build_item(row, number, existing, seen_ids, seen_names)
      errors = []
      warnings = []
      format = row["csv_format"].to_s
      errors << "Unknown CSV format." if format.present? && format != FORMAT
      data = row.transform_values { |value| decode_cell(value, format) }
      id = data["id"].to_s.strip
      record = nil
      if id.present?
        if !id.match?(/\A[1-9]\d*\z/)
          errors << "ID must be a positive integer."
        elsif seen_ids.include?(id)
          errors << "ID appears more than once in this CSV."
        else
          seen_ids << id
          record = existing.find { |carousel| carousel.id.to_s == id }
          errors << "ID #{id} does not exist." unless record
        end
        if record
          if data["updated_at"].blank? || data["updated_at"] != record.updated_at.utc.iso8601(6)
            errors << "This record changed since export, or its updated_at is missing. Export it again."
          end
          errors << "Slug is read-only." if data["slug"].present? && data["slug"] != record.slug
        end
      elsif data["slug"].present? || data["updated_at"].present?
        errors << "New rows must have blank ID, slug, and updated_at."
      end
      record ||= Carousel.new
      original = record.attributes.deep_dup
      assign_fields(record, data, errors)
      if record.persisted? && original["sections_count"].present? && original["rows_count"].present? &&
          (record.sections_count != original["sections_count"] || record.rows_count != original["rows_count"])
        errors << "A known layout's dimensions cannot be changed through CSV."
      end
      errors.concat(record.errors.full_messages) unless record.valid?
      changes = record.changes.except("slug", "updated_at", "created_at")
      if record.new_record?
        changes["status"] ||= [ nil, record.status ]
        changes["layout_provisional"] ||= [ nil, record.layout_provisional ]
      end
      if record.new_record? && record.name.present?
        matches = existing.select do |other|
          ([ other.name ] + other.other_names.to_s.lines.map(&:strip)).any? { |name| name.casecmp?(record.name.strip) }
        end
        warnings.concat(matches.map { |other| "Possible duplicate: #{other.name} (#{other.location.presence || 'location unknown'}; ID #{other.id})." })
        warnings << "Another new row has the same name." if seen_names.include?(record.name.strip.downcase)
        seen_names << record.name.strip.downcase
      end
      Item.new(number:, record:, changes:, warnings:, errors:)
    end

    def assign_fields(record, data, errors)
      FIELDS.each do |field|
        value = data[field]
        next if value.blank?
        value = import_value(value)
        if INTEGERS.include?(field) && value && !value.match?(/\A-?\d+\z/)
          errors << "#{field} must be an integer."
          next
        end
        if field == "layout_provisional" && value && !%w[true false].include?(value)
          errors << "layout_provisional must be true or false."
          next
        end
        if field == "layout_provisional" && value.nil?
          errors << "layout_provisional cannot be cleared; use true or false."
          next
        end
        if field == "maker_id" && value && !Maker.exists?(id: value)
          errors << "maker_id does not identify an existing maker."
          next
        end
        record.public_send("#{field}=", value)
      end

      rings = record.ring_details.deep_dup
      RING_FIELDS.each do |field|
        value = data[field]
        next if value.blank?
        _, letter, *name = field.split("_")
        key = name.join("_")
        value = import_value(value)
        if key != "mount" && value && !value.match?(/\A\d+\z/)
          errors << "#{field} must be a nonnegative integer."
          next
        end
        rings[letter] ||= {}
        rings[letter][key] = value
      end
      record.ring_details = rings
    end

    def decode_cell(value, format)
      return value if value.nil? || format != FORMAT

      value = value.delete_prefix("'") if value.match?(/\A'(?:[ \t\r\n]*[=+\-@]|\t|\r|\n|')/)
      value
    end

    def import_value(value)
      return value.delete_prefix("\\") if value == "\\#{CLEAR}" || value.start_with?("\\\\")
      return nil if value == CLEAR

      value
    end
end
