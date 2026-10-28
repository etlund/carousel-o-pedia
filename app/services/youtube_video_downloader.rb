require "open3"
require "timeout"
require "tmpdir"

class YoutubeVideoDownloader
  class Error < StandardError; end

  COMMAND_TIMEOUT = 180

  def initialize(analysis, command_runner: nil, command_timeout: COMMAND_TIMEOUT)
    @analysis = analysis
    @command_runner = command_runner || method(:run)
    @command_timeout = command_timeout
  end

  def call
    url = VideoAnalysis.canonical_youtube_url(@analysis.youtube_url)
    start = @analysis.youtube_start_seconds
    duration = @analysis.youtube_duration_seconds
    unless url && start.is_a?(Integer) && start >= 0 &&
        duration.is_a?(Integer) && (1..VideoAnalysis::MAX_YOUTUBE_DURATION).cover?(duration)
      raise Error, "The YouTube link or clip times are invalid"
    end

    metadata = JSON.parse(@command_runner.call(*base_command, "--skip-download", "--dump-single-json", url))
    raise Error, "YouTube returned unreadable video information" unless metadata.is_a?(Hash)
    if metadata["is_live"] || metadata["live_status"] == "is_upcoming"
      raise Error, "Use a finished YouTube video, not a live stream or an upcoming premiere"
    end
    length = metadata["duration"]
    raise Error, "The YouTube video's length could not be read" unless length.is_a?(Numeric) && length.positive?
    raise Error, "The selected clip extends past the end of this #{length.round} second video" if start + duration > length

    Dir.mktmpdir("carousel-youtube") do |dir|
      @command_runner.call(*base_command,
        "--format", "bv[ext=mp4][height<=1080]/b[ext=mp4][height<=1080]",
        "--download-sections", "*#{start}-#{start + duration}", "--force-keyframes-at-cuts",
        "--max-filesize", VideoAnalysis::MAX_VIDEO_SIZE.to_s,
        "--output", File.join(dir, "clip.%(ext)s"), url)
      path = File.join(dir, "clip.mp4")
      unless File.file?(path) && File.size(path).positive? && File.size(path) <= VideoAnalysis::MAX_VIDEO_SIZE
        raise Error, "YouTube did not provide a usable clip within the video size limit"
      end

      File.open(path, "rb") do |file|
        @analysis.side_video.attach(io: file, filename: "youtube-#{start}-#{start + duration}.mp4", content_type: "video/mp4")
      end
      raise Error, "The downloaded clip could not be stored: #{@analysis.errors.full_messages.to_sentence}" unless @analysis.side_video.attached?
    end
  rescue JSON::ParserError
    raise Error, "YouTube returned unreadable video information"
  end

  private
    def base_command
      local_binary = Rails.root.join(".venv-video/bin/yt-dlp")
      [ File.executable?(local_binary) ? local_binary.to_s : "yt-dlp",
        "--ignore-config", "--no-playlist", "--no-cache-dir", "--no-progress", "--no-color",
        "--js-runtimes", "node", "--socket-timeout", "20", "--retries", "1", "--fragment-retries", "1" ]
    end

    def run(*command)
      Open3.popen2e(*command, pgroup: true, rlimit_fsize: VideoAnalysis::MAX_VIDEO_SIZE) do |input, output, process|
        input.close
        begin
          Timeout.timeout(@command_timeout) do
            text = output.read
            unless process.value.success?
              reason = text.lines.last(4).join.strip.truncate(350)
              raise Error, "YouTube retrieval failed: #{reason.presence || "the downloader exited unsuccessfully"}. Try uploading the clip instead."
            end
            text
          end
        rescue Timeout::Error
          terminate(process)
          raise Error, "YouTube retrieval timed out. Try a shorter clip or upload it instead."
        end
      end
    rescue Errno::ENOENT
      raise Error, "yt-dlp is not installed on the server; see the video analysis deployment instructions"
    end

    def terminate(process)
      Process.kill("TERM", -process.pid)
      process.join(5)
      Process.kill("KILL", -process.pid)
      process.join
    rescue Errno::ESRCH
      process.join
    end
end
