class AddWebsiteLinksToCarousels < ActiveRecord::Migration[8.1]
  def change
    add_column :carousels, :official_url, :string
    add_column :carousels, :wikipedia_url, :string
    add_column :carousels, :other_links, :text
  end
end
