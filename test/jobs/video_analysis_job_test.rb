require "test_helper"

class VideoAnalysisJobTest < ActiveJob::TestCase
  setup do
    @carousel = build_carousel(sections: 2, rows: 2)
    @analysis = create_analysis(@carousel)
  end

  test "stores the draft and deletes the clips once the analysis succeeds" do
    stub_analyzer(-> { { draft: sample_draft, frames_count: 4, model: "claude-opus-5-5",
      input_tokens: 10, output_tokens: 5, estimated_cost_usd: 0.01234567 } }) do
      perform_enqueued_jobs { VideoAnalysisJob.perform_now(@analysis) }
    end

    @analysis.reload
    assert @analysis.complete?
    assert_equal 4, @analysis.proposed_seats.size
    assert_equal 0.01234567, @analysis.estimated_cost_usd
    assert_not @analysis.side_video.attached?
  end

  test "keeps the clips and the reason when the analysis fails" do
    stub_analyzer(-> { raise CarouselVideoAnalyzer::Error, "ffmpeg is not installed on the server" }) do
      VideoAnalysisJob.perform_now(@analysis)
    end

    @analysis.reload
    assert @analysis.failed?
    assert_equal "ffmpeg is not installed on the server", @analysis.error_message
    assert @analysis.side_video.attached?
  end

  test "keeps the clips and records RubyLLM and transport failures" do
    [ RubyLLM::UnauthorizedError.new("Invalid API key"),
      RubyLLM::ConfigurationError.new("Provider is not configured"),
      Faraday::TimeoutError.new("Request timed out") ].each do |error|
      @analysis.update!(status: "queued")
      stub_analyzer(-> { raise error }) { VideoAnalysisJob.perform_now(@analysis) }

      @analysis.reload
      assert @analysis.failed?
      assert_equal error.message, @analysis.error_message
      assert @analysis.side_video.attached?
    end
  end

  private
    def stub_analyzer(behavior)
      analyzer = Object.new
      analyzer.define_singleton_method(:call) { behavior.call }
      CarouselVideoAnalyzer.define_singleton_method(:new) { |*| analyzer }
      yield
    ensure
      CarouselVideoAnalyzer.singleton_class.remove_method(:new)
    end
end
