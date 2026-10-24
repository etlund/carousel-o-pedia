class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Empty form fields save as nil, so page history doesn't show nil-to-blank edits.
  def self.blank_as_nil(*attributes) = normalizes(*attributes, with: ->(value) { value.presence })
end
