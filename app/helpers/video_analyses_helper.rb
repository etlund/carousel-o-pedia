module VideoAnalysesHelper
  def video_analysis_source(analysis)
    return "Uploaded clips" unless analysis.youtube?

    link_to "YouTube: #{analysis.youtube_start_seconds}s–#{analysis.youtube_start_seconds + analysis.youtube_duration_seconds}s",
      analysis.youtube_playback_url
  end

  def video_analysis_timestamp(analysis)
    tag.time analysis.created_at.strftime("%B %-d, %Y at %-l:%M:%S %p %Z"), datetime: analysis.created_at.iso8601
  end

  def video_analysis_delete_button(analysis)
    return if analysis.processing?

    button_to "Delete", carousel_video_analysis_path(analysis.carousel, analysis), method: :delete, class: "link-button",
      form: { data: { turbo_confirm: "Delete this video analysis? Anything already applied to the carousel stays." } },
      aria: { label: "Delete the analysis from #{analysis.created_at.strftime("%B %-d, %Y at %-l:%M:%S %p")}" }
  end

  def video_analysis_status(analysis)
    case analysis.status
    when "queued" then "Waiting to start"
    when "processing" then "Analyzing"
    when "failed" then "Failed"
    else analysis.applied? ? "Applied #{analysis.applied_at.to_date.to_fs(:long)}" : "Draft ready to review"
    end
  end

  # Seats the reviewer is likely to accept start ticked; doubtful ones start unticked.
  def video_analysis_seat_checked?(proposal, seat, carousel)
    return false if proposal["state"] == "unknown" || proposal["confidence"] == "low"

    !carousel.layout_known? || (seat.present? && seat.figure.nil? && seat.state == "unknown")
  end

  def video_analysis_current_seat(seat)
    if seat.nil? then "Not on the chart"
    elsif seat.figure then seat.figure.name
    else seat.state.capitalize
    end
  end
end
