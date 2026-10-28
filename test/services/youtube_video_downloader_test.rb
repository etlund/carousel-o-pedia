require "test_helper"

class YoutubeVideoDownloaderTest < ActiveSupport::TestCase
  setup do
    @analysis = VideoAnalysis.create!(carousel: build_carousel, user: users(:admin),
      youtube_url: "https://youtu.be/Usok6GXGavc", youtube_start_seconds: 12, youtube_duration_seconds: 60)
    @commands = []
    @metadata = { duration: 360, is_live: false }.to_json
    @runner = lambda do |*command|
      @commands << command
      if command.include?("--dump-single-json")
        @metadata
      else
        @path = command[command.index("--output") + 1].sub("%(ext)s", "mp4")
        FileUtils.cp(file_fixture("carousel.mp4"), @path)
        ""
      end
    end
  end

  test "downloads just the requested range as an MP4 and attaches it before cleaning temporary files" do
    YoutubeVideoDownloader.new(@analysis, command_runner: @runner).call

    assert @analysis.reload.side_video.attached?
    assert_equal "video/mp4", @analysis.side_video.content_type
    assert_equal File.size(file_fixture("carousel.mp4")), @analysis.side_video.byte_size
    command = @commands.last
    assert_equal "*12-72", command[command.index("--download-sections") + 1]
    assert_equal "https://www.youtube.com/watch?v=Usok6GXGavc", command.last
    %w[ --ignore-config --no-playlist --force-keyframes-at-cuts --max-filesize ].each { assert_includes command, _1 }
    assert_equal "node", command[command.index("--js-runtimes") + 1]
    assert_not File.exist?(@path)
    assert_not Dir.exist?(File.dirname(@path))
    @analysis.side_video.blob.open { |file| assert_equal File.binread(file_fixture("carousel.mp4")), file.read }
  end

  test "rejects live videos, malformed metadata, unknown lengths, and out-of-bounds intervals before downloading" do
    [ { duration: 360, is_live: true }, { duration: nil }, { duration: 50 },
      { duration: 360, live_status: "is_upcoming" }, [], "not json" ].each do |metadata|
      @commands.clear
      @metadata = metadata.is_a?(String) ? metadata : metadata.to_json
      assert_raises(YoutubeVideoDownloader::Error) do
        YoutubeVideoDownloader.new(@analysis, command_runner: @runner).call
      end
      assert_equal 1, @commands.size
      assert_empty @analysis.attached_passes
    end
  end

  test "checks persisted source fields again before running any commands" do
    @analysis.youtube_url = "https://127.0.0.1/private"
    assert_raises(YoutubeVideoDownloader::Error) do
      YoutubeVideoDownloader.new(@analysis, command_runner: @runner).call
    end
    assert_empty @commands
  end

  test "cleans partially downloaded files on failure and keeps the URL for retry" do
    runner = lambda do |*command|
      result = @runner.call(*command)
      raise YoutubeVideoDownloader::Error, "Video is unavailable" if command.include?("--output")
      result
    end
    assert_raises(YoutubeVideoDownloader::Error) { YoutubeVideoDownloader.new(@analysis, command_runner: runner).call }
    assert_not Dir.exist?(File.dirname(@path))
    assert_empty @analysis.attached_passes
    assert @analysis.reload.youtube?
  end

  test "rejects oversized downloads before attaching them" do
    runner = lambda do |*command|
      result = @runner.call(*command)
      File.truncate(@path, VideoAnalysis::MAX_VIDEO_SIZE + 1) if command.include?("--output")
      result
    end
    error = assert_raises(YoutubeVideoDownloader::Error) { YoutubeVideoDownloader.new(@analysis, command_runner: runner).call }
    assert_match "size limit", error.message
    assert_empty @analysis.attached_passes
    assert_not Dir.exist?(File.dirname(@path))
  end

  test "rejects a successful command that produced no clip" do
    runner = ->(*command) { command.include?("--dump-single-json") ? @metadata : "" }
    error = assert_raises(YoutubeVideoDownloader::Error) { YoutubeVideoDownloader.new(@analysis, command_runner: runner).call }
    assert_match "usable clip", error.message
    assert_empty @analysis.attached_passes
  end

  test "timeout kills downloader children even when the parent exits first" do
    Dir.mktmpdir("youtube-timeout-test") do |dir|
      pid_file = File.join(dir, "child.pid")
      script = 'fork { trap("TERM", "IGNORE"); File.write(ARGV[0], Process.pid); sleep 30 }; sleep 30'
      error = assert_raises(YoutubeVideoDownloader::Error) do
        YoutubeVideoDownloader.new(@analysis, command_timeout: 2).send(:run, RbConfig.ruby, "-e", script, pid_file)
      end
      assert_match "timed out", error.message
      pid = Integer(File.read(pid_file))
      state, status = Open3.capture2e("ps", "-o", "stat=", "-p", pid.to_s)
      assert !status.success? || state.strip.start_with?("Z"), "Downloader child #{pid} is still running"
    end
  end

  test "reports missing binaries, nonzero exits, and timeouts explicitly" do
    downloader = YoutubeVideoDownloader.new(@analysis)
    error = assert_raises(YoutubeVideoDownloader::Error) { downloader.send(:run, "/not-installed/yt-dlp") }
    assert_match "not installed", error.message

    error = assert_raises(YoutubeVideoDownloader::Error) do
      downloader.send(:run, RbConfig.ruby, "-e", 'warn "Video unavailable"; exit 1')
    end
    assert_match "Video unavailable", error.message

    error = assert_raises(YoutubeVideoDownloader::Error) do
      YoutubeVideoDownloader.new(@analysis, command_timeout: 0.1).send(:run, RbConfig.ruby, "-e", "sleep 30")
    end
    assert_match "timed out", error.message
  end
end
