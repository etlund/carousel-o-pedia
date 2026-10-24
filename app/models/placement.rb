# Which figure sits in which seat, and when. A blank ended_on means it is there now.
class Placement < ApplicationRecord
  has_paper_trail

  belongs_to :figure
  belongs_to :seat

  scope :current, -> { where(ended_on: nil) }

  validates :figure_id, uniqueness: { conditions: -> { current } }, if: -> { ended_on.nil? }
  validates :seat_id, uniqueness: { conditions: -> { current } }, if: -> { ended_on.nil? }
end
