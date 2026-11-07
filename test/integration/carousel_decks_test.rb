require "test_helper"

class CarouselDecksTest < ActionDispatch::IntegrationTest
  setup do
    @carousel = Carousel.create!(name: "Two decks", published_horses_count: 12,
      published_other_animals_count: 4, published_chariots_count: 2, summary_sources: "Whole ride census")
    @lower = @carousel.carousel_decks.create!(name: "Lower", position: 1, sections_count: 4, rows_count: 2)
    @upper = @carousel.carousel_decks.create!(name: "Upper", position: 2)
    sign_in_as users(:editor)
  end

  test "deck pages show separate charts and carousel totals remain aggregate" do
    get carousel_path(@carousel)
    assert_response :success
    assert_select ".deck-layout", 2
    assert_select "[data-deck-id='#{@lower.id}'] svg.seat-chart a.seat", 8
    assert_select "[data-deck-id='#{@upper.id}'] svg.seat-chart", 0
    assert_select "a[href=?]", new_carousel_deck_path(@carousel), text: "Add deck"
    assert_select "a[href=?]", new_carousel_layout_draft_path(@carousel, deck_id: @upper.id)
    assert_select ".figure-count", text: "12"
    get carousels_path
    assert_response :success
    assert_select "a[href=?] svg.mini-seat-chart", carousel_deck_path(@carousel, @lower), 1
  end

  test "editors can add and edit a sourced deck without assigning aggregate counts" do
    get new_carousel_deck_path(@carousel)
    assert_response :success
    assert_difference "CarouselDeck.count", 1 do
      post carousel_decks_path(@carousel), params: { carousel_deck: { name: "Third", position: 3 } }
    end
    deck = @carousel.carousel_decks.find_by!(name: "Third")
    assert_redirected_to carousel_deck_path(@carousel, deck)
    assert_empty deck.seats
    assert_equal [ nil, nil, nil ], deck.published_category_totals.values
    patch carousel_deck_path(@carousel, deck), params: { carousel_deck: {
      rows_count: 1, sections_count: 3, published_horses_count: 3, summary_sources: "Deck survey"
    } }
    assert_redirected_to carousel_deck_path(@carousel, deck)
    assert_equal 3, deck.reload.seats.count
    assert_equal 12, @carousel.reload.published_horses_count
    get history_carousel_deck_path(@carousel, deck)
    assert_response :success
    assert_select ".changes", text: /Deck survey/
    get edit_carousel_deck_path(@carousel, deck)
    assert_response :success
  end

  test "deck seats and badges link to their own layout and retain placement history" do
    seat = @lower.seat("1A")
    get deck_seat_path(@carousel, @lower, seat)
    assert_response :success
    assert_select "h1", "Seat Lower - 1A"
    assert_select "a[href=?]", edit_deck_seat_path(@carousel, @lower, seat)
    get edit_deck_seat_path(@carousel, @lower, seat)
    assert_response :success
    assert_select "input[name='seat[rows_spanned]'][max='2']"
    patch deck_seat_path(@carousel, @lower, seat), params: { seat: { figure_id: "empty", confidence: "confirmed", rows_spanned: 2 } }
    assert_redirected_to deck_seat_path(@carousel, @lower, seat)
    assert_equal 2, seat.reload.rows_spanned
    get history_deck_seat_path(@carousel, @lower, seat)
    assert_response :success
    get recent_changes_path
    assert_response :success
    assert_select "a[href=?]", deck_seat_path(@carousel, @lower, seat)
    get carousel_seat_path(@carousel, seat.code)
    assert_response :not_found
  end

  test "deck draft previews and confirmation retain deck scope" do
    FigureType.create!(name: "Horse", category: "horse")
    FigureType.create!(name: "Chariot", category: "chariot")
    get new_carousel_layout_draft_path(@carousel, deck_id: @upper.id)
    assert_response :success
    assert_select "input[name='layout_draft[horses_count]'][value]", 0
    params = { input_mode: "sketch", horses_count: 3, other_animals_count: 1, chariots_count: 0,
      rows_count: 1, chariot_rows_spanned: 1, source_notes: "Tentative upper allocation" }
    post preview_carousel_layout_draft_path(@carousel, deck_id: @upper.id), params: { layout_draft: params }
    assert_response :success
    assert_select "form[action=?]", carousel_layout_draft_path(@carousel, deck_id: @upper.id)
    token = css_select("input[name=preview_token]").sole["value"]
    post carousel_layout_draft_path(@carousel, deck_id: @upper.id), params: { preview_token: token }
    assert_redirected_to carousel_path(@carousel)
    assert @upper.reload.layout_provisional?
    assert_equal 4, @upper.seats.count
    assert_equal 8, @lower.seats.count
    assert_nil @carousel.reload.sections_count
    get carousel_path(@carousel)
    assert_response :success
    assert_select "[data-deck-id='#{@upper.id}'] svg.seat-chart a.seat", 4
  end

  test "fill previews apply only to the requested deck" do
    horse = FigureType.create!(name: "Horse", category: "horse")
    get new_carousel_seat_fill_path(@carousel, deck_id: @lower.id)
    assert_response :success
    post preview_carousel_seat_fill_path(@carousel, deck_id: @lower.id), params: {
      seat_fill: { figure_type_id: horse.id, mount: "", source_notes: "Lower deck draft" }
    }
    assert_response :success
    token = css_select("input[name=preview_token]").sole["value"]
    post carousel_seat_fill_path(@carousel, deck_id: @lower.id), params: { preview_token: token }
    assert_redirected_to carousel_path(@carousel)
    assert_equal 8, @lower.category_totals.fetch("horse")
    assert_empty @upper.seats
    assert_equal 8, @carousel.category_totals.fetch("horse")
    get figures_path(carousel_id: @carousel.id)
    assert_response :success
    assert_select "a[href=?]", deck_seat_path(@carousel, @lower, "1A")
  end

  test "restricted editors cannot edit other carousels or select their decks" do
    other = Carousel.create!(name: "Other ride")
    other_deck = other.carousel_decks.create!(name: "Upper", position: 1)
    users(:editor).update!(access_scope: "carousel", editable_carousel: other)
    get edit_carousel_deck_path(@carousel, @upper)
    assert_denied
    post carousel_decks_path(@carousel), params: { carousel_deck: { name: "Denied", position: 3 } }
    assert_denied
    get new_carousel_layout_draft_path(@carousel, deck_id: @upper.id)
    assert_denied
    users(:editor).update!(editable_carousel: @carousel)
    get new_carousel_layout_draft_path(@carousel, deck_id: other_deck.id)
    assert_response :not_found
    get carousel_deck_path(@carousel, other_deck)
    assert_response :not_found
  end

  private
    def assert_denied
      assert_redirected_to root_path
      assert_equal "You do not have permission to make that change.", flash[:alert]
    end
end
