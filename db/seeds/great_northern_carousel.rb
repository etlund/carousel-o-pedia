# The Great Northern Carousel in Helena, Montana, read from Eric's video on 2026-10-24.
# Titan the hippocampus is the lead figure, so his section is section 1.
# The outer row is certain. Middle and inner seats are a best reading unless marked confirmed.

types_by_name = {
  "Horse" => "horse",
  "Trout" => "menagerie", "Bison" => "menagerie", "Triceratops" => "menagerie",
  "Jackrabbit" => "menagerie", "Bighorn sheep" => "menagerie", "Toad" => "menagerie",
  "Mountain goat" => "menagerie", "Wolf" => "menagerie", "Otter" => "menagerie",
  "Grizzly bear" => "menagerie", "Bobcat" => "menagerie",
  "Frog" => "menagerie", "Hippocampus" => "menagerie", "Pronghorn" => "menagerie",
  "Tea-cup" => "chariot", "Chariot" => "chariot"
}.freeze

# code => [name, short name, type, description, extra seat attributes]
seats = {
  "1A"  => [ "Titan the Hippocampus", "Titan", "Hippocampus", "Half horse, half fish from Greek and Roman myth, the creatures that pulled Poseidon's chariot. White horse front, teal curled fish tail, and a face medallion carved to resemble Alan Nicholson, the carousel's owner" ],
  "1B"  => [ "Moon Wind", nil, "Horse", "Black and white pinto horse" ],
  "1C"  => [ "Horse 17", nil, "Horse", "White, green checkered blanket" ],
  "2A"  => [ "Horse 18", nil, "Horse", "Brown with white feathered chest trim" ],
  "2B"  => [ "Pronghorn", nil, "Pronghorn", "White and tan, black horns" ],
  "2C"  => [ "Bobcat", nil, "Bobcat", "Orange striped cat" ],
  "3A"  => [ "Cutty the Trout", "Cutty", "Trout", "Cutthroat trout with a saddle" ],
  "3B"  => [ "Horse 1", nil, "Horse", "Dark grey, teal saddle" ],
  "3C"  => [ "Horse 2", nil, "Horse", "Grey, turquoise and orange blanket" ],
  "4A"  => [ "Tea-cup", nil, "Tea-cup", "Red spinning tub with gold scrolls; fills the whole section", { rows_spanned: 3 } ],
  "5A"  => [ "Nickel", nil, "Bison", "Bison, dark brown, blue blanket and red saddle; Lewis and Clark, two prairie dogs, ride on his back" ],
  "5B"  => [ "Horse 3", nil, "Horse", "Dark brown with a big black mane" ],
  "5C"  => [ "Horse 4", nil, "Horse", "Brown, blue and white blanket" ],
  "6A"  => [ "Sarah the Triceratops", "Sarah", "Triceratops", "Grey-blue dinosaur with red spots" ],
  "6B"  => [ "Rabbit", nil, "Jackrabbit", "White jackrabbit, pink saddle, green collar" ],
  "6C"  => [ "Horse 5", nil, "Horse", "Dappled grey, purple and teal saddle" ],
  "7A"  => [ "Lancelot", nil, "Horse", "Armored horse: black, silver head armor, white blanket with a cross" ],
  "7B"  => [ "Stormy", nil, "Horse", "Cream horse, feather blanket" ],
  "7C"  => [ "Horse 8", nil, "Horse", "Small white horse, red bridle" ],
  "8A"  => [ "Bighorn Ram", "Ram", "Bighorn sheep", "Tan, flower garland and teal blanket" ],
  "8B"  => [ "Horse 9", nil, "Horse", "Black, blue blanket" ],
  "8C"  => [ "Pony the Hop Toad", "Pony (toad)", "Toad", "Green toad with a blue saddle", { confidence: "confirmed" } ],
  "9A"  => [ "Gulliver", nil, "Mountain goat", "White mountain goat, blue saddle, \"G.N. Mining Co.\" gold pan" ],
  "9B"  => [ "Horse 10", nil, "Horse", "Brown, black mane" ],
  "9C"  => [ "Otter 2", nil, "Otter", "River otter floating on his back with a green leaf across his belly", { confidence: "confirmed" } ],
  "10A" => [ "Lupin the Wolf", "Lupin", "Wolf", "Leaping white-and-grey wolf, green and blue markings" ],
  "10B" => [ "Skimmer", nil, "Otter", "Otter, brown with a curled tail" ],
  "10C" => [ "Horse 11", nil, "Horse", "Small pinto, brown and white" ],
  "11A" => [ "Sandhill Cranes", "Cranes", "Chariot", "Blue chariot bench with sandhill cranes carved on its sides", { rows_spanned: 2 } ],
  "11C" => [ "Horse 12", nil, "Horse", "White horse with blue straps, an American flag and a bald eagle on its side", { confidence: "confirmed" } ],
  "12A" => [ "Mountain Goat 2", "Goat 2", "Mountain goat", "White goat, yellow saddle, orange flowers" ],
  "12B" => [ "Pronghorn 2", nil, "Pronghorn", "Tan pronghorn with big ears", { confidence: "confirmed" } ],
  "12C" => [ "Horse 13", nil, "Horse", "Grey, blue harness" ],
  "13A" => [ "Grandpa Griz", nil, "Grizzly bear", "Grizzly bear, dark brown, blue blanket" ],
  "13B" => [ "Horse 14", nil, "Horse", "White, yellow and pink saddle" ],
  "13C" => [ "Hopper the Jack Rabbit", "Hopper", "Jackrabbit", "White jackrabbit, blue collar" ],
  "14A" => [ "Trapper", nil, "Bobcat", "Bobcat, orange striped, blue blanket" ],
  "14B" => [ "Frog", nil, "Frog", "Green leopard frog with dark spots" ],
  "14C" => [ "Trigger", nil, "Horse", "Palomino horse, after Roy Rogers' horse Trigger" ]
}.freeze

