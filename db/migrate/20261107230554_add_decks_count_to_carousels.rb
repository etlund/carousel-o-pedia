class AddDecksCountToCarousels < ActiveRecord::Migration[8.1]
  def change
    add_column :carousels, :decks_count, :integer
  end
end
