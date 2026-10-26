class InvitationsMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    mail subject: "#{invitation.invited_by.name} invited you to edit carousel-o-pedia", to: invitation.email_address
  end
end
