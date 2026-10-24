# Adds a public history action listing every saved version of the controller's record.
module PageHistory
  extend ActiveSupport::Concern

  included do
    allow_unauthenticated_access only: %i[ show history ]
  end

  def history
    @record = history_record
    @versions = @record.versions.reorder(created_at: :desc, id: :desc)
    render "versions/history"
  end
end
