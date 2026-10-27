require "test_helper"

class CarouselDirectoryTest < ActionDispatch::IntegrationTest
  test "state options show alphabetical directory-wide counts and preserve filter values" do
    Carousel.create!(name: "Northern Carousel", region: "Montana")
    Carousel.create!(name: "Western Carousel", region: "Montana")
    Carousel.create!(name: "Southern Carousel", region: "Colorado")
    Carousel.create!(name: "Unlocated Carousel")
    Carousel.create!(name: "Blank Region Carousel", region: "")

    [ {}, { q: "Northern", region: "Montana" }, { q: "Missing", region: "Montana" } ].each do |filters|
      get carousels_path, params: filters

      assert_response :success
      options = css_select("select[name=region] option")
      assert_equal [ "All states", "Colorado (1)", "Montana (2)" ], options.map(&:text)
      assert_equal [ "", "Colorado", "Montana" ], options.map { |option| option["value"] }
      if filters[:region]
        assert_select "select[name=region] option[selected][value=Montana]", text: "Montana (2)"
      end
    end
  end

  test "directory shows its total below the filter form for every sort order" do
    Carousel.create!(name: "Northern Carousel")
    Carousel.create!(name: "Southern Carousel")

    [ nil, "name", "updated", "completeness" ].each do |sort|
      get carousels_path, params: { sort: }

      assert_response :success
      assert_select "form.form + p.carousel-count", text: "2 carousels listed"
      assert_select ".cards > .card", count: 2
    end
  end

  test "filtered directory shows matching count and total including no matches" do
    Carousel.create!(name: "Northern Carousel", region: "Montana")
    Carousel.create!(name: "Southern Carousel", region: "Colorado")

    [
      [ { q: "Northern" }, 1 ],
      [ { region: "Colorado" }, 1 ],
      [ { q: "Northern", region: "Colorado" }, 0 ]
    ].each do |filters, matches|
      get carousels_path, params: filters

      assert_response :success
      assert_select "form.form + p.carousel-count", text: "#{matches} of 2 carousels listed"
      assert_select ".cards > .card", count: matches
      assert_select "p", text: "No carousels match these filters." if matches.zero?
    end
  end

  test "directory uses singular wording for one carousel" do
    Carousel.create!(name: "Only Carousel")

    get carousels_path

    assert_response :success
    assert_select ".carousel-count", text: "1 carousel listed"
  end

  test "empty directory still shows a zero total" do
    get carousels_path

    assert_response :success
    assert_select ".carousel-count", text: "0 carousels listed"
    assert_select "p", text: "No carousels match these filters."
  end
end
