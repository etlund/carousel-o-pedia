require "test_helper"

class SeatFillTest < ActiveSupport::TestCase
  setup do
    @carousel = build_carousel(sections: 3, rows: 3)
    @type = FigureType.create!(name: "Horse", category: "horse")
    @attributes = { figure_type_id: @type.id, mount: "jumper", source_notes: "[Research](https://example.com/) with uncertain identities." }
  end

  test "fills only unknown seats with distinct sourced best-reading figures" do
    chariot = create_figure("Chariot", category: "chariot")
    @carousel.seat("1A").update!(rows_spanned: 2, confidence: "confirmed")
    SeatAssignment.new(@carousel.seat("1A"), chariot).save!
    SeatAssignment.new(@carousel.seat("1C"), nil, empty: true).save!
    known = create_figure("Known horse")
    SeatAssignment.new(@carousel.seat("2A"), known).save!
    reserve = create_figure("Unseated reserve")
    @carousel.seat("2B").update!(confidence: "confirmed")
    original = @carousel.seats.where.not(state: "unknown").map(&:attributes)
    seat_count = @carousel.seats.count
    fill = SeatFill.new(@carousel, @attributes)
    assert fill.valid?
    assert_equal %w[ 2B 2C 3A 3B 3C ], fill.seats.map(&:code)
    fill, snapshot = SeatFill.from_preview(@carousel, fill.preview_token)

    PaperTrail.request(whodunnit: users(:editor).id.to_s) do
      assert_difference [ "Figure.count", "Placement.count" ], 5 do
        assert_equal 5, fill.apply!(expected_snapshot: snapshot)
      end
    end

    assert_equal original, @carousel.seats.where.not(state: "unknown").where.not(id: fill.seats.map(&:id)).map(&:attributes)
    assert_equal seat_count, @carousel.seats.count
    assert_equal chariot, @carousel.seat("1A").figure
    assert_equal 2, @carousel.seat("1A").rows_spanned
    assert_nil @carousel.seat("1B")
    assert_equal known, @carousel.seat("2A").figure
    assert_nil reserve.reload.seat
    fill.seats.each do |seat|
      seat.reload
      figure = seat.figure
      assert_equal "filled", seat.state
      assert_equal "best_reading", seat.confidence
      assert_equal "Horse #{seat.code}", figure.name
      assert_equal [ @carousel, @type, "jumper", "Horse" ],
        [ figure.carousel, figure.figure_type, figure.mount, figure.short_name ]
      assert_includes figure.description, "Provisional"
      assert_includes figure.body, @attributes[:source_notes]
      assert_equal users(:editor).id.to_s, figure.versions.last.whodunnit
      assert_equal users(:editor).id.to_s, seat.versions.last.whodunnit
      assert_equal users(:editor).id.to_s, seat.current_placement.versions.last.whodunnit
    end
  end

  test "does not replace a current placement even if the seat state is inconsistent" do
    seat = @carousel.seat("1A")
    figure = create_figure("Existing figure")
    SeatAssignment.new(seat, figure).save!
    seat.update!(state: "unknown")

    fill = SeatFill.new(@carousel, @attributes)

    assert_not_includes fill.seats.map(&:id), seat.id
    assert_equal figure, seat.reload.figure
  end

  test "fills the Perkasie-style layout with exactly twelve horses per row" do
    carousel = build_carousel(sections: 14, rows: 3)
    [ 1, 8 ].each do |section|
      chariot = create_figure("Chariot #{section}", category: "chariot", carousel:)
      carousel.seat("#{section}A").update!(rows_spanned: 2)
      SeatAssignment.new(carousel.seat("#{section}A"), chariot).save!
      SeatAssignment.new(carousel.seat("#{section}C"), nil, empty: true).save!
    end
    fill = SeatFill.new(carousel, @attributes)
    assert fill.valid?
    fill, snapshot = SeatFill.from_preview(carousel, fill.preview_token)

    assert_difference "Figure.count", 36 do
      assert_equal 36, fill.apply!(expected_snapshot: snapshot)
    end

    assert_empty carousel.seats.unknown
    assert_equal 2, carousel.seats.where(state: "empty").count
    assert_equal 38, carousel.figures.count
    %w[ A B C ].each do |row|
      horses = carousel.seats.where(row:).filter { _1.category == "horse" }
      assert_equal 12, horses.size
      assert horses.all? { _1.confidence == "best_reading" && _1.figure.mount == "jumper" }
    end
  end

  test "preserves unknown row spans and allows unknown motion" do
    @carousel.seat("1A").update!(rows_spanned: 2)
    fill = SeatFill.new(@carousel, @attributes.merge(mount: ""))
    fill, snapshot = SeatFill.from_preview(@carousel, fill.preview_token)

    assert_equal 8, fill.apply!(expected_snapshot: snapshot)
    assert_equal 2, @carousel.seat("1A").rows_spanned
    assert_nil @carousel.seat("1B")
    assert_nil @carousel.seat("1A").figure.mount
  end

  test "rejects missing invalid and nonexistent choices without writes" do
    [ { source_notes: " " }, { figure_type_id: "" }, { figure_type_id: "1oops" },
      { figure_type_id: -1 }, { figure_type_id: FigureType.maximum(:id) + 1 },
      { mount: "flying" } ].each do |invalid|
      fill = SeatFill.new(@carousel, @attributes.merge(invalid))
      assert_not fill.valid?, invalid.inspect
      assert fill.errors.any?
    end

    unknown = SeatFill.new(Carousel.create!(name: "No layout"), @attributes)
    assert_not unknown.valid?
    assert_includes unknown.errors.full_messages.to_sentence, "sections and rows"
    @carousel.seats.each { SeatAssignment.new(_1, nil, empty: true).save! }
    complete = SeatFill.new(@carousel, @attributes)
    assert_not complete.valid?
    assert_includes complete.errors.full_messages.to_sentence, "no unknown seats"
  end

  test "a changed seat rejects the entire preview rather than applying a subset" do
    fill = SeatFill.new(@carousel, @attributes)
    fill, snapshot = SeatFill.from_preview(@carousel, fill.preview_token)
    SeatAssignment.new(@carousel.seat("3C"), nil, empty: true).save!

    assert_no_difference [ "Figure.count", "Placement.count", "PaperTrail::Version.count" ] do
      error = assert_raises(SeatFill::Conflict) { fill.apply!(expected_snapshot: snapshot) }
      assert_includes error.message, "changed since your preview"
    end
    assert_equal 8, @carousel.seats.unknown.count
  end

  test "a changed figure type invalidates the preview" do
    fill = SeatFill.new(@carousel, @attributes)
    fill, snapshot = SeatFill.from_preview(@carousel, fill.preview_token)
    travel 1.second do
      @type.update!(name: "Renamed horse")
    end

    assert_no_difference "Figure.count" do
      assert_raises(SeatFill::Conflict) { fill.apply!(expected_snapshot: snapshot) }
    end
  end

  test "all figure placement seat and history changes roll back on a later failure" do
    @carousel.seats.update_all(confidence: "confirmed")
    fill = SeatFill.new(@carousel, @attributes)
    fill, snapshot = SeatFill.from_preview(@carousel, fill.preview_token)
    reject_second = -> {
      if name == "Horse 1B"
        errors.add(:base, "Injected draft failure")
        raise ActiveRecord::RecordInvalid.new(self)
      end
    }
    Figure.set_callback(:create, :before, reject_second)
    before = [ Carousel, Seat, Figure, Placement, PaperTrail::Version ].map { _1.order(:id).map(&:attributes) }

    error = assert_raises(ActiveRecord::RecordInvalid) { fill.apply!(expected_snapshot: snapshot) }

    assert_includes error.message, "Injected draft failure"
    assert_equal before, [ Carousel, Seat, Figure, Placement, PaperTrail::Version ].map { _1.order(:id).map(&:attributes) }
  ensure
    Figure.skip_callback(:create, :before, reject_second)
  end
end
