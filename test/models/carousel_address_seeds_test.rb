require "test_helper"

class CarouselAddressSeedsTest < ActiveSupport::TestCase
  setup do
    Dir[Rails.root.join("db/seeds/*.rb")].sort.each do |file|
      load file unless File.basename(file) == "zz_carousel_addresses.rb"
    end
    @addresses = JSON.parse(Rails.root.join("db/seeds/carousel_addresses.json").read)
  end

  test "all 54 seeded carousels receive sourced physical addresses without inventory changes" do
    assert_equal 54, @addresses.size
    assert_equal Carousel.order(:slug).pluck(:slug), @addresses.map { _1.fetch("slug") }.sort
    assert_equal 54, @addresses.map { _1.fetch("slug") }.uniq.size
    before = Carousel.order(:id).map { _1.attributes.except("street_address", "postal_code", "address_sources", "updated_at") }
    assert_no_difference %w[ Carousel.count Seat.count Figure.count Placement.count Maker.count FigureType.count ] do
      assert_difference "Carousel.where.not(street_address: nil, postal_code: nil).count", 54 do
        load_addresses
      end
    end
    assert_equal before, Carousel.order(:id).map { _1.attributes.except("street_address", "postal_code", "address_sources", "updated_at") }

    @addresses.each do |entry|
      carousel = Carousel.find_by!(slug: entry.fetch("slug"))
      assert entry.fetch("street_address").present?, carousel.slug
      assert_no_match(/\bP\.?\s*O\.?\s*Box\b/i, entry.fetch("street_address"), carousel.slug)
      assert_instance_of String, entry.fetch("postal_code")
      assert_match(/\A\d{5}(-\d{4})?\z/, entry.fetch("postal_code"), carousel.slug)
      assert_match(/\Ahttps:\/\//, entry.fetch("source_url"), carousel.slug)
      assert entry.fetch("notes").present?, carousel.slug
      assert_equal entry.fetch("street_address"), carousel.street_address
      assert_equal entry.fetch("postal_code"), carousel.postal_code
      assert_includes carousel.address_sources, entry.fetch("source_url")
      assert_includes carousel.address_sources, entry.fetch("notes")
      assert_includes carousel.address_sources, "October 26, 2026"
      assert_includes carousel.address_sources, "does not establish verified coordinates"
    end
  end

  test "address seed is idempotent including timestamps and history" do
    load_addresses
    before = snapshot
    2.times { load_addresses }
    assert_equal before, snapshot
  end

  test "conflicting existing streets or postal codes preserve the entire address pair" do
    entries = @addresses.first(3)
    changes = [
      { street_address: "Wiki ride entrance", postal_code: "99999" },
      { street_address: "Different wiki entrance", postal_code: nil },
      { street_address: nil, postal_code: "99998" }
    ]
    originals = entries.zip(changes).to_h do |entry, attributes|
      carousel = Carousel.find_by!(slug: entry.fetch("slug"))
      carousel.update!(**attributes, address_sources: "Wiki address source")
      [ carousel.id, carousel.attributes ]
    end
    load_addresses
    originals.each { |id, attributes| assert_equal attributes, Carousel.find(id).attributes }
  end

  test "matching partial addresses fill missing values and retain source notes and wiki metadata" do
    entry = @addresses.first
    carousel = Carousel.find_by!(slug: entry.fetch("slug"))
    carousel.update!(street_address: entry.fetch("street_address"), name: "Wiki name",
      body: "Wiki history", address_sources: "Earlier entrance research")
    load_addresses
    assert_equal entry.fetch("postal_code"), carousel.reload.postal_code
    assert_equal "Wiki name", carousel.name
    assert_equal "Wiki history", carousel.body
    assert_includes carousel.address_sources, "Earlier entrance research"
    assert_includes carousel.address_sources, entry.fetch("source_url")

    second = @addresses.second
    another = Carousel.find_by!(slug: second.fetch("slug"))
    another.update!(street_address: nil, postal_code: second.fetch("postal_code"), address_sources: "Postal research")
    load_addresses
    assert_equal second.fetch("street_address"), another.reload.street_address
    assert_includes another.address_sources, "Postal research"
  end

  test "complete matching wiki addresses and unrelated carousels are not touched" do
    entry = @addresses.first
    carousel = Carousel.find_by!(slug: entry.fetch("slug"))
    carousel.update!(street_address: entry.fetch("street_address"), postal_code: entry.fetch("postal_code"),
      address_sources: "Wiki verified source")
    extra = Carousel.create!(name: "Unseeded carousel", street_address: "Existing street", postal_code: "00123")
    before = [ carousel, extra ].map(&:attributes)
    load_addresses
    assert_equal before, [ carousel, extra ].map { _1.reload.attributes }
  end

  private
    def load_addresses
      load Rails.root.join("db/seeds/zz_carousel_addresses.rb")
    end

    def snapshot
      [ Carousel, Seat, Figure, Placement, Maker, FigureType, PaperTrail::Version ].map { _1.order(:id).map(&:attributes) }
    end
end
