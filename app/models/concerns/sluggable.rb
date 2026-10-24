# Gives a record a readable, unique URL slug built from its name.
module Sluggable
  extend ActiveSupport::Concern

  included do
    validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
    before_validation :assign_slug, if: -> { slug.blank? && name.present? }
  end

  def to_param = slug

  private
    def assign_slug
      base = name.parameterize
      candidate = base
      counter = 2
      while self.class.where.not(id: id).exists?(slug: candidate)
        candidate = "#{base}-#{counter}"
        counter += 1
      end
      self.slug = candidate
    end
end
