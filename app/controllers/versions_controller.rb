class VersionsController < ApplicationController
  allow_unauthenticated_access only: :index
  before_action :require_admin, only: :revert

  # Recent changes across the whole site.
  def index
    @versions = PaperTrail::Version.order(created_at: :desc, id: :desc).limit(100)
  end

  # Puts a record back the way it was before this version's change.
  def revert
    version = PaperTrail::Version.find(params[:id])
    previous = version.reify
    # Versions recorded before carousel ownership existed must retain today's owner.
    if previous.is_a?(Figure) && previous.carousel_id.nil?
      previous.carousel = Figure.find(previous.id).carousel
    end
    if version.event == "update" && previous&.save
      redirect_back_or_to recent_changes_path, notice: "Reverted."
    else
      redirect_back_or_to recent_changes_path, alert: "That change can't be reverted."
    end
  end
end
