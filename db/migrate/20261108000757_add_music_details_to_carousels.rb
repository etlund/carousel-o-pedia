class AddMusicDetailsToCarousels < ActiveRecord::Migration[8.1]
  def change
    add_column :carousels, :music_type, :string
    add_column :carousels, :music_description, :text
  end
end
