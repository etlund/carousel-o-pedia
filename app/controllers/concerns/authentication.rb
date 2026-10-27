module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    before_action :require_contribution_agreement
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      skip_before_action :require_contribution_agreement, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      if cookies.signed[:session_id]
        session = Session.includes(:user).find_by(id: cookies.signed[:session_id])
        return session if session && !session.user.suspended?

        cookies.delete(:session_id)
      end
      nil
    end

    def require_contribution_agreement
      unless Current.user.contribution_terms_accepted?
        redirect_to edit_contribution_agreement_path, alert: "Please review and agree to the contribution terms before editing."
      end
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      user.with_lock do
        if user.suspended?
          redirect_to new_session_path, alert: "This account is suspended. You can still browse without signing in."
          return nil
        end

        user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
          Current.session = session
          cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
        end
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
