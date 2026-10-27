class AddRingDetailsToCarousels < ActiveRecord::Migration[8.1]
  def change
    add_column :carousels, :ring_details, :json, default: {}, null: false
  end
end
