module VideoAnalysisTestHelper
  def sample_draft(sections: 2, rows: 2)
    seats = (1..sections).flat_map do |section|
      ("A"..).first(rows).map do |row|
        { "section" => section, "row" => row, "rows_spanned" => 1, "state" => "filled",
          "figure_type" => "Horse", "category" => "horse", "mount" => "jumper",
          "description" => "Horse at #{section}#{row}", "confidence" => "high", "evidence" => "side clip, 3s" }
      end
    end
    { "sections_count" => sections, "rows_count" => rows, "rotation" => "counterclockwise",
      "lead_figure" => "White horse with a red saddle", "seats" => seats, "notes" => "Inner row partly hidden" }
  end

  def video_upload
    Rack::Test::UploadedFile.new(file_fixture("carousel.mp4"), "video/mp4")
  end

  def create_analysis(carousel, user: users(:admin), **attributes)
    VideoAnalysis.create!(carousel:, user:, side_video: video_upload, **attributes)
  end

  # Stands in for the Anthropic client: returns one canned message from beta.messages.stream.
  class FakeClaude
    Usage = Struct.new(:input_tokens, :output_tokens)
    Block = Struct.new(:type, :text)
    Message = Struct.new(:content, :stop_reason, :model, :usage)

    attr_reader :requests

    def initialize(text, stop_reason: :end_turn)
      @message = Message.new([ Block.new(:text, text) ], stop_reason, :"claude-opus-5-5", Usage.new(1200, 800))
      @requests = []
    end

    def beta = self
    def messages = self

    def stream(**params)
      @requests << params
      Struct.new(:accumulated_message).new(@message)
    end
  end
end
