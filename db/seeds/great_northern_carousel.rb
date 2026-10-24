# The Great Northern Carousel in Helena, Montana, read from Eric's video on 2026-10-24.
# The outer row is certain. Middle and inner seats are a best reading unless marked confirmed.

types_by_name = {
  "Horse" => "horse",
  "Trout" => "menagerie", "Bison" => "menagerie", "Triceratops" => "menagerie",
  "Jackrabbit" => "menagerie", "Bighorn sheep" => "menagerie", "Toad" => "menagerie",
  "Mountain goat" => "menagerie", "Wolf" => "menagerie", "Otter" => "menagerie",
  "Deer" => "menagerie", "Grizzly bear" => "menagerie", "Bobcat" => "menagerie",
  "Frog" => "menagerie", "Hippocampus" => "menagerie", "Pronghorn" => "menagerie",
  "Tea-cup" => "chariot", "Chariot" => "chariot"
}.freeze

# code => [name, short name, type, description, extra seat attributes]
seats = {
  "1A"  => [ "Cutty the Trout", "Cutty", "Trout", "Cutthroat trout with a saddle" ],
  "1B"  => [ "Horse 1", nil, "Horse", "Dark grey, teal saddle" ],
  "1C"  => [ "Horse 2", nil, "Horse", "Grey, turquoise and orange blanket" ],
  "2A"  => [ "Tea-cup", nil, "Tea-cup", "Red spinning tub with gold scrolls; fills the whole section", { rows_spanned: 3 } ],
  "3A"  => [ "Nickel", nil, "Bison", "Bison, dark brown, blue blanket and red saddle; Lewis and Clark, two prairie dogs, ride on his back" ],
  "3B"  => [ "Horse 3", nil, "Horse", "Dark brown with a big black mane" ],
  "3C"  => [ "Horse 4", nil, "Horse", "Brown, blue and white blanket" ],
  "4A"  => [ "Sarah the Triceratops", "Sarah", "Triceratops", "Grey-blue dinosaur with red spots" ],
  "4B"  => [ "Rabbit", nil, "Jackrabbit", "White jackrabbit, pink saddle, green collar" ],
  "4C"  => [ "Horse 5", nil, "Horse", "Dappled grey, purple and teal saddle" ],
  "5A"  => [ "Lancelot", nil, "Horse", "Armored horse: black, silver head armor, white blanket with a cross" ],
  "5B"  => [ "Stormy", nil, "Horse", "Cream horse, feather blanket" ],
  "5C"  => [ "Horse 8", nil, "Horse", "Small white horse, red bridle" ],
  "6A"  => [ "Bighorn Ram", "Ram", "Bighorn sheep", "Tan, flower garland and teal blanket" ],
  "6B"  => [ "Horse 9", nil, "Horse", "Black, blue blanket" ],
  "6C"  => [ "Pony the Hop Toad", "Pony (toad)", "Toad", "Green toad with a blue saddle", { confidence: "confirmed" } ],
  "7A"  => [ "Gulliver", nil, "Mountain goat", "White mountain goat, blue saddle, \"G.N. Mining Co.\" gold pan" ],
  "7B"  => [ "Horse 10", nil, "Horse", "Brown, black mane" ],
  "7C"  => [ nil, nil, nil, nil, { state: "unknown" } ],
  "8A"  => [ "Lupin the Wolf", "Lupin", "Wolf", "Leaping white-and-grey wolf, green and blue markings" ],
  "8B"  => [ "Skimmer", nil, "Otter", "Otter, brown with a curled tail" ],
  "8C"  => [ "Horse 11", nil, "Horse", "Small pinto, brown and white" ],
  "9A"  => [ "Chariot", nil, "Chariot", "Blue bench with sandhill cranes carved on the sides", { rows_spanned: 2 } ],
  "9C"  => [ "Horse 12", nil, "Horse", "White, stars-and-stripes blanket", { confidence: "confirmed" } ],
  "10A" => [ "Mountain Goat 2", "Goat 2", "Mountain goat", "White goat, yellow saddle, orange flowers" ],
  "10B" => [ "Deer", nil, "Deer", "Tan deer with big ears" ],
  "10C" => [ "Horse 13", nil, "Horse", "Grey, blue harness" ],
  "11A" => [ "Grandpa Griz", nil, "Grizzly bear", "Grizzly bear, dark brown, blue blanket" ],
  "11B" => [ "Horse 14", nil, "Horse", "White, yellow and pink saddle" ],
  "11C" => [ "Hopper the Jack Rabbit", "Hopper", "Jackrabbit", "White jackrabbit, blue collar" ],
  "12A" => [ "Trapper", nil, "Bobcat", "Bobcat, orange striped, blue blanket" ],
  "12B" => [ "Frog", nil, "Frog", "Green leopard frog with dark spots" ],
  "12C" => [ "Trigger", nil, "Horse", "Palomino horse, after Roy Rogers' horse Trigger" ],
  "13A" => [ "Titan the Hippocampus", "Titan", "Hippocampus", "Half horse, half fish from Greek and Roman myth, the creatures that pulled Poseidon's chariot. White horse front, teal curled fish tail, and a face medallion carved to resemble Alan Nicholson, the carousel's owner" ],
  "13B" => [ "Moon Wind", nil, "Horse", "Black and white pinto horse" ],
  "13C" => [ "Horse 17", nil, "Horse", "White, green checkered blanket" ],
  "14A" => [ "Horse 18", nil, "Horse", "Brown with white feathered chest trim" ],
  "14B" => [ "Pronghorn", nil, "Pronghorn", "White and tan, black horns" ],
  "14C" => [ "Bobcat", nil, "Bobcat", "Orange striped cat" ]
}.freeze

mounts = { "Tea-cup" => "spinning", "Chariot" => "fixed" }.freeze

ActiveRecord::Base.transaction do
  types = types_by_name.to_h do |name, category|
    [ name, FigureType.find_or_create_by!(name:) { |type| type.category = category } ]
  end

  carousel = Carousel.find_or_create_by!(slug: "great-northern-carousel") do |c|
    c.name = "Great Northern Carousel"
    c.city = "Helena"
    c.region = "Montana"
    c.country = "United States"
    c.sections_count = 14
    c.rows_count = 3
    c.rotation = "counterclockwise"
    c.body = <<~MD
      A hand-carved carousel in Helena, Montana, with 36 animals and a spinning tea-cup on a 14-section, three-row platform. Most of its figures are Montana wildlife.

      Section 1 starts at Cutty the trout, and sections are numbered in the order the figures pass someone standing at the rail.
    MD
  end

  seats.each do |code, (name, short_name, type_name, description, seat_attributes)|
    attributes = { confidence: code.end_with?("A") ? "confirmed" : "best_reading" }.merge(seat_attributes || {})
    seat = carousel.seats.find_or_initialize_by(Seat.parse_code(code))
    seat.update!(attributes)
    next unless name

    figure = Figure.find_or_initialize_by(name:, figure_type: types.fetch(type_name))
    figure.update!(short_name:, description:, mount: mounts[type_name])
    Placement.find_or_create_by!(figure:, seat:, ended_on: nil)
  end
end