mounts = { "Tea-cup" => "spinning", "Chariot" => "fixed" }.freeze

ActiveRecord::Base.transaction do
  types = types_by_name.to_h do |name, category|
    type = FigureType.find_or_initialize_by(slug: name.parameterize)
    type.update!(name:, category:)
    [ name, type ]
  end

  carousel = Carousel.find_or_initialize_by(slug: "great-northern-carousel")
  carousel.update!(
    name: "Great Northern Carousel", city: "Helena", region: "Montana", country: "United States",
    status: "operating", venue: nil, maker: nil, year_built: nil, year_opened: nil,
    sections_count: 14, rows_count: 3, rotation: "counterclockwise",
    body: <<~MD
      A hand-carved carousel in Helena, Montana, with 37 animals, a spinning tea-cup and a chariot bench on a 14-section, three-row platform. Most of its figures are Montana wildlife.

      Titan the hippocampus is the lead figure, in seat 1A, and sections are numbered in the order the figures pass someone standing at the rail.
    MD
  )

  seeded_figures = seats.to_h do |code, (name, short_name, type_name, description)|
    figure = Figure.find_or_initialize_by(slug: name.parameterize)
    SeatAssignment.new(figure.seat, nil).save! if figure.seat && figure.seat.carousel_id != carousel.id
    figure.update!(
      name:, short_name:, carousel:, figure_type: types.fetch(type_name), description:,
      mount: mounts[type_name], sponsor: nil, carver: nil, year_carved: nil, body: nil
    )
    [ code, figure ]
  end

  Placement.current.where(figure: seeded_figures.values).or(Placement.current.where(seat: carousel.seats)).each do |placement|
    next if placement.seat.carousel_id == carousel.id && seeded_figures[placement.seat.code] == placement.figure

    SeatAssignment.new(placement.seat, nil).save!
  end

  carousel.seats.where.not(section: 1..carousel.sections_count, row: carousel.row_letters).destroy_all
  carousel.seats.each do |seat|
    seat_attributes = seats.fetch(seat.code, [])[4] || {}
    expected_span = seat_attributes.fetch(:rows_spanned, 1)
    seat.update!(rows_spanned: 1) if seat.rows_spanned != expected_span && seat.rows_spanned != 1
  end
  carousel.fill_missing_seats

  seats.each do |code, values|
    attributes = { confidence: code.end_with?("A") ? "confirmed" : "best_reading" }.merge(values[4] || {})
    seat = carousel.seats.find_or_initialize_by(Seat.parse_code(code))
    seat.update!(attributes)
    SeatAssignment.new(seat, seeded_figures.fetch(code)).save!
  end
end
