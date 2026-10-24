# Editing is invite-only: an admin invites an email address, and the link in the
# invitation lets that person pick a name and password.
class Invitation < ApplicationRecord
  EXPIRES_IN = 14.days

  belongs_to :invited_by, class_name: "User"
  has_secure_token

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :not_already_a_user, on: :create

  scope :pending, -> { where(accepted_at: nil).where(created_at: EXPIRES_IN.ago..) }

  def self.find_pending!(token) = pending.find_by!(token:)

  def accept!(name:, password:, password_confirmation:)
    transaction do
      user = User.create!(email_address:, name:, password:, password_confirmation:)
      update!(accepted_at: Time.current)
      user
    end
  end

  private
    def not_already_a_user
      errors.add(:email_address, "already has an account") if User.exists?(email_address:)
    end
end
