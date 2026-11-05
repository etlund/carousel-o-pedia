class CreateCarouselCsvImportReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :carousel_csv_import_receipts do |t|
      t.string :token_digest, null: false
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :carousel_csv_import_receipts, :token_digest, unique: true
  end
end
