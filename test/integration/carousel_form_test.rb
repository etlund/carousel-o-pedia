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

  private
    def assert_field_order(layout_known:)
      fields = %w[ name other_names status maker_id year_built year_opened
        venue street_address city region postal_code country address_sources body
        official_url wikipedia_url other_links ]
      fields += layout_known ? %w[ lead_seat_id layout_provisional ] : %w[ sections_count rows_count ]
      fields += %w[ rotation published_horses_count published_other_animals_count
        published_chariots_count summary_sources ]
      fields += ("A"..).first(Carousel::MAX_ROWS).flat_map do |letter|
        %w[ positions_count horses_count mount ].map { "ring_details_#{letter}_#{_1}" }
      end

      assert_equal fields.map { "carousel_#{_1}" },
        css_select("form.form input[id], form.form select[id], form.form textarea[id]").map { _1["id"] }
    end
end
