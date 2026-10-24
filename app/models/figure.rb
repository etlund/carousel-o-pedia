class Figure < ApplicationRecord
  include Sluggable
  has_paper_trail

  MOUNTS = %w[ jumper stander spinning fixed ].freeze

  belongs_to :figure_type
  belongs_to :carver, class_name: "Maker", optional: true
  has_many :placements, -> { order(started_on: :desc) }, dependent: :destroy
  has_one :current_placement, -> { where(ended_on: nil) }, class_name: "Placement", inverse_of: :figure
  has_one :seat, through: :current_placement
  has_one :carousel, through: :seat

  validates :name, presence: true
  validates :mount, inclusion: { in: MOUNTS }, allow_nil: true

  delegate :category, to: :figure_type

  def chart_label = short_name.presence || name
end
