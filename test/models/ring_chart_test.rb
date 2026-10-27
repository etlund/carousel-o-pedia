require "test_helper"

class RingChartTest < ActiveSupport::TestCase
  setup do
    @carousel = Carousel.create!(name: "Independent rings", rows_count: 4, summary_sources: "Research reference",
      ring_details: { "A" => { "positions_count" => 18 }, "B" => { "positions_count" => 16 },
        "C" => { "positions_count" => 14 } })
  end

  test "unequal ring counts and unknown rings do not create a regular seat grid" do
    bands = RingChart.new(@carousel).bands
    assert_equal %w[ A B C D ], bands.map(&:letter)
    assert_equal [ 18, 16, 14, nil ], bands.map(&:positions_count)
    assert_equal [ 370, 302.5, 235, 167.5 ], bands.map(&:outer_radius)
    assert_equal [ 302.5, 235, 167.5, 100 ], bands.map(&:inner_radius)
    assert_empty @carousel.seats
    assert_not @carousel.layout_known?
  end

  test "horse counts and motion do not establish position counts" do
    @carousel.update!(ring_details: { "A" => { "horses_count" => 18, "mount" => "stander" },
      "B" => { "mount" => "jumper" } })
    band = RingChart.new(@carousel).bands.first
    assert_nil band.positions_count
    assert_equal 18, band.horses_count
    assert_equal "stander", band.mount
    assert_empty @carousel.seats
  end

  test "form values normalize without dropping zero or accepting invalid numbers" do
    @carousel.update!(ring_details: { "A" => { "positions_count" => " 0 ", "horses_count" => "", "mount" => "" },
      "B" => { "positions_count" => "", "horses_count" => "", "mount" => "" } })
    assert_equal({ "A" => { "positions_count" => 0 } }, @carousel.reload.ring_details)
    [ "-1", "1.5", "not a count" ].each do |value|
      @carousel.ring_details = { "A" => { "positions_count" => value } }
      assert_not @carousel.valid?
      assert @carousel.errors[:ring_details].any?
    end
  end

  test "invalid shapes fields rows and motion are rejected explicitly" do
    [ [], "invalid", nil, { "E" => { "positions_count" => 1 } }, { "A" => "invalid" },
      { "A" => { "unexpected" => 1 } }, { "A" => { "mount" => "spinning" } },
      { "A" => { "positions_count" => 1, "horses_count" => 2 } } ].each do |details|
      @carousel.ring_details = details
      assert_not @carousel.valid?, details.inspect
      assert @carousel.errors[:ring_details].any?
    end
  end

  test "ring research requires a known row count and sources" do
    @carousel.rows_count = nil
    assert_not @carousel.valid?
    assert @carousel.errors[:ring_details].any?
    @carousel.rows_count = 4
    @carousel.summary_sources = nil
    assert_not @carousel.valid?
    assert @carousel.errors[:summary_sources].any?
  end

  test "ring research does not change an existing mapped chart" do
    mapped = build_carousel
    before = mapped.seats.order(:id).map(&:attributes)
    mapped.update!(summary_sources: "Independent research", ring_details: { "A" => { "positions_count" => 6 } })
    assert_equal before, mapped.seats.reload.order(:id).map(&:attributes)
    assert_equal 4, SeatChart.new(mapped).section_count
  end
end
