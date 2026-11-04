require "test_helper"
require "csv"

class CarouselCsvTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
    @carousel = Carousel.create!(name: "Example", city: "Before", country: "United States")
  end

  test "export contains all fields and unchanged rows round trip without history or changes" do
    maker = Maker.create!(name: "Maker")
    @carousel.update!(maker:, other_names: "Alternate\nAnother", body: "=literal\ntext",
      rows_count: 2, summary_sources: "Research", ring_details: { "A" => { "positions_count" => 5 } })
    csv = CarouselCsv.export
    row = CSV.parse(csv, headers: true).find { _1["id"] == @carousel.id.to_s }
    assert_equal CarouselCsv::HEADERS, row.headers
    assert_equal "'=literal\ntext", row["body"]
    assert_nil row["published_horses_count"]
    assert_equal "5", row["ring_A_positions_count"]
    import = CarouselCsv.new(csv)
    assert import.valid?, import.items.flat_map(&:errors).inspect
    assert_empty import.items.find { _1.record.id == @carousel.id }.changes
    assert_no_difference "PaperTrail::Version.count" do
      counts = CarouselCsv.apply!(import.preview_token(@user), @user)
      assert_equal 1, counts[:unchanged]
    end
    assert_equal "=literal\ntext", @carousel.reload.body
  end

  test "merges provided values leaves blanks alone and supports explicit clears and zero" do
    @carousel.update!(venue: "Old venue", published_horses_count: 3, summary_sources: "Source")
    csv = rows([ %w[id updated_at name city venue published_horses_count],
      [ @carousel.id, stamp(@carousel), "", "", "__CLEAR__", "0" ] ])
    import = CarouselCsv.new(csv)
    assert import.valid?, import.items.flat_map(&:errors).inspect
    CarouselCsv.apply!(import.preview_token(@user), @user)
    assert_equal "Before", @carousel.reload.city
    assert_nil @carousel.venue
    assert_equal 0, @carousel.published_horses_count
  end

  test "escaped literal markers apostrophes backslashes and spreadsheet formulas round trip" do
    [ "__CLEAR__", "\\__CLEAR__", "\\\\path", "'=original", "=formula", "+text", "-text", "@text", "\ttext" ].each do |value|
      @carousel.update!(body: value)
      import = CarouselCsv.new(CarouselCsv.export)
      assert import.valid?, "#{value.inspect}: #{import.items.flat_map(&:errors).inspect}"
      assert_empty import.items.find { _1.record.id == @carousel.id }.changes, value.inspect
    end
  end

  test "new rows require names and report possible existing and batch duplicates" do
    import = CarouselCsv.new(rows([ %w[name city], [ "Example", "Elsewhere" ], [ "Example", "Other" ] ]))
    assert import.valid?, import.items.flat_map(&:errors).inspect
    assert_match(/Possible duplicate/, import.items.first.warnings.join)
    assert_match(/Another new row/, import.items.last.warnings.join)
    assert_difference "Carousel.count", 2 do
      CarouselCsv.apply!(import.preview_token(@user), @user)
    end
    assert_equal 2, Carousel.where(name: "Example").where.not(id: @carousel.id).pluck(:slug).uniq.size
  end

  test "new imports default to unknown while explicit and existing statuses are preserved" do
    csv = rows([ %w[id updated_at name status],
      [ "", "", "Missing status", "" ],
      [ "", "", "Known operating", "operating" ],
      [ @carousel.id, stamp(@carousel), "", "" ] ])
    import = CarouselCsv.new(csv)
    assert import.valid?, import.items.flat_map(&:errors).inspect
    assert_equal [ nil, "unknown" ], import.items.first.changes["status"]
    assert_equal [ nil, "operating" ], import.items.second.changes["status"]
    assert_not import.items.last.changes.key?("status")
    CarouselCsv.apply!(import.preview_token(@user), @user)
    assert_equal "unknown", Carousel.find_by!(name: "Missing status").status
    assert_equal "operating", Carousel.find_by!(name: "Known operating").status
    assert_equal "operating", @carousel.reload.status
    assert_equal "operating", Carousel.new.status
    reimport = CarouselCsv.new(CarouselCsv.export)
    assert reimport.valid?, reimport.items.flat_map(&:errors).inspect
    assert reimport.items.all? { |item| item.changes.empty? }
  end

  test "unknown can be assigned explicitly but clearing status is invalid" do
    import = CarouselCsv.new(rows([ %w[id updated_at name status], [ @carousel.id, stamp(@carousel), "", "unknown" ] ]))
    assert import.valid?, import.items.flat_map(&:errors).inspect
    CarouselCsv.apply!(import.preview_token(@user), @user)
    assert_equal "unknown", @carousel.reload.status

    import = CarouselCsv.new(rows([ %w[name status], [ "New", "__CLEAR__" ] ]))
    assert_not import.valid?
    assert_match(/Status/, import.items.first.errors.join)
  end

  test "rejects stale nonexistent duplicate and modified reference IDs" do
    [ [ @carousel.id, "old", @carousel.slug ], [ 999999, "old", "" ],
      [ "abc", "", "" ], [ @carousel.id, stamp(@carousel), "other" ] ].each do |id, time, slug|
      import = CarouselCsv.new(rows([ %w[id updated_at slug name], [ id, time, slug, "Changed" ] ]))
      assert_not import.valid?
      assert import.items.first.errors.any?
    end
    import = CarouselCsv.new(rows([ %w[id updated_at name],
      [ @carousel.id, stamp(@carousel), "Changed" ], [ @carousel.id, stamp(@carousel), "Changed again" ] ]))
    assert_not import.valid?
    assert_match(/more than once/, import.items.last.errors.join)
  end

  test "validates numbers, references, sources, URLs, and ring details without coercion" do
    [
      { "published_horses_count" => "2.5" },
      { "published_horses_count" => "3" },
      { "maker_id" => "999999" },
      { "official_url" => "javascript:alert(1)" },
      { "rows_count" => "2", "ring_A_horses_count" => "4", "ring_A_positions_count" => "2", "summary_sources" => "Source" },
      { "layout_provisional" => "yes" }
    ].each do |values|
      import = CarouselCsv.new(rows([ [ "name" ] + values.keys, [ "New carousel" ] + values.values ]))
      assert_not import.valid?, values.inspect
      assert import.items.first.errors.any?
    end
  end

  test "does not allow known dimensions to be changed and bounds new seat generation" do
    @carousel.update!(sections_count: 3, rows_count: 2)
    import = CarouselCsv.new(rows([ %w[id updated_at name sections_count], [ @carousel.id, stamp(@carousel), "", "4" ] ]))
    assert_not import.valid?
    assert_match(/dimensions cannot be changed/, import.items.first.errors.join)
    error = assert_raises(CarouselCsv::Error) do
      CarouselCsv.new(rows([ %w[name sections_count rows_count], [ "Huge", "10001", "1" ] ]))
    end
    assert_match(/10,?000|10000/, error.message)
  end

  test "creating a layout generates unknown seats and no figures" do
    csv = rows([ %w[id updated_at name sections_count rows_count],
      [ @carousel.id, stamp(@carousel), "", "3", "2" ] ])
    import = CarouselCsv.new(csv)
    assert import.valid?, import.items.flat_map(&:errors).inspect
    assert_difference "Seat.count", 6 do
      assert_no_difference "Figure.count" do
        CarouselCsv.apply!(import.preview_token(@user), @user)
      end
    end
    assert_equal [ "unknown" ], @carousel.seats.distinct.pluck(:state)
  end

  test "a save failure rolls back the entire batch and its receipt" do
    import = CarouselCsv.new(rows([ %w[name], [ "First new" ], [ "Second new" ] ]))
    token = import.preview_token(@user)
    failure = -> { raise ActiveRecord::RecordInvalid.new(self) if name == "Second new" }
    Carousel.set_callback(:save, :before, failure)
    begin
      assert_no_difference [ "Carousel.count", "PaperTrail::Version.count", "CarouselCsvImportReceipt.count" ] do
        assert_raises(ActiveRecord::RecordInvalid) { CarouselCsv.apply!(token, @user) }
      end
    ensure
      Carousel.skip_callback(:save, :before, failure)
    end
  end

  test "row numbers include blank spreadsheet rows" do
    import = CarouselCsv.new("name\nFirst\n\nSecond\n")
    assert_equal [ 2, 4 ], import.items.map(&:number)
  end

  test "preview is user bound expires is single use and detects changed records and duplicates" do
    csv = rows([ %w[id updated_at name city], [ @carousel.id, stamp(@carousel), "", "After" ] ])
    import = CarouselCsv.new(csv)
    token = import.preview_token(@user)
    assert_raises(CarouselCsv::Conflict) { CarouselCsv.apply!(token, users(:editor)) }
    @carousel.update!(city: "Someone else's edit")
    assert_raises(CarouselCsv::Conflict) { CarouselCsv.apply!(token, @user) }
    assert_equal "Someone else's edit", @carousel.reload.city

    import = CarouselCsv.new(rows([ %w[name], [ "Brand new" ] ]))
    token = import.preview_token(@user)
    Carousel.create!(name: "Brand new")
    assert_raises(CarouselCsv::Conflict) { CarouselCsv.apply!(token, @user) }
    assert_equal 1, Carousel.where(name: "Brand new").count

    token = CarouselCsv.new(rows([ %w[name], [ "Once" ] ])).preview_token(@user)
    CarouselCsv.apply!(token, @user)
    assert_raises(CarouselCsv::Conflict) { CarouselCsv.apply!(token, @user) }
    assert_equal 1, Carousel.where(name: "Once").count
    token = CarouselCsv.new(rows([ %w[name], [ "Expired" ] ])).preview_token(@user)
    travel 31.minutes do
      assert_raises(CarouselCsv::Conflict) { CarouselCsv.apply!(token, @user) }
    end
  end

  test "invalid CSV and batches above limits are reported" do
    [ "", "name,name\nx,y\n", "name,unexpected\nx,y\n", "name\n\"bad",
      "name\n#{"x" * CarouselCsv::MAX_BYTES}" ].each do |input|
      assert_raises(CarouselCsv::Error) { CarouselCsv.new(input) }
    end
    assert_raises(CarouselCsv::Error) do
      CarouselCsv.new("name\n" + ("test\n" * (CarouselCsv::MAX_ROWS + 1)))
    end
  end

  private
    def rows(values) = CSV.generate { |csv| values.each { |row| csv << row } }
    def stamp(carousel) = carousel.updated_at.utc.iso8601(6)
end
