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

  test "a retrieved YouTube clip is analyzed then purged while the source and interval remain" do
    @analysis.destroy!
    @analysis = VideoAnalysis.create!(carousel: @carousel, user: users(:admin),
      youtube_url: "https://youtu.be/Usok6GXGavc", youtube_start_seconds: 3, youtube_duration_seconds: 20)
    downloader = Object.new
    analysis = @analysis
    upload = video_upload
    downloader.define_singleton_method(:call) { analysis.side_video.attach(upload) }
    YoutubeVideoDownloader.define_singleton_method(:new) { |*| downloader }
    stub_analyzer(-> {
      assert analysis.side_video.attached?
      { draft: sample_draft, frames_count: 4 }
    }) do
      perform_enqueued_jobs { VideoAnalysisJob.perform_now(@analysis) }
    end
    assert @analysis.reload.complete?
    assert_empty @analysis.attached_passes
    assert_equal [ 3, 20 ], [ @analysis.youtube_start_seconds, @analysis.youtube_duration_seconds ]
    assert @analysis.youtube?
  ensure
    YoutubeVideoDownloader.singleton_class.remove_method(:new)
  end

  test "download failures are recorded without calling the analyzer" do
    @analysis.destroy!
    @analysis = VideoAnalysis.create!(carousel: @carousel, user: users(:admin),
      youtube_url: "https://youtu.be/Usok6GXGavc")
    downloader = Object.new
    downloader.define_singleton_method(:call) { raise YoutubeVideoDownloader::Error, "Video unavailable" }
    YoutubeVideoDownloader.define_singleton_method(:new) { |*| downloader }
    stub_analyzer(-> { flunk "The analyzer must not run without a downloaded clip" }) do
      VideoAnalysisJob.perform_now(@analysis)
    end
    assert @analysis.reload.failed?
    assert_equal "Video unavailable", @analysis.error_message
    assert @analysis.retryable?
  ensure
    YoutubeVideoDownloader.singleton_class.remove_method(:new)
  end

  test "a YouTube clip already attached after a failed analysis is reused on retry" do
    @analysis.update!(youtube_url: "https://www.youtube.com/watch?v=Usok6GXGavc")
    YoutubeVideoDownloader.define_singleton_method(:new) { |*| raise "Do not download the clip again" }
    stub_analyzer(-> { { draft: sample_draft, frames_count: 4 } }) { VideoAnalysisJob.perform_now(@analysis) }
    assert @analysis.reload.complete?
  ensure
    YoutubeVideoDownloader.singleton_class.remove_method(:new)
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
