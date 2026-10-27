require "test_helper"

class RingResearchTest < ActionDispatch::IntegrationTest
  setup do
    @carousel = Carousel.create!(name: "Unequal ring research", rows_count: 4, summary_sources: "Research reference",
      ring_details: { "A" => { "positions_count" => 18 }, "B" => { "positions_count" => 16 },
        "C" => { "horses_count" => 0 } })
  end

  test "detail and preview diagrams segment each known ring independently" do
    get carousel_path(@carousel)
    assert_response :success
    assert_select "svg.ring-chart[aria-label*='not a mapped seating layout']", 1
    assert_select "svg.ring-chart text.ring-label", 4
    assert_select ".research-ring[data-ring=A] .research-position", 18
    assert_select ".research-ring[data-ring=B] .research-position", 16
    assert_select ".research-ring[data-ring=C] .research-position", 0
    assert_select ".research-ring[data-ring=D] .research-position", 0
    assert_select ".ring-details tr[data-ring=C] td:nth-child(3)", "0"
    assert_select "a.seat, table.sections", 0

    get carousels_path
    assert_response :success
    assert_select "svg.mini-seat-chart .research-ring[data-ring=A] .research-position", 18
    assert_select "svg.mini-seat-chart .research-ring[data-ring=B] .research-position", 16
    assert_select "svg.mini-seat-chart[aria-label*='not verified seating']", 1
  end

  test "editors can record clear and correct partial ring facts with history" do
    sign_in_as users(:editor)
    get edit_carousel_path(@carousel)
    assert_select "input[name='carousel[ring_details][A][positions_count]'][value='18']"
    assert_select "select[name='carousel[ring_details][A][mount]']"
    patch carousel_path(@carousel), params: { carousel: { ring_details: {
      A: { positions_count: "", horses_count: "18", mount: "stander" },
      B: { positions_count: "", horses_count: "", mount: "jumper" },
      C: { positions_count: "", horses_count: "", mount: "" }
    } } }
    assert_redirected_to carousel_path(@carousel)
    assert_equal({ "A" => { "horses_count" => 18, "mount" => "stander" }, "B" => { "mount" => "jumper" } },
      @carousel.reload.ring_details)
    assert_empty @carousel.seats
    get history_carousel_path(@carousel)
    assert_response :success
    assert_select ".changes", text: /stander/

    patch carousel_path(@carousel), params: { carousel: { ring_details: { A: { positions_count: "-2" } } } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /nonnegative integer/
    assert_equal 18, @carousel.reload.ring_details.dig("A", "horses_count")

    patch carousel_path(@carousel), params: { carousel: { ring_details: { A: { positions_count: "", horses_count: "", mount: "" } } } }
    assert_redirected_to carousel_path(@carousel)
    assert_empty @carousel.reload.ring_details
  end
end
