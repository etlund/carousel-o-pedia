module ApplicationHelper
  def category_label(category) = FigureType::CATEGORY_LABELS.fetch(category)

  def seat_destination_path(seat)
    seat.figure ? figure_path(seat.figure) : seat_record_path(seat)
  end

  def seat_record_path(seat)
    seat.carousel_deck ? deck_seat_path(seat.carousel, seat.carousel_deck, seat) : carousel_seat_path(seat.carousel, seat)
  end

  def edit_seat_record_path(seat)
    seat.carousel_deck ? edit_deck_seat_path(seat.carousel, seat.carousel_deck, seat) : edit_carousel_seat_path(seat.carousel, seat)
  end

  def history_seat_record_path(seat)
    seat.carousel_deck ? history_deck_seat_path(seat.carousel, seat.carousel_deck, seat) : history_carousel_seat_path(seat.carousel, seat)
  end

  def seat_link(seat)
    link_to seat_record_path(seat), class: "seat-link" do
      safe_join([ seat_badge(seat), seat.layout.display_name ])
    end
  end

  def wiki_body(text)
    if text.present?
      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(hard_wrap: true), autolink: true, fenced_code_blocks: true)
      sanitize(markdown.render(text))
    end
  end
end
