class AddPublishedCountsToCarousels < ActiveRecord::Migration[8.1]
  def change
    add_column :carousels, :published_horses_count, :integer
    add_column :carousels, :published_other_animals_count, :integer
    add_column :carousels, :published_chariots_count, :integer
    add_column :carousels, :summary_sources, :text
  end
end
