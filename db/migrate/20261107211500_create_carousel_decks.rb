class CreateCarouselDecks < ActiveRecord::Migration[8.1]
  def change
    create_table :carousel_decks do |t|
      t.references :carousel, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false
      t.integer :sections_count
      t.integer :rows_count
      t.boolean :layout_provisional, default: false, null: false
      t.integer :published_horses_count
      t.integer :published_other_animals_count
      t.integer :published_chariots_count
      t.text :summary_sources
      t.timestamps
    end
    add_index :carousel_decks, [ :carousel_id, :position ], unique: true
    add_reference :seats, :carousel_deck, foreign_key: true
    remove_index :seats, [ :carousel_id, :section, :row ]
    add_index :seats, [ :carousel_id, :section, :row ], unique: true,
      where: "carousel_deck_id IS NULL", name: "index_seats_on_main_platform"
    add_index :seats, [ :carousel_deck_id, :section, :row ], unique: true,
      where: "carousel_deck_id IS NOT NULL", name: "index_seats_on_deck_position"
  end
end
