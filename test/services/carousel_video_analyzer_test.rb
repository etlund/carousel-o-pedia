require "test_helper"

class CarouselVideoAnalyzerTest < ActiveSupport::TestCase
  setup do
    @carousel = build_carousel(sections: 2, rows: 2)
    @analysis = create_analysis(@carousel)
  end

  test "sends frames from each clip to Claude and returns the parsed draft" do
    chat = stub_chat
    result = CarouselVideoAnalyzer.new(@analysis, chat:).call

    assert_equal 2, result[:draft]["sections_count"]
    assert_equal 8, result[:frames_count]
    assert_equal [ 1200, 800 ], result.values_at(:input_tokens, :output_tokens)
    assert_equal CarouselVideoAnalyzer::MODEL, result[:model]
    assert_in_delta 0.0208, result[:estimated_cost_usd]

    request = @requests.sole
    content = request["messages"].sole["content"]
    images = content.select { _1["type"] == "image" }
    assert_equal 8, images.size
    assert_equal "image/jpeg", images.first["source"]["media_type"]
    assert_equal "json_schema", request["output_config"]["format"]["type"]
    assert_equal CarouselVideoAnalyzer::SCHEMA.deep_stringify_keys, request["output_config"]["format"]["schema"]
    assert_equal "default", request["fallbacks"]
    assert_equal "adaptive", request["thinking"]["type"]
    assert_equal "high", request["output_config"]["effort"]
    assert_equal CarouselVideoAnalyzer::MAX_TOKENS, request["max_tokens"]
    assert_equal CarouselVideoAnalyzer::SYSTEM_PROMPT, request["system"].sole["text"]
    assert_match "2 sections and 2 rows", content.first["text"]
    assert_equal "text", content[2]["type"]
    assert_equal "image", content[3]["type"]
    assert_equal "text", content[4]["type"]
    assert_equal "image", content[5]["type"]
  end

  test "tells Claude which figure is the lead when one is recorded" do
    lead = create_figure("Titan the Hippocampus", category: "menagerie", carousel: @carousel)
    lead.update!(description: "White horse front, teal tail")
    SeatAssignment.new(@carousel.seat("1A"), lead).save!
    chat = stub_chat

    CarouselVideoAnalyzer.new(@analysis, chat:).call
    assert_match "lead figure (1A) is Titan the Hippocampus", @requests.sole["messages"].sole["content"].first["text"]
  end

  test "reports a refusal or unreadable reply as an analysis error" do
    error = assert_raises(CarouselVideoAnalyzer::Error) do
      CarouselVideoAnalyzer.new(@analysis, chat: stub_chat(text: "", stop_reason: "refusal")).call
    end
    assert_match "declined", error.message
    error = assert_raises(CarouselVideoAnalyzer::Error) do
      CarouselVideoAnalyzer.new(@analysis, chat: stub_chat(text: "not json")).call
    end
    assert_match "unexpected format", error.message
  end

  test "rejects a truncated reply even when it contains valid JSON" do
    error = assert_raises(CarouselVideoAnalyzer::Error) do
      CarouselVideoAnalyzer.new(@analysis, chat: stub_chat(stop_reason: "max_tokens")).call
    end
    assert_match "cut off", error.message
  end

  test "rejects JSON that is not a draft object" do
    [ "null", "[]", "42" ].each do |text|
      error = assert_raises(CarouselVideoAnalyzer::Error) do
        CarouselVideoAnalyzer.new(@analysis, chat: stub_chat(text:)).call
      end
      assert_match "unexpected format", error.message
    end
  end

  test "explains when the API key is missing" do
    with_env("ANTHROPIC_API_KEY" => nil) do
      error = assert_raises(CarouselVideoAnalyzer::Error) { CarouselVideoAnalyzer.new(@analysis).call }
      assert_match "ANTHROPIC_API_KEY", error.message
    end
  end

  test "rejects videos without readable frames before requesting analysis" do
    chat = stub_chat
    error = assert_raises(CarouselVideoAnalyzer::Error) do
      CarouselVideoAnalyzer.new(@analysis, chat:, frame_extractor: ->(_) { [] }).call
    end
    assert_match "No frames", error.message
    assert_empty @requests
  end

  private
    def stub_chat(text: sample_draft.to_json, stop_reason: "end_turn")
      @requests = []
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1/messages") do |env|
          @requests << JSON.parse(env.body)
          assert_equal CarouselVideoAnalyzer::FALLBACK_BETA, env.request_headers["anthropic-beta"]
          assert_equal "test-key", env.request_headers["x-api-key"]
          body = { role: "assistant", model: CarouselVideoAnalyzer::MODEL, stop_reason:,
            content: [ { type: "text", text: } ], usage: { input_tokens: 1200, output_tokens: 800 } }
          [ 200, { "content-type" => "application/json" }, body.to_json ]
        end
      end
      context = RubyLLM.context do |config|
        config.anthropic_api_key = "test-key"
        config.faraday_adapter = Class.new(Faraday::Adapter::Test) do
          define_method(:initialize) { |app| super(app, stubs) }
        end
      end
      context.chat(model: CarouselVideoAnalyzer::MODEL, provider: :anthropic, assume_model_exists: true)
    end

    def with_env(values)
      previous = values.keys.index_with { ENV[_1] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      previous.each { |key, value| ENV[key] = value }
    end
end
