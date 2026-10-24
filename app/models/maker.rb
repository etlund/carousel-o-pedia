class Maker < ApplicationRecord
  include Sluggable
  has_paper_trail

  KINDS = %w[ person company ].freeze

  has_many :carousels, dependent: :nullify
  has_many :figures, foreign_key: :carver_id, dependent: :nullify, inverse_of: :carver

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }, allow_nil: true
end
