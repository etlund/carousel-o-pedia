require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds the Great Northern Carousel from the seating chart" do
    carousel = load_seeds

    assert_equal 14, carousel.sections_count
    assert_equal 3, carousel.rows_count
    assert_equal({ "horse" => 18, "menagerie" => 19, "chariot" => 2 }, carousel.category_totals)
    assert_equal "Titan the Hippocampus", carousel.lead_figure.name
    assert_equal "Cutty the Trout", carousel.seat("3A").figure.name
    assert_equal "Gulliver", carousel.seat("9A").figure.name
    assert_equal %w[ A B C ], carousel.seat("4A").rows_covered
    assert_equal "Otter 2", carousel.seat("9C").figure.name
    assert_equal "Sandhill Cranes", carousel.seat("11A").figure.name
    assert_equal "Pronghorn", carousel.seat("12B").figure.figure_type.name
    assert carousel.seat("8C").confirmed?
    assert_not carousel.seat("8B").confirmed?
  end

  test "loading seeds again restores Great Northern data without creating duplicates" do
    carousel = load_seeds
    carousel.update!(name: "Edited name", rotation: "clockwise")
    carousel.seat("9A").figure.update!(name: "Edited figure name")
    carousel.seat("9A").figure.update!(description: "Edited on the wiki")
    carousel.seat("9A").update!(confidence: "best_reading")

    assert_no_difference %w[ Carousel.count Maker.count Seat.count Figure.count Placement.count FigureType.count ] do
      load_seeds
    end

    carousel.reload
    assert_equal "Great Northern Carousel", carousel.name
    assert_equal "counterclockwise", carousel.rotation
    assert_equal "Gulliver", carousel.seat("9A").figure.name
    assert_includes carousel.seat("9A").figure.description, "G.N. Mining Co."
    assert carousel.seat("9A").confirmed?
    assert carousel.seats.all? { _1.state == "filled" }
  end

  test "seeds A Carousel for Missoula with sourced history and video seating" do
    load_seeds
    carousel = Carousel.find_by!(slug: "a-carousel-for-missoula")

    assert_equal "A Carousel for Missoula", carousel.name
    assert_equal "Missoula, Montana, United States", carousel.location
    assert_equal "Caras Park", carousel.venue
    assert_equal "operating", carousel.status
    assert_equal 1995, carousel.year_opened
    assert_nil carousel.year_built
    assert_equal "Chuck Kaparich", carousel.maker.name
    assert_equal "person", carousel.maker.kind
    assert_equal 14, carousel.sections_count
    assert_equal 3, carousel.rows_count
    assert_equal "counterclockwise", carousel.rotation
    assert_equal 40, carousel.seats.count
    assert carousel.seats.all? { _1.state == "filled" }
    assert_equal 39, carousel.seats.where(confidence: "best_reading").count
    assert_equal 40, carousel.placements.current.count
    assert_equal "Columbia Belle", carousel.lead_figure.name
    assert_equal "filled", carousel.lead_seat.state
    assert carousel.lead_seat.confirmed?
    assert_equal({ "horse" => 37, "menagerie" => 1, "chariot" => 2 }, carousel.category_totals)
    assert_includes carousel.body, "May 27, 1995"
    assert_includes carousel.body, "38 permanent ponies, 3 replacement ponies, 2 chariots"
    assert_includes carousel.body, "not a verified current survey"
    assert_not_includes carousel.body, "provisional"
    assert_includes carousel.body, "not a verified historical seat code"
    assert_no_match(/\bpage \d+/i, carousel.body)
    assert_includes carousel.body, "https://www.missoulacarousel.org/building-a-community-dream-a-carousel-for-missoula/"
    assert_includes carousel.body, "RING MACHINE entry describes equipment"

    expected_sections = [
      [ "Columbia Belle", "Leo the Lionheart", "Star Boy" ],
      [ "Evansgone", "Bud", "Marguerite" ],
      [ "Sleipnir", "Soro", "Rubie" ],
      [ "Bogie", "Toyo", "Orchard Belle" ],
      [ "Midnight Rose", "Cherished Angel", "Lil' Buck" ],
      [ "Prairie Rose", "Sweet Sue", "Koko" ],
      [ "Altrusa Chariot", nil, "Avalon" ],
      [ "Big Sky Gaiety", "Sir Franklin", "Zonta" ],
      [ "Paint", "Moonlight", "Montana Appaloosa" ],
      [ "Red Ribbons", "Meriwether", "Seattle Sue" ],
      [ "Cannonball", "Snapples", "American Beauty" ],
      [ "Dispatch", "Prince", "Hard Hat" ],
      [ "Scaffi", "Freya", "Norm" ],
      [ "Eagle Chariot", nil, "Pal's Pal" ]
    ]
    expected_sections.each_with_index do |names, index|
      names.each_with_index do |name, row|
        code = "#{index + 1}#{"ABC"[row]}"
        if name
          assert_equal name, carousel.seat(code).figure.name, code
          assert_includes carousel.seat(code).figure.body, "Video reading: seat #{code}"
          assert_includes carousel.seat(code).figure.body, "https://www.youtube.com/watch?v=8E3DemQtIis&t="
        else
          assert_nil carousel.seat(code), code
        end
      end
    end
    %w[ 7A 14A ].each { assert_equal %w[ A B ], carousel.seat(_1).rows_covered }
  end

  test "seeds the complete Missoula inventory from the booklet and NCA captions" do
    load_seeds
    inventory = Figure.where("figures.slug LIKE ?", "a-carousel-for-missoula-%")
    pony_names = [
      "Columbia Belle", "Leo the Lionheart", "Star Boy", "Evansgone", "Bud", "Marguerite",
      "Dispatch", "Soro", "Rubie", "Silver", "Toyo", "Orchard Belle", "Midnight Rose",
      "Cherished Angel", "Lil' Buck", "Prairie Rose", "Sweet Sue", "Koko", "Avalon",
      "Big Sky Gaiety", "Sir Franklin", "Zonta", "Bogie", "Moonlight", "Montana Appaloosa",
      "Red Ribbons", "Meriwether", "Seattle Sue", "Cannonball", "Snapples", "American Beauty",
      "Paint", "Prince", "Hard Hat", "Sleipnir", "Freya", "Norm", "Pal's Pal",
      "Santa's Pony", "Patches", "Low Bid"
    ]

    assert_equal 45, inventory.count
    assert_equal pony_names.sort, inventory.joins(:figure_type).where(figure_types: { category: "horse" }).pluck(:name).sort
    assert_equal [ "Altrusa Chariot", "Eagle Chariot" ], inventory.joins(:figure_type).where(figure_types: { category: "chariot" }).order(:name).pluck(:name)
    assert_equal [ "Lucky Red Ringer", "Scaffi" ], inventory.joins(:figure_type).where(figure_types: { category: "menagerie" }).order(:name).pluck(:name)
    assert_equal [ "Low Bid", "Lucky Red Ringer", "Patches", "Santa's Pony", "Silver" ], inventory.where.missing(:current_placement).order(:name).pluck(:name)
    inventory.each do |figure|
      assert_predicate figure.description, :present?
      assert_includes figure.body, "A Carousel for Missoula inventory."
      assert_no_match(/\bpage \d+/i, figure.body)
      assert_includes figure.body, figure.name == "Scaffi" ? "Source: Eric's booklet" : "https://carousels.org/psp/Missoula/"
    end

    lead = missoula_figure("Columbia Belle")
    assert_equal "Steve Weiler", lead.carver.name
    assert_equal "Pat and Kitte Robins", lead.sponsor
    assert_includes lead.body, "Design: John Thompson"
    assert_includes lead.body, "Painting: Bette Largent"
    assert_nil missoula_figure("Leo the Lionheart").carver
    assert_includes missoula_figure("Leo the Lionheart").body, "body and legs, Jim Dunlap"
    assert_equal "Chuck Kaparich", missoula_figure("Zonta").carver.name
    assert_includes missoula_figure("Midnight Rose").body, "Al Kapusta and Heinz Schleyer"
    assert_includes missoula_figure("Eagle Chariot").description, "wheelchair-accessible"
    assert_includes missoula_figure("Altrusa Chariot").description, "wheelchair-accessible"

    { "Santa's Pony" => "Outside-row", "Patches" => "Middle-row", "Low Bid" => "Inside-row" }.each do |name, row|
      figure = missoula_figure(name)
      assert_includes figure.body, "#{row} replacement pony"
      assert_nil figure.current_placement
    end

    assert_includes missoula_figure("Scaffi").description, "Eric confirmed its identity as Scaffi"
    assert_nil missoula_figure("Scaffi").sponsor
    assert_equal "13A", missoula_figure("Scaffi").current_placement.seat.code
    assert_includes missoula_figure("Lucky Red Ringer").body, "not a riding figure"
    assert_nil missoula_figure("Lucky Red Ringer").current_placement
    assert_not inventory.exists?(name: "RING MACHINE")
  end

  test "loading Missoula seeds again restores seeded attributes without creating duplicates" do
    load_seeds
    carousel = Carousel.find_by!(slug: "a-carousel-for-missoula")
    carousel.update!(body: "Edited history", sections_count: 15, rotation: "clockwise")
    carousel.maker.update!(body: "Edited biography")
    missoula_figure("Columbia Belle").update!(name: "Edited name", sponsor: "Edited sponsor")
    missoula_figure("Columbia Belle").carver.update!(name: "Edited carver")
    missoula_figure("Patches").update!(description: "Edited replacement description")
    missoula_figure("Patches").figure_type.update!(name: "Edited type", category: "menagerie")

    assert_no_difference %w[ Carousel.count Maker.count Seat.count Figure.count Placement.count FigureType.count ] do
      load_seeds
    end

    carousel.reload
    assert_includes carousel.body, "May 27, 1995"
    assert_equal 14, carousel.sections_count
    assert_equal "counterclockwise", carousel.rotation
    assert_includes carousel.maker.body, "cabinet-maker"
    assert_equal "Columbia Belle", carousel.lead_figure.name
    assert_equal "Pat and Kitte Robins", carousel.lead_figure.sponsor
    assert_equal "Steve Weiler", carousel.lead_figure.carver.name
    assert_equal "Horse", carousel.lead_figure.figure_type.name
    assert_equal "horse", carousel.lead_figure.category
    assert_includes missoula_figure("Patches").description, "Bertlin and Mostad"
  end

  test "authoritative seeds restore moved figures and chart shapes and keep unrelated records" do
    great_northern = load_seeds
    missoula = Carousel.find_by!(slug: "a-carousel-for-missoula")
    unrelated = create_figure("Unrelated wiki figure")
    SeatAssignment.new(great_northern.seat("1A"), unrelated).save!
    SeatAssignment.new(missoula.seat("2A"), great_northern.seat("3A").figure).save!
    SeatAssignment.new(great_northern.seat("2A"), missoula_figure("Patches")).save!
    SeatAssignment.new(missoula.seat("3A"), missoula_figure("Columbia Belle")).save!
    great_northern.seat("4A").update!(rows_spanned: 1)
    SeatAssignment.new(missoula.seat("4B"), nil).save!
    missoula.seat("4A").update!(rows_spanned: 2)
    missoula.seat("7A").update!(rows_spanned: 1)
    SeatAssignment.new(missoula.seat("7B"), missoula_figure("Silver")).save!
    missoula.update!(sections_count: 15, rows_count: 4)
    missoula.fill_missing_seats

    load_seeds

    assert_equal "Titan the Hippocampus", great_northern.reload.lead_figure.name
    assert_equal "Cutty the Trout", great_northern.seat("3A").figure.name
    assert_equal %w[ A B C ], great_northern.seat("4A").rows_covered
    assert_equal 39, great_northern.seats.count
    assert great_northern.seats.all? { _1.state == "filled" }
    assert_equal "Columbia Belle", missoula.reload.lead_figure.name
    assert_equal 40, missoula.seats.count
    assert missoula.seats.all? { _1.state == "filled" }
    assert_equal 40, missoula.placements.current.count
    assert_equal "Toyo", missoula.seat("4B").figure.name
    assert_equal %w[ A B ], missoula.seat("7A").rows_covered
    assert_nil missoula_figure("Silver").reload.current_placement
    assert_nil missoula_figure("Patches").reload.current_placement
    assert Figure.exists?(unrelated.id)
    assert_nil unrelated.reload.current_placement
    assert Placement.where(figure: unrelated).where.not(ended_on: nil).exists?

    assert_no_difference %w[ Carousel.count Maker.count Seat.count Figure.count Placement.count FigureType.count PaperTrail::Version.count ] do
      load_seeds
    end
  end

  test "seeds Spokane with sourced history and every documented figure position" do
    load_seeds
    carousel = Carousel.find_by!(slug: "spokane-looff-carrousel")
    inventory = Figure.where("figures.slug LIKE ?", "spokane-looff-carrousel-%")

    assert_equal "Looff Carrousel", carousel.name
    assert_equal "Spokane, Washington, United States", carousel.location
    assert_equal "Riverfront Park", carousel.venue
    assert_equal "operating", carousel.status
    assert_equal 1909, carousel.year_built
    assert_equal 1909, carousel.year_opened
    assert_equal "Charles Looff", carousel.maker.name
    assert_equal "person", carousel.maker.kind
    assert_equal 20, carousel.sections_count
    assert_equal 3, carousel.rows_count
    assert_equal "counterclockwise", carousel.rotation
    assert_equal 58, carousel.seats.count
    assert carousel.seats.all? { _1.state == "filled" && _1.confirmed? }
    assert_equal "Geri Giraffe", carousel.lead_figure.name
    assert_equal 58, carousel.placements.current.count
    assert_equal({ "horse" => 54, "menagerie" => 2, "chariot" => 2 }, carousel.category_totals)
    assert_includes carousel.body, "July 18, 1909"
    assert_includes carousel.body, "54 jumping horses, 1 giraffe, 1 tiger, and 2 Chinese dragon chariots"
    assert_includes carousel.body, "confirms twenty radial rows"
    assert_not_includes carousel.body, "provisional"
    assert_includes carousel.body, "contemporary middle-row jumper"
    assert_includes carousel.body, "These sources differ"
    assert_includes carousel.body, "https://my.spokanecity.org/riverfrontspokane/attractions/looff-carrousel/"
    assert_includes carousel.body, "https://carousels.org/psp/SpokaneWA/"
    assert_includes carousel.body, "https://carousels.org/USACensus/census.pl?NCANo=221"
    assert_includes carousel.body, "https://spokanecarrousel.org/figurepics.html"

    expected_sections = [
      [ "Geri Giraffe", "Dragon Chariot 1", nil ],
      [ "Hunter", "Hutton", "Song" ],
      [ "Oliver's Pride", "Kazumi", "Candy Cane" ],
      [ "Snow Dancer", "Sweetie Pie", "Cooper" ],
      [ "LoofFun", "Koko", "Little Beauty" ],
      [ "Chastity", "Faith", "Scotty" ],
      [ "Casper, the Ghost Horse", "Steely Dan", "Valentine" ],
      [ "Rainbow Warrior", "Corbin", "Katydid" ],
      [ "Cisco", "Penny Lane", "Trigger" ],
      [ "Warrior", "The Christmas Horse", "Lloyd Vogel" ],
      [ "Sneaky the Tiger", "Dragon Chariot 2", nil ],
      [ "Miss Liberty", "Etta May", "Aimee" ],
      [ "Prince", "Paige", "Cotton Candy" ],
      [ "Bing", "Noel", "Wilber" ],
      [ "Scout", "Joker", "Rufus" ],
      [ "Duke of Earl", "Mr. Ed", "Jameson" ],
      [ "Daisy, the Wishing Horse", "Emma Looff Vogel", "Randina" ],
      [ "Athena", "Stella", "Louis Vogel" ],
      [ "Tina", "Rocky", "Arizona" ],
      [ "The Parrot Horse", "Michelle", "Wendy Jay" ]
    ]
    expected_sections.each_with_index do |names, index|
      names.each_with_index do |name, row|
        seat = carousel.seat("#{index + 1}#{%w[ A B C ].fetch(row)}")
        if name
          assert_equal name, seat.figure.name, seat.code
          assert_equal "jumper", seat.figure.mount if seat.figure.category == "horse"
          assert_includes seat.figure.body, "wiki seat #{seat.code}"
        else
          assert_nil seat
        end
      end
    end

    assert_equal %w[ B C ], carousel.seat("1B").rows_covered
    assert_equal %w[ B C ], carousel.seat("11B").rows_covered
    assert_equal "fixed", carousel.seat("1B").figure.mount
    assert_equal "fixed", carousel.seat("11B").figure.mount
    assert_includes carousel.seat("20C").figure.body, "https://spokanecarrousel.org/20i.html"
    assert_equal 60, inventory.count
    assert_equal [ "Billy Bob", "Missoula Lilac" ], inventory.where.missing(:current_placement).order(:name).pluck(:name)
    assert_equal 2, inventory.joins(:figure_type).where(figure_types: { category: "chariot" }).count
    assert_equal "stander", carousel.seat("1A").figure.mount
    assert_equal "stander", carousel.seat("11A").figure.mount
    assert_not_equal missoula_figure("Koko"), carousel.seat("5B").figure
    assert_not_equal Figure.find_by!(slug: "trigger"), carousel.seat("9C").figure
    inventory.each do |figure|
      assert_nil figure.carver
      assert_nil figure.year_carved
      assert_includes figure.body, "https://spokanecarrousel.org/"
    end
    goat = inventory.find_by!(name: "Billy Bob")
    assert_includes goat.description, "around 1885"
    assert_includes goat.description, "approximately 1890"
    assert_includes goat.body, "not a permanent platform assignment"
    assert_nil goat.mount
    assert_includes inventory.find_by!(name: "Missoula Lilac").description, "Chuck's garage"
    assert_includes carousel.seat("1A").figure.description, "without confirming"
  end

  test "Spokane seeds restore authoritative figure positions and are repeatable" do
    load_seeds
    carousel = Carousel.find_by!(slug: "spokane-looff-carrousel")
    giraffe = Figure.find_by!(slug: "spokane-looff-carrousel-giraffe")
    carousel.update!(name: "Edited carousel", sections_count: 21, rows_count: 4, rotation: "clockwise")
    carousel.fill_missing_seats
    carousel.maker.update!(name: "Edited maker")
    giraffe.update!(name: "Edited giraffe", description: "Edited description")
    SeatAssignment.new(carousel.seat("2A"), giraffe).save!
    goat = Figure.find_by!(slug: "spokane-looff-carrousel-spare-goat")
    SeatAssignment.new(carousel.seat("3A"), goat).save!
    carousel.seat("1B").update!(rows_spanned: 1, confidence: "best_reading")

    load_seeds

    assert_equal "Looff Carrousel", carousel.reload.name
    assert_equal "Charles Looff", carousel.maker.name
    assert_equal 20, carousel.sections_count
    assert_equal 3, carousel.rows_count
    assert_equal "counterclockwise", carousel.rotation
    assert_equal 58, carousel.seats.count
    assert carousel.seats.all? { _1.state == "filled" && _1.confirmed? }
    assert_equal 58, carousel.placements.current.count
    assert_equal "Geri Giraffe", giraffe.reload.name
    assert_equal "1A", giraffe.seat.code
    assert_equal "Hunter", carousel.seat("2A").figure.name
    assert_equal "Oliver's Pride", carousel.seat("3A").figure.name
    assert_equal %w[ B C ], carousel.seat("1B").rows_covered
    assert_nil goat.reload.current_placement
    assert Placement.where(figure: giraffe).where.not(ended_on: nil).exists?
    assert Placement.where(figure: goat).where.not(ended_on: nil).exists?

    assert_no_difference %w[ Carousel.count Maker.count Seat.count Figure.count Placement.count FigureType.count PaperTrail::Version.count ] do
      load_seeds
    end
  end

  test "Spokane seed upgrades the five shell figures without duplicate identities" do
    carousel = Carousel.create!(slug: "spokane-looff-carrousel", name: "Looff shell", sections_count: 20, rows_count: 3)
    shell_figures = {
      "giraffe" => [ "Giraffe", "Giraffe", "menagerie" ],
      "tiger" => [ "Tiger", "Tiger", "menagerie" ],
      "dragon-chariot-1" => [ "Dragon Chariot 1", "Chariot", "chariot" ],
      "dragon-chariot-2" => [ "Dragon Chariot 2", "Chariot", "chariot" ],
      "spare-goat" => [ "Spare Goat", "Goat", "menagerie" ]
    }.to_h do |suffix, (name, type_name, category)|
      type = FigureType.find_or_create_by!(name: type_name) { _1.category = category }
      figure = Figure.create!(slug: "#{carousel.slug}-#{suffix}", name:, figure_type: type, carousel:)
      [ suffix, figure.id ]
    end

    load_seeds

    shell_figures.each do |suffix, id|
      assert_equal id, Figure.find_by!(slug: "#{carousel.slug}-#{suffix}").id
    end
    assert_equal 60, Figure.where("figures.slug LIKE ?", "spokane-looff-carrousel-%").count
    assert_equal "Geri Giraffe", Figure.find(shell_figures.fetch("giraffe")).name
    assert_equal "Sneaky the Tiger", Figure.find(shell_figures.fetch("tiger")).name
    assert_equal "Billy Bob", Figure.find(shell_figures.fetch("spare-goat")).name
    assert_equal 58, carousel.placements.current.count
  end

  test "Salem seeds retain documented history and Eric's saved video assignments" do
    load_seeds
    carousel = Carousel.find_by!(slug: "salems-riverfront-carousel")
    assert_equal "Salem's Riverfront Carousel", carousel.name
    assert_equal "Salem, Oregon, United States", carousel.location
    assert_equal "Riverfront Park", carousel.venue
    assert_equal [ 2001, 2001 ], [ carousel.year_built, carousel.year_opened ]
    assert_equal "Chance", carousel.maker.name
    assert_equal "company", carousel.maker.kind
    assert_equal [ 12, 3, "counterclockwise" ], [ carousel.sections_count, carousel.rows_count, carousel.rotation ]
    assert_equal 34, carousel.seats.count
    assert_equal 0, carousel.seats.where(state: "unknown").count
    assert_equal 34, carousel.placements.current.count
    assert_equal 34, carousel.seats.where(state: "filled", confidence: "confirmed").count
    assert_equal "The General", carousel.lead_figure.name
    assert carousel.lead_seat.confirmed?
    assert_equal({ "horse" => 24, "menagerie" => 8, "chariot" => 2 }, carousel.category_totals)
    [ "June 2, 2001", "1996", "June 14, 2000", "Johnson Style 163", "28 jumping horses and 6 standing horses",
      "not a manufacturer's plan", "not a verified filming date", "not a published seat number",
      "https://www.youtube.com/watch?v=rSIXxKsNcXA&t=87s",
      "https://www.youtube.com/watch?v=YGSPO9XFu-8", "October 24, 2026" ].each do |detail|
      assert_includes carousel.body, detail
    end

    expected_sections = [
      [ "The General", "Highland Laddie", "Snickerdoodle" ],
      [ "Blackberry", "Cloud Walker", "Mr. Hopkins" ],
      [ "American Flyer", "Magic", "Heather" ],
      [ "Chuck Wagon", nil, "Bondo" ],
      [ "Glad Tidings", "Legal Tender", "Brown Beauty" ],
      [ "Jazz", "Kate", "Francis the Mule" ],
      [ "Harriett", "Sonshine", "G.J." ],
      [ "Emerald the Dragon", "Rosinante", "Hero" ],
      [ "Ramses the Friendly Shark", "West Wind", "Thunder" ],
      [ "Covered Wagon", nil, "Billiebom" ],
      [ "Abby", "Gigi", "Stardust" ],
      [ "Bucky", "Liberty", "Goldie" ]
    ]
    expected_sections.each_with_index do |names, index|
      names.each_with_index do |name, row|
        code = "#{index + 1}#{"ABC"[row]}"
        seat = carousel.seat(code)
        if name
          assert_equal name, seat.figure.name, code
          assert seat.confirmed?, code
          assert_includes seat.figure.body, "Video-derived layout: wiki seat #{code}."
          assert_includes seat.figure.body, "https://www.youtube.com/watch?v=YGSPO9XFu-8"
        else
          assert_nil seat, code
        end
      end
    end
    %w[ 4A 10A ].each { assert_equal %w[ A B ], carousel.seat(_1).rows_covered }
  end

  test "Salem seeds include the complete sourced catalog without inventing dates or positions" do
    load_seeds
    inventory = Figure.where("figures.slug LIKE ?", "salems-riverfront-carousel-%")
    originals = [
      "Abby", "Ambassador", "American Flyer", "Big Sky", "Bondo", "Billiebom", "Brown Beauty", "Bucky",
      "Cloud Walker", "Francis the Mule", "The General", "G.J.", "Glad Tidings", "Goldie", "Happy Holidays",
      "Hero", "Heather", "Kate", "Jazz", "Highland Laddie", "Legal Tender", "Liberty", "Magic", "Little Joe",
      "Maudie Ann", "Morning Glory", "Nugget", "Raindancer", "Razzle Dazzle", "Rosinante", "Ruby Rose",
      "Sarah Jane", "Salem Peace Pony", "Seahorse Dawn", "Sonshine", "Snickerdoodle", "Stardust",
      "Spring Charm", "Thunder", "Tropical Breeze", "West Wind", "Woodland's Crusader"
    ]
    new_dreams = [
      "Dakota Darlin'", "Benny the Beaver", "Blackberry", "The Duck", "Emerald the Dragon", "Gigi",
      "Harriett", "Larry the Circus Pony", "Mr. Hopkins", "Pancho", "Mr. Sprinkles", "Patch the Pirate Pony",
      "Ramses the Friendly Shark", "Ronnie the Rabbit", "Sally Brown the Hummingbird", "Sweet Pea the Llama", "Sweet Tart"
    ]
    expected_names = originals + new_dreams + [ "Chuck Wagon", "Covered Wagon", "Serendipity Salmon" ]
    assert_equal 62, inventory.count
    assert_equal expected_names.sort, inventory.pluck(:name).sort
    assert_equal 28, inventory.where.missing(:current_placement).count
    assert_equal({ "horse" => 42, "menagerie" => 18, "chariot" => 2 }, inventory.joins(:figure_type).group("figure_types.category").count)
    inventory.each do |figure|
      assert_nil figure.year_carved
      assert_nil figure.carver
      assert_predicate figure.description, :present?
      assert_includes figure.body, "Salem's Riverfront Carousel inventory."
      assert_includes figure.body, "https://www.salemcarousel.org/"
    end

    {
      "Francis the Mule" => "Mule", "Jazz" => "Zebra", "Magic" => "Pegacorn",
      "Seahorse Dawn" => "Horse", "Thunder" => "Horse", "Gigi" => "Horse", "Pancho" => "Elephant",
      "Mr. Sprinkles" => "Unicorn", "Sweet Tart" => "Skunk", "Serendipity Salmon" => "Salmon"
    }.each { |name, type| assert_equal type, salem_figure(name).figure_type.name }
    { "Abby" => "jumper", "The General" => "stander", "Chuck Wagon" => "fixed" }.each do |name, mount|
      assert_equal mount, salem_figure(name).mount
    end
    { "Ambassador" => "Standard", "Bondo" => "Prancer", "Brown Beauty" => "Prancer", "Thunder" => "Prancer", "Jazz" => "Star Gazer" }.each do |name, pose|
      assert_nil salem_figure(name).mount
      assert_includes salem_figure(name).body, "Source pose: #{pose}"
    end
    assert_equal "Dan & Gerry Koonce", salem_figure("Abby").sponsor
    assert_equal "Jen & Richard Gassner", salem_figure("Jazz").sponsor
    assert_includes salem_figure("Abby").body, "First ride: June 2, 2001 (opening day)"
    assert_includes salem_figure("Cloud Walker").body, "First ride: 2001."
    assert_not_includes salem_figure("Cloud Walker").body, "June 2"
    assert_not_includes salem_figure("Ambassador").body, "First ride:"
    { "Abby" => "Outside", "Kate" => "Middle", "Hero" => "Inside" }.each do |name, ring|
      assert_includes salem_figure(name).body, "Documented ring: #{ring}"
    end
    assert_equal "11A", salem_figure("Abby").seat.code
    assert_includes salem_figure("American Flyer").body, "Documented ring: Middle"
    assert_equal "3A", salem_figure("American Flyer").seat.code
    assert_includes salem_figure("American Flyer").body, "may differ from the video-derived layout"
    { "Ambassador" => "Traveling", "Ruby Rose" => "Reserve", "Happy Holidays" => "Yuletide", "Spring Charm" => "spring-only", "Serendipity Salmon" => "not a riding figure" }.each do |name, role|
      assert_includes salem_figure(name).body, role
      assert_nil salem_figure(name).current_placement
    end
    assert_includes salem_figure("Stardust").body, "Design: Alicia Sykes, McNary High School."
    assert_includes salem_figure("Morning Glory").description, "Dave Walker"
    assert_includes salem_figure("Covered Wagon").body, "/copy-of-chuck-wagon"
    assert_includes salem_figure("Benny the Beaver").body, "/sponsorships"
    assert_includes salem_figure("Sweet Tart").body, "completion, installation date, and exact seat not established"
    new_dreams.each { assert_nil salem_figure(_1).sponsor }
  end

  test "Salem seeds restore the complete layout without duplicate records or history churn" do
    load_seeds
    carousel = Carousel.find_by!(slug: "salems-riverfront-carousel")
    general = salem_figure("The General")
    carousel.update!(name: "Edited name", sections_count: 14, rows_count: 4, rotation: "clockwise")
    carousel.fill_missing_seats
    carousel.maker.update!(name: "Edited maker")
    general.update!(sponsor: "Edited sponsor", year_carved: 2001)
    SeatAssignment.new(carousel.seat("2A"), general).save!
    SeatAssignment.new(carousel.seat("3B"), salem_figure("Serendipity Salmon")).save!
    SeatAssignment.new(carousel.seat("13D"), create_figure("Unrelated carving")).save!
    carousel.seat("4A").update!(rows_spanned: 1, confidence: "best_reading")
    SeatAssignment.new(carousel.seat("4B"), salem_figure("Pancho")).save!
    SeatAssignment.new(carousel.seat("10C"), nil).save!
    carousel.seat("10A").update!(rows_spanned: 3)
    carousel.seat("3C").update!(confidence: "best_reading")
    carousel.seat("6C").update!(state: "empty", confidence: "confirmed")

    load_seeds

    assert_equal "Salem's Riverfront Carousel", carousel.reload.name
    assert_equal "Chance", carousel.maker.name
    assert_equal [ 12, 3, "counterclockwise" ], [ carousel.sections_count, carousel.rows_count, carousel.rotation ]
    assert_equal 34, carousel.seats.count
    assert carousel.seats.all? { _1.state == "filled" && _1.confirmed? }
    assert_equal 34, carousel.placements.current.count
    assert_equal "2A", salem_figure("Blackberry").seat.code
    assert_equal "3B", salem_figure("Magic").seat.code
    assert carousel.seat("3C").confirmed?
    assert_equal "Francis the Mule", carousel.seat("6C").figure.name
    assert_equal "Billiebom", carousel.seat("10C").figure.name
    %w[ 4A 10A ].each { assert_equal %w[ A B ], carousel.seat(_1).rows_covered }
    assert_nil salem_figure("Pancho").current_placement
    assert_equal "1A", general.reload.seat.code
    assert_equal "Hazel Patton & Family", general.sponsor
    assert_nil general.year_carved
    assert_nil salem_figure("Serendipity Salmon").current_placement
    assert_nil Figure.find_by!(name: "Unrelated carving").current_placement
    assert Placement.where(figure: general).where.not(ended_on: nil).exists?
    assert Placement.where(figure: salem_figure("Serendipity Salmon")).where.not(ended_on: nil).exists?

    assert_no_difference %w[ Carousel.count Maker.count Seat.count Figure.count Placement.count FigureType.count PaperTrail::Version.count ] do
      load_seeds
    end
  end

  test "all seeded inventory has authoritative carousel ownership including unseated figures" do
    load_seeds
    expected = {
      "great-northern-carousel" => 39, "a-carousel-for-missoula" => 45,
      "spokane-looff-carrousel" => 60, "salems-riverfront-carousel" => 62
    }
    expected.each do |slug, count|
      assert_equal count, Carousel.find_by!(slug:).figures.count
    end
    assert_equal 0, Placement.current.joins(:seat, :figure).where("seats.carousel_id != figures.carousel_id").count

    destination = build_carousel
    figures = [
      Figure.find_by!(slug: "titan-the-hippocampus"), missoula_figure("Silver"),
      Figure.find_by!(slug: "spokane-looff-carrousel-spare-goat"), salem_figure("Pancho")
    ]
    owners = figures.to_h { |figure| [ figure.id, figure.carousel_id ] }
    figures.each_with_index do |figure, index|
      SeatAssignment.new(destination.seat("#{index + 1}A"), figure).save!
      assert_equal destination, figure.reload.carousel
    end

    load_seeds

    figures.each { assert_equal owners.fetch(_1.id), _1.reload.carousel_id }
    assert_equal "1A", figures.first.seat.code
    figures.drop(1).each { assert_nil _1.seat }
    assert destination.seats.all? { _1.figure.nil? }
    assert_no_difference %w[ Figure.count Placement.count PaperTrail::Version.count ] do
      load_seeds
    end
  end

  private
    def salem_figure(name)
      Figure.find_by!(slug: "salems-riverfront-carousel-#{name.parameterize}")
    end

    def missoula_figure(name)
      Figure.find_by!(slug: "a-carousel-for-missoula-#{name.parameterize}")
    end
end
