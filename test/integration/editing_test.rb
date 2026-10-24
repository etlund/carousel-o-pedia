require "test_helper"

class EditingTest < ActionDispatch::IntegrationTest
  setup { @carousel = load_seeds }

  test "reading is public but editing needs a signed-in editor" do
    get carousel_path(@carousel)
    assert_response :success
    assert_select "a", text: "Edit", count: 0

    get edit_carousel_path(@carousel)
    assert_redirected_to new_session_path

    patch figure_path(Figure.find_by!(name: "Gulliver")), params: { figure: { name: "Changed" } }
    assert_redirected_to new_session_path
    assert Figure.exists?(name: "Gulliver")
  end

  test "an editor's change is saved with their name in the history" do
    sign_in_as users(:editor)
    gulliver = Figure.find_by!(name: "Gulliver")

    patch figure_path(gulliver), params: { figure: { description: "White mountain goat with a gold pan" } }
    assert_redirected_to figure_path(gulliver)
    assert_equal "White mountain goat with a gold pan", gulliver.reload.description

    get history_figure_path(gulliver)
    assert_select ".version-line", /Ed Editor\s+edited/
    assert_select ".changes ins", "White mountain goat with a gold pan"
  end

  test "an editor puts a new figure in a seat" do
    sign_in_as users(:editor)

    post figures_path, params: { figure: { name: "Rocky the Marmot", carousel_id: @carousel.id, figure_type_id: FigureType.find_by!(name: "Jackrabbit").id, mount: "" } }
    rocky = Figure.find_by!(name: "Rocky the Marmot")
    assert_nil rocky.mount
    assert_equal @carousel, rocky.carousel

    patch carousel_seat_path(@carousel, "9C"), params: { seat: { figure_id: rocky.id, confidence: "confirmed", rows_spanned: 1 } }
    assert_redirected_to carousel_seat_path(@carousel, "9C")
    assert_equal rocky, @carousel.seat("9C").figure
    assert @carousel.seat("9C").confirmed?
  end

  test "seat editor lists only the current carousel's figures including unseated inventory" do
    sign_in_as users(:editor)
    reserve = create_figure("Local reserve")
    seat = @carousel.seat("1A")
    expected = [ "", "empty" ] + @carousel.figures.order(:name).pluck(:id).map(&:to_s)

    get edit_carousel_seat_path(@carousel, seat)
    assert_response :success
    assert_equal expected, css_select("select[name='seat[figure_id]'] option").map { _1["value"] }
    assert_select "select[name='seat[figure_id]'] option[value=?]", reserve.id.to_s
    assert_select "select[name='seat[figure_id]'] option[selected][value=?]", seat.figure.id.to_s
    assert_select "a[href=?]", new_figure_path(carousel_id: @carousel.id), text: "Add it first"

    patch carousel_seat_path(@carousel, seat), params: {
      seat: { figure_id: reserve.id, rows_spanned: 9, confidence: "confirmed" }
    }
    assert_response :unprocessable_entity
    assert_equal expected, css_select("select[name='seat[figure_id]'] option").map { _1["value"] }
  end

  test "an editor can mark a seat empty" do
    sign_in_as users(:editor)
    figure = @carousel.seat("9C").figure
    patch carousel_seat_path(@carousel, "9C"), params: { seat: { figure_id: "empty", confidence: "confirmed", rows_spanned: 1 } }
    assert_equal "empty", @carousel.seat("9C").state
    assert_equal @carousel, figure.reload.carousel
    assert_nil figure.seat
  end

  test "figure creation requires a carousel and supports preselecting one" do
    sign_in_as users(:editor)
    get new_figure_path(carousel_id: @carousel.id)
    assert_response :success
    assert_select "select[name='figure[carousel_id]'][required] option[selected][value=?]", @carousel.id.to_s

    assert_no_difference "Figure.count" do
      post figures_path, params: { figure: { name: "Missing owner", figure_type_id: FigureType.first.id } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Carousel must exist/
  end

  test "an editor can reassign unseated inventory but cannot strand an occupied seat" do
    sign_in_as users(:editor)
    figure = Figure.find_by!(slug: "salems-riverfront-carousel-pancho")
    patch figure_path(figure), params: { figure: { carousel_id: @carousel.id } }
    assert_redirected_to figure_path(figure)
    assert_equal @carousel, figure.reload.carousel

    seated = @carousel.seat("1A").figure
    other = Carousel.find_by!(slug: "salems-riverfront-carousel")
    get edit_figure_path(seated)
    assert_select "select[name='figure[carousel_id]'][disabled]"
    patch figure_path(seated), params: { figure: { carousel_id: other.id } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /must match the current seat/
    assert_equal @carousel, seated.reload.carousel
    assert_equal seated, @carousel.seat("1A").figure
  end

  test "a seat edit transfers an unseated figure from another carousel" do
    sign_in_as users(:editor)
    figure = Figure.find_by!(slug: "salems-riverfront-carousel-pancho")
    patch carousel_seat_path(@carousel, "9C"), params: {
      seat: { figure_id: figure.id, confidence: "confirmed", rows_spanned: 1 }
    }
    assert_redirected_to carousel_seat_path(@carousel, "9C")
    assert_equal @carousel, figure.reload.carousel
    assert_equal figure, @carousel.seat("9C").figure

    get history_figure_path(figure)
    assert_select ".changes ins", @carousel.name
  end

  test "a new carousel gets a full chart of unknown seats" do
    sign_in_as users(:editor)
    post carousels_path, params: { carousel: { name: "Spokane Looff Carrousel", sections_count: 12, rows_count: 4, rotation: "counterclockwise", status: "operating" } }

    carousel = Carousel.find_by!(name: "Spokane Looff Carrousel")
    assert_redirected_to carousel_path(carousel)
    assert_equal 48, carousel.seats.count
  end

  test "the platform size can't change after the carousel is made" do
    sign_in_as users(:editor)
    patch carousel_path(@carousel), params: { carousel: { name: "Great Northern Carousel", sections_count: 20 } }
    assert_equal 14, @carousel.reload.sections_count
  end

  test "an editor sets the lead figure from the carousel form" do
    sign_in_as users(:editor)
    cutty_seat = @carousel.seat("3A")

    patch carousel_path(@carousel), params: { carousel: { name: "Great Northern Carousel", lead_seat_id: cutty_seat.id } }

    assert_redirected_to carousel_path(@carousel)
    assert_equal "Cutty the Trout", @carousel.lead_figure.name
    assert_equal "1A", cutty_seat.reload.code
  end

  test "only admins can revert" do
    gulliver = Figure.find_by!(name: "Gulliver")
    original = gulliver.description
    gulliver.update!(description: "Vandalized")
    version = gulliver.versions.last

    sign_in_as users(:editor)
    post revert_version_path(version)
    assert_equal "Vandalized", gulliver.reload.description

    sign_in_as users(:admin)
    post revert_version_path(version)
    assert_equal original, gulliver.reload.description
  end

  test "recent changes lists edits across the site" do
    get recent_changes_path
    assert_response :success
    assert_select ".version", minimum: 50
  end

  test "reverting a pre-ownership figure version retains its current carousel" do
    figure = Figure.find_by!(name: "Gulliver")
    original = figure.description
    figure.update!(description: "Edited after migration")
    version = figure.versions.last
    snapshot = PaperTrail.serializer.load(version.object).except("carousel_id")
    version.update!(object: PaperTrail.serializer.dump(snapshot))

    sign_in_as users(:admin)
    post revert_version_path(version)

    assert_equal original, figure.reload.description
    assert_equal @carousel, figure.carousel
    assert_equal "9A", figure.seat.code
    assert_equal "Reverted.", flash[:notice]
  end

  test "an admin can revert an unseated figure's carousel reassignment" do
    figure = Figure.find_by!(slug: "salems-riverfront-carousel-pancho")
    original = figure.carousel
    figure.update!(carousel: @carousel)
    sign_in_as users(:admin)
    post revert_version_path(figure.versions.last)
    assert_equal original, figure.reload.carousel
    assert_nil figure.seat
    assert_equal "Reverted.", flash[:notice]
  end
end
