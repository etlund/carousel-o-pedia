require "test_helper"

class CarouselFormTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:editor)
  end

  test "edit sections show only their own fields for known and unknown layouts" do
    [ build_carousel, Carousel.create!(name: "Unknown layout") ].each do |carousel|
      %w[ basic location details ].each do |section|
        get edit_carousel_path(carousel, section:)

        assert_response :success
        assert_fields(section:, layout_known: carousel.layout_known?)
        assert_select "nav [aria-current=page]", count: 1
        assert_select "input[name=section][value=?]", section
        assert_select ".actions a[href=?]", carousel_path(carousel), text: "Cancel"
      end
    end
  end

  test "new form retains all fields and editable layout dimensions" do
    get new_carousel_path

    assert_response :success
    assert_fields(section: nil, layout_known: false)
    assert_select "#carousel_name[required]"
    assert_select ".actions input[type=submit]"
    assert_select ".actions a[href=?]", carousels_path, text: "Cancel"
  end

  test "saving everyday details preserves existing ring research without exposing its fields" do
    carousel = Carousel.create!(name: "Researched carousel", rows_count: 3,
      summary_sources: "Research reference", ring_details: { "A" => { "horses_count" => 18 } })
    research = carousel.ring_details.deep_dup

    get edit_carousel_path(carousel, section: "details")

    assert_response :success
    assert_fields(section: "details", layout_known: false)
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

    get edit_carousel_path(carousel, section: "details")
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

    patch carousel_path(carousel), params: { section: "details", carousel: { decks_count: 1 } }

    assert_response :unprocessable_entity
    assert_nil carousel.reload.decks_count
    assert_select ".flash.alert", text: /cannot be less than the number of deck records/
    assert_select "#carousel_decks_count[value='1']"
    assert_select "nav [aria-current=page]", text: "Details"
  end

  test "sections save independently and preserve other sections" do
    carousel = Carousel.create!(name: "Original", city: "Original city", music_type: "Organ")

    patch carousel_path(carousel), params: { section: "basic", carousel: { name: "Revised", body: "Page text" } }
    assert_redirected_to carousel_path(carousel)
    patch carousel_path(carousel), params: { section: "location", carousel: { city: "New city" } }
    assert_redirected_to carousel_path(carousel)
    patch carousel_path(carousel), params: { section: "details", carousel: { music_type: "Piano" } }
    assert_redirected_to carousel_path(carousel)
    carousel.reload
    assert_equal [ "Revised", "Page text", "New city", "Piano" ],
      [ carousel.name, carousel.body, carousel.city, carousel.music_type ]
  end

  test "basic validation errors retain the submitted values and section" do
    carousel = Carousel.create!(name: "Original")
    patch carousel_path(carousel), params: { section: "basic", carousel: { name: "", body: "Unsaved text" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Name/
    assert_select "textarea[name='carousel[body]']", text: "Unsaved text"
    assert_select "nav [aria-current=page]", text: "Basics"
    assert_equal "Original", carousel.reload.name
  end

  test "music details can be edited and appear on the carousel page" do
    carousel = Carousel.create!(name: "Musical carousel")

    get edit_carousel_path(carousel, section: "details")
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

  private
    def assert_fields(section:, layout_known:)
      groups = {
        "basic" => %w[ name other_names status maker_id year_built year_opened body official_url wikipedia_url other_links ],
        "location" => %w[ venue street_address city region postal_code country address_sources ],
        "details" => %w[ music_type music_description decks_count sections_count rows_count ]
      }
      groups["details"] += %w[ lead_seat_id layout_provisional ] if layout_known
      groups["details"] += %w[ rotation published_horses_count published_other_animals_count published_chariots_count summary_sources ]
      fields = section ? groups.fetch(section) : groups["basic"].first(6) + groups["location"] + groups["basic"].drop(6) + groups["details"]

      assert_equal fields.map { "carousel_#{_1}" },
        css_select("form.form [name^='carousel['][id]").map { _1["id"] }
      assert_select "form.form [name^='carousel[ring_details]']", count: 0
    end
end
