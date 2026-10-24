require "test_helper"
require Rails.root.join("db/migrate/20261024213321_add_carousel_to_figures")

class AddCarouselToFiguresTest < ActiveSupport::TestCase
  class MigrationRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  setup do
    MigrationRecord.establish_connection(adapter: "sqlite3", database: ":memory:")
    @connection = MigrationRecord.connection
    @connection.create_table(:carousels) { |table| table.string :slug }
    @connection.create_table(:figures) { |table| table.string :slug }
    @connection.create_table(:seats) { |table| table.integer :carousel_id }
    @connection.create_table(:placements) do |table|
      table.integer :figure_id
      table.integer :seat_id
      table.date :started_on
      table.date :ended_on
    end
    @connection.execute("INSERT INTO carousels (id, slug) VALUES (1, 'a-carousel-for-missoula'), (2, 'salems-riverfront-carousel'), (3, 'spokane-looff-carrousel')")
    @connection.execute("INSERT INTO seats (id, carousel_id) VALUES (1, 1), (2, 2)")
  end

  teardown { MigrationRecord.remove_connection }

  test "backfills current seats before recent history and known unseated seed collections" do
    @connection.execute(<<~SQL)
      INSERT INTO figures (id, slug) VALUES
        (1, 'a-carousel-for-missoula-visitor'), (2, 'historical-figure'),
        (3, 'a-carousel-for-missoula-reserve'), (4, 'salems-riverfront-carousel-project'),
        (5, 'spokane-looff-carrousel-spare')
    SQL
    @connection.execute(<<~SQL)
      INSERT INTO placements (figure_id, seat_id, started_on, ended_on) VALUES
        (1, 1, '2020-01-01', '2021-01-01'), (1, 2, '2022-01-01', NULL),
        (2, 1, '2020-01-01', '2021-01-01'), (2, 2, '2022-01-01', '2023-01-01')
    SQL

    migrate(:up)

    assert_equal [ 2, 2, 1, 2, 3 ], @connection.select_values("SELECT carousel_id FROM figures ORDER BY id")
    assert_not @connection.columns(:figures).find { _1.name == "carousel_id" }.null
    assert @connection.foreign_keys(:figures).any? { _1.to_table == "carousels" }
    migrate(:down)
    assert_not @connection.column_exists?(:figures, :carousel_id)
    assert_equal 5, @connection.select_value("SELECT COUNT(*) FROM figures")
  end

  test "unknown ownership stops atomically rather than assigning an arbitrary carousel" do
    @connection.execute("INSERT INTO figures (slug) VALUES ('unknown-owner')")

    error = assert_raises ActiveRecord::MigrationError do
      migrate(:up)
    end

    assert_includes error.message, "unknown-owner"
    assert_includes error.message, "Cannot determine a carousel"
    assert_not @connection.column_exists?(:figures, :carousel_id)
    assert_equal 1, @connection.select_value("SELECT COUNT(*) FROM figures")
  end

  private
    def migrate(direction)
      @connection.transaction do
        migration = AddCarouselToFigures.new
        migration.suppress_messages { migration.exec_migration(@connection, direction) }
      end
    end
end
