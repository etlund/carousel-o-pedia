class VideoAnalysisJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(analysis)
    return unless analysis.queued?

    analysis.update!(status: "processing", started_at: Time.current, error_message: nil)
    result = CarouselVideoAnalyzer.new(analysis).call
    analysis.update!(status: "complete", finished_at: Time.current, **result)
    # The draft keeps everything the tool read; the clips are large, so they go once it succeeds.
    analysis.purge_videos
  rescue CarouselVideoAnalyzer::Error, RubyLLM::Error, RubyLLM::ConfigurationError,
    Faraday::Error => error
    analysis.update!(status: "failed", finished_at: Time.current, error_message: error.message.truncate(500))
  end
end
