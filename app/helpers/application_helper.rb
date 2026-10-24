module ApplicationHelper
  def category_label(category) = FigureType::CATEGORY_LABELS.fetch(category)

  def seat_link(seat, text = nil)
    link_to text || "#{seat.carousel.name}, seat #{seat.code}", carousel_seat_path(seat.carousel, seat)
  end

  # Page text is plain paragraphs for now; Markdown with [[wiki links]] comes later.
  def wiki_body(text)
    simple_format(text) if text.present?
  end
end
