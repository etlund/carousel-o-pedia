require "test_helper"

class MountIconsTest < ActionDispatch::IntegrationTest
  setup do
    @carousel = build_carousel(sections: 4, rows: 2)
    @figures = Figure::MOUNTS.map.with_index do |mount, index|
      figure = create_figure("Mount #{mount}", carousel: @carousel)
      figure.update!(mount:)
      SeatAssignment.new(@carousel.seat("#{index + 1}A"), figure).save!
      figure
    end
    @unknown = create_figure("Unknown mount", carousel: @carousel)
    SeatAssignment.new(@carousel.seat("1B"), @unknown).save!
    @carousel.seat("2B").update!(state: "empty")
  end

  test "large chart and sections table show known mounts only and retain seat labels" do
    get carousel_path(@carousel)
    assert_response :success
    assert_select "[data-controller=chart-viewer]" do
      assert_select ".chart-tools[hidden] button[aria-expanded=false]", text: "Expand chart"
      assert_select "dialog.chart-dialog:not([open])[aria-label=?]", "Seating chart for #{@carousel.name}"
      assert_select ".seat-chart-panel > svg.seat-chart", 1
      assert_select ".seat-chart-panel > svg.seat-chart + ul.legend:not(.mount-legend)", 1
      assert_select ".seat-chart-panel > ul.legend + ul.mount-legend", 1
      assert_select ".legend:not(.mount-legend) .mount-icon", 0
      assert_select ".mount-legend li", Figure::MOUNTS.length
    end
    assert_select "svg.seat-chart a.seat", 8
    assert_select "svg.seat-chart a.seat svg.mount-icon", 4
    @figures.each do |figure|
      assert_select "svg.seat-chart a.seat[href=?]", figure_path(figure) do
        assert_select "> title", "#{figure.seat.code}: #{figure.name} (#{figure.mount.capitalize})"
        assert_select ".seat-label", figure.chart_label
        assert_select ".seat-code", figure.seat.code
        assert_select "svg.mount-icon[aria-hidden=true][width='10']", 1
      end
      assert_select "table.sections td:has(a[href='#{figure_path(figure)}']) svg.mount-icon[aria-label=?]", figure.mount.capitalize
      assert_select ".mount-legend li:has(svg.mount-icon)", text: /#{figure.mount.capitalize}/
    end
    assert_select "svg.seat-chart a.seat[href=?] svg.mount-icon", figure_path(@unknown), count: 0
    assert_select "svg.seat-chart a.seat.unknown svg.mount-icon, svg.seat-chart a.seat.empty svg.mount-icon", 0
    assert_select "table.sections svg.mount-icon", 4
  end

  test "figure details pair icons with text without changing current seat badges" do
    @figures.each do |figure|
      get figure_path(figure)
      assert_response :success
      assert_select ".figure-details dd:has(svg.mount-icon[aria-hidden=true])", text: /#{figure.mount.capitalize}/
      assert_select ".seat-context .mount-icon", 0
      assert_select "svg.seat-badge .mount-icon", 0
    end
    get figure_path(@unknown)
    assert_select ".mount-icon", 0
    assert_select ".figure-details dt", text: "Mount", count: 0
  end

  test "figure lists identify mounts accessibly while mini charts stay icon free" do
    get figures_path(carousel_id: @carousel.id)
    assert_response :success
    assert_select "td svg.mount-icon[role=img]", 4
    @figures.each do |figure|
      assert_select "tr:has(a[href='#{figure_path(figure)}']) svg.mount-icon[aria-label=?]", figure.mount.capitalize
    end
    assert_select "tr:has(a[href='#{figure_path(@unknown)}']) svg.mount-icon", 0
    assert_select "svg.seat-badge .mount-icon", 0

    get carousels_path
    assert_select "svg.mini-seat-chart .mount-icon", 0
  end
end
