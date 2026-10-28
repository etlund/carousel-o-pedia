class User < ApplicationRecord
  ROLES = %w[ editor admin ].freeze
  CONTRIBUTION_TERMS_VERSION = "2026-10-27".freeze
  ACCESS_SCOPES = %w[ site_wide carousel ].freeze
  class AccessDenied < StandardError; end

  attr_accessor :contribution_terms

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :invitations, foreign_key: :invited_by_id, dependent: :destroy, inverse_of: :invited_by
  belongs_to :editable_carousel, class_name: "Carousel", optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :role, inclusion: { in: ROLES }
  validates :access_scope, inclusion: { in: ACCESS_SCOPES }
  validates :editable_carousel, absence: true, unless: :carousel_restricted?
  validates :editable_carousel, presence: true, if: -> { editable_carousel_id.present? }
  validates :contribution_terms, acceptance: { allow_nil: false }, on: :contribution_agreement
  validates :contribution_terms_version, inclusion: {
    in: [ CONTRIBUTION_TERMS_VERSION ], message: "has changed. Review the current terms and agree again"
  }, on: :contribution_agreement
  validate :only_editors_can_be_suspended

  def admin? = role == "admin"
  def suspended? = suspended_at.present?
  def carousel_restricted? = access_scope == "carousel"
  def site_wide_access? = !suspended? && (admin? || !carousel_restricted?)
  def can_create_carousel? = site_wide_access? || (!suspended? && editable_carousel_id.nil?)

  def editable_carousels
    site_wide_access? ? Carousel.all : Carousel.where(id: suspended? ? nil : editable_carousel_id)
  end

  def can_edit?(record)
    return false if suspended?
    return true if site_wide_access?

    carousel_id = case record
    when Carousel then record.id
    when Figure, Seat then record.carousel_id
    end
    editable_carousel_id.present? && carousel_id == editable_carousel_id
  end

  def access_description
    if site_wide_access? || !carousel_restricted?
      "Site-wide editing"
    elsif editable_carousel
      "Only #{editable_carousel.name}"
    else
      "Create and edit one new carousel"
    end
  end

  def create_carousel(attributes)
    # Serialize the permission check and assignment so concurrent requests cannot create two.
    with_lock do
      raise AccessDenied unless can_create_carousel?

      carousel = Carousel.new(attributes)
      if carousel.save && carousel_restricted? && !admin?
        update!(editable_carousel: carousel)
      end
      carousel
    end
  end

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
