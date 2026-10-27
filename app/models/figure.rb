class Figure < ApplicationRecord
  include Sluggable
  has_paper_trail

  MOUNTS = %w[ jumper stander spinning fixed ].freeze

  belongs_to :figure_type
  belongs_to :carousel, touch: true
  belongs_to :carver, class_name: "Maker", optional: true
  has_many :placements, -> { order(started_on: :desc) }, dependent: :destroy
  has_one :current_placement, -> { where(ended_on: nil) }, class_name: "Placement", inverse_of: :figure
  has_one :seat, through: :current_placement

  validates :name, presence: true
  blank_as_nil :mount, :short_name, :sponsor, :description, :body

  validates :mount, inclusion: { in: MOUNTS }, allow_nil: true
  validate :carousel_matches_current_seat, if: :will_save_change_to_carousel_id?

  delegate :category, to: :figure_type

  def chart_label = short_name.presence || name

  private
    def carousel_matches_current_seat
      return unless persisted?

      seated_carousel_id = Placement.current.joins(:seat).where(figure_id: id).pick("seats.carousel_id")
      if seated_carousel_id && seated_carousel_id != carousel_id
        errors.add(:carousel, "must match the current seat; remove the figure from its seat before changing its carousel")
      end
    end
end
