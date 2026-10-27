require "test_helper"

class CarouselAccessTest < ActionDispatch::IntegrationTest
  setup do
    @carousel = build_carousel
    @other = build_carousel
    @figure = create_figure("Local figure", carousel: @carousel)
    @other_figure = create_figure("Other figure", carousel: @other)
    @editor = users(:editor)
    @editor.update!(access_scope: "carousel", editable_carousel: @carousel)
    sign_in_as @editor
  end

  test "an admin can invite an editor for an existing carousel or one new carousel" do
    sign_out
    sign_in_as users(:admin)
    get invitations_path
    assert_select "select[name='invitation[access_scope]']"
    assert_select "select[name='invitation[editable_carousel_id]'] option[value=?]", @carousel.id.to_s

    [ @carousel, nil ].each_with_index do |carousel, index|
      post invitations_path, params: { invitation: {
        email_address: "limited#{index}@example.com", access_scope: "carousel",
        editable_carousel_id: carousel&.id
      } }
      assert_redirected_to invitations_path
      invitation = Invitation.last
      assert_equal "carousel", invitation.access_scope
      if carousel
        assert_equal carousel, invitation.editable_carousel
      else
        assert_nil invitation.editable_carousel
      end
      sign_out

      get edit_invitation_acceptance_path(invitation.token)
      assert_response :success
      assert_select "p", /#{Regexp.escape(invitation.access_description)}/
      patch invitation_acceptance_path(invitation.token), params: { user: {
        name: "Limited editor", password: "secret123", password_confirmation: "secret123",
        contribution_terms: "1", contribution_terms_version: User::CONTRIBUTION_TERMS_VERSION,
        access_scope: "site_wide", editable_carousel_id: @other.id
      } }
      assert_redirected_to carousel ? carousel_path(carousel) : new_carousel_path
      user = User.find_by!(email_address: invitation.email_address)
      assert_equal "carousel", user.access_scope
      if carousel
        assert_equal carousel, user.editable_carousel
      else
        assert_nil user.editable_carousel
      end
      sign_out
      sign_in_as users(:admin)
    end
  end

  test "invalid invitation scopes and carousel references show errors" do
    sign_out
    sign_in_as users(:admin)
    [
      { access_scope: "admin" },
      { access_scope: "carousel", editable_carousel_id: -1 },
      { access_scope: "site_wide", editable_carousel_id: @carousel.id }
    ].each do |attributes|
      assert_no_difference "Invitation.count" do
        post invitations_path, params: {
          invitation: { email_address: "limited@example.com" }.merge(attributes)
        }
      end
      assert_response :unprocessable_entity
      assert_select ".flash"
    end
  end

  test "a new-carousel editor creates a blank carousel only once and can retry invalid input" do
    @editor.update!(editable_carousel: nil)
    get new_carousel_path
    assert_response :success
    assert_no_difference "Carousel.count" do
      post carousels_path, params: { carousel: { name: "" } }
    end
    assert_response :unprocessable_entity
    assert_nil @editor.reload.editable_carousel_id

    assert_difference "Carousel.count", 1 do
      post carousels_path, params: { carousel: { name: "My blank carousel" } }
    end
    carousel = Carousel.find_by!(name: "My blank carousel")
    assert_redirected_to carousel_path(carousel)
    assert_equal carousel, @editor.reload.editable_carousel
    assert_empty carousel.seats
    assert_empty carousel.figures
    assert_nil carousel.sections_count
    assert_nil carousel.rows_count

    get new_carousel_path
    assert_denied
    assert_no_difference "Carousel.count" do
      post carousels_path, params: { carousel: { name: "Second carousel" } }
    end
    assert_denied
    patch carousel_path(carousel), params: { carousel: { city: "Missoula" } }
    assert_redirected_to carousel_path(carousel)
    assert_equal "Missoula", carousel.reload.city
  end

  test "a pending new-carousel editor cannot edit existing records or add figures" do
    @editor.update!(editable_carousel: nil)
    get new_figure_path
    assert_denied
    get edit_carousel_path(@carousel)
    assert_denied
    assert_no_difference "Figure.count" do
      post figures_path, params: { figure: {
        name: "Not mine", carousel_id: @carousel.id, figure_type_id: @figure.figure_type_id
      } }
    end
    assert_denied
  end

  test "carousel editing is limited to the assigned carousel" do
    get edit_carousel_path(@carousel)
    assert_response :success
    patch carousel_path(@carousel), params: { carousel: { city: "Local city" } }
    assert_redirected_to carousel_path(@carousel)
    assert_equal "Local city", @carousel.reload.city

    get edit_carousel_path(@other)
    assert_denied
    patch carousel_path(@other), params: { carousel: { city: "Unauthorized city" } }
    assert_denied
    assert_nil @other.reload.city
    get new_carousel_path
    assert_denied
  end

  test "figure editing and creation stay within the assigned carousel" do
    get new_figure_path
    assert_response :success
    assert_equal [ @carousel.id.to_s ],
      css_select("select[name='figure[carousel_id]'] option").map { _1["value"] }
    get new_figure_path(carousel_id: @other.id)
    assert_denied

    post figures_path, params: { figure: {
      name: "New local figure", carousel_id: @carousel.id, figure_type_id: @figure.figure_type_id
    } }
    created = Figure.find_by!(name: "New local figure")
    assert_redirected_to figure_path(created)
    patch figure_path(@figure), params: { figure: { description: "Local research" } }
    assert_redirected_to figure_path(@figure)
    assert_equal "Local research", @figure.reload.description

    get edit_figure_path(@other_figure)
    assert_denied
    [
      [ @figure, { carousel_id: @other.id } ],
      [ @other_figure, { carousel_id: @carousel.id, description: "Imported" } ]
    ].each do |figure, attributes|
      patch figure_path(figure), params: { figure: attributes }
      assert_denied
    end
    assert_equal @carousel.id, @figure.reload.carousel_id
    assert_equal @other.id, @other_figure.reload.carousel_id
    assert_nil @other_figure.description
    assert_no_difference "Figure.count" do
      post figures_path, params: { figure: {
        name: "Not local", carousel_id: @other.id, figure_type_id: @figure.figure_type_id
      } }
    end
    assert_denied
  end

  test "seat assignment cannot move figures or modify seats from another carousel" do
    SeatAssignment.new(@other.seat("1A"), @other_figure).save!
    patch carousel_seat_path(@carousel, "1A"), params: { seat: { figure_id: @figure.id, confidence: "confirmed" } }
    assert_redirected_to figure_path(@figure)
    assert_equal @figure, @carousel.seat("1A").figure
    get edit_carousel_seat_path(@other, "1A")
    assert_denied

    assert_no_difference "Placement.count" do
      patch carousel_seat_path(@carousel, "1A"), params: { seat: { figure_id: @other_figure.id, confidence: "best_reading" } }
      assert_denied
      patch carousel_seat_path(@other, "1A"), params: { seat: { figure_id: @figure.id } }
      assert_denied
    end
    assert_equal @other_figure, @other.seat("1A").figure
    assert_equal @other.id, @other_figure.reload.carousel_id
    assert_equal @figure, @carousel.seat("1A").figure
    assert @carousel.seat("1A").confirmed?
  end

  test "shared catalogs and admin operations are read-only for a limited editor" do
    maker = Maker.create!(name: "Shared maker")
    type = @figure.figure_type
    [ [ makers_path, new_maker_path, maker_path(maker), edit_maker_path(maker), :maker, maker ],
      [ figure_types_path, new_figure_type_path, figure_type_path(type), edit_figure_type_path(type), :figure_type, type ]
    ].each do |index, new_path, show_path, edit_path, key, record|
      get show_path
      assert_response :success
      assert_select "a[href=?]", edit_path, count: 0
      get new_path
      assert_denied
      get edit_path
      assert_denied
      assert_no_difference record.class.name + ".count" do
        post index, params: { key => { name: "Unauthorized", category: "horse" } }
      end
      assert_denied
      name = record.name
      patch show_path, params: { key => { name: "Unauthorized" } }
      assert_denied
      assert_equal name, record.reload.name
    end
    get invitations_path
    assert_redirected_to root_path
    patch carousel_path(@carousel), params: { carousel: { city: "Versioned" } }
    post revert_version_path(@carousel.versions.last)
    assert_redirected_to root_path
    assert_equal "Versioned", @carousel.reload.city
  end

  test "browsing stays available while unavailable editing controls are hidden" do
    get carousel_path(@carousel)
    assert_select "a[href=?]", edit_carousel_path(@carousel)
    get carousel_path(@other)
    assert_response :success
    assert_select "a[href=?]", edit_carousel_path(@other), count: 0
    get figure_path(@other_figure)
    assert_response :success
    assert_select "a[href=?]", edit_figure_path(@other_figure), count: 0
    get history_carousel_path(@other)
    assert_response :success
    get carousels_path
    assert_select "a[href=?]", new_carousel_path, count: 0
    get makers_path
    assert_select "a[href=?]", new_maker_path, count: 0
    get figure_types_path
    assert_select "a[href=?]", new_figure_type_path, count: 0
  end

  private
    def assert_denied
      assert_redirected_to root_path
      assert_equal "You do not have permission to make that change.", flash[:alert]
    end
end
