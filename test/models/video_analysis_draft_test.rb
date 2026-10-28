require "test_helper"

class VideoAnalysisDraftTest < ActiveSupport::TestCase
  test "records the layout and fills every ticked seat on a carousel with no layout" do
    carousel = Carousel.create!(name: "Unmapped Carousel")
    analysis = complete_analysis(carousel)

    result = VideoAnalysisDraft.new(analysis, seats: form_seats(analysis), apply_layout: true).apply!

    carousel.reload
    assert_equal [ 2, 2, "counterclockwise" ], [ carousel.sections_count, carousel.rows_count, carousel.rotation ]
    assert_equal %w[ 1A 1B 2A 2B ], result.added
    assert_equal [ "Horse 1", "Horse 2", "Horse 3", "Horse 4" ], carousel.seats.map { _1.figure.name }
    seat = carousel.seat("1A")
    assert_equal [ "jumper", "Horse at 1A", "best_reading" ], [ seat.figure.mount, seat.figure.description, seat.confidence ]
    assert analysis.reload.applied?
  end

  test "never replaces a seat an editor already filled in" do
    carousel = build_carousel(sections: 2, rows: 2)
    lead = create_figure("Titan", carousel:)
    SeatAssignment.new(carousel.seat("1A"), lead).save!
    SeatAssignment.new(carousel.seat("2B"), nil, empty: true).save!
    analysis = complete_analysis(carousel)

    result = VideoAnalysisDraft.new(analysis, seats: form_seats(analysis), apply_layout: false).apply!

    assert_equal %w[ 1B 2A ], result.added
    assert_equal %w[ 1A 2B ], result.skipped
    assert_equal "Titan", carousel.seat("1A").figure.name
    assert_equal "empty", carousel.seat("2B").state
  end

  test "applies the reviewer's corrections, unticked seats stay unknown, and new types are created once" do
    carousel = build_carousel(sections: 2, rows: 2)
    analysis = complete_analysis(carousel)
    seats = form_seats(analysis)
    seats[0].merge!(figure_type: "mountain goat", category: "menagerie", mount: "stander", description: "White goat")
    seats[1].merge!(figure_type: "Mountain goat", category: "menagerie")
    seats[2][:include] = "0"
    seats[3].merge!(state: "empty")

    VideoAnalysisDraft.new(analysis, seats:, apply_layout: false).apply!

    assert_equal [ "Mountain goat 1", "stander", "menagerie" ], [ carousel.seat("1A").figure.name, carousel.seat("1A").figure.mount, carousel.seat("1A").category ]
    assert_equal "Mountain goat 2", carousel.seat("1B").figure.name
    assert_equal 1, FigureType.where(name: "Mountain goat").count
    assert_equal "unknown", carousel.seat("2A").state
    assert_equal "empty", carousel.seat("2B").state
  end

  test "a tub that fills a whole section takes over the seats behind it" do
    carousel = build_carousel(sections: 2, rows: 2)
    draft = sample_draft
    draft["seats"][0].merge!("figure_type" => "Tea-cup", "category" => "chariot", "mount" => "spinning", "rows_spanned" => 2)
    analysis = complete_analysis(carousel, draft:)

    result = VideoAnalysisDraft.new(analysis, seats: form_seats(analysis), apply_layout: false).apply!

    assert_equal 2, carousel.seat("1A").rows_spanned
    assert_nil carousel.seat("1B")
    assert_includes result.skipped, "1B"
  end

  test "refuses a draft whose layout disagrees with the recorded one" do
    carousel = build_carousel(sections: 3, rows: 2)
    analysis = complete_analysis(carousel)

    assert analysis.layout_conflict?
    assert_raises(VideoAnalysisDraft::Conflict) do
      VideoAnalysisDraft.new(analysis, seats: form_seats(analysis), apply_layout: false).apply!
    end
    assert carousel.seats.all? { _1.state == "unknown" }
    assert_not analysis.reload.applied?
  end

  private
    def complete_analysis(carousel, draft: sample_draft)
      create_analysis(carousel).tap { _1.update!(status: "complete", draft:) }
    end

    def form_seats(analysis)
      analysis.proposed_seats.map do |seat|
        { code: "#{seat["section"]}#{seat["row"]}", include: "1", state: seat["state"], figure_type: seat["figure_type"],
          category: seat["category"], mount: seat["mount"], description: seat["description"], rows_spanned: seat["rows_spanned"].to_s }
      end
    end
end
