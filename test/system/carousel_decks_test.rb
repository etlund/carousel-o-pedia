require "application_system_test_case"

class CarouselDecksSystemTest < ApplicationSystemTestCase
  setup do
    @carousel = Carousel.create!(name: "Independent decks", published_horses_count: 10,
      summary_sources: "Whole ride inventory")
    visit new_session_path
    fill_in "Email", with: users(:editor).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "button", text: "Sign out"
  end

  test "editor adds a deck and opens its deck-specific seat editor" do
    visit carousel_path(@carousel)
    click_link "Add deck"
    fill_in "Deck name", with: "Lower deck"
    fill_in "Sections", with: "3"
    fill_in "Rows", with: "2"
    click_button "Create Carousel deck"
    assert_selector "h1", text: "Lower deck"
    assert_selector "svg.seat-chart a.seat", count: 6
    click_link "Lower deck - 1A", exact: true
    assert_selector "h1", text: "Seat Lower deck - 1A"
    visit find_link("Edit placement")[:href]
    assert_field "Rows it fills", with: "1"
    assert_button "Save seat"
  end

  test "adding an unknown deck does not copy carousel-wide geometry or inventory" do
    @carousel.carousel_decks.create!(name: "Lower deck", position: 1, sections_count: 3, rows_count: 2)
    visit new_carousel_deck_path(@carousel)
    fill_in "Deck name", with: "Upper deck"
    click_button "Create Carousel deck"
    assert_selector "h1", text: "Upper deck"
    assert_text "No seating layout has been recorded for this deck."
    visit find_link("Create draft layout for Upper deck")[:href]
    assert_selector "h1", text: "Sketch carousel layout"
    assert_field "Horses", with: ""
    assert_field "Rows", with: ""

    visit carousel_path(@carousel)
    assert_selector ".deck-layout", count: 2
    assert_selector ".figure-count", text: "10"
  end
end
