class InvitationsMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    mail subject: "#{invitation.invited_by.name} invited you to edit Carousel-pedia", to: invitation.email_address
  end
end
