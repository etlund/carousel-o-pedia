require "test_helper"

class CarouselDeckTest < ActiveSupport::TestCase
  setup do
    @carousel = build_carousel(sections: 4, rows: 2)
    @lower = @carousel.carousel_decks.create!(name: "Lower", position: 1, sections_count: 3, rows_count: 2)
    @upper = @carousel.carousel_decks.create!(name: "Upper", position: 2, sections_count: 2, rows_count: 1)
  end

  test "each platform has independent seat codes and dimensions without changing legacy seats" do
    assert_equal 8, @carousel.seats.count
    assert_equal 6, @lower.seats.count
    assert_equal 2, @upper.seats.count
    assert_equal 16, @carousel.all_seats.count
    assert_equal %w[ A B ], @lower.row_letters
    assert_equal %w[ A ], @upper.row_letters
    assert_equal "Upper - 1A", @upper.seat("1A").display_code
    assert_equal @carousel.id, @upper.seat("1A").carousel_id
    assert_not_equal @upper.seat("1A").id, @lower.seat("1A").id
    assert_not_equal @upper.seat("1A").id, @carousel.seat("1A").id
  end

  test "named unknown decks leave geometry and count allocations blank" do
    deck = @carousel.carousel_decks.create!(name: "Unresearched", position: 3)
    assert_not deck.layout_known?
    assert_empty deck.seats
    assert_equal [ nil, nil, nil ], deck.published_category_totals.values
    assert_not deck.update(published_horses_count: 5)
    assert deck.errors[:summary_sources].any?
  end

  test "spanning and shrinking are isolated to the selected deck and protect history" do
    seat = @lower.seat("1A")
    seat.update!(rows_spanned: 2)
    assert_nil @lower.seat("1B")
    assert @carousel.seat("1B")
    assert @upper.seat("1A")
    assert_not @lower.update(rows_count: 1)
    assert_includes @lower.errors.full_messages.to_sentence, "spanning"
    @upper.update!(sections_count: 3)
    assert_equal 3, @upper.seats.count
    @upper.seat("3A").update!(confidence: "confirmed")
    assert_not @upper.update(sections_count: 2)
    assert_equal 4, @carousel.sections_count
  end

  test "figures can move between decks and totals count each figure once" do
    figure = create_figure("Traveler", carousel: @carousel)
    SeatAssignment.new(@lower.seat("1A"), figure).save!
    SeatAssignment.new(@upper.seat("1A"), figure).save!
    assert_equal "empty", @lower.seat("1A").state
    assert_equal @upper.id, figure.reload.seat.carousel_deck_id
    assert_equal 1, @carousel.category_totals.fetch("horse")
    assert_equal 0, @lower.category_totals.fetch("horse")
    assert_equal 1, @upper.category_totals.fetch("horse")
    assert_equal 2, figure.placements.count
  end

  test "seat ownership cannot cross carousel or deck boundaries" do
    other = build_carousel
    seat = Seat.new(carousel: other, carousel_deck: @upper, section: 1, row: "A")
    assert_not seat.valid?
    assert seat.errors[:carousel_deck].any?
    seat = @upper.seat("1A")
    assert_not seat.update(carousel_deck: @lower)
    assert_includes seat.errors.full_messages.to_sentence, "cannot move"
    assert_raises(ArgumentError) { @upper.renumber_from!(@lower.seat("1A")) }
    assert_not @upper.update(carousel: other)
  end

  test "deck drafts preserve the parent and other decks and do not allocate aggregate counts" do
    @carousel.update!(published_horses_count: 20, summary_sources: "Aggregate census")
    deck = @carousel.carousel_decks.create!(name: "Draft", position: 3)
    FigureType.create!(name: "Horse", category: "horse")
    FigureType.create!(name: "Chariot", category: "chariot")
    defaults = LayoutDraft.sketch_defaults_for(deck)
    assert_nil defaults[:horses_count]
    assert_nil defaults[:rows_count]
    draft = LayoutDraft.new(deck, defaults.merge(horses_count: 5, other_animals_count: 1,
      chariots_count: 0, rows_count: 2, source_notes: "Proposed allocation"))
    assert draft.valid?, draft.errors.full_messages.inspect
    preview, snapshot = LayoutDraft.from_preview(deck, draft.preview_token)
    assert_raises(LayoutDraft::Conflict) { LayoutDraft.from_preview(@carousel, draft.preview_token) }
    assert_raises(LayoutDraft::Conflict) { LayoutDraft.from_preview(@upper, draft.preview_token) }
    preview.apply!(expected_snapshot: snapshot)
    assert deck.reload.layout_provisional?
    assert_equal [ 3, 2 ], [ deck.sections_count, deck.rows_count ]
    assert_equal 6, deck.seats.unknown.count
    assert_equal [ 4, 2, 20 ], @carousel.reload.attributes.values_at("sections_count", "rows_count", "published_horses_count")
    assert_equal 2, @upper.seats.count
    assert_empty @carousel.figures
  end

  test "preview conflicts on a changed deck and row spans never remove figures on another deck" do
    figure = create_figure("Upper horse", carousel: @carousel)
    SeatAssignment.new(@upper.seat("1A"), figure).save!
    SeatEdit.new(@lower.seat("1A"), nil, attributes: { rows_spanned: 2 }).save!
    assert_equal figure.id, @upper.seat("1A").figure.id

    FigureType.create!(name: "Horse", category: "horse") unless FigureType.exists?(name: "Horse")
    fill = SeatFill.new(@lower, figure_type_id: figure.figure_type_id, source_notes: "Tentative lower figures")
    assert fill.valid?
    token = fill.preview_token
    assert_raises(SeatFill::Conflict) { SeatFill.from_preview(@upper, token) }
    draft, snapshot = SeatFill.from_preview(@lower, token)
    @lower.seat("2A").update!(confidence: "confirmed")
    assert_raises(SeatFill::Conflict) { draft.apply!(expected_snapshot: snapshot) }
    assert_equal figure.id, @upper.seat("1A").figure.id
  end
end
