require "test_helper"

class LayoutDraftTest < ActiveSupport::TestCase
  setup do
    @carousel = Carousel.create!(name: "Inventory-only carousel", rows_count: 4, rotation: "counterclockwise",
      published_horses_count: 68, published_other_animals_count: 0, published_chariots_count: 2,
      summary_sources: "[Inventory](https://example.com/): 16, 16, 18, 18 horses; two chariots.")
    @horse = FigureType.create!(name: "Horse", category: "horse")
    @chariot = FigureType.create!(name: "Chariot", category: "chariot")
    @attributes = LayoutDraft.defaults_for(@carousel)
  end

  test "suggests an explicitly provisional 18 by 4 grid with two-row opposite chariots" do
    draft = LayoutDraft.new(@carousel, @attributes)

    assert draft.valid?, draft.errors.full_messages.inspect
    assert_equal [ "18", "4", "2", "1A, 10A" ],
      [ draft.sections_count, draft.rows_count, draft.chariot_rows_spanned, draft.chariot_seats ]
    assert_equal({ "horse" => 68, "menagerie" => 0, "chariot" => 2 }, draft.category_totals)
    assert_equal 70, draft.proposals.size
    assert_includes draft.assumptions, "assumptions"
    assert_includes draft.assumptions, "not confirmed"
    assert_equal @carousel.summary_sources, draft.source_notes
    assert_nil @carousel.sections_count
    assert_empty @carousel.seats
  end

  test "unknown inventory counts are not silently treated as zero for section suggestions" do
    @carousel.update!(published_other_animals_count: nil)
    assert_nil LayoutDraft.defaults_for(@carousel)[:sections_count]

    @carousel.update!(sections_count: 18)
    assert_equal 18, LayoutDraft.defaults_for(@carousel)[:sections_count]
  end

  test "provisional geometry requires both dimensions and supporting source notes" do
    @carousel.layout_provisional = true
    assert_not @carousel.valid?
    assert_includes @carousel.errors[:layout_provisional], "requires recorded sections and rows"

    carousel = Carousel.new(name: "Unsourced estimate", sections_count: 18, rows_count: 4, layout_provisional: true)
    assert_not carousel.valid?
    assert carousel.errors[:summary_sources].any?
    carousel.summary_sources = "Proposed from a roster; chariot footprints are assumed."
    assert carousel.valid?
    assert_not Carousel.new.layout_provisional?
  end

  test "preview builds categorized unsaved seats without changing carousel records" do
    draft = LayoutDraft.new(@carousel, @attributes)
    assert draft.valid?
    before = record_snapshot

    seats = draft.preview_seats

    assert_equal before, record_snapshot
    assert seats.all?(&:new_record?)
    assert draft.preview_carousel.new_record?
    assert_equal({ "horse" => 68, "chariot" => 2 }, seats.map(&:category).tally)
    assert_equal [ %w[ A B ], %w[ A B ] ], seats.select { _1.category == "chariot" }.map(&:rows_covered)
  end

  test "applies all geometry figures placements sources and uncertainty together" do
    reserve = create_figure("Reserve", carousel: @carousel)
    original_sources = @carousel.reload.summary_sources
    draft, snapshot = previewed_draft

    PaperTrail.request(whodunnit: users(:editor).id.to_s) do
      assert_difference [ "Figure.count", "Placement.count" ], 70 do
        assert_equal 70, draft.apply!(expected_snapshot: snapshot)
      end
    end

    @carousel.reload
    assert @carousel.layout_provisional?
    assert_equal [ 18, 4, "counterclockwise" ], [ @carousel.sections_count, @carousel.rows_count, @carousel.rotation ]
    assert_equal [ 68, 0, 2 ], @carousel.published_category_totals.values
    assert_equal 70, @carousel.seats.count
    assert_empty @carousel.seats.unknown
    assert_equal({ "horse" => 68, "menagerie" => 0, "chariot" => 2 }, @carousel.category_totals)
    assert @carousel.seats.all? { _1.state == "filled" && _1.confidence == "best_reading" }
    assert_nil reserve.reload.seat
    assert_includes @carousel.summary_sources, original_sources
    assert_equal 1, @carousel.summary_sources.scan(original_sources).size
    [ "1A", "10A" ].each do |code|
      seat = @carousel.seat(code)
      assert_equal 2, seat.rows_spanned
      assert_equal "chariot", seat.category
      assert_equal "fixed", seat.figure.mount
      assert_equal "Chariot #{code}", seat.figure.name
      assert_includes seat.figure.body, "footprints are drafting assumptions"
      assert_includes seat.figure.body, original_sources
      assert_equal users(:editor).id.to_s, seat.figure.versions.last.whodunnit
    end
    assert_nil @carousel.seat("1B")
    assert_nil @carousel.seat("10B")
    assert_equal "jumper", @carousel.seat("1C").figure.mount
    assert_equal users(:editor).id.to_s, @carousel.versions.last.whodunnit
  end

  test "chariot footprints starting positions and empty cells can be adjusted before saving" do
    draft, snapshot = previewed_draft(chariot_rows_spanned: "1", chariot_seats: "2B, 11B", empty_seats: "2A, 11A")
    assert_equal({ "horse" => 68, "menagerie" => 0, "chariot" => 2 }, draft.category_totals)

    draft.apply!(expected_snapshot: snapshot)

    assert_equal 1, @carousel.seat("2B").rows_spanned
    assert_equal "chariot", @carousel.seat("2B").category
    assert_equal "empty", @carousel.seat("2A").state
    assert_equal "empty", @carousel.seat("11A").state
    assert_equal "best_reading", @carousel.seat("2A").confidence
    assert_equal 72, @carousel.seats.count
  end

  test "invalid dimensions footprints overlapping codes choices and sources are rejected" do
    [
      { sections_count: "18.5" }, { sections_count: "0" }, { rows_count: "7" },
      { rows_count: "" }, { chariot_rows_spanned: "0" }, { chariot_rows_spanned: "2.5" },
      { chariot_seats: "1D" }, { chariot_seats: "19A" }, { chariot_seats: "not-a-seat" },
      { chariot_seats: "1A, 1B" }, { chariot_seats: "1A, 01a" },
      { empty_seats: "1B" }, { empty_seats: "2A, 2a" }, { empty_seats: "1E" },
      { figure_type_id: "bad" }, { figure_type_id: FigureType.maximum(:id) + 1 },
      { chariot_type_id: @horse.id }, { chariot_type_id: "" }, { mount: "flying" }, { source_notes: " " }
    ].each do |invalid|
      draft = LayoutDraft.new(@carousel, @attributes.merge(invalid))
      assert_not draft.valid?, invalid.inspect
      assert draft.errors.any?
    end
    assert_empty @carousel.seats
    assert_empty @carousel.figures
  end

  test "a draft may have no chariots and unknown default motion" do
    draft, snapshot = previewed_draft(chariot_seats: "", chariot_type_id: "", mount: "")

    assert_equal 72, draft.apply!(expected_snapshot: snapshot)
    assert @carousel.seats.all? { _1.category == "horse" && _1.figure.mount.nil? }
    assert @carousel.reload.layout_provisional?
  end

  test "existing layouts are never replaced" do
    @carousel.update!(sections_count: 18)
    before = record_snapshot
    draft = LayoutDraft.new(@carousel, @attributes)

    assert_not draft.valid?
    assert_includes draft.errors.full_messages.to_sentence, "already exists"
    assert_equal before, record_snapshot
  end

  test "changes since preview and repeated application are explicit conflicts" do
    draft, snapshot = previewed_draft
    travel 1.second do
      @carousel.update!(summary_sources: "Another editor corrected the source.")
    end
    before = record_snapshot
    assert_raises(LayoutDraft::Conflict) { draft.apply!(expected_snapshot: snapshot) }
    assert_equal before, record_snapshot

    draft, snapshot = previewed_draft
    draft.apply!(expected_snapshot: snapshot)
    before = record_snapshot
    assert_raises(LayoutDraft::Conflict) { draft.apply!(expected_snapshot: snapshot) }
    assert_equal before, record_snapshot
  end

  test "late failures roll back layout geometry figures placements sources flag and history" do
    draft, snapshot = previewed_draft
    reject_horse = -> {
      if name == "Horse 1C"
        errors.add(:base, "Injected draft failure")
        raise ActiveRecord::RecordInvalid.new(self)
      end
    }
    Figure.set_callback(:create, :before, reject_horse)
    before = record_snapshot

    error = assert_raises(ActiveRecord::RecordInvalid) { draft.apply!(expected_snapshot: snapshot) }

    assert_includes error.message, "Injected draft failure"
    assert_equal before, record_snapshot
    assert_not @carousel.reload.layout_provisional?
  ensure
    Figure.skip_callback(:create, :before, reject_horse)
  end

  private
    def previewed_draft(**changes)
      draft = LayoutDraft.new(@carousel, @attributes.merge(changes))
      assert draft.valid?, draft.errors.full_messages.inspect
      LayoutDraft.from_preview(@carousel, draft.preview_token)
    end

    def record_snapshot
      [ Carousel, Seat, Figure, Placement, FigureType, PaperTrail::Version ].map { _1.order(:id).map(&:attributes) }
    end
end
