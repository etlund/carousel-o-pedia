require "test_helper"

class UsDirectorySeedsTest < ActiveSupport::TestCase
  EXPECTED_SUMMARIES = {
    "janes-carousel-brooklyn" => [ 48, 0, 2, 3 ],
    "paragon-carousel-hull" => [ 66, 0, 2, 4 ],
    "bushnell-park-carousel-hartford" => [ 48, 0, 2, 3 ],
    "glen-echo-dentzel-carousel" => [ 40, 12, 2, 3 ],
    "pullen-park-carousel-raleigh" => [ 29, 23, 2, 3 ],
    "kit-carson-county-carousel-burlington" => [ 25, 21, 4, 3 ],
    "cafesjians-carousel-st-paul" => [ 68, 0, 2, 4 ],
    "balboa-park-carousel-san-diego" => [ 27, 25, 3, 3 ],
    "looff-carousel-santa-cruz-beach-boardwalk" => [ 73, 0, 2, 4 ],
    "oaks-park-carousel-portland" => [ 24, 26, 4, 3 ]
  }.freeze

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
      expected = EXPECTED_SUMMARIES[carousel.slug] || [ nil, nil, nil, nil ]
      assert_equal expected, carousel.attributes.values_at("published_horses_count", "published_other_animals_count", "published_chariots_count", "rows_count")
      if EXPECTED_SUMMARIES.key?(carousel.slug)
        assert_includes carousel.summary_sources, "https://carousels.org/USACensus/stdqueries/census-cCLA.html"
        assert_includes carousel.summary_sources, "October 25, 2026"
      else
        assert_nil carousel.summary_sources
      end
      assert_nil carousel.rotation
      assert_not carousel.layout_known?
      assert_includes carousel.body, carousel.official_url
      assert_includes carousel.body, "October 25, 2026"
      assert_includes carousel.body, "seasonal"
    end
    assert_equal 10, carousels.where.not(rows_count: nil).count
    assert_includes Carousel.find_by!(slug: "balboa-park-carousel-san-diego").summary_sources, "26 other animals rather than 25"
    assert_includes Carousel.find_by!(slug: "oaks-park-carousel-portland").summary_sources, "two chariots, two tubs"
  end

  test "directory research fills missing facts without replacing existing metadata or source notes" do
    carousel = Carousel.create!(slug: "janes-carousel-brooklyn", name: "Wiki name", city: "Wiki city",
      official_url: "https://example.com/", body: "Wiki notes", published_horses_count: 99,
      rows_count: 4, summary_sources: "Existing researched source")
    original = carousel.attributes.slice("name", "city", "official_url", "body", "published_horses_count", "rows_count")
    load_directory_seed
    assert_equal original, carousel.reload.attributes.slice(*original.keys)
    assert_equal 0, carousel.published_other_animals_count
    assert_equal 2, carousel.published_chariots_count
    assert_nil carousel.sections_count
    assert_empty carousel.seats
    assert_includes carousel.summary_sources, "Existing researched source"
    assert_includes carousel.summary_sources, "30 jumping and 18 standing horses"
    before = carousel.attributes
    load_directory_seed
    assert_equal before, carousel.reload.attributes
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
