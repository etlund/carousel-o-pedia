require "test_helper"

class CarouselDirectoryTest < ActionDispatch::IntegrationTest
  test "directory searches primary and other names with region filters without duplicate cards" do
    carousel = Carousel.create!(name: "Elitch Gardens Carousel", region: "Colorado",
      other_names: "Philadelphia Toboggan Company Carousel #51\nPTC #51\nElitch Gardens")
    Carousel.create!(name: "Another Carousel", region: "Montana", other_names: "PTC #51")
    Carousel.create!(name: "Unrelated Carousel", region: "Colorado")

    [ "elitch", "TOBOGGAN", "ptc #51" ].each do |query|
      get carousels_path, params: { q: query, region: "Colorado" }

      assert_response :success
      assert_select ".cards > .card", count: 1
      assert_select ".card h2 a[href=?]", carousel_path(carousel), text: carousel.name
      assert_select ".card .other-names", text: "Other names: Philadelphia Toboggan Company Carousel #51; PTC #51; Elitch Gardens"
    end
  end

  test "directory treats wildcard characters in other name searches literally" do
    carousel = Carousel.create!(name: "Literal Carousel", other_names: "100%_Fun!")
    Carousel.create!(name: "Decoy Carousel", other_names: "100 percent Fun!")

    get carousels_path, params: { q: "%_" }

    assert_response :success
    assert_select ".cards > .card", count: 1
    assert_select ".card h2 a[href=?]", carousel_path(carousel)
  end

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

  test "country options show alphabetical directory-wide counts and exclude missing countries" do
    Carousel.create!(name: "Canadian Carousel", country: "Canada", region: "Ontario")
    Carousel.create!(name: "American Carousel", country: "United States", region: "Ontario")
    Carousel.create!(name: "Another American Carousel", country: "United States", region: "Montana")
    Carousel.create!(name: "Unknown Country")

    [ {}, { country: "Canada", region: "Montana", q: "Missing" } ].each do |filters|
      get carousels_path, params: filters
      assert_response :success
      options = css_select("select[name=country] option")
      assert_equal [ "All countries", "Canada (1)", "United States (2)" ], options.map(&:text)
      assert_equal [ "", "Canada", "United States" ], options.map { |option| option["value"] }
      assert_select "select[name=country] option[selected][value=Canada]", text: "Canada (1)" if filters[:country]
    end
  end

  test "country combines with state, name, and sorting and reports matching totals" do
    match = Carousel.create!(name: "Carousel One", other_names: "Shared Alias", country: "Canada", region: "Ontario")
    Carousel.create!(name: "Carousel Two", other_names: "Shared Alias", country: "United States", region: "Ontario")
    Carousel.create!(name: "Other", country: "Canada", region: "Quebec")
    get carousels_path, params: { country: "Canada", region: "Ontario", q: "alias", sort: "name" }
    assert_response :success
    assert_select ".carousel-count", text: "1 of 3 carousels listed"
    assert_select ".cards > .card", count: 1
    assert_select ".card h2 a[href=?]", carousel_path(match)
    assert_select "select[name=country] option[selected][value=Canada]"
    assert_select "select[name=sort] option[selected][value=name]"

    get carousels_path, params: { country: "Canada", region: "Ontario", q: "missing" }
    assert_select ".carousel-count", text: "0 of 3 carousels listed"
    assert_select "p", text: "No carousels match these filters."
    get carousels_path, params: { country: "Unknown country" }
    assert_response :not_found
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

  test "directory pages results and keeps filters in page links" do
    14.times { |i| Carousel.create!(name: "Carousel #{format("%02d", i)}", region: "Montana", country: "United States") }

    get carousels_path, params: { sort: "name", region: "Montana", country: "United States" }

    assert_response :success
    assert_select ".cards > .card", count: 12
    assert_select ".carousel-count", text: "14 of 14 carousels listed"
    assert_select "nav.pagy a[href*=?][href*=?]", "page=2", "region=Montana"
    assert_select "nav.pagy a[href*=?][href*=?]", "page=2", "country=United"

    get carousels_path, params: { sort: "name", region: "Montana", country: "United States", page: 2 }

    assert_response :success
    assert_select ".cards > .card", count: 2
    assert_select ".card h2 a", text: "Carousel 13"
  end

  test "directory omits page links when everything fits on one page" do
    Carousel.create!(name: "Only Carousel")

    get carousels_path

    assert_select "nav.pagy", count: 0
  end

  test "directory restores filters sorting and current page from a persistent cookie" do
    14.times do |i|
      Carousel.create!(name: "Carousel #{format("%02d", i)}", region: "Montana", country: "United States")
    end
    preferences = { q: "Carousel", region: "Montana", country: "United States", sort: "name", page: 2 }
    get carousels_path, params: preferences
    assert_response :success
    cookie = response.headers["Set-Cookie"].to_s
    assert_match(/carousel_directory=.*expires=/i, cookie)
    assert_match(/httponly/i, cookie)
    assert_match(/samesite=lax/i, cookie)

    [ root_path, carousels_path ].each do |path|
      get path
      assert_redirected_to carousels_path(preferences)
      follow_redirect!
      assert_response :success
      assert_select ".cards > .card", count: 2
      assert_select ".card h2 a", text: "Carousel 13"
      assert_select "input[name=q][value=Carousel]"
      assert_select "select[name=region] option[selected][value=Montana]"
      assert_select "select[name=country] option[selected][value='United States']"
      assert_select "select[name=sort] option[selected][value=name]"
      assert_select "nav.pagy a[href*=?][href*=?]", "page=1", "region=Montana"
    end
  end

  test "explicit filters replace saved filters and reset paging including blank values" do
    13.times { |i| Carousel.create!(name: "Carousel #{i}", region: "Montana", country: "United States") }
    Carousel.create!(name: "Other", region: "Colorado", country: "Canada")
    get carousels_path, params: { q: "Carousel", region: "Montana", country: "United States", sort: "name", page: 2 }

    get carousels_path, params: { country: "Canada" }
    assert_response :success
    assert_select ".card h2 a", text: "Other"
    assert_select "input[name=q][value]", count: 0
    assert_select "select[name=region] option[selected]", count: 0
    assert_select "select[name=sort] option[selected][value=completeness]"
    get carousels_path
    assert_redirected_to carousels_path(country: "Canada")
    follow_redirect!

    get carousels_path, params: { country: "", q: "", region: "", sort: "completeness" }
    assert_response :success
    assert_select ".cards > .card", count: 12
    assert_select "nav.pagy a[aria-current=page]", text: "1"
    get carousels_path
    assert_response :success
    assert_select ".carousel-count", text: "14 carousels listed"
  end

  test "clearing filters clears the cookie and restores defaults on later visits" do
    Carousel.create!(name: "Northern Carousel", region: "Montana")
    Carousel.create!(name: "Southern Carousel", region: "Colorado")
    get carousels_path, params: { q: "Northern", region: "Montana", sort: "name" }

    get carousels_path, params: { clear_filters: 1 }
    assert_redirected_to carousels_path
    follow_redirect!
    assert_response :success
    assert_not cookies[:carousel_directory].present?
    assert_select ".cards > .card", count: 2
    assert_select "select[name=sort] option[selected][value=completeness]"

    get root_path
    assert_response :success
    assert_select ".cards > .card", count: 2
  end

  test "invalid requests do not replace saved preferences and tampered cookies are ignored" do
    Carousel.create!(name: "Northern Carousel", region: "Montana")
    get carousels_path, params: { region: "Montana" }
    get carousels_path, params: { sort: "invalid" }
    assert_response :bad_request
    get carousels_path
    assert_redirected_to carousels_path(region: "Montana")
    follow_redirect!

    cookies[:carousel_directory] = "tampered"
    get carousels_path
    assert_response :success
    assert_select ".cards > .card", count: 1
  end

  test "saved locations removed from the directory no longer block returning visitors" do
    carousel = Carousel.create!(name: "Northern Carousel", region: "Montana")
    get carousels_path, params: { region: "Montana" }
    carousel.update!(region: "Colorado")

    get carousels_path
    assert_redirected_to carousels_path
    follow_redirect!
    assert_response :success
    assert_select ".cards > .card", count: 1
    assert_select "select[name=region] option[selected]", count: 0
  end
end
