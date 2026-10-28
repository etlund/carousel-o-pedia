# Editing is invite-only. Invitations can be bound to an email address or shared
# privately as a single-use link.
class Invitation < ApplicationRecord
  EXPIRES_IN = 14.days

  belongs_to :invited_by, class_name: "User"
  belongs_to :editable_carousel, class_name: "Carousel", optional: true
  has_secure_token

  normalizes :email_address, with: ->(e) { e.strip.downcase.presence }

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :access_scope, inclusion: { in: User::ACCESS_SCOPES }
  validates :editable_carousel, absence: true, unless: -> { access_scope == "carousel" }
  validates :editable_carousel, presence: true, if: -> { editable_carousel_id.present? }
  validate :not_already_a_user, on: :create

  scope :pending, -> { where(accepted_at: nil).where(created_at: EXPIRES_IN.ago..) }

  def self.find_pending!(token) = pending.find_by!(token:)

  def accept!(name:, password:, password_confirmation:, email_address: nil, contribution_terms: nil, contribution_terms_version: nil)
    with_lock do
      raise ActiveRecord::RecordNotFound unless self.class.pending.exists?(id:)

      user = User.new(email_address: self.email_address.presence || email_address,
        name:, password:, password_confirmation:, access_scope:, editable_carousel:)
      user.accept_contribution_terms!(agreement: contribution_terms, version: contribution_terms_version)
      update!(accepted_at: Time.current, email_address: user.email_address)
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
