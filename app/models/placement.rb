# Which figure sits in which seat, and when. A blank ended_on means it is there now.
class Placement < ApplicationRecord
  has_paper_trail

  belongs_to :figure
  belongs_to :seat, touch: true

  scope :current, -> { where(ended_on: nil) }

  validates :figure_id, uniqueness: { conditions: -> { current } }, if: -> { ended_on.nil? }
  validates :seat_id, uniqueness: { conditions: -> { current } }, if: -> { ended_on.nil? }
  validate :figure_belongs_to_carousel, if: -> { ended_on.nil? }

  private
    def figure_belongs_to_carousel
      if figure && seat && figure.carousel_id != seat.carousel_id
        errors.add(:figure, "must belong to the seat's carousel")
      end
    end
end
