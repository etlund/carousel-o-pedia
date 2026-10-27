class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_paper_trail_whodunnit

  helper_method :current_user, :can_edit?

  rescue_from User::AccessDenied do
    redirect_to root_path, alert: "You do not have permission to make that change."
  end

  private
    def current_user
      resume_session
      Current.user
    end

    # Recorded on every version, so page history shows who made each edit.
    def user_for_paper_trail = current_user&.id

    def require_admin
      redirect_to root_path, alert: "Only admins can do that." unless current_user&.admin?
    end

    def can_edit?(record) = current_user&.can_edit?(record)

    def authorize_edit!(record)
      raise User::AccessDenied unless can_edit?(record)
    end

    def require_site_wide_access
      raise User::AccessDenied unless current_user&.site_wide_access?
    end
end
