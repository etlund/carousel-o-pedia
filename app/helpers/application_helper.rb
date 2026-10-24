module ApplicationHelper
  def category_label(category) = FigureType::CATEGORY_LABELS.fetch(category)

  def seat_link(seat)
    link_to carousel_seat_path(seat.carousel, seat), class: "seat-link" do
      safe_join([ seat_badge(seat), seat.carousel.name ])
    end
  end

  # Page text is plain paragraphs for now; Markdown with [[wiki links]] comes later.
  def wiki_body(text)
    simple_format(text) if text.present?
  end
end
