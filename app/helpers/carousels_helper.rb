require "base64"

module CarouselsHelper
  def carousel_favicon_data_uri(carousel)
    seats = carousel.seats.includes(current_placement: { figure: :figure_type })
    svg = render(partial: "carousels/favicon", formats: [ :svg ], locals: { carousel:, seats: })
    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end

  def carousel_figure_count(carousel, category, mapped_count)
    published = carousel.published_category_totals.fetch(category)
    return published unless published.nil?

    mapped_count if carousel.layout_known?
  end

  def carousel_platform_label(carousel)
    return if carousel.sections_count.nil? && carousel.rows_count.nil?

    label = [
      carousel.sections_count ? pluralize(carousel.sections_count, "section") : "Sections unknown",
      carousel.rows_count ? pluralize(carousel.rows_count, "row") : "Rows unknown"
    ].join(", ")
    carousel.layout_provisional? ? "#{label} (provisional)" : label
  end

  def carousel_seating_completeness_label(carousel)
    completeness = carousel.seating_completeness
    if completeness.confirmed_seats + completeness.best_reading_seats > 0
      return "#{completeness.confirmed_seats} confirmed \u00b7 #{completeness.best_reading_seats} best reading"
    end
    return "Layout unknown" unless completeness.rows_count || completeness.sections_count

    details = []
    details << "#{pluralize(completeness.rows_count, 'row')} recorded" if completeness.rows_count
    details << "#{pluralize(completeness.sections_count, 'section')} recorded" if completeness.sections_count
    details << "rows unknown" unless completeness.rows_count
    details << "sections unknown" unless completeness.sections_count
    details.join(" \u00b7 ")
  end
end
