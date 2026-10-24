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

    post figures_path, params: { figure: { name: "Rocky the Marmot", figure_type_id: FigureType.find_by!(name: "Jackrabbit").id, mount: "" } }
    rocky = Figure.find_by!(name: "Rocky the Marmot")
    assert_nil rocky.mount

    patch carousel_seat_path(@carousel, "9C"), params: { seat: { figure_id: rocky.id, confidence: "confirmed", rows_spanned: 1 } }
    assert_redirected_to carousel_seat_path(@carousel, "9C")
    assert_equal rocky, @carousel.seat("9C").figure
    assert @carousel.seat("9C").confirmed?
  end

  test "an editor can mark a seat empty" do
    sign_in_as users(:editor)
    patch carousel_seat_path(@carousel, "9C"), params: { seat: { figure_id: "empty", confidence: "confirmed", rows_spanned: 1 } }
    assert_equal "empty", @carousel.seat("9C").state
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
end
