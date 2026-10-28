require "open3"

# Reads a draft seating layout from carousel video. ffmpeg pulls still frames from each
# clip, and Claude reads the frames to count sections and rows and describe each figure.
# The result is only a draft: VideoAnalysisDraft applies the seats a reviewer accepts.
class CarouselVideoAnalyzer
  class Error < StandardError; end

  MODEL = ENV.fetch("VIDEO_ANALYSIS_MODEL", "claude-opus-5-5")
  # Each sample is a pair of frames a moment apart, so a jumper's rise or fall shows up.
  SAMPLES_PER_CLIP = 36
  MIN_SECONDS_BETWEEN_SAMPLES = 1.0
  PAIR_GAP = 0.33
  FRAME_WIDTH = 1024
  MAX_TOKENS = 64_000
  FALLBACK_BETA = "server-side-fallback-2026-07-01"

  SEAT_SCHEMA = {
    type: "object",
    additionalProperties: false,
    required: %w[ section row rows_spanned state figure_type category mount description confidence evidence ],
    properties: {
      section: { type: "integer", description: "Section number, counting from the lead figure's section as 1 in the order figures pass a fixed viewer" },
      row: { type: "string", enum: ("A".."F").to_a, description: "A is the outer row, then B, C inward" },
      rows_spanned: { type: "integer", description: "1 for a single figure; more for a tub or chariot that fills several rows, counted inward from row" },
      state: { type: "string", enum: %w[ filled empty unknown ], description: "empty when the spot is visibly bare; unknown when it was never clearly seen" },
      figure_type: { type: "string", description: "Animal or object, e.g. Horse, Mountain goat, Tea-cup. Reuse a listed existing type name when it fits. Blank unless filled" },
      category: { type: "string", enum: %w[ horse menagerie chariot ], description: "horse; menagerie for any other animal; chariot for chariots, benches, tubs and tea-cups" },
      mount: { type: "string", enum: %w[ jumper stander spinning fixed unknown ], description: "jumper moves up and down on its pole; stander stays still with hooves on the platform; spinning for tubs; fixed for chariots" },
      description: { type: "string", description: "Short visual description: colors, trappings, carved details, pose" },
      confidence: { type: "string", enum: %w[ high medium low ] },
      evidence: { type: "string", description: "Which clip and frame times show this seat" }
    }
  }.freeze

  SCHEMA = {
    type: "object",
    additionalProperties: false,
    required: %w[ sections_count rows_count rotation lead_figure seats notes ],
    properties: {
      sections_count: { type: "integer", description: "Number of sections (radial slices) around the platform" },
      rows_count: { type: "integer", description: "Number of rows from the outer edge inward" },
      rotation: { type: "string", enum: %w[ clockwise counterclockwise unknown ], description: "Seen from above" },
      lead_figure: { type: "string", description: "The figure numbered 1A and why it was chosen" },
      seats: { type: "array", items: SEAT_SCHEMA, description: "One entry per seat, every section and row" },
      notes: { type: "string", description: "What was uncertain and what footage would settle it" }
    }
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You catalog carousels for carousel-o-pedia, a wiki of carousels and their figures.
    You will see still frames, in time order, from one or more video clips of a single
    carousel. Each clip is a little over one revolution, filmed from a different spot.

    Work out the platform layout and every figure on it:
    - Sections are the radial slices of the platform, each holding one figure per row
      (a tub or chariot can fill several rows of one section). Rows are lettered from the
      outside in: A is the outer row.
    - Section 1 holds the lead figure in row A. Number the other sections in the order
      their figures pass a fixed viewer after the lead figure, so section 2 follows it.
    - Track figures across frames so each physical figure is counted once. A clip ends
      back where it started, so use the repeat of the first figures to close the loop.
    - Tell rows apart by depth, not by left-right position in one frame: inner-row
      figures sit nearer the center pole, look smaller, and pass behind the rows outside
      them. Keep each section's rows in that inward order.
    - A tub, tea-cup or chariot bench often fills two or all rows of its section. Set
      rows_spanned by checking whether a figure ever appears behind it in its own section;
      a spot behind it where no figure is ever seen is probably covered by it.
    - Identify each figure's animal or object. Horses are horses; any other animal is
      menagerie; chariots, benches, tubs and tea-cups are chariot. Painted patterns
      mislead: a horse-shaped body with spots, stripes or patches is usually a painted
      horse. Name another animal only when its head, horns, ears or body shape show it.
    - Decide stander or jumper from motion. Frames come in pairs about a third of a
      second apart. The camera may shake, so judge each figure against things on the
      ride in the same frame, never against the frame edges:
      - Look first at the top of each figure's pole, where it meets the overhead
        machinery. A jumper's pole hangs from a crank that turns as the ride goes, so
        its top moves up and down against the canopy and rounding boards. A stander's
        pole top stays fixed in its bracket.
      - Then compare the figure's height against the platform edge and its neighbours
        within each pair and across pairs: a jumper's height changes, a stander's does
        not, and a stander usually has three or four hooves planted.
      Use unknown when the ride was still or you could not compare a figure in two frames.
    - Describe what you can see. Never guess names; describe colors and carving instead.

    Be honest about uncertainty. Mark confidence low, or the seat unknown, rather than
    inventing a figure you did not clearly see. Include every seat of every section.
  PROMPT

  def initialize(analysis, client: nil, frame_extractor: nil)
    @analysis = analysis
    @client = client
    @frame_extractor = frame_extractor || method(:extract_frames)
  end

  # Returns the draft hash and token usage.
  def call
    clips = @analysis.attached_passes.map { |pass| [ pass, frames_for(pass) ] }
    frames_count = clips.sum { |_, frames| frames.size }
    raise Error, "No frames could be read from the video" if frames_count.zero?

    message = client.beta.messages.stream(
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system_: SYSTEM_PROMPT,
      thinking: { type: "adaptive" },
      output_config: { effort: :high, format_: { type: :json_schema, schema: SCHEMA } },
      fallbacks: :default,
      betas: [ FALLBACK_BETA ],
      messages: [ { role: "user", content: content_for(clips) } ]
    ).accumulated_message

    raise Error, "The model declined to analyze this video" if message.stop_reason == :refusal
    raise Error, "The analysis was cut off before it finished" if message.stop_reason == :max_tokens

    text = message.content.select { |block| block.type == :text }.map(&:text).join
    { draft: JSON.parse(text), frames_count:, model: message.model.to_s,
      input_tokens: message.usage.input_tokens, output_tokens: message.usage.output_tokens }
  rescue JSON::ParserError
    raise Error, "The analysis came back in an unexpected format"
  end

  private
    def client
      @client ||= Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"].presence || raise(Error, "Video analysis isn't set up yet: ANTHROPIC_API_KEY is missing"))
    end

    def frames_for(pass)
      @analysis.public_send(pass).blob.open { |file| @frame_extractor.call(file.path) }
    end

    def content_for(clips)
      blocks = [ { type: "text", text: carousel_context } ]
      clips.each do |pass, frames|
        blocks << { type: "text", text: "Clip: #{VideoAnalysis::PASSES.fetch(pass)}. #{frames.size} frames follow, in pairs #{PAIR_GAP}s apart." }
        frames.each do |seconds, jpeg|
          blocks << { type: "text", text: "#{pass.delete_suffix("_video")} clip, #{seconds.round(1)}s" }
          blocks << { type: "image", source: { type: "base64", media_type: "image/jpeg", data: Base64.strict_encode64(jpeg) } }
        end
      end
      blocks << { type: "text", text: "Return the layout and every seat as JSON matching the schema." }
    end

    def carousel_context
      carousel = @analysis.carousel
      lines = [ "Carousel: #{carousel.name}#{" in #{carousel.location}" if carousel.location.present?}." ]
      if carousel.layout_known?
        lines << "Editors have recorded #{carousel.sections_count} sections and #{carousel.rows_count} rows. Check this against the video and say so in notes if it disagrees."
      end
      lines << "Editors have recorded the rotation as #{carousel.rotation}." if carousel.rotation
      if (lead = carousel.lead_figure)
        lines << "The lead figure (1A) is #{lead.name}: #{lead.description}. Number sections from it."
      else
        lines << "No lead figure is recorded. Choose the most distinctive outer-row figure, or one marked as the lead, and say which in lead_figure."
      end
      lines << "Existing figure type names to reuse when they fit: #{FigureType.order(:name).pluck(:name).join(", ")}."
      lines.join("\n")
    end

    # Evenly spaced pairs of JPEG stills as [seconds, bytes], in time order.
    def extract_frames(path)
      duration = probe_duration(path)
      interval = [ duration / SAMPLES_PER_CLIP, MIN_SECONDS_BETWEEN_SAMPLES ].max
      [ 0, PAIR_GAP ].flat_map { |offset| frames_from(path, offset:, interval:) }.sort_by(&:first)
    end

    def frames_from(path, offset:, interval:)
      Dir.mktmpdir("carousel-frames") do |dir|
        run "ffmpeg", "-nostdin", "-loglevel", "error", "-ss", offset.to_s, "-i", path,
          "-vf", "fps=1/#{interval.round(3)},scale=min(#{FRAME_WIDTH}\\,iw):-2", "-frames:v", SAMPLES_PER_CLIP.to_s,
          "-q:v", "4", File.join(dir, "frame-%03d.jpg")
        Dir[File.join(dir, "frame-*.jpg")].sort.each_with_index.map { |file, index| [ offset + index * interval, File.binread(file) ] }
      end
    end

    def probe_duration(path)
      output = run "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path
      Float(output.strip).tap { |seconds| raise Error, "The video has no length" unless seconds.positive? }
    rescue ArgumentError
      raise Error, "The video's length could not be read"
    end

    def run(*command)
      output, status = Open3.capture2e(*command)
      raise Error, "Could not read the video (#{command.first} failed)" unless status.success?
      output
    rescue Errno::ENOENT
      raise Error, "#{command.first} is not installed on the server"
    end
end
