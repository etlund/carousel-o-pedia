require "test_helper"

class LayoutDraftsTest < ActionDispatch::IntegrationTest
  setup do
    @carousel = Carousel.create!(name: "Four-ring carousel", rows_count: 4, published_horses_count: 68,
      published_other_animals_count: 0, published_chariots_count: 2, summary_sources: "[Roster](https://example.com/)")
    FigureType.create!(name: "Horse", category: "horse")
    FigureType.create!(name: "Chariot", category: "chariot")
    @attributes = LayoutDraft.defaults_for(@carousel).merge(chariot_rows_spanned: "2")
    sign_in_as users(:editor)
  end

  test "editors discover the draft workflow before a seating chart exists" do
    get carousel_path(@carousel)
    assert_select "a[href=?]", new_carousel_layout_draft_path(@carousel), text: "Create draft layout"
    assert_select "a[href=?]", new_carousel_seat_fill_path(@carousel), 0
    get new_carousel_layout_draft_path(@carousel)
    assert_response :success
    assert_select "input[name='layout_draft[sections_count]'][value='18']"
    assert_select "input[name='layout_draft[rows_count]'][value='4']"
    assert_select "input[name='layout_draft[chariot_rows_spanned]'][value='2']:not([readonly]):not([disabled])"
    assert_select "input[name='layout_draft[chariot_seats]'][value='1A, 10A']"
    assert_select "form[action=?][data-turbo=false]", preview_carousel_layout_draft_path(@carousel)
  end

  test "preview displays assumptions and inventory without saving then creates an explicitly provisional chart" do
    token = preview
    assert_select "svg.draft-layout-chart .horse.unsure", 68
    assert_select "svg.draft-layout-chart .chariot.unsure", 2
    assert_select "table.draft-placements tbody tr", 70
    assert_equal %w[ Figure Type Seat ], css_select("table.draft-placements thead th").map(&:text)
    assert_select "table.draft-placements tbody tr td:nth-child(4)", 0
    assert_select "table.draft-placements.sections", 0
    assert_select "table.draft-placements svg.seat-badge[role=img]", 70
    assert_select "table.draft-placements svg.seat-badge.chariot[aria-label='Seat 1A']" do |badges|
      assert_equal %w[ A B c d ], badges.sole.css("text.row").map(&:text)
      assert_select "title", text: "Seat 1A: section 1, rows A to B"
    end
    assert_select "table.draft-placements svg.seat-badge.horse[aria-label='Seat 1C']" do |badges|
      assert_equal %w[ a b C d ], badges.sole.css("text.row").map(&:text)
    end
    assert_select "table.draft-placements td:first-child svg.mount-icon[aria-label=Jumper]", 68
    assert_select "table.draft-placements td:first-child svg.mount-icon[aria-label=Fixed]", 2
    assert_select "table.draft-placements td:first-child a, table.draft-placements td:last-child a", 0
    assert_select "table.draft-placements td:nth-child(2) a[href=?]", figure_type_path(FigureType.find_by!(name: "Chariot")), count: 2
    assert_select "table.draft-placements td:nth-child(3) svg.seat-badge", 70
    assert_select "table.draft-totals tr", text: /Horses\s*68\s*68/
    assert_select "p[role=status]", 0
    assert_select "input[type=submit][value='Create provisional layout']"

    assert_difference [ "Figure.count", "Placement.count" ], 70 do
      post carousel_layout_draft_path(@carousel), params: { preview_token: token }
    end
    assert_redirected_to carousel_path(@carousel)
    follow_redirect!
    assert_select ".provisional-layout", text: /Provisional seating layout/
    assert_select "svg.seat-chart[aria-label*='provisional layout']"
    assert_select "svg.ring-chart", 0
    assert_select "a[href=?]", new_carousel_layout_draft_path(@carousel), 0
    assert_select "#summary-sources", text: /footprints are drafting assumptions/

    get carousels_path
    assert_select ".card p", text: /18 sections, 4 rows \(provisional\)/
    assert_select "svg.mini-seat-chart[aria-label*='Provisional layout']"
    get history_carousel_path(@carousel)
    assert_select ".version-line", text: /Ed Editor/
  end

  test "changed footprints affect preview totals and source mismatches are visible" do
    preview(chariot_rows_spanned: "1")
    assert_select "svg.draft-layout-chart .horse.unsure", 70
    assert_select "table.draft-totals tr", text: /Horses\s*70\s*68/
    assert_select "p[role=status]", text: /Draft totals differ/
    change_path = css_select("a").find { _1.text == "Change choices" }["href"]
    get change_path
    assert_select "input[name='layout_draft[chariot_rows_spanned]'][value='1']"
    assert_select "textarea[name='layout_draft[source_notes]']", text: @attributes[:source_notes]
  end

  test "invalid positions report errors and preserve choices" do
    assert_no_difference [ "Figure.count", "Seat.count" ] do
      post preview_carousel_layout_draft_path(@carousel), params: { layout_draft: @attributes.merge(empty_seats: "1B") }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /overlaps/
    assert_select "input[name='layout_draft[empty_seats]'][value='1B']"
    assert_select "input[name=preview_token]", 0
  end

  test "proposed empty placements use empty seat badges without figure or motion links" do
    preview(empty_seats: "2C", mount: "")

    assert_select "table.draft-placements tr", text: /Empty\s*Not applicable/ do |rows|
      assert_select "svg.seat-badge.empty[aria-label='Seat 2C']"
      assert_equal %w[ a b C d ], rows.sole.css("text.row").map(&:text)
      assert_select "td:first-child a, svg.mount-icon", 0
    end
    assert_select "table.draft-placements svg.seat-badge", 70
    assert_select "table.draft-placements svg.mount-icon[aria-label=Jumper]", 0
  end

  test "tampered expired and wrong-carousel previews cannot apply a layout" do
    token = preview
    other = Carousel.create!(name: "Other carousel")
    [ [ @carousel, "#{token}changed" ], [ other, token ] ].each do |carousel, value|
      assert_no_difference [ "Figure.count", "Seat.count" ] do
        post carousel_layout_draft_path(carousel), params: { preview_token: value }
      end
      assert_redirected_to new_carousel_layout_draft_path(carousel)
    end
    travel 61.minutes do
      assert_no_difference [ "Figure.count", "Seat.count" ] do
        post carousel_layout_draft_path(@carousel), params: { preview_token: token }
      end
      assert_redirected_to new_carousel_layout_draft_path(@carousel)
    end
    assert_nil @carousel.reload.sections_count
  end

  test "unpreviewed injected parameters cannot change the confirmed draft" do
    token = preview
    post carousel_layout_draft_path(@carousel), params: {
      preview_token: token, layout_draft: @attributes.merge(chariot_rows_spanned: 1), layout_provisional: false
    }
    assert_redirected_to carousel_path(@carousel)
    assert_equal 2, @carousel.seat("1A").rows_spanned
    assert @carousel.reload.layout_provisional?

    assert_no_difference [ "Figure.count", "Seat.count" ] do
      post carousel_layout_draft_path(@carousel), params: { preview_token: token }
    end
    assert_redirected_to new_carousel_layout_draft_path(@carousel)
  end

  test "only authorized editors can open preview and apply the draft" do
    token = preview
    editor = users(:editor)
    editor.update!(access_scope: "carousel", editable_carousel: Carousel.create!(name: "Other assignment"))

    get carousel_path(@carousel)
    assert_select "a[href=?]", new_carousel_layout_draft_path(@carousel), 0
    get new_carousel_layout_draft_path(@carousel)
    assert_denied
    assert_no_difference [ "Figure.count", "Seat.count" ] do
      post preview_carousel_layout_draft_path(@carousel), params: { layout_draft: @attributes }
      assert_denied
      post carousel_layout_draft_path(@carousel), params: { preview_token: token }
      assert_denied
    end

    editor.update!(editable_carousel: @carousel)
    token = preview
    post carousel_layout_draft_path(@carousel), params: { preview_token: token }
    assert_redirected_to carousel_path(@carousel)
  end

  test "sign in and current contribution agreement are required" do
    token = preview
    sign_out
    get new_carousel_layout_draft_path(@carousel)
    assert_redirected_to new_session_path
    assert_no_difference [ "Figure.count", "Seat.count" ] do
      post preview_carousel_layout_draft_path(@carousel), params: { layout_draft: @attributes }
      assert_redirected_to new_session_path
      post carousel_layout_draft_path(@carousel), params: { preview_token: token }
      assert_redirected_to new_session_path
    end
    editor = users(:editor)
    editor.update!(contribution_terms_version: nil, contribution_terms_accepted_at: nil)
    sign_in_as editor
    get new_carousel_layout_draft_path(@carousel)
    assert_redirected_to edit_contribution_agreement_path
    assert_no_difference [ "Figure.count", "Seat.count" ] do
      post preview_carousel_layout_draft_path(@carousel), params: { layout_draft: @attributes }
      assert_redirected_to edit_contribution_agreement_path
      post carousel_layout_draft_path(@carousel), params: { preview_token: token }
      assert_redirected_to edit_contribution_agreement_path
    end
  end

  test "verifying draft geometry removes its warning without confirming placements" do
    token = preview
    post carousel_layout_draft_path(@carousel), params: { preview_token: token }
    get edit_carousel_path(@carousel)
    assert_select "input[name='carousel[layout_provisional]'][type=checkbox][checked]"
    assert_select "input[name='carousel[sections_count]']", 0
    patch carousel_path(@carousel), params: { carousel: { layout_provisional: "0" } }
    assert_redirected_to carousel_path(@carousel)
    assert_not @carousel.reload.layout_provisional?
    assert @carousel.seats.all? { _1.confidence == "best_reading" }
    get carousel_path(@carousel)
    assert_select ".provisional-layout", 0
  end

  private
    def preview(**changes)
      assert_no_difference [ "Figure.count", "Seat.count", "Placement.count", "PaperTrail::Version.count" ] do
        post preview_carousel_layout_draft_path(@carousel), params: { layout_draft: @attributes.merge(changes) }
      end
      assert_response :success
      css_select("input[name=preview_token]").sole["value"]
    end

    def assert_denied
      assert_redirected_to root_path
      assert_match(/permission/, flash[:alert])
    end
end
