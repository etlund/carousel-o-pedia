require "test_helper"

class VideoAnalysisTest < ActiveSupport::TestCase
  setup do
    @analysis = VideoAnalysis.new(carousel: build_carousel, user: users(:admin),
      youtube_url: "https://youtu.be/Usok6GXGavc?t=12")
  end

  test "a YouTube source needs no upload and defaults to a sixty second clip starting at zero" do
    assert @analysis.valid?, @analysis.errors.full_messages.to_sentence
    assert_equal "https://www.youtube.com/watch?v=Usok6GXGavc", @analysis.youtube_url
    assert_equal [ 0, 60 ], [ @analysis.youtube_start_seconds, @analysis.youtube_duration_seconds ]
    assert_empty @analysis.attached_passes
  end

  test "accepts only canonicalizable single-video YouTube links" do
    %w[
      https://www.youtube.com/watch?v=Usok6GXGavc&list=anything
      http://youtube.com/watch?v=Usok6GXGavc
      https://m.youtube.com/watch?v=Usok6GXGavc
      https://youtu.be/Usok6GXGavc
      https://www.youtube.com/shorts/Usok6GXGavc
      https://www.youtube.com/live/Usok6GXGavc
      https://www.youtube.com/embed/Usok6GXGavc
    ].each do |url|
      assert_equal "https://www.youtube.com/watch?v=Usok6GXGavc", VideoAnalysis.canonical_youtube_url(url), url
    end

    %w[
      https://youtube.com.evil.example/watch?v=Usok6GXGavc
      https://youtube.com@127.0.0.1/watch?v=Usok6GXGavc
      https://user:password@www.youtube.com/watch?v=Usok6GXGavc
      https://www.youtube.com:8443/watch?v=Usok6GXGavc
      http://127.0.0.1/watch?v=Usok6GXGavc
      file:///etc/passwd
      https://www.youtube.com/playlist?list=anything
      https://www.youtube.com/watch?v=short
      https://www.youtube.com/watch?v=Usok6GXGavc&v=aaaaaaaaaaa
      https://youtu.be/Usok6GXGavc/another-path
      --exec=anything
    ].each do |url|
      @analysis.youtube_url = url
      assert_not @analysis.valid?, url
      assert @analysis.errors.of_kind?(:youtube_url, "must link to a single YouTube video"), url
    end
  end

  test "requires integer clip times and enforces the actual one to three hundred second bounds" do
    [ nil, "", "1.5", "oops", -1 ].each do |start|
      @analysis.youtube_start_seconds = start
      assert_not @analysis.valid?, start.inspect
      assert @analysis.errors[:youtube_start_seconds].any?
    end
    @analysis.youtube_start_seconds = 42

    [ nil, "", "1.5", "oops", 0, -1, 301 ].each do |duration|
      @analysis.youtube_duration_seconds = duration
      assert_not @analysis.valid?, duration.inspect
      assert @analysis.errors[:youtube_duration_seconds].any?
    end
    [ 1, 60, 300 ].each do |duration|
      @analysis.youtube_duration_seconds = duration
      assert @analysis.valid?, @analysis.errors.full_messages.to_sentence
    end
  end

  test "does not mix links and uploads and preserves the upload-only flow with unused times blank" do
    @analysis.side_video.attach(video_upload)
    assert_not @analysis.valid?
    assert_includes @analysis.errors[:base], "Use either uploaded clips or a YouTube link, not both"

    @analysis.youtube_url = ""
    @analysis.youtube_start_seconds = nil
    @analysis.youtube_duration_seconds = nil
    assert @analysis.save!, @analysis.errors.full_messages.to_sentence
  end
end
