module VideoAnalysesHelper
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
