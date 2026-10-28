class AddOtherNamesToCarousels < ActiveRecord::Migration[8.1]
  def change
    add_column :carousels, :other_names, :text
  end
end
