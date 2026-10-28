class AddLayoutProvisionalToCarousels < ActiveRecord::Migration[8.1]
  def change
    add_column :carousels, :layout_provisional, :boolean, null: false, default: false
  end
end
