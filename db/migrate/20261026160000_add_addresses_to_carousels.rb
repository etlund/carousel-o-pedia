class AddAddressesToCarousels < ActiveRecord::Migration[8.1]
  def change
    add_column :carousels, :street_address, :string
    add_column :carousels, :postal_code, :string
    add_column :carousels, :address_sources, :text
  end
end
