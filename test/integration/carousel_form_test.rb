require "test_helper"

class CarouselFormTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:editor)
  end

  test "edit forms prioritize everyday details for known and unknown layouts" do
    [ build_carousel, Carousel.create!(name: "Unknown layout") ].each do |carousel|
      get edit_carousel_path(carousel)

      assert_response :success
      assert_field_order(layout_known: carousel.layout_known?)
      assert_select "#carousel_name[value=?]", carousel.name
      assert_select ".actions a[href=?]", carousel_path(carousel), text: "Cancel"
    end
  end

  test "new form uses the same priorities and retains editable layout dimensions" do
    get new_carousel_path

    assert_response :success
    assert_field_order(layout_known: false)
    assert_select "#carousel_name[required]"
    assert_select ".actions input[type=submit]"
    assert_select ".actions a[href=?]", carousels_path, text: "Cancel"
  end

  test "saving everyday details preserves existing ring research without exposing its fields" do
    carousel = Carousel.create!(name: "Researched carousel", rows_count: 3,
      summary_sources: "Research reference", ring_details: { "A" => { "horses_count" => 18 } })
    research = carousel.ring_details.deep_dup

    get edit_carousel_path(carousel)

    assert_response :success
    assert_field_order(layout_known: false)
    assert_select "a[href=?]", new_carousel_layout_draft_path(carousel), text: "Create draft layout"

    patch carousel_path(carousel), params: { carousel: { name: "Updated carousel", rows_count: 3,
      sections_count: "", summary_sources: "Research reference" } }

    assert_redirected_to carousel_path(carousel.reload)
    assert_equal "Updated carousel", carousel.name
    assert_equal research, carousel.ring_details
    assert_empty carousel.seats
  end

  test "carousel deck count can be recorded without adding deck details" do
    carousel = Carousel.create!(name: "Undocumented multi-deck carousel")

    get edit_carousel_path(carousel)
    assert_response :success
    assert_select "#carousel_decks_count[min='1']"

    patch carousel_path(carousel), params: { carousel: { decks_count: 3 } }

    assert_redirected_to carousel_path(carousel)
    assert_equal 3, carousel.reload.decks_count
    assert_empty carousel.carousel_decks

    get carousel_path(carousel)
    assert_response :success
    assert_select "dt", text: "Number of decks"
    assert_select "dd", text: "3"

    get carousels_path(q: carousel.name)
    assert_response :success
    assert_select ".cards > li.card", text: /3 decks; Layout unknown/
  end

  test "carousel deck count cannot be smaller than the number of recorded decks" do
    carousel = Carousel.create!(name: "Two recorded decks")
    2.times { |index| carousel.carousel_decks.create!(name: "Deck #{index + 1}", position: index + 1) }

    patch carousel_path(carousel), params: { carousel: { decks_count: 1 } }

    assert_response :unprocessable_entity
    assert_nil carousel.reload.decks_count
    assert_select ".flash.alert", text: /cannot be less than the number of deck records/
  end

  private
    def assert_field_order(layout_known:)
      fields = %w[ name other_names status maker_id year_built year_opened
        venue street_address city region postal_code country address_sources body
        official_url wikipedia_url other_links music_type music_description
        decks_count sections_count rows_count ]
      fields += %w[ lead_seat_id layout_provisional ] if layout_known
      fields += %w[ rotation published_horses_count published_other_animals_count
        published_chariots_count summary_sources ]

      assert_equal fields.map { "carousel_#{_1}" },
        css_select("form.form input[id], form.form select[id], form.form textarea[id]").map { _1["id"] }
      assert_select "form.form legend", text: "Independent ring research", count: 0
      assert_select "form.form [name^='carousel[ring_details]']", count: 0
    end

    test "music details can be edited and appear on the carousel page" do
      carousel = Carousel.create!(name: "Musical carousel")

      get edit_carousel_path(carousel)
      assert_response :success
      assert_select "#carousel_music_type"
      assert_select "#carousel_music_year", count: 0
      assert_select "#carousel_music_description"

      patch carousel_path(carousel), params: { carousel: {
        music_type: "Band organ", music_description: "Original instrument (1912); [archive](https://example.com/)."
      } }

      assert_redirected_to carousel_path(carousel)
      carousel.reload
      assert_equal "Band organ", carousel.music_type
      assert_equal "Original instrument (1912); [archive](https://example.com/).", carousel.music_description

      get carousel_path(carousel)
      assert_response :success
      assert_select "dt", text: "Music type"
      assert_select "dd", text: "Band organ"
      assert_select "dd.prose a[href='https://example.com/']", text: "archive"
    end
end
