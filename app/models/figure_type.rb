class FigureType < ApplicationRecord
  include Sluggable
  has_paper_trail

  # The category decides a figure's colour on the seat chart and which count it adds to.
  CATEGORIES = %w[ horse menagerie chariot ].freeze
  CATEGORY_LABELS = { "horse" => "Horses", "menagerie" => "Other animals", "chariot" => "Chariots and tubs" }.freeze

  has_many :figures, dependent: :restrict_with_error

  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }
end
