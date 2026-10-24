module VersionsHelper
  EVENT_WORDS = { "create" => "added", "update" => "edited", "destroy" => "removed" }.freeze
  HIDDEN_FIELDS = %w[ id created_at updated_at slug ].freeze

  def version_author(version)
    User.find_by(id: version.whodunnit)&.name || "Seed data"
  end

  def version_event(version) = EVENT_WORDS.fetch(version.event, version.event)

  # A readable name and link for whatever the version changed, even if it is gone now.
  def version_subject(version)
    record = version.item || version.reify
    case record
    when Seat then link_to("#{record.carousel.name} seat #{record.code}", carousel_seat_path(record.carousel, record))
    when Placement then placement_summary(record)
    when nil then version.item_type
    else link_to(record.name, record)
    end
  end

  def version_changes(version)
    version.changeset.except(*HIDDEN_FIELDS)
  end

  def change_value(field, value)
    return tag.span("blank", class: "muted") if value.blank?
    return value.to_s.humanize if field.in?(%w[ state confidence status rotation ])
    return Figure.find_by(id: value)&.name || value if field == "figure_id"
    return FigureType.find_by(id: value)&.name || value if field == "figure_type_id"
    return Maker.find_by(id: value)&.name || value if field.in?(%w[ maker_id carver_id ])

    truncate(value.to_s, length: 140)
  end

  private
    def placement_summary(placement)
      figure, seat = placement.figure, placement.seat
      return "A placement" unless figure && seat

      safe_join([ link_to(figure.name, figure), " in ", link_to("#{seat.carousel.name} #{seat.code}", carousel_seat_path(seat.carousel, seat)) ])
    end
end
