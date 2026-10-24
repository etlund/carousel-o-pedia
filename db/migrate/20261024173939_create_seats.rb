class CreateSeats < ActiveRecord::Migration[8.1]
  def change
    create_table :seats do |t|
      t.references :carousel, null: false, foreign_key: true
      t.integer :section, null: false
      t.string :row, null: false
      t.integer :rows_spanned, null: false, default: 1
      t.string :state, null: false, default: "filled"
      t.string :confidence, null: false, default: "best_reading"

      t.timestamps
    end
    add_index :seats, [ :carousel_id, :section, :row ], unique: true
  end
end
