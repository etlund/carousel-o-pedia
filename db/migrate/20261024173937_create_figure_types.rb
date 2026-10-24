class CreateFigureTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :figure_types do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :category, null: false
      t.text :body

      t.timestamps
    end
    add_index :figure_types, :slug, unique: true
  end
end
