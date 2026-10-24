class CreateMakers < ActiveRecord::Migration[8.1]
  def change
    create_table :makers do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :kind
      t.string :years_active
      t.text :body

      t.timestamps
    end
    add_index :makers, :slug, unique: true
  end
end
