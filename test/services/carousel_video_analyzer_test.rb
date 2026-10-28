require "test_helper"

class CarouselVideoAnalyzerTest < ActiveSupport::TestCase
  setup do
    @carousel = build_carousel(sections: 2, rows: 2)
    @analysis = create_analysis(@carousel)
  end

  test "sends frames from each clip to Claude and returns the parsed draft" do
    claude = FakeClaude.new(sample_draft.to_json)
    result = CarouselVideoAnalyzer.new(@analysis, client: claude).call

    assert_equal 2, result[:draft]["sections_count"]
    assert_equal 4, result[:frames_count]
    assert_equal [ 1200, 800 ], result.values_at(:input_tokens, :output_tokens)

    request = claude.requests.sole
    images = request[:messages].sole[:content].select { _1[:type] == "image" }
    assert_equal 4, images.size
    assert_equal "image/jpeg", images.first[:source][:media_type]
    assert_equal :json_schema, request[:output_config][:format_][:type]
    assert_equal :default, request[:fallbacks]
    assert_match "2 sections and 2 rows", request[:messages].sole[:content].first[:text]
  end

  test "tells Claude which figure is the lead when one is recorded" do
    lead = create_figure("Titan the Hippocampus", category: "menagerie", carousel: @carousel)
    lead.update!(description: "White horse front, teal tail")
    SeatAssignment.new(@carousel.seat("1A"), lead).save!
    claude = FakeClaude.new(sample_draft.to_json)

    CarouselVideoAnalyzer.new(@analysis, client: claude).call
    assert_match "lead figure (1A) is Titan the Hippocampus", claude.requests.sole[:messages].sole[:content].first[:text]
  end

  test "reports a refusal or unreadable reply as an analysis error" do
    assert_raises(CarouselVideoAnalyzer::Error) do
      CarouselVideoAnalyzer.new(@analysis, client: FakeClaude.new("", stop_reason: :refusal)).call
    end
    error = assert_raises(CarouselVideoAnalyzer::Error) do
      CarouselVideoAnalyzer.new(@analysis, client: FakeClaude.new("not json")).call
    end
    assert_match "unexpected format", error.message
  end

  test "explains when the API key is missing" do
    with_env("ANTHROPIC_API_KEY" => nil) do
      error = assert_raises(CarouselVideoAnalyzer::Error) { CarouselVideoAnalyzer.new(@analysis).call }
      assert_match "ANTHROPIC_API_KEY", error.message
    end
  end

  private
    def with_env(values)
      previous = values.keys.index_with { ENV[_1] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      previous.each { |key, value| ENV[key] = value }
    end
end
