class AddEditorAccessAndContributionTermsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :suspended_at, :datetime
    add_column :users, :contribution_terms_version, :string
    add_column :users, :contribution_terms_accepted_at, :datetime
  end
end
