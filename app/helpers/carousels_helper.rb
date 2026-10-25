module CarouselsHelper
  def carousel_figure_count(carousel, category, mapped_count)
    published = carousel.published_category_totals.fetch(category)
    return published unless published.nil?

    mapped_count if carousel.layout_known?
  end

  def carousel_platform_label(carousel)
    return if carousel.sections_count.nil? && carousel.rows_count.nil?

    [
      carousel.sections_count ? pluralize(carousel.sections_count, "section") : "Sections unknown",
      carousel.rows_count ? pluralize(carousel.rows_count, "row") : "Rows unknown"
    ].join(", ")
  end
end
