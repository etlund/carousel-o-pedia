class AddDraftPlaceholderToFigures < ActiveRecord::Migration[8.1]
  def up
    add_column :figures, :draft_placeholder, :boolean, default: false, null: false
    execute <<~SQL
      UPDATE figures
      SET draft_placeholder = TRUE
      WHERE description = 'Provisional seat-based name; individual identity and decoration have not been verified.'
        AND body LIKE '## Draft seating sources%'
        AND NOT EXISTS (
          SELECT 1 FROM versions
          WHERE versions.item_type = 'Figure'
            AND versions.item_id = figures.id
            AND versions.event = 'update'
        )
    SQL
  end

  def down
    remove_column :figures, :draft_placeholder
  end
end
