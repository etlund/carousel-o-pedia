class VideoAnalysisAccessesController < ApplicationController
  before_action :require_admin
  before_action :set_user

  def create
    @user.update!(can_analyze_videos: true)
    redirect_to invitations_path, notice: "#{@user.name} can now upload carousel videos for analysis."
  end

  def destroy
    @user.update!(can_analyze_videos: false)
    redirect_to invitations_path, notice: "#{@user.name} can no longer upload carousel videos for analysis."
  end

  private
    def set_user
      @user = User.where(role: "editor").find(params[:editor_id])
    end
end
