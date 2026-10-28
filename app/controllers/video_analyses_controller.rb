class VideoAnalysesController < ApplicationController
  before_action :set_carousel
  before_action -> { raise User::AccessDenied unless current_user.can_analyze_videos_of?(@carousel) }
  before_action :set_analysis, only: %i[ show apply retry ]

  def index
    @analyses = @carousel.video_analyses.includes(:user).recent_first
  end

  def new
    @analysis = @carousel.video_analyses.build
  end

  def create
    @analysis = @carousel.video_analyses.build(analysis_params.merge(user: current_user))
    if @analysis.save
      VideoAnalysisJob.perform_later(@analysis)
      redirect_to carousel_video_analysis_path(@carousel, @analysis), notice: "Video uploaded. The analysis usually takes a few minutes."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def apply
    result = VideoAnalysisDraft.new(@analysis, seats: seat_params, apply_layout: params[:apply_layout] == "1").apply!
    notice = [ "Added #{result.added.size} #{"figure".pluralize(result.added.size)}" ]
    notice << "marked #{result.emptied.size} empty" if result.emptied.any?
    notice << "skipped #{result.skipped.to_sentence} because #{result.skipped.one? ? "it was" : "they were"} already filled in" if result.skipped.any?
    redirect_to @carousel, notice: "#{notice.to_sentence}. New figures are marked as a best reading."
  rescue VideoAnalysisDraft::Conflict, ActiveRecord::RecordInvalid => error
    redirect_to carousel_video_analysis_path(@carousel, @analysis), alert: error.message
  end

  def retry
    if @analysis.failed? && @analysis.attached_passes.any?
      @analysis.update!(status: "queued", error_message: nil, started_at: nil, finished_at: nil)
      VideoAnalysisJob.perform_later(@analysis)
      redirect_to carousel_video_analysis_path(@carousel, @analysis), notice: "Trying the analysis again."
    else
      redirect_to carousel_video_analysis_path(@carousel, @analysis), alert: "Only a failed analysis with its video still attached can be retried."
    end
  end

  private
    def set_carousel
      @carousel = Carousel.find_by!(slug: params[:carousel_id])
    end

    def set_analysis
      @analysis = @carousel.video_analyses.find(params[:id])
    end

    def analysis_params
      params.fetch(:video_analysis, {}).permit(*VideoAnalysis::PASSES.keys)
    end

    def seat_params
      params.fetch(:seats, {}).values.map do |seat|
        seat.permit(:code, :include, :state, :figure_type, :category, :mount, :description, :rows_spanned).to_h.symbolize_keys
      end
    end
end
