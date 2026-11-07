require "test_helper"

class EditingTest < ActionDispatch::IntegrationTest
  setup { @carousel = load_seeds }

  test "editors can create update and clear other names with public display and history" do
    sign_in_as users(:editor)
    get new_carousel_path
    assert_select "textarea[name='carousel[other_names]']:not([required])"

    post carousels_path, params: { carousel: { name: "Primary carousel name",
      other_names: " Historical name \r\n Manufacturer #51 " } }
    carousel = Carousel.find_by!(name: "Primary carousel name")
    slug = carousel.slug
    assert_redirected_to carousel_path(carousel)
    assert_equal "Historical name\nManufacturer #51", carousel.other_names

    get carousel_path(carousel)
    assert_select ".other-names li", text: "Historical name"
    assert_select ".other-names li", text: "Manufacturer #51"

    patch carousel_path(carousel), params: { carousel: { other_names: "New alternate name\n<script>alert('unsafe')</script>" } }
    assert_redirected_to carousel_path(carousel)
    assert_equal slug, carousel.reload.slug
    assert_equal "Primary carousel name", carousel.name

    get history_carousel_path(carousel)
    assert_select ".changes ins", text: /New alternate name/
    get edit_carousel_path(carousel)
    assert_select "textarea[name='carousel[other_names]']", text: carousel.other_names
    get carousel_path(carousel)
    assert_select ".other-names li", text: "<script>alert('unsafe')</script>"
    assert_select ".other-names script", count: 0

    patch carousel_path(carousel), params: { carousel: { other_names: "" } }
    assert_redirected_to carousel_path(carousel)
    assert_nil carousel.reload.other_names
    get carousel_path(carousel)
    assert_select ".other-names", count: 0
  end

  test "editors can create update and clear physical addresses with history" do
    sign_in_as users(:editor)
    get new_carousel_path
    assert_select "input[name='carousel[street_address]'][autocomplete=street-address]:not([required])"
    assert_select "input[name='carousel[postal_code]'][type=text]:not([required])"
    assert_select "textarea[name='carousel[address_sources]']"
    post carousels_path, params: { carousel: { name: "Address editing test", street_address: "  1 Main Street  ",
      city: "Hull", region: "Massachusetts", postal_code: "  02045 ", country: "United States",
      address_sources: "[Operator](https://example.com/)" } }
    carousel = Carousel.find_by!(name: "Address editing test")
    assert_redirected_to carousel_path(carousel)
    assert_equal "1 Main Street", carousel.street_address
    assert_equal "02045", carousel.postal_code
    assert_empty carousel.seats

    patch carousel_path(carousel), params: { carousel: { street_address: "2 Main Street", postal_code: "02045-1234",
      address_sources: "[Updated entrance](https://example.com/entrance)" } }
    assert_redirected_to carousel_path(carousel)
    assert_equal "2 Main Street", carousel.reload.street_address
    assert_equal "02045-1234", carousel.postal_code
    get history_carousel_path(carousel)
    assert_select ".changes ins", "2 Main Street"
    get edit_carousel_path(carousel)
    assert_select "input[name='carousel[postal_code]'][value='02045-1234']"

    patch carousel_path(carousel), params: { carousel: { street_address: " ", postal_code: "", address_sources: "" } }
    assert_redirected_to carousel_path(carousel)
    assert_nil carousel.reload.street_address
    assert_nil carousel.postal_code
    assert_nil carousel.address_sources
  end

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
    assert_redirected_to figure_path(rocky)
    follow_redirect!
    assert_response :success
    assert_select ".flash", text: "Saved."
    assert_select "h1", rocky.name
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
    assert_redirected_to carousel_seat_path(@carousel, "9C")
    assert_equal "empty", @carousel.seat("9C").state
    assert_equal @carousel, figure.reload.carousel
    assert_nil figure.seat
  end

  test "an editor corrects two auto-filled sections to spanning chariots and empty inner seats" do
    sign_in_as users(:editor)
    carousel = build_carousel(sections: 12, rows: 3)
    horse_type = FigureType.create!(name: "Correction horse", category: "horse")
    fill = SeatFill.new(carousel, figure_type_id: horse_type.id, mount: "jumper", source_notes: "Draft source")
    fill, snapshot = SeatFill.from_preview(carousel, fill.preview_token)
    assert_equal 36, fill.apply!(expected_snapshot: snapshot)
    chariots = [ 1, 7 ].map { create_figure("Chariot #{_1}", category: "chariot", carousel:) }

    get edit_carousel_seat_path(carousel, "1A")
    assert_select "option", text: "Correction horse 1A (#{carousel.name})"
    assert_select "option", text: "Correction horse 2A (#{carousel.name})", count: 0
    assert_select ".hint", text: /Expanding across auto-filled draft figures removes those placeholders/
    get figure_path(carousel.seat("1A").figure)
    assert_select ".card", text: /Auto-filled draft figure.*Edit figure.*Edit placement/

    [ 1, 7 ].zip(chariots).each do |section, chariot|
      patch carousel_seat_path(carousel, "#{section}A"), params: {
        seat: { figure_id: chariot.id, confidence: "confirmed", rows_spanned: 2 }
      }
      assert_redirected_to figure_path(chariot)
      patch carousel_seat_path(carousel, "#{section}C"), params: {
        seat: { figure_id: "empty", confidence: "confirmed", rows_spanned: 1 }
      }
      assert_redirected_to carousel_seat_path(carousel, "#{section}C")
    end

    carousel.reload
    assert_equal 30, carousel.figures.where(figure_type: horse_type).count
    assert_equal 32, carousel.figures.count
    assert_equal chariots, [ carousel.seat("1A").figure, carousel.seat("7A").figure ]
    assert_equal [ 2, 2 ], [ carousel.seat("1A").rows_spanned, carousel.seat("7A").rows_spanned ]
    assert_nil carousel.seat("1B")
    assert_nil carousel.seat("7B")
    assert_equal %w[ empty empty ], [ carousel.seat("1C").state, carousel.seat("7C").state ]
    %w[ 1A 1B 1C 7A 7B 7C ].each { assert_not Figure.exists?(name: "Correction horse #{_1}") }
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
    assert_redirected_to figure_path(figure)
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

  test "editors can create directory entries then record their first layout" do
    sign_in_as users(:editor)
    get new_carousel_path
    assert_select "input[name='carousel[sections_count]']:not([required])"
    assert_select "input[name='carousel[rows_count]']:not([required])"
    post carousels_path, params: { carousel: { name: "Directory entry", city: "Seattle",
      region: "Washington", country: "United States", official_url: "https://example.com/" } }
    carousel = Carousel.find_by!(name: "Directory entry")
    assert_redirected_to carousel_path(carousel)
    assert_match "seating layout has not been recorded", flash[:notice]
    assert_not carousel.layout_known?
    assert_nil carousel.rotation
    assert_empty carousel.seats

    get edit_carousel_path(carousel)
    assert_select "input[name='carousel[sections_count]']"
    assert_select "input[name='carousel[rows_count]']"
    assert_select "select[name='carousel[lead_seat_id]']", 0
    patch carousel_path(carousel), params: { carousel: { sections_count: 3, rows_count: 2 } }
    assert_redirected_to carousel_path(carousel)
    assert carousel.reload.layout_known?
    assert_equal 6, carousel.seats.count
    get carousel_path(carousel)
    assert_select "svg.seat-chart a.seat.unknown", 6
    assert_select "table.sections tbody tr", 3
    get edit_carousel_path(carousel)
    assert_select "input[name='carousel[sections_count]'][value='3']"
    assert_select "select[name='carousel[lead_seat_id]']"
  end

  test "invalid first layouts keep the editing fields and do not create seats" do
    sign_in_as users(:editor)
    carousel = Carousel.create!(name: "Directory entry")
    [ { sections_count: 3, rows_count: 0 }, { sections_count: 3, rows_count: 7 } ].each do |dimensions|
      patch carousel_path(carousel), params: { carousel: dimensions }
      assert_response :unprocessable_entity
      assert_select "[role=alert]"
      assert_select "input[name='carousel[sections_count]'][value='3']"
      assert_select "input[name='carousel[rows_count]']"
      assert_not carousel.reload.layout_known?
      assert_empty carousel.seats
    end
  end

  test "creating a three-row carousel saves all three rows" do
    sign_in_as users(:editor)
    post carousels_path, params: { carousel: { name: "Three-row carousel", sections_count: 3, rows_count: 3 } }
    carousel = Carousel.find_by!(name: "Three-row carousel")
    assert_redirected_to carousel_path(carousel)
    assert_equal 3, carousel.rows_count
    assert_equal %w[ 1A 1B 1C 2A 2B 2C 3A 3B 3C ], carousel.seats.map(&:code)
  end

  test "editors can record partial layout facts and published totals with sources" do
    sign_in_as users(:editor)
    carousel = Carousel.create!(name: "Partial research")
    patch carousel_path(carousel), params: { carousel: {
      sections_count: 18, published_horses_count: 68, published_other_animals_count: 0,
      published_chariots_count: 2, summary_sources: "[Operator](https://example.com/) reports these totals."
    } }
    assert_redirected_to carousel_path(carousel)
    assert_equal [ 18, nil ], carousel.reload.attributes.values_at("sections_count", "rows_count")
    assert_equal 68, carousel.published_horses_count
    assert_equal 0, carousel.published_other_animals_count
    assert_empty carousel.seats
    get edit_carousel_path(carousel)
    assert_select "input[name='carousel[sections_count]'][value='18']"
    assert_select "input[name='carousel[rows_count]']"
    assert_select "input[name='carousel[published_horses_count]'][value='68']"
    assert_select "textarea[name='carousel[summary_sources]']", text: /Operator/

    patch carousel_path(carousel), params: { carousel: { rows_count: 4 } }
    assert_redirected_to carousel_path(carousel)
    assert_equal 72, carousel.reload.seats.count
    assert_equal 68, carousel.published_horses_count

    patch carousel_path(carousel), params: { carousel: { published_horses_count: -1 } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /greater than or equal to 0/
    assert_equal 68, carousel.reload.published_horses_count

    patch carousel_path(carousel), params: { carousel: { published_horses_count: "", published_other_animals_count: "",
      published_chariots_count: "", summary_sources: "" } }
    assert_redirected_to carousel_path(carousel)
    assert_not carousel.reload.published_counts?
    assert_nil carousel.summary_sources
  end

  test "an editor can create update and clear carousel website fields" do
    sign_in_as users(:editor)
    get new_carousel_path
    assert_response :success
    assert_select "input[type=url][name='carousel[official_url]']:not([required])"
    assert_select "input[type=url][name='carousel[wikipedia_url]']:not([required])"
    assert_select "textarea[name='carousel[other_links]']"

    links = {
      official_url: "https://example.com/official",
      wikipedia_url: "https://en.wikipedia.org/wiki/Example",
      other_links: "[NCA gallery](https://carousels.org/)"
    }
    post carousels_path, params: { carousel: { name: "Linked carousel", sections_count: 1, rows_count: 1 }.merge(links) }
    carousel = Carousel.find_by!(name: "Linked carousel")
    assert_redirected_to carousel_path(carousel)
    links.each { |attribute, value| assert_equal value, carousel.public_send(attribute) }

    patch carousel_path(carousel), params: { carousel: links.merge(official_url: "https://example.com/updated") }
    assert_redirected_to carousel_path(carousel)
    assert_equal "https://example.com/updated", carousel.reload.official_url
    get history_carousel_path(carousel)
    assert_select ".changes ins", "https://example.com/updated"

    patch carousel_path(carousel), params: { carousel: { official_url: "", wikipedia_url: "", other_links: "" } }
    assert_redirected_to carousel_path(carousel)
    carousel.reload
    %i[ official_url wikipedia_url other_links ].each { assert_nil carousel.public_send(_1) }
  end

  test "invalid carousel URLs show form errors without saving" do
    sign_in_as users(:editor)
    original = @carousel.official_url
    assert_no_difference "PaperTrail::Version.count" do
      patch carousel_path(@carousel), params: { carousel: { official_url: "javascript:alert(1)" } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /must be an http:\/\/ or https:\/\/ URL/
    assert_select "input[name='carousel[official_url]'][value=?]", "javascript:alert(1)"
    assert_equal original, @carousel.reload.official_url
  end

  test "an editor can correct one row to three while keeping figures and recording history" do
    sign_in_as users(:editor)
    carousel = build_carousel(sections: 3, rows: 1)
    figure = create_figure("Existing figure", carousel:)
    SeatAssignment.new(carousel.seat("2A"), figure).save!
    original_ids = carousel.seats.ids

    get edit_carousel_path(carousel)
    assert_select "input[name='carousel[sections_count]'][value='3']"
    assert_select "input[name='carousel[rows_count]'][value='1']"
    patch carousel_path(carousel), params: { carousel: { rows_count: 3 } }
    assert_redirected_to carousel_path(carousel)
    assert_equal 3, carousel.reload.rows_count
    assert_equal 9, carousel.seats.count
    assert_empty original_ids - carousel.seats.ids
    assert_equal figure, carousel.seat("2A").figure
    assert_equal "unknown", carousel.seat("2C").state
    get carousel_path(carousel)
    assert_select "svg.seat-chart a.seat", 9
    get history_carousel_path(carousel)
    assert_select ".version-line", /Ed Editor\s+edited/
    assert_select ".changes", text: /Rows count/
  end

  test "editors can expand sections and shrink untouched positions" do
    sign_in_as users(:editor)
    carousel = build_carousel(sections: 2, rows: 1)
    patch carousel_path(carousel), params: { carousel: { sections_count: 3, rows_count: 3 } }
    assert_redirected_to carousel_path(carousel)
    assert_equal 9, carousel.reload.seats.count
    patch carousel_path(carousel), params: { carousel: { sections_count: 2, rows_count: 1 } }
    assert_redirected_to carousel_path(carousel)
    assert_equal %w[ 1A 2A ], carousel.reload.seats.map(&:code)
  end

  test "unsafe and invalid layout corrections show errors and retain editable dimensions" do
    sign_in_as users(:editor)
    [ { sections_count: 1 }, { rows_count: 0 }, { rows_count: 7 }, { rows_count: "" } ].each do |dimensions|
      assert_no_difference "PaperTrail::Version.count" do
        patch carousel_path(@carousel), params: { carousel: dimensions }
      end
      assert_response :unprocessable_entity
      assert_select "[role=alert]"
      assert_select "input[name='carousel[sections_count]']"
      assert_select "input[name='carousel[rows_count]']"
      assert_equal [ 14, 3 ], @carousel.reload.attributes.values_at("sections_count", "rows_count")
    end
  end

  test "shrinking cannot remove the selected lead section" do
    sign_in_as users(:editor)
    carousel = build_carousel(sections: 3, rows: 1)
    patch carousel_path(carousel), params: { carousel: { sections_count: 2, lead_seat_id: carousel.seat("3A").id } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Choose a lead figure/
    assert_equal 3, carousel.reload.sections_count
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
