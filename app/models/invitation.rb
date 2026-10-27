# Editing is invite-only: an admin invites an email address, and the link in the
# invitation lets that person pick a name and password.
class Invitation < ApplicationRecord
  EXPIRES_IN = 14.days

  belongs_to :invited_by, class_name: "User"
  belongs_to :editable_carousel, class_name: "Carousel", optional: true
  has_secure_token

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :access_scope, inclusion: { in: User::ACCESS_SCOPES }
  validates :editable_carousel, absence: true, unless: -> { access_scope == "carousel" }
  validates :editable_carousel, presence: true, if: -> { editable_carousel_id.present? }
  validate :not_already_a_user, on: :create

  scope :pending, -> { where(accepted_at: nil).where(created_at: EXPIRES_IN.ago..) }

  def self.find_pending!(token) = pending.find_by!(token:)

  def accept!(name:, password:, password_confirmation:, contribution_terms: nil, contribution_terms_version: nil)
    transaction do
      user = User.new(email_address:, name:, password:, password_confirmation:, access_scope:, editable_carousel:)
      user.accept_contribution_terms!(agreement: contribution_terms, version: contribution_terms_version)
      update!(accepted_at: Time.current)
      user
    end
  end

  def access_description
    User.new(access_scope:, editable_carousel:).access_description
  end

  private
    def not_already_a_user
      errors.add(:email_address, "already has an account") if User.exists?(email_address:)
    end
end
