class EditorSuspensionsController < ApplicationController
  before_action :require_admin
  before_action :set_editor

  def create
    @editor.suspend!
    redirect_to invitations_path, notice: "Access suspended for #{@editor.name}. All their sessions have been revoked."
  end

  def destroy
    @editor.restore_access!
    redirect_to invitations_path, notice: "Access restored for #{@editor.name}. They can sign in again."
  end

  private
    def set_editor
      @editor = User.where(role: "editor").find(params[:editor_id])
    end
end
