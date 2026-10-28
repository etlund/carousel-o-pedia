class InvitationAcceptancesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :update, with: -> { redirect_to root_path, alert: "Try again later." }

  before_action :set_invitation
  rescue_from ActiveRecord::RecordNotFound do
    redirect_to new_session_path, alert: "That invitation link has expired or was already used."
  end

  def edit
    @user = User.new(email_address: @invitation.email_address)
  end

  def update
    user = @invitation.accept!(**params.expect(user: %i[
      email_address name password password_confirmation contribution_terms contribution_terms_version
    ]).to_h.symbolize_keys)
    return unless start_new_session_for(user)
    destination = if user.carousel_restricted?
      user.editable_carousel || new_carousel_path
    else
      root_path
    end
    redirect_to destination, notice: "Welcome, #{user.name}. #{user.access_description}."
  rescue ActiveRecord::RecordInvalid => error
    @user = error.record
    render :edit, status: :unprocessable_entity
  end

  private
    def set_invitation
      @invitation = Invitation.find_pending!(params[:token])
    end
end
