class AddCarouselToFigures < ActiveRecord::Migration[8.1]
  def up
    add_reference :figures, :carousel, foreign_key: true

    execute <<~SQL
      UPDATE figures
      SET carousel_id = (
        SELECT seats.carousel_id
        FROM placements
        INNER JOIN seats ON seats.id = placements.seat_id
        WHERE placements.figure_id = figures.id
        ORDER BY CASE WHEN placements.ended_on IS NULL THEN 0 ELSE 1 END,
          placements.ended_on DESC, placements.started_on DESC, placements.id DESC
        LIMIT 1
      )
    SQL

    %w[ a-carousel-for-missoula great-northern-carousel salems-riverfront-carousel spokane-looff-carrousel ].each do |slug|
      execute <<~SQL
        UPDATE figures
        SET carousel_id = (SELECT id FROM carousels WHERE slug = #{connection.quote(slug)})
        WHERE carousel_id IS NULL AND slug LIKE #{connection.quote("#{slug}-%")}
      SQL
    end

    unassigned = select_values("SELECT slug FROM figures WHERE carousel_id IS NULL ORDER BY slug")
    if unassigned.any?
      raise ActiveRecord::MigrationError, "Cannot determine a carousel for: #{unassigned.join(", ")}. Assign these figures to known seats before migrating, or add an explicit backfill mapping."
    end

    change_column_null :figures, :carousel_id, false
  end

  def down
    remove_reference :figures, :carousel, foreign_key: true
  end
end
