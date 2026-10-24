class CreatePlacements < ActiveRecord::Migration[8.1]
  def change
    create_table :placements do |t|
      t.references :figure, null: false, foreign_key: true
      t.references :seat, null: false, foreign_key: true
      t.date :started_on
      t.date :ended_on

      t.timestamps
    end
  end
end
