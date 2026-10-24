class CreateCarousels < ActiveRecord::Migration[8.1]
  def change
    create_table :carousels do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :city
      t.string :region
      t.string :country
      t.string :venue
      t.string :status, null: false, default: "operating"
      t.integer :year_built
      t.integer :year_opened
      t.references :maker, foreign_key: true
      t.integer :sections_count, null: false
      t.integer :rows_count, null: false
      t.string :rotation, null: false, default: "counterclockwise"
      t.text :body

      t.timestamps
    end
    add_index :carousels, :slug, unique: true
  end
end
