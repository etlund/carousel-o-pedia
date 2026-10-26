module ApplicationHelper
  def category_label(category) = FigureType::CATEGORY_LABELS.fetch(category)

  def seat_destination_path(seat)
    seat.figure ? figure_path(seat.figure) : carousel_seat_path(seat.carousel, seat)
  end

  def seat_link(seat)
    link_to carousel_seat_path(seat.carousel, seat), class: "seat-link" do
      safe_join([ seat_badge(seat), seat.carousel.name ])
    end
  end

  def wiki_body(text)
    if text.present?
      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(hard_wrap: true), autolink: true, fenced_code_blocks: true)
      sanitize(markdown.render(text))
    end
  end
end
