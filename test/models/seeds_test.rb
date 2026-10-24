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

  test "seeds A Carousel for Missoula with sourced history and only the lead placed" do
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
    assert_equal 42, carousel.seats.count
    assert_equal 41, carousel.seats.where(state: "unknown", confidence: "best_reading").count
    assert_equal 1, carousel.placements.current.count
    assert_equal "Columbia Belle", carousel.lead_figure.name
    assert_equal "filled", carousel.lead_seat.state
    assert carousel.lead_seat.confirmed?
    assert_equal({ "horse" => 1, "menagerie" => 0, "chariot" => 0 }, carousel.category_totals)
    assert_includes carousel.body, "May 27, 1995"
    assert_includes carousel.body, "38 permanent ponies, 3 replacement ponies, 2 chariots"
    assert_includes carousel.body, "provisional values, not verified facts"
    assert_includes carousel.body, "not a verified historical seat code"
    assert_no_match(/\bpage \d+/i, carousel.body)
    assert_includes carousel.body, "https://www.missoulacarousel.org/building-a-community-dream-a-carousel-for-missoula/"
    assert_includes carousel.body, "RING MACHINE entry describes equipment"
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
    assert_equal 44, inventory.where.missing(:current_placement).count
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

    assert_includes missoula_figure("Scaffi").description, "Whether it ever rode on the carousel is unknown"
    assert_nil missoula_figure("Scaffi").sponsor
    assert_nil missoula_figure("Scaffi").current_placement
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
    missoula.seat("4A").update!(rows_spanned: 2)
    missoula.update!(sections_count: 15, rows_count: 4)
    missoula.fill_missing_seats

    load_seeds

    assert_equal "Titan the Hippocampus", great_northern.reload.lead_figure.name
    assert_equal "Cutty the Trout", great_northern.seat("3A").figure.name
    assert_equal %w[ A B C ], great_northern.seat("4A").rows_covered
    assert_equal 39, great_northern.seats.count
    assert great_northern.seats.all? { _1.state == "filled" }
    assert_equal "Columbia Belle", missoula.reload.lead_figure.name
    assert_equal 42, missoula.seats.count
    assert_equal 41, missoula.seats.where(state: "unknown").count
    assert_equal 1, missoula.placements.current.count
    assert_nil missoula_figure("Patches").reload.current_placement
    assert Figure.exists?(unrelated.id)
    assert_nil unrelated.reload.current_placement
    assert Placement.where(figure: unrelated).where.not(ended_on: nil).exists?

    assert_no_difference %w[ Carousel.count Maker.count Seat.count Figure.count Placement.count FigureType.count PaperTrail::Version.count ] do
      load_seeds
    end
  end

  private
    def missoula_figure(name)
      Figure.find_by!(slug: "a-carousel-for-missoula-#{name.parameterize}")
    end
end
