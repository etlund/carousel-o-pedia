require "test_helper"

class InvitationsMailerTest < ActionMailer::TestCase
  test "invite links to the acceptance page" do
    invitation = users(:admin).invitations.create!(email_address: "friend@example.com")
    mail = InvitationsMailer.invite(invitation)

    assert_equal [ "friend@example.com" ], mail.to
    assert_equal "Ada Admin invited you to edit carousel-o-pedia", mail.subject
    assert_match "carousel-o-pedia", mail.text_part.body.to_s
    assert_match "carousel-o-pedia", mail.html_part.body.to_s
    assert_match "/invitations/accept/#{invitation.token}/edit", mail.text_part.body.to_s
  end
end
