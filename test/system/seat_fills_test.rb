require "application_system_test_case"

class SeatFillsSystemTest < ApplicationSystemTestCase
  setup do
    @carousel = build_carousel(sections: 2, rows: 3)
    FigureType.create!(name: "Horse", category: "horse")
    chariot = create_figure("Draft chariot", category: "chariot")
    @carousel.seat("1A").update!(rows_spanned: 2)
    SeatAssignment.new(@carousel.seat("1A"), chariot).save!
    SeatAssignment.new(@carousel.seat("1C"), nil, empty: true).save!

    visit new_session_path
    fill_in "Email", with: users(:editor).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "button", text: "Sign out"
  end

  test "an editor previews and fills a draft while preserving a spanning chariot and empty seat" do
    visit carousel_path(@carousel)
    click_link "Fill unknown seats"
    assert_text "3 unknown seats"
    select "Horse", from: "Figure type"
    select "Jumper", from: "Motion"
    fill_in "Source and research notes", with: "[Operator](https://example.com/): draft horses, identities uncertain."
    click_button "Preview seats"

    assert_selector "h1", text: "Preview draft seats"
    assert_selector "table tbody tr", count: 3
    assert_text "Horse 2A"
    assert_text "best reading, not confirmed"
    assert_equal 1, @carousel.figures.count
    click_link "Change choices"
    assert_field "Source and research notes", with: "[Operator](https://example.com/): draft horses, identities uncertain."
    select "Unknown", from: "Motion"
    click_button "Preview seats"
    assert_selector "table td", text: "Unknown", count: 3
    click_button "Create 3 draft figures"

    assert_selector ".flash", text: "Added 3 draft figures"
    assert_selector "svg.seat-chart a.seat.horse.unsure", count: 3
    assert_selector "svg.seat-chart a.seat.chariot", count: 1
    assert_selector "svg.seat-chart a.seat.empty", count: 1
    assert_no_link "Fill unknown seats"
    assert_equal 4, @carousel.figures.count
    assert_nil @carousel.seat("2A").figure.mount
    assert_equal 2, @carousel.seat("1A").rows_spanned

    visit figures_path(carousel_id: @carousel.id)
    click_link "Horse 2A"
    assert_text "Provisional seat-based name"
    assert_link "Operator", href: "https://example.com/"
    assert_text "Best reading, not yet confirmed"
  end

  test "an editor replaces auto-filled horses with a spanning chariot and empty inner seat" do
    type = FigureType.find_by!(name: "Horse")
    %w[ 2A 2B 2C ].each do |code|
      DraftSeatAssignment.create!(@carousel.seat(code), figure_type: type, mount: "jumper", source_notes: "Draft source")
    end
    chariot = create_figure("Replacement chariot", category: "chariot", carousel: @carousel)

    visit edit_carousel_seat_path(@carousel, "2A")
    select "Replacement chariot (#{@carousel.name})", from: "Figure in this seat"
    fill_in "Rows it fills", with: "2"
    select "Confirmed", from: "Confidence"
    click_button "Save seat"

    assert_selector "h1", text: "Replacement chariot"
    assert_equal chariot, @carousel.reload.seat("2A").figure
    assert_nil @carousel.seat("2B")
    assert_not Figure.exists?(name: "Horse 2A")
    assert_not Figure.exists?(name: "Horse 2B")

    visit edit_carousel_seat_path(@carousel, "2C")
    select "Empty", from: "Figure in this seat"
    click_button "Save seat"

    assert_selector "h1", text: "Seat 2C"
    assert_equal "empty", @carousel.reload.seat("2C").state
    assert_not Figure.exists?(name: "Horse 2C")
  end
end
