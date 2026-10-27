class User < ApplicationRecord
  ROLES = %w[ editor admin ].freeze
  CONTRIBUTION_TERMS_VERSION = "2026-10-27".freeze

  attr_accessor :contribution_terms

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :invitations, foreign_key: :invited_by_id, dependent: :destroy, inverse_of: :invited_by

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }
  validates :contribution_terms, acceptance: { allow_nil: false }, on: :contribution_agreement
  validates :contribution_terms_version, inclusion: {
    in: [ CONTRIBUTION_TERMS_VERSION ], message: "has changed. Review the current terms and agree again"
  }, on: :contribution_agreement
  validate :only_editors_can_be_suspended

  def admin? = role == "admin"
  def suspended? = suspended_at.present?

  def contribution_terms_accepted?
    contribution_terms_accepted_at.present? && contribution_terms_version == CONTRIBUTION_TERMS_VERSION
  end

  def accept_contribution_terms!(agreement:, version:)
    self.contribution_terms = agreement
    self.contribution_terms_version = version
    self.contribution_terms_accepted_at = Time.current
    save!(context: :contribution_agreement)
  end

  def suspend!
    with_lock do
      update!(suspended_at: Time.current)
      sessions.destroy_all
    end
  end

  def restore_access!
    update!(suspended_at: nil)
  end

  private
    def only_editors_can_be_suspended
      errors.add(:suspended_at, "can only be set for editors") if suspended? && admin?
    end
end
