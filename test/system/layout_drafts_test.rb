require "application_system_test_case"

class LayoutDraftsSystemTest < ApplicationSystemTestCase
  setup do
    @carousel = Carousel.create!(name: "Four-ring draft example", rows_count: 4,
      published_horses_count: 68, published_other_animals_count: 0, published_chariots_count: 2,
      summary_sources: "[Roster](https://example.com/): 68 horses in four rings, with two chariots.")
    FigureType.create!(name: "Horse", category: "horse")
    FigureType.create!(name: "Chariot", category: "chariot")
    visit new_session_path
    fill_in "Email", with: users(:editor).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "button", text: "Sign out"
  end

  test "an editor adjusts the two-row approximation and reviews the complete provisional layout" do
    visit carousel_path(@carousel)
    click_link "Create draft layout"
    click_link "use the detailed layout"
    assert_field "Sections", with: "18"
    assert_field "Rows", with: "4"
    assert_field "Rows per chariot", with: "2"
    assert_field "Chariot starting seats", with: "1A, 10A"
    click_button "Preview draft layout"
    assert_selector "h1", text: "Preview draft layout"
    assert_selector "svg.draft-layout-chart .horse", count: 68
    assert_selector "svg.draft-layout-chart .chariot", count: 2
    assert_selector "table.draft-placements tbody tr", count: 70
    within("table.draft-placements") do
      assert_selector "thead", text: /Figure Type Seat/i
      assert_selector "svg.seat-badge.horse", count: 68
      assert_selector "svg.seat-badge.chariot", count: 2
      assert_selector "svg.seat-badge[aria-label='Seat 1A'] text.row.on", text: "A"
      assert_selector "svg.seat-badge[aria-label='Seat 1A'] text.row.on", text: "B"
      assert_selector "svg.mount-icon[aria-label=Jumper]", count: 68
    end
    assert_text "footprints are drafting assumptions"
    assert_empty @carousel.seats

    click_link "Change choices"
    fill_in "Rows per chariot", with: "1"
    click_button "Preview draft layout"
    assert_selector "p[role=status]", text: "Draft totals differ"
    assert_selector "svg.draft-layout-chart .horse", count: 70
    click_link "Change choices"
    fill_in "Empty seats", with: "1B, 10B"
    click_button "Preview draft layout"
    assert_selector "svg.draft-layout-chart .horse", count: 68
    assert_selector "svg.draft-layout-chart .empty", count: 2
    assert_selector "table.draft-placements svg.seat-badge.empty", count: 2
    assert_no_selector "p[role=status]"
    click_button "Create provisional layout"

    assert_selector ".flash", text: "Created a provisional seating layout with 70 draft figures"
    assert_selector ".provisional-layout", text: "Provisional seating layout"
    assert_selector "svg.seat-chart a.seat.horse.unsure", count: 68
    assert_selector "svg.seat-chart a.seat.chariot.unsure", count: 2
    assert_selector "svg.seat-chart a.seat.empty.unsure", count: 2
    assert @carousel.reload.layout_provisional?
    assert_equal 1, @carousel.seat("1A").rows_spanned
    assert_equal "empty", @carousel.seat("1B").state

    click_link "Edit", exact: true
    assert_checked_field "Provisional layout (geometry not yet verified)"
    uncheck "Provisional layout (geometry not yet verified)"
    click_button "Update Carousel"
    assert_selector ".flash", text: "Saved."
    assert_no_selector ".provisional-layout"
    assert_not @carousel.reload.layout_provisional?
    assert_equal "best_reading", @carousel.seat("1A").confidence
  end

  test "simple sketch previews exact counts and saves provisional geometry" do
    visit carousel_path(@carousel)
    click_link "Create draft layout"
    assert_selector "h1", text: "Sketch carousel layout"
    assert_no_field "Sections"
    assert_no_field "Chariot starting seats"
    assert_field "Horses", with: "68"
    assert_field "Chariots", with: "2"
    fill_in "Horses", with: "67"
    click_button "Preview sketch"
    assert_selector "svg.draft-layout-chart .horse", count: 67
    assert_selector "svg.draft-layout-chart .empty", count: 1
    assert_text "1 assumed empty position"
    assert_selector "svg.draft-layout-chart .chariot", count: 2
    assert_link "Adjust chariot footprint"
    assert_empty @carousel.seats
    click_button "Create provisional layout"
    assert_selector ".provisional-layout", text: "Provisional seating layout"
    assert_equal 2, @carousel.seat("1A").rows_spanned
    assert_equal 67, @carousel.reload.category_totals.fetch("horse")
    assert_equal 1, @carousel.seats.where(state: "empty").count
    assert_equal 68, @carousel.published_horses_count
  end

  test "mixed animal sketch shows the combined total without assigning species" do
    @carousel.update!(rows_count: 3, published_horses_count: 25, published_other_animals_count: 21,
      published_chariots_count: 4)
    visit new_carousel_layout_draft_path(@carousel)
    assert_field "Horses", with: "25"
    assert_field "Other animals", with: "21"
    click_button "Preview sketch"
    assert_text "46 unclassified animal positions"
    assert_selector "svg.draft-layout-chart .unknown", count: 46
    assert_selector "svg.draft-layout-chart .chariot", count: 4
    assert_no_selector "svg.draft-layout-chart .horse, svg.draft-layout-chart .menagerie"
    assert_empty @carousel.seats
  end
end
