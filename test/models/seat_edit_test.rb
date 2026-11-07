require "test_helper"

class SeatEditTest < ActiveSupport::TestCase
  setup do
    @carousel = build_carousel(sections: 2, rows: 3)
    @horse_type = FigureType.create!(name: "Draft horse", category: "horse")
    @carousel.seats.each do |seat|
      DraftSeatAssignment.create!(seat, figure_type: @horse_type, mount: "jumper", source_notes: "Draft source")
    end
  end

  test "replacing a draft with a spanning chariot removes covered draft placeholders" do
    chariot = create_figure("Chariot", category: "chariot", carousel: @carousel)
    seat = @carousel.seat("1A")

    assert_difference "Figure.count", -2 do
      SeatEdit.new(seat, chariot, attributes: { rows_spanned: 2, confidence: "confirmed" }).save!
    end

    assert_equal chariot, @carousel.reload.seat("1A").figure
    assert_equal 2, @carousel.seat("1A").rows_spanned
    assert_nil @carousel.seat("1B")
    assert_not Figure.exists?(name: "Draft horse 1A")
    assert_not Figure.exists?(name: "Draft horse 1B")
    assert Figure.exists?(name: "Draft horse 1C")
  end

  test "marking a draft seat empty removes its generated figure" do
    seat = @carousel.seat("1C")
    figure = seat.figure

    assert_difference "Figure.count", -1 do
      SeatEdit.new(seat, nil, attributes: { rows_spanned: 1, confidence: "confirmed" }, empty: true).save!
    end

    assert_not Figure.exists?(figure.id)
    assert_equal "empty", seat.reload.state
    assert_nil seat.figure
  end

  test "researched figures block spans and preserve all draft placeholders on failure" do
    researched = create_figure("Researched horse", carousel: @carousel)
    SeatEdit.new(@carousel.seat("1B"), researched,
      attributes: { rows_spanned: 1, confidence: "confirmed" }).save!
    chariot = create_figure("Chariot", category: "chariot", carousel: @carousel)
    original_ids = @carousel.figures.ids

    error = assert_raises ActiveRecord::RecordInvalid do
      SeatEdit.new(@carousel.seat("1A"), chariot,
        attributes: { rows_spanned: 2, confidence: "confirmed" }).save!
    end

    assert_match(/would cover 1B/, error.message)
    assert_equal original_ids, @carousel.figures.reload.ids
    assert_equal "Draft horse 1A", @carousel.seat("1A").figure.name
    assert_equal researched, @carousel.seat("1B").figure
  end

  test "editing a draft figure promotes it to researched inventory" do
    figure = @carousel.seat("2B").figure
    assert_predicate figure, :draft_placeholder?

    figure.update!(name: "Identified horse")

    assert_not figure.reload.draft_placeholder?
    assert_raises ActiveRecord::RecordInvalid do
      SeatEdit.new(@carousel.seat("2A"), @carousel.seat("2A").figure,
        attributes: { rows_spanned: 2, confidence: "confirmed" }).save!
    end
    assert Figure.exists?(figure.id)
  end
end
