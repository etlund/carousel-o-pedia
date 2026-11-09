require "test_helper"

class MultiDeckLayoutDraftsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:editor)
    FigureType.create!(name: "Horse", category: "horse")
    FigureType.create!(name: "Chariot", category: "chariot")
    @carousel = Carousel.create!(name: "Columbia draft", decks_count: 2,
      published_horses_count: 88, published_other_animals_count: 15, published_chariots_count: 3,
      summary_sources: "Whole carousel inventory")
    @decks = [
      { name: "Lower", horses_count: "44", other_animals_count: "15", chariots_count: "2",
        rows_count: "3", chariot_rows_spanned: "2", source_notes: "Tentative lower allocation" },
      { name: "Upper", horses_count: "44", other_animals_count: "0", chariots_count: "1",
        rows_count: "2", chariot_rows_spanned: "2", source_notes: "Tentative upper allocation" }
    ]
  end

  test "known totals suggest an even split and three rows without saving records" do
    get carousel_path(@carousel)
    assert_select "a[href=?]", new_carousel_layout_draft_path(@carousel), text: "Create draft layout"
    assert_no_difference "CarouselDeck.count" do
      get new_carousel_layout_draft_path(@carousel)
    end
    assert_response :success
    assert_select ".deck-draft-fields", 2
    assert_select "#draft_deck_0_horses_count[value='44']"
    assert_select "#draft_deck_1_horses_count[value='44']"
    assert_select "#draft_deck_0_other_animals_count[value='8']"
    assert_select "#draft_deck_1_other_animals_count[value='7']"
    assert_select "#draft_deck_0_chariots_count[value='2']"
    assert_select "#draft_deck_1_chariots_count[value='1']"
    assert_select "input[name='multi_deck_layout_draft[decks][][rows_count]'][value='3']", 2
    assert_select "#draft_deck_0_source_notes", text: /not a verified deck allocation/
    assert_select "form[action=?]", preview_carousel_layout_draft_path(@carousel)
  end

  test "default splits preserve known deck counts and geometry and leave unknown totals blank" do
    @carousel.update!(published_other_animals_count: nil)
    @carousel.carousel_decks.create!(name: "Known lower", position: 1, rows_count: 4,
      published_horses_count: 50, published_chariots_count: 0, summary_sources: "Lower survey")
    draft = MultiDeckLayoutDraft.new(@carousel)
    lower, upper = draft.entries.map(&:draft)
    assert_equal [ "50", "38" ], [ lower.horses_count, upper.horses_count ]
    assert_equal [ "0", "3" ], [ lower.chariots_count, upper.chariots_count ]
    assert_nil lower.other_animals_count
    assert_nil upper.other_animals_count
    assert_equal [ "4", "3" ], [ lower.rows_count, upper.rows_count ]
    assert_equal "Lower survey", lower.source_notes
    assert_includes upper.source_notes, "provisional even split"
  end

  test "overallocated published counts are not converted to negative suggestions" do
    @carousel.carousel_decks.create!(name: "Lower", position: 1,
      published_horses_count: 90, summary_sources: "Conflicting survey")
    upper = MultiDeckLayoutDraft.new(@carousel).entries.last.draft
    assert_nil upper.horses_count
  end

  test "Columbia suggestions can compare three and four row layouts without saving" do
    draft = MultiDeckLayoutDraft.new(@carousel)
    assert draft.valid?, draft.errors.full_messages.inspect
    assert_equal({ "horse" => 88, "menagerie" => 15, "chariot" => 3 }, draft.requested_totals)
    choices = draft.attributes
    assert_no_difference [ "CarouselDeck.count", "Seat.count", "Figure.count" ] do
      post preview_carousel_layout_draft_path(@carousel), params: { multi_deck_layout_draft: choices }
      assert_response :success
      assert_select ".draft-geometry", text: "19 sections, 3 rows."
      assert_select ".draft-geometry", text: "18 sections, 3 rows."
      choices["decks"].first["rows_count"] = "4"
      post preview_carousel_layout_draft_path(@carousel), params: { multi_deck_layout_draft: choices }
      assert_response :success
      assert_select ".draft-geometry", text: "14 sections, 4 rows."
      assert_select ".draft-geometry", text: "18 sections, 3 rows."
      assert_select "p[role=status]", 0
    end
  end

  test "previews both decks then saves independent layouts atomically without changing published totals" do
    assert_no_difference [ "CarouselDeck.count", "Seat.count", "Figure.count", "Placement.count" ] do
      post preview_carousel_layout_draft_path(@carousel), params: { multi_deck_layout_draft: { decks: @decks } }
    end
    assert_response :success
    assert_select ".deck-draft-preview", 2
    assert_select ".deck-draft-preview:first-of-type svg .unknown", 59
    assert_select ".deck-draft-preview:first-of-type svg .chariot", 2
    assert_select "p[role=status]", 0
    token = css_select("input[name=preview_token]").sole["value"]
    change_path = css_select("a").find { _1.text == "Change choices" }["href"]
    get change_path
    assert_response :success
    assert_select "#draft_deck_0_horses_count[value='44']"
    assert_select "#draft_deck_1_rows_count[value='2']"

    assert_difference "CarouselDeck.count", 2 do
      post carousel_layout_draft_path(@carousel), params: { preview_token: token }
    end
    assert_redirected_to carousel_path(@carousel)
    lower, upper = @carousel.carousel_decks.reload.to_a
    assert_equal [ "Lower", "Upper" ], [ lower.name, upper.name ]
    assert_equal [ 21, 3, 23, 2 ], [ lower.sections_count, lower.rows_count, upper.sections_count, upper.rows_count ]
    assert lower.layout_provisional?
    assert upper.layout_provisional?
    assert_equal 59, lower.seats.unknown.count
    assert_equal 44, upper.category_totals.fetch("horse")
    assert_equal %w[ A B ], upper.row_letters
    assert_nil @carousel.reload.sections_count
    assert_empty @carousel.seats
    assert_equal [ 88, 15, 3 ], @carousel.published_category_totals.values

    assert_no_difference [ "CarouselDeck.count", "Seat.count", "Figure.count" ] do
      post carousel_layout_draft_path(@carousel), params: { preview_token: token }
    end
    assert_redirected_to new_carousel_layout_draft_path(@carousel)
    assert_match /changed/, flash[:alert]
  end

  test "invalid deck inputs preserve choices without saving any deck" do
    @decks.last[:rows_count] = "0"
    post preview_carousel_layout_draft_path(@carousel), params: { multi_deck_layout_draft: { decks: @decks } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Deck 2/
    assert_select "#draft_deck_1_rows_count[value='0']"
    assert_select "input[name=preview_token]", 0
    assert_empty @carousel.carousel_decks
  end

  test "combined inventory mismatch is explicit" do
    @decks.last[:horses_count] = "43"
    post preview_carousel_layout_draft_path(@carousel), params: { multi_deck_layout_draft: { decks: @decks } }
    assert_response :success
    assert_select "p[role=status]", text: /Combined draft totals differ/
  end

  test "incomplete deck lists and duplicate names cannot produce a preview" do
    [ @decks.first(1), @decks.map { _1.merge(name: "Same name") } ].each do |decks|
      assert_no_difference [ "CarouselDeck.count", "Seat.count", "Figure.count" ] do
        post preview_carousel_layout_draft_path(@carousel), params: { multi_deck_layout_draft: { decks: } }
      end
      assert_response :unprocessable_entity
      assert_select "[role=alert]"
      assert_select "input[name=preview_token]", 0
    end
  end

  test "invalid signed tokens do not save any deck" do
    assert_no_difference [ "CarouselDeck.count", "Seat.count", "Figure.count" ] do
      post carousel_layout_draft_path(@carousel), params: { preview_token: "invalid" }
    end
    assert_redirected_to new_carousel_layout_draft_path(@carousel)
    assert_match /invalid or has expired/, flash[:alert]
  end

  test "changed carousel or figure types invalidate the whole preview" do
    post preview_carousel_layout_draft_path(@carousel), params: { multi_deck_layout_draft: { decks: @decks } }
    token = css_select("input[name=preview_token]").sole["value"]
    FigureType.find_by!(name: "Horse").update!(name: "Horse revised")
    assert_no_difference [ "CarouselDeck.count", "Seat.count", "Figure.count" ] do
      post carousel_layout_draft_path(@carousel), params: { preview_token: token }
    end
    assert_redirected_to new_carousel_layout_draft_path(@carousel)
    assert_match /changed/, flash[:alert]
  end

  test "existing decks can be drafted together but existing charts are protected" do
    @decks.each_with_index do |attributes, index|
      deck = @carousel.carousel_decks.create!(name: attributes[:name], position: index + 1)
      attributes[:id] = deck.id
    end
    post preview_carousel_layout_draft_path(@carousel), params: { multi_deck_layout_draft: { decks: @decks } }
    assert_response :success
    token = css_select("input[name=preview_token]").sole["value"]
    assert_no_difference "CarouselDeck.count" do
      post carousel_layout_draft_path(@carousel), params: { preview_token: token }
    end
    assert_redirected_to carousel_path(@carousel)

    post preview_carousel_layout_draft_path(@carousel), params: { multi_deck_layout_draft: { decks: @decks } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /already exists/
  end

  test "deck IDs cannot refer to another carousel" do
    other = Carousel.create!(name: "Other carousel")
    @decks.first[:id] = other.carousel_decks.create!(name: "Other deck", position: 1).id
    post preview_carousel_layout_draft_path(@carousel), params: { multi_deck_layout_draft: { decks: @decks } }
    assert_response :not_found
  end

  test "new decks follow existing display positions without collisions" do
    lower = @carousel.carousel_decks.create!(name: "Lower", position: 7)
    @decks.first[:id] = lower.id
    post preview_carousel_layout_draft_path(@carousel), params: { multi_deck_layout_draft: { decks: @decks } }
    assert_response :success
    token = css_select("input[name=preview_token]").sole["value"]
    post carousel_layout_draft_path(@carousel), params: { preview_token: token }
    assert_redirected_to carousel_path(@carousel)
    assert_equal [ 7, 8 ], @carousel.carousel_decks.reload.pluck(:position)
  end

  test "a failure saving the second deck rolls back both layouts and figures" do
    post preview_carousel_layout_draft_path(@carousel), params: { multi_deck_layout_draft: { decks: @decks } }
    token = css_select("input[name=preview_token]").sole["value"]
    calls = 0
    failure = ->(figure) {
      calls += 1
      if calls == 3
        figure.errors.add(:base, "Simulated save failure")
        raise ActiveRecord::RecordInvalid.new(figure)
      end
    }
    Figure.before_create failure
    assert_no_difference [ "CarouselDeck.count", "Seat.count", "Figure.count", "Placement.count" ] do
      post carousel_layout_draft_path(@carousel), params: { preview_token: token }
    end
    assert_response :unprocessable_entity
    assert_equal 3, calls
    assert_select "[role=alert]", text: /Nothing was saved/
  ensure
    Figure.skip_callback(:create, :before, failure) if failure
  end
end
