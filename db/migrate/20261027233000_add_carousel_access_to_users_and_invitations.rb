class AddCarouselAccessToUsersAndInvitations < ActiveRecord::Migration[8.1]
  def change
    %i[ users invitations ].each do |table|
      add_column table, :access_scope, :string, null: false, default: "site_wide"
      add_reference table, :editable_carousel, foreign_key: { to_table: :carousels }
      add_check_constraint table, "access_scope IN ('site_wide', 'carousel')", name: "#{table}_access_scope"
      add_check_constraint table, "access_scope = 'carousel' OR editable_carousel_id IS NULL",
        name: "#{table}_editable_carousel_scope"
    end
  end
end
