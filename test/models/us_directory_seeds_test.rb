require "test_helper"

class UsDirectorySeedsTest < ActiveSupport::TestCase
  test "directory seed adds fifty operating US carousels without invented layouts or figures" do
    assert_no_difference %w[ Seat.count Figure.count Placement.count FigureType.count Maker.count ] do
      assert_difference "Carousel.count", 50 do
        load_directory_seed
      end
    end

    carousels = Carousel.order(:slug)
    assert_equal 50, carousels.count
    assert_equal 50, carousels.pluck(:slug).uniq.size
    assert_equal 50, carousels.pluck(:name, :city, :region).uniq.size
    carousels.each do |carousel|
      assert carousel.name.present?, carousel.slug
      assert carousel.city.present?, carousel.slug
      assert carousel.region.present?, carousel.slug
      assert carousel.official_url.present?, carousel.slug
      assert_equal "United States", carousel.country
      assert_equal "operating", carousel.status
      assert_nil carousel.sections_count
      assert_nil carousel.rows_count
      assert_nil carousel.rotation
      assert_not carousel.layout_known?
      assert_includes carousel.body, carousel.official_url
      assert_includes carousel.body, "October 25, 2026"
      assert_includes carousel.body, "seasonal"
    end
  end

  test "directory seed is idempotent including timestamps and history" do
    load_directory_seed
    before = Carousel.order(:id).map(&:attributes)
    assert_no_difference %w[ Carousel.count Seat.count Figure.count Placement.count PaperTrail::Version.count ] do
      2.times { load_directory_seed }
    end
    assert_equal before, Carousel.order(:id).map(&:attributes)
  end

  test "directory seed preserves wiki edits researched layouts inventories and placements" do
    load_directory_seed
    carousel = Carousel.order(:slug).first
    carousel.update!(name: "Edited name", city: "Edited city", region: "Edited region",
      official_url: "https://example.com/updated", status: "stored", body: "Reviewed wiki notes",
      sections_count: 4, rows_count: 2, rotation: "clockwise")
    figure = create_figure("Newly researched figure", carousel:)
    SeatAssignment.new(carousel.seat("1A"), figure).save!

    records = [ Carousel, Seat, Figure, Placement, PaperTrail::Version ]
    before = records.map { |model| model.order(:id).map(&:attributes) }
    load_directory_seed
    assert_equal before, records.map { |model| model.order(:id).map(&:attributes) }
  end

  test "directory seed does not change the four detailed carousel inventories" do
    load_seeds
    detailed = Carousel.where(slug: %w[ great-northern-carousel a-carousel-for-missoula spokane-looff-carrousel salems-riverfront-carousel ])
    assert_equal 4, detailed.count
    assert_equal 206, detailed.joins(:figures).count
    records = [ Carousel, Seat, Figure, Placement, PaperTrail::Version ]
    before = records.map { |model| model.order(:id).map(&:attributes) }
    load_directory_seed
    assert_equal before, records.map { |model| model.order(:id).map(&:attributes) }
  end

  private
    def load_directory_seed
      load Rails.root.join("db/seeds/us_operating_carousels.rb")
    end
end
