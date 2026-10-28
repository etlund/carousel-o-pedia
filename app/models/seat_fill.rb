require "digest"

class SeatFill
  include ActiveModel::Model
  include ActiveModel::Attributes
  include SeatingPreview

  class Conflict < StandardError; end

  attribute :figure_type_id, :string
  attribute :mount, :string
  attribute :source_notes, :string

  validates :figure_type, presence: { message: "must be an existing figure type" }
  validates :mount, inclusion: { in: Figure::MOUNTS }, allow_blank: true
  validates :source_notes, presence: true
  validate :layout_and_seats_available

  def initialize(carousel, attributes = {})
    @carousel = carousel
    super(attributes)
  end

  def figure_type
    FigureType.find_by(id: figure_type_id) if figure_type_id.to_s.match?(/\A[1-9]\d*\z/)
  end

  def seats = @seats ||= @carousel.seats.unknown.to_a

  def figure_name(seat) = "#{figure_type.name} #{seat.code}"

  def apply!(expected_snapshot:)
    @carousel.with_lock do
      @seats = @carousel.seats.unknown.lock.to_a
      unless snapshot == expected_snapshot
        raise Conflict, "The seats or figure type changed since your preview. Nothing was saved. Preview the unknown seats again."
      end
      validate!

      type = figure_type
      seats.each do |seat|
        DraftSeatAssignment.create!(seat, figure_type: type, mount:, source_notes:)
      end
    end
    seats.size
  end

  private
    def snapshot
      Digest::SHA256.hexdigest([
        @carousel.sections_count, @carousel.rows_count, figure_type&.cache_key_with_version,
        seats.map { [ _1.id, _1.updated_at.iso8601(6), _1.rows_spanned ] }
      ].to_json)
    end

    def layout_and_seats_available
      if !@carousel.layout_known?
        errors.add(:base, "Record the carousel's sections and rows before filling unknown seats.")
      elsif seats.empty?
        errors.add(:base, "There are no unknown seats to fill.")
      end
    end
end
