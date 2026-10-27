require "test_helper"

class MountsHelperTest < ActionView::TestCase
  test "every mount has a distinct SVG path and an accessible name" do
    assert_equal Figure::MOUNTS.sort, MountsHelper::MOUNT_ICON_PATHS.keys.sort
    paths = Figure::MOUNTS.map do |mount|
      render html: mount_icon(mount)
      assert_select "svg.mount-icon[role=img][aria-label=?][viewBox='0 0 16 16'][focusable=false]", mount.capitalize
      assert_select "svg title", mount.capitalize
      assert_select "svg[aria-hidden]", 0
      css_select("svg path").first["d"]
    end
    assert_equal paths.size, paths.uniq.size
  end

  test "unknown mounts leave no icon and invalid mount types fail explicitly" do
    assert_nil mount_icon(nil)
    assert_nil mount_icon("")
    assert_raises(KeyError) { mount_icon("invalid") }
  end

  test "decorative icons do not repeat adjacent text" do
    render html: mount_icon("fixed", decorative: true, size: 10, x: 25, y: 30)
    assert_select "svg[aria-hidden=true][width='10'][height='10'][x='25'][y='30']" do
      assert_select "title", 0
      assert_select "path[fill=currentColor]", 1
    end
    assert_select "svg[role], svg[aria-label]", 0
  end
end
