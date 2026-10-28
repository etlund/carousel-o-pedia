# A video of a carousel that a trusted user uploads, and the draft seating layout
# read from it. The draft stays separate from the carousel's data until someone
# reviews it and applies the seats they agree with.
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

  belongs_to :carousel
  belongs_to :user
  PASSES.each_key { |pass| has_one_attached pass }

  validates :status, inclusion: { in: STATUSES }
  validate :at_least_one_video, on: :create
  validate :videos_are_videos, on: :create

  scope :recent_first, -> { order(created_at: :desc) }

  STATUSES.each { |name| define_method(:"#{name}?") { status == name } }

  def finished? = complete? || failed?

  def applied? = applied_at.present?

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
      errors.add(:base, "Add at least one video clip") if attached_passes.empty?
    end

    def videos_are_videos
      attached_passes.each do |pass|
        blob = public_send(pass).blob
        errors.add(pass, "must be an MP4, MOV, or WebM video") unless VIDEO_TYPES.include?(blob.content_type)
        errors.add(pass, "must be smaller than #{MAX_VIDEO_SIZE / 1.gigabyte} GB") if blob.byte_size > MAX_VIDEO_SIZE
      end
    end
end
