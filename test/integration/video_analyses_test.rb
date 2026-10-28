require "test_helper"

class VideoAnalysesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @carousel = build_carousel(sections: 2, rows: 2)
    @editor = users(:editor)
  end

  test "editors need an admin's permission to analyze video" do
    get new_carousel_video_analysis_path(@carousel)
    assert_redirected_to new_session_path

    sign_in_as @editor
    get carousel_path(@carousel)
    assert_select "a", text: "Analyze a video", count: 0
    get new_carousel_video_analysis_path(@carousel)
    assert_redirected_to root_path

    sign_in_as users(:admin)
    get invitations_path
    assert_select "button", text: "Allow video analysis for Ed Editor"
    post editor_video_analysis_access_path(@editor)
    assert @editor.reload.can_analyze_videos?

    sign_in_as @editor
    get carousel_path(@carousel)
    assert_select "a[href=?]", new_carousel_video_analysis_path(@carousel), text: "Analyze a video"
    get new_carousel_video_analysis_path(@carousel)
    assert_response :success
    assert_select "h2", text: "How to film it"

    sign_in_as users(:admin)
    delete editor_video_analysis_access_path(@editor)
    assert_not @editor.reload.can_analyze_videos?
  end

  test "allowed editors still only analyze carousels they can edit" do
    other = build_carousel
    @editor.update!(can_analyze_videos: true, access_scope: "carousel", editable_carousel: @carousel)
    sign_in_as @editor

    get new_carousel_video_analysis_path(other)
    assert_redirected_to root_path
    get new_carousel_video_analysis_path(@carousel)
    assert_response :success
  end

  test "uploading queues an analysis, and the reviewed draft is applied to the carousel" do
    sign_in_as users(:admin)

    post carousel_video_analyses_path(@carousel), params: { video_analysis: { side_video: video_upload } }
    analysis = @carousel.video_analyses.sole
    assert_enqueued_with(job: VideoAnalysisJob, args: [ analysis ])
    assert_redirected_to carousel_video_analysis_path(@carousel, analysis)
    follow_redirect!
    assert_select "meta[http-equiv=refresh]"

    analysis.update!(status: "complete", draft: sample_draft, frames_count: 40, estimated_cost_usd: 1.23456789)
    get carousel_video_analysis_path(@carousel, analysis)
    assert_select "td", text: "Inner row partly hidden", count: 0
    assert_select "p", text: "Inner row partly hidden"
    assert_select "input[type=checkbox][name='seats[0][include]'][checked]"
    assert_select "dt", text: "Estimated cost"
    assert_select "dd", text: "$1.2346"

    seats = analysis.proposed_seats.each_with_index.to_h do |seat, index|
      [ index.to_s, { code: "#{seat["section"]}#{seat["row"]}", include: "1", state: "filled", figure_type: "Horse",
        category: "horse", mount: "jumper", description: seat["description"], rows_spanned: "1" } ]
    end
    post apply_carousel_video_analysis_path(@carousel, analysis), params: { seats: }
    assert_redirected_to carousel_path(@carousel)
    assert_equal 4, @carousel.figures.count
    assert_equal users(:admin).id.to_s, @carousel.seat("1A").versions.last.whodunnit
  end

  test "an upload needs a video file" do
    sign_in_as users(:admin)

    assert_no_difference "VideoAnalysis.count" do
      post carousel_video_analyses_path(@carousel), params: { video_analysis: { side_video: Rack::Test::UploadedFile.new(StringIO.new("hi"), "text/plain", original_filename: "notes.txt") } }
    end
    assert_response :unprocessable_entity
    assert_select ".flash.alert", /MP4, MOV, or WebM/

    post carousel_video_analyses_path(@carousel), params: { video_analysis: {} }
    assert_response :unprocessable_entity
    assert_select ".flash.alert", /at least one video clip/
  end

  test "a failed analysis shows why and can be retried" do
    sign_in_as users(:admin)
    analysis = create_analysis(@carousel, status: "failed", error_message: "Video analysis isn't set up yet")

    get carousel_video_analysis_path(@carousel, analysis)
    assert_select ".flash.alert", /isn't set up yet/
    post retry_carousel_video_analysis_path(@carousel, analysis)
    assert analysis.reload.queued?
    assert_enqueued_with(job: VideoAnalysisJob, args: [ analysis ])
  end

  test "the list names each analysis by its exact upload time, and an analysis can be deleted" do
    sign_in_as users(:admin)
    analysis = create_analysis(@carousel, status: "complete", draft: sample_draft, created_at: Time.utc(2026, 10, 28, 17, 10, 41))

    get carousel_video_analyses_path(@carousel)
    assert_select "a[href=?] time[datetime=?]", carousel_video_analysis_path(@carousel, analysis), "2026-10-28T17:10:41Z",
      text: "October 28, 2026 at 5:10:41 PM UTC"

    assert_difference "VideoAnalysis.count", -1 do
      delete carousel_video_analysis_path(@carousel, analysis)
    end
    assert_redirected_to carousel_video_analyses_path(@carousel)
  end

  test "an analysis still running cannot be deleted" do
    sign_in_as users(:admin)
    analysis = create_analysis(@carousel, status: "processing")

    get carousel_video_analysis_path(@carousel, analysis)
    assert_select "button", text: "Delete", count: 0
    assert_no_difference "VideoAnalysis.count" do
      delete carousel_video_analysis_path(@carousel, analysis)
    end
  end
end
