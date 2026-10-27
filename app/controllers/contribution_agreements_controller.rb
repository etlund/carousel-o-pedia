class ContributionAgreementsController < ApplicationController
  skip_before_action :require_contribution_agreement

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    agreement = params.expect(user: %i[ contribution_terms contribution_terms_version ])
    @user.accept_contribution_terms!(agreement: agreement[:contribution_terms], version: agreement[:contribution_terms_version])
    redirect_to root_path, notice: "Thank you for agreeing to the contribution terms. You can edit now."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end
end
