class InvitationsController < ApplicationController
  before_action :require_admin

  def index
    @invitations = Invitation.pending.includes(:invited_by, :editable_carousel).order(created_at: :desc)
    @users = User.includes(:editable_carousel).order(:name)
    @invitation = Invitation.new
  end

  def create
    @invitation = current_user.invitations.build(invitation_params)
    if @invitation.save
      InvitationsMailer.invite(@invitation).deliver_later
      redirect_to invitations_path, notice: "Invitation sent to #{@invitation.email_address}."
    else
      @invitations = Invitation.pending.includes(:invited_by, :editable_carousel).order(created_at: :desc)
      @users = User.includes(:editable_carousel).order(:name)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    Invitation.find(params[:id]).destroy
    redirect_to invitations_path, notice: "Invitation withdrawn."
  end

  private
    def invitation_params = params.expect(invitation: %i[ email_address access_scope editable_carousel_id ])
end
