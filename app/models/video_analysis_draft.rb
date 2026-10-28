# Applies the seats a reviewer accepted from a video analysis to the carousel. It only
# fills seats nobody has filled yet, so it never overwrites an editor's work, and every
# figure it adds is marked as a best reading for someone to confirm.
class VideoAnalysisDraft
  Result = Data.define(:added, :emptied, :skipped)
  class Conflict < StandardError; end

  # seats: an array of hashes from the review form, each with code, include, figure_type,
  # category, mount, description, rows_spanned and state.
  def initialize(analysis, seats:, apply_layout:)
    @analysis, @carousel = analysis, analysis.carousel
    @seats = seats.select { |seat| ActiveModel::Type::Boolean.new.cast(seat[:include]) }
    @apply_layout = apply_layout
  end

  def apply!
    added, emptied, skipped = [], [], []
    ActiveRecord::Base.transaction do
      apply_layout if @apply_layout
      raise Conflict, "The draft's layout doesn't match this carousel's #{@carousel.sections_count} sections and #{@carousel.rows_count} rows" if @analysis.layout_conflict? && @seats.any?
      raise Conflict, "Record the carousel's layout before adding seats" if !@carousel.layout_known? && @seats.any?

      @seats.sort_by { |seat| Seat.parse_code(seat[:code]).values_at(:section, :row) }.each do |proposal|
        seat = @carousel.seats.reload.find_by(Seat.parse_code(proposal[:code]) || { id: nil })
        if seat.nil? || seat.figure || seat.state == "empty"
          skipped << proposal[:code]
        elsif proposal[:state] == "empty"
          SeatAssignment.new(seat, nil, empty: true).save!
          emptied << seat.code
        elsif proposal[:state] == "filled" && proposal[:figure_type].present?
          place_figure(seat, proposal)
          added << seat.code
        else
          skipped << proposal[:code]
        end
      end
      @analysis.update!(applied_at: Time.current)
    end
    Result.new(added:, emptied:, skipped:)
  end

  private
    def apply_layout
      return if @carousel.layout_known?

      layout = @analysis.proposed_layout
      rotation = layout["rotation"] if Carousel::ROTATIONS.include?(layout["rotation"])
      @carousel.update!(sections_count: layout["sections_count"], rows_count: layout["rows_count"],
        rotation: @carousel.rotation || rotation)
    end

    def place_figure(seat, proposal)
      rows_spanned = proposal[:rows_spanned].to_i
      seat.update!(confidence: "best_reading", **(rows_spanned > 1 ? { rows_spanned: } : {}))

      type = figure_type_for(proposal)
      mount = proposal[:mount] if Figure::MOUNTS.include?(proposal[:mount])
      figure = Figure.create!(name: next_name(type), figure_type: type, carousel: @carousel,
        mount:, description: proposal[:description].to_s.strip.presence, body: youtube_source_notes)
      SeatAssignment.new(seat, figure).save!
    end

    def youtube_source_notes
      return unless @analysis.youtube?

      "## Video analysis source\n\n[YouTube video](#{@analysis.youtube_playback_url}), " \
        "#{@analysis.youtube_start_seconds}s to #{@analysis.youtube_start_seconds + @analysis.youtube_duration_seconds}s. " \
        "Provisional identification from video analysis, reviewed by an editor."
    end

    def figure_type_for(proposal)
      name = proposal[:figure_type].to_s.strip.upcase_first
      FigureType.where("LOWER(name) = ?", name.downcase).first ||
        FigureType.create!(name:, category: FigureType::CATEGORIES.include?(proposal[:category]) ? proposal[:category] : "menagerie")
    end

    # Unnamed figures are numbered by type, like the hand-built charts: Horse 1, Horse 2.
    def next_name(type)
      pattern = /\A#{Regexp.escape(type.name)}(?: (\d+))?\z/i
      taken = @carousel.figures.pluck(:name).filter_map { |name| pattern.match(name)&.then { |match| match[1].to_i.nonzero? || 1 } }
      "#{type.name} #{(taken.max || 0) + 1}"
    end
end
