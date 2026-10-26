require "test_helper"
require "rake"

class CarouselsTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("carousels:import_elitch_gardens")
    @task = Rake::Task["carousels:import_elitch_gardens"]
    @task.reenable
  end

  test "imports only Denver data into a database without directory records" do
    assert_difference "Carousel.count", 1 do
      assert_difference "Figure.count", 2 do
        assert_no_difference [ "Seat.count", "Placement.count", "User.count" ] do
          assert_output(/Elitch Gardens import complete/) { @task.invoke }
        end
      end
    end
    carousel = Carousel.find_by!(slug: "elitch-gardens-carousel-denver")
    assert_equal [ 62, 0, 4, 4, nil ], carousel.attributes.values_at(
      "published_horses_count", "published_other_animals_count", "published_chariots_count",
      "rows_count", "sections_count"
    )
    assert_equal 2, carousel.figures.count
    assert_includes carousel.summary_sources, "64 hand-carved horses"
  end

  test "repeated imports leave unrelated data wiki edits and history unchanged" do
    assert_output { @task.invoke }
    carousel = Carousel.find_by!(slug: "elitch-gardens-carousel-denver")
    carousel.update!(name: "Wiki name", body: "Wiki history", published_horses_count: 64,
      sections_count: 18, rows_count: 4, summary_sources: "#{carousel.summary_sources}\n\nWiki notes")
    figure = carousel.figures.first
    figure.update!(name: "Wiki figure", body: "Wiki figure notes")
    SeatAssignment.new(carousel.seat("3C"), figure).save!
    create_figure("Unrelated figure")
    before = snapshot
    @task.reenable
    assert_output(/0 added/) { @task.invoke }
    assert_equal before, snapshot
  end

  test "an inventory import failure rolls back the directory facts too" do
    reject_import = -> { raise ActiveRecord::RecordInvalid.new(self) }
    Figure.set_callback(:create, :before, reject_import)
    before = snapshot
    assert_raises(ActiveRecord::RecordInvalid) { @task.invoke }
    assert_equal before, snapshot
  ensure
    Figure.skip_callback(:create, :before, reject_import)
  end

  test "unknown directory slugs fail without importing any records" do
    before = snapshot
    assert_raises(ArgumentError) { OperatingCarouselImport.call(slug: "not-a-carousel") }
    assert_equal before, snapshot
  end

  private
    def snapshot
      [ Carousel, Seat, Figure, Placement, FigureType, PaperTrail::Version ].map { _1.order(:id).map(&:attributes) }
    end
end
