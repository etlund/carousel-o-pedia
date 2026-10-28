require "test_helper"

class SeatFillsTest < ActionDispatch::IntegrationTest
  setup do
    @carousel = build_carousel(sections: 2, rows: 2)
    @type = FigureType.create!(name: "Horse", category: "horse")
    @attributes = { figure_type_id: @type.id, mount: "jumper", source_notes: "[Operator](https://example.com/), reviewed today; identities uncertain." }
    sign_in_as users(:editor)
  end

  test "editor previews changes corrects choices and confirms without repetitive seat edits" do
    SeatAssignment.new(@carousel.seat("1A"), nil, empty: true).save!
    get carousel_path(@carousel)
    assert_select "a[href=?]", new_carousel_seat_fill_path(@carousel), text: "Fill unknown seats"

    get new_carousel_seat_fill_path(@carousel)
    assert_response :success
    assert_select "select[name='seat_fill[figure_type_id]'] option[selected][value=?]", @type.id.to_s
    assert_select "select[name='seat_fill[mount]'] option[selected][value=jumper]"
    assert_select "textarea[name='seat_fill[source_notes]'][required]"
    assert_select "form[action=?][data-turbo=false]", preview_carousel_seat_fill_path(@carousel)

    token = preview
    assert_select "table tbody tr", 3
    assert_select "table th", text: "1A", count: 0
    assert_select "table td", text: "Horse 1B"
    assert_select "table td", text: "Jumper", count: 3
    assert_select ".prose a[href='https://example.com/']", text: "Operator"
    assert_select "input[type=submit][value='Create 3 draft figures']"
    change_path = css_select("a").find { _1.text == "Change choices" }["href"]
    get change_path
    assert_response :success
    assert_select "textarea[name='seat_fill[source_notes]']", text: @attributes[:source_notes]
    assert_select "select[name='seat_fill[mount]'] option[selected][value=jumper]"

    assert_difference [ "Figure.count", "Placement.count" ], 3 do
      post carousel_seat_fill_path(@carousel), params: { preview_token: token }
    end
    assert_redirected_to carousel_path(@carousel)
    follow_redirect!
    assert_select ".flash", text: /Added 3 draft figures/
    assert_select "a[href=?]", new_carousel_seat_fill_path(@carousel), count: 0
    assert_select "svg.seat-chart a.seat.horse.unsure", 3
    assert_equal "empty", @carousel.seat("1A").state

    figure = @carousel.seat("1B").figure
    get history_figure_path(figure)
    assert_select ".version-line", text: /Ed Editor/
    assert_includes figure.body, @attributes[:source_notes]
  end

  test "preview validation preserves input and reports errors without writes" do
    [ { source_notes: " " }, { mount: "flying" }, { figure_type_id: "bogus" } ].each do |invalid|
      assert_no_difference [ "Figure.count", "Placement.count", "PaperTrail::Version.count" ] do
        post preview_carousel_seat_fill_path(@carousel), params: { seat_fill: @attributes.merge(invalid) }
      end
      assert_response :unprocessable_entity
      assert_select "[role=alert]"
      assert_select "input[name=preview_token]", 0
    end
  end

  test "invalid expired or wrong-carousel previews cannot create figures" do
    token = preview
    other = build_carousel
    travel 61.minutes do
      assert_no_difference "Figure.count" do
        post carousel_seat_fill_path(@carousel), params: { preview_token: token }
      end
      assert_redirected_to new_carousel_seat_fill_path(@carousel)
    end

    [ [ @carousel, "#{token}tampered" ], [ other, token ] ].each do |carousel, value|
      assert_no_difference [ "Figure.count", "Placement.count" ] do
        post carousel_seat_fill_path(carousel), params: { preview_token: value }
      end
      assert_redirected_to new_carousel_seat_fill_path(carousel)
      follow_redirect!
      assert_select ".flash.alert", text: /invalid or has expired/
    end
  end

  test "application uses the previewed choices not injected parameters and cannot be repeated" do
    token = preview
    post carousel_seat_fill_path(@carousel), params: {
      preview_token: token, seat_fill: @attributes.merge(mount: "fixed", source_notes: "Changed after preview"),
      confidence: "confirmed", carousel_id: @carousel.slug
    }
    assert_redirected_to carousel_path(@carousel)
    assert_equal "jumper", @carousel.seat("1A").figure.mount
    assert_includes @carousel.seat("1A").figure.body, @attributes[:source_notes]
    assert_equal "best_reading", @carousel.seat("1A").confidence

    assert_no_difference [ "Figure.count", "Placement.count" ] do
      post carousel_seat_fill_path(@carousel), params: { preview_token: token }
    end
    assert_redirected_to new_carousel_seat_fill_path(@carousel)
    follow_redirect!
    assert_select ".flash.alert", text: /changed since your preview/
  end

  test "a stale preview reports a conflict and leaves every other seat untouched" do
    token = preview
    SeatAssignment.new(@carousel.seat("1A"), nil, empty: true).save!

    assert_no_difference [ "Figure.count", "Placement.count" ] do
      post carousel_seat_fill_path(@carousel), params: { preview_token: token }
    end
    assert_redirected_to new_carousel_seat_fill_path(@carousel)
    follow_redirect!
    assert_select ".flash.alert", text: /Nothing was saved/
    assert_equal 3, @carousel.seats.unknown.count
  end

  test "unmapped and completed layouts offer guidance instead of a fill form" do
    unmapped = Carousel.create!(name: "No layout yet", rows_count: 3)
    get new_carousel_seat_fill_path(unmapped)
    assert_response :success
    assert_select "a[href=?]", edit_carousel_path(unmapped), text: "Edit carousel layout"
    assert_select "input[type=submit]", 0
    post preview_carousel_seat_fill_path(unmapped), params: { seat_fill: @attributes }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Record the carousel's sections and rows/

    @carousel.seats.each { SeatAssignment.new(_1, nil, empty: true).save! }
    get new_carousel_seat_fill_path(@carousel)
    assert_response :success
    assert_select "p", text: /There are no unknown seats/
    assert_select "input[type=submit]", 0
  end

  test "only authorized editors can access preview or apply fills" do
    other = build_carousel
    token = preview
    editor = users(:editor)
    editor.update!(access_scope: "carousel", editable_carousel: other)

    get carousel_path(@carousel)
    assert_select "a[href=?]", new_carousel_seat_fill_path(@carousel), 0
    get new_carousel_seat_fill_path(@carousel)
    assert_denied
    assert_no_difference [ "Figure.count", "Placement.count" ] do
      post preview_carousel_seat_fill_path(@carousel), params: { seat_fill: @attributes }
      assert_denied
      post carousel_seat_fill_path(@carousel), params: { preview_token: token }
      assert_denied
    end

    editor.update!(editable_carousel: @carousel)
    token = preview
    assert_difference "Figure.count", 4 do
      post carousel_seat_fill_path(@carousel), params: { preview_token: token }
    end
    assert_redirected_to carousel_path(@carousel)
  end

  test "anonymous visitors and editors without agreement cannot use the workflow" do
    token = preview
    sign_out
    get new_carousel_seat_fill_path(@carousel)
    assert_redirected_to new_session_path
    assert_no_difference "Figure.count" do
      post preview_carousel_seat_fill_path(@carousel), params: { seat_fill: @attributes }
      assert_redirected_to new_session_path
      post carousel_seat_fill_path(@carousel), params: { preview_token: token }
      assert_redirected_to new_session_path
    end

    editor = users(:editor)
    editor.update!(contribution_terms_version: nil, contribution_terms_accepted_at: nil)
    sign_in_as editor
    get new_carousel_seat_fill_path(@carousel)
    assert_redirected_to edit_contribution_agreement_path
    assert_no_difference "Figure.count" do
      post preview_carousel_seat_fill_path(@carousel), params: { seat_fill: @attributes }
      assert_redirected_to edit_contribution_agreement_path
      post carousel_seat_fill_path(@carousel), params: { preview_token: token }
      assert_redirected_to edit_contribution_agreement_path
    end
  end

  private
    def preview
      assert_no_difference [ "Figure.count", "Placement.count", "PaperTrail::Version.count" ] do
        post preview_carousel_seat_fill_path(@carousel), params: { seat_fill: @attributes }
      end
      assert_response :success
      css_select("input[name=preview_token]").sole["value"]
    end

    def assert_denied
      assert_redirected_to root_path
      assert_match(/permission/, flash[:alert])
    end
end
