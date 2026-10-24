class User < ApplicationRecord
  ROLES = %w[ editor admin ].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :invitations, foreign_key: :invited_by_id, dependent: :destroy, inverse_of: :invited_by

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }

  def admin? = role == "admin"
end
