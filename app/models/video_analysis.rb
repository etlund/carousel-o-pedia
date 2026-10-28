# A video of a carousel that a trusted user uploads, and the draft seating layout
# read from it. The draft stays separate from the carousel's data until someone
# reviews it and applies the seats they agree with.
require "uri"

class VideoAnalysis < ApplicationRecord
  STATUSES = %w[ queued processing complete failed ].freeze
  # Each clip is a little over one revolution filmed from a different spot.
  PASSES = {
    "side_video" => "Side pass: at the rail, pointed straight in at the center pole",
    "oncoming_video" => "Oncoming pass: at the rail, angled about 45° toward figures coming at you",
    "inner_video" => "Inner pass: on the platform, pointed outward from the inner row"
  }.freeze
  VIDEO_TYPES = %w[ video/mp4 video/quicktime video/webm video/x-m4v ].freeze
  MAX_VIDEO_SIZE = 1.gigabyte
  MAX_YOUTUBE_DURATION = 300

  belongs_to :carousel
  belongs_to :user
  PASSES.each_key { |pass| has_one_attached pass }

  validates :status, inclusion: { in: STATUSES }
  before_validation :normalize_youtube_url
  validates :youtube_start_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, if: :youtube?
  validates :youtube_duration_seconds, numericality: { only_integer: true, in: 1..MAX_YOUTUBE_DURATION }, if: :youtube?
  validate :youtube_url_is_a_video
  validate :at_least_one_video, on: :create
  validate :videos_are_videos, on: :create

  scope :recent_first, -> { order(created_at: :desc) }

  STATUSES.each { |name| define_method(:"#{name}?") { status == name } }

  def finished? = complete? || failed?

  def applied? = applied_at.present?

  def youtube? = youtube_url.present?

  def retryable? = failed? && (youtube? || attached_passes.any?)

  def youtube_playback_url = "#{youtube_url}&t=#{youtube_start_seconds}"

  def self.canonical_youtube_url(value)
    uri = URI.parse(value.to_s.strip)
    return unless %w[ http https ].include?(uri.scheme) && uri.userinfo.nil?
    return unless uri.port == uri.default_port

    video_id = case uri.host&.downcase
    when "youtube.com", "www.youtube.com", "m.youtube.com"
      if uri.path == "/watch"
        ids = URI.decode_www_form(uri.query.to_s).select { |key, _| key == "v" }.map(&:last)
        ids.sole if ids.one?
      else
        uri.path.match(%r{\A/(?:shorts|live|embed)/([A-Za-z0-9_-]{11})/?\z})&.captures&.first
      end
    when "youtu.be"
      uri.path.match(%r{\A/([A-Za-z0-9_-]{11})/?\z})&.captures&.first
    end
    "https://www.youtube.com/watch?v=#{video_id}" if video_id&.match?(/\A[A-Za-z0-9_-]{11}\z/)
  rescue URI::InvalidURIError, ArgumentError
    nil
  end

  def attached_passes = PASSES.keys.select { |pass| public_send(pass).attached? }

  def proposed_seats = draft.fetch("seats", [])

  def proposed_layout = draft.slice("sections_count", "rows_count", "rotation", "lead_figure")

  # The draft's layout can go on the carousel only if the carousel has none yet or it matches.
  def layout_conflict?
    return false unless carousel.layout_known? && draft.present?

    carousel.sections_count != draft["sections_count"] || carousel.rows_count != draft["rows_count"]
  end

  def purge_videos
    attached_passes.each { |pass| public_send(pass).purge_later }
  end

  private
    def at_least_one_video
      errors.add(:base, "Add at least one video clip or a YouTube link") if attached_passes.empty? && !youtube?
      errors.add(:base, "Use either uploaded clips or a YouTube link, not both") if attached_passes.any? && youtube?
    end

    def normalize_youtube_url
      self.youtube_url = self.class.canonical_youtube_url(youtube_url) || youtube_url.to_s.strip.presence
    end

    def youtube_url_is_a_video
      if youtube? && self.class.canonical_youtube_url(youtube_url).nil?
        errors.add(:youtube_url, "must link to a single YouTube video")
      end
    end

    def videos_are_videos
      attached_passes.each do |pass|
        blob = public_send(pass).blob
        errors.add(pass, "must be an MP4, MOV, or WebM video") unless VIDEO_TYPES.include?(blob.content_type)
        errors.add(pass, "must be smaller than #{MAX_VIDEO_SIZE / 1.gigabyte} GB") if blob.byte_size > MAX_VIDEO_SIZE
      end
    end
end
