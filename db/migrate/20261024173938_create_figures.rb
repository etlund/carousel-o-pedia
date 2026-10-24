class CreateFigures < ActiveRecord::Migration[8.1]
  def change
    create_table :figures do |t|
      t.string :name, null: false
      t.string :short_name
      t.string :slug, null: false
      t.references :figure_type, null: false, foreign_key: true
      t.string :mount
      t.text :description
      t.references :carver, foreign_key: { to_table: :makers }
      t.integer :year_carved
      t.string :sponsor
      t.text :body

      t.timestamps
    end
    add_index :figures, :slug, unique: true
  end
end
