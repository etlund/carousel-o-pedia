class AllowInvitationsWithoutEmailAddresses < ActiveRecord::Migration[8.1]
  def change
    change_column_null :invitations, :email_address, true
  end
end
