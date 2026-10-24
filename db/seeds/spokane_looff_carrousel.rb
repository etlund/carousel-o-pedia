# Source rows are our sections; source outside/middle/inside rings are our A/B/C rows.
# Chariot inside pages show the reverse of the same figure, not additional chariots.
# Sources are recorded below; seeding never fetches them.

horse_rows = {
  2 => [ "Hunter", "Hutton", "Song" ],
  3 => [ "Oliver's Pride", "Kazumi", "Candy Cane" ],
  4 => [ "Snow Dancer", "Sweetie Pie", "Cooper" ],
  5 => [ "LoofFun", "Koko", "Little Beauty" ],
  6 => [ "Chastity", "Faith", "Scotty" ],
  7 => [ "Casper, the Ghost Horse", "Steely Dan", "Valentine" ],
  8 => [ "Rainbow Warrior", "Corbin", "Katydid" ],
  9 => [ "Cisco", "Penny Lane", "Trigger" ],
  10 => [ "Warrior", "The Christmas Horse", "Lloyd Vogel" ],
  12 => [ "Miss Liberty", "Etta May", "Aimee" ],
  13 => [ "Prince", "Paige", "Cotton Candy" ],
  14 => [ "Bing", "Noel", "Wilber" ],
  15 => [ "Scout", "Joker", "Rufus" ],
  16 => [ "Duke of Earl", "Mr. Ed", "Jameson" ],
  17 => [ "Daisy, the Wishing Horse", "Emma Looff Vogel", "Randina" ],
  18 => [ "Athena", "Stella", "Louis Vogel" ],
  19 => [ "Tina", "Rocky", "Arizona" ],
  20 => [ "The Parrot Horse", "Michelle", "Wendy Jay" ]
}.freeze

horse_descriptions = {
  "Hunter" => "A jumping horse with a ring-necked pheasant decoration, restored using a 1975 photograph of Geri Sperling riding him.",
  "Faith" => "Named by centennial volunteer Bridget for her daughter Faith.",
  "Casper, the Ghost Horse" => "Also called the jinx horse, with a cherub beneath the saddle cantle. The source attributes his name to artist L.R. Montgomery and tells of his low jump making rings difficult to reach.",
  "Daisy, the Wishing Horse" => "A gray horse with flowers on her flanks, named for Bill Oliver's wife, who worked in Natatorium Park's carousel ticket booth for twenty years. The source associates catching the gold ring with making a wish.",
  "Warrior" => "A Trojan-style horse with a roached mane, described as a Helen of Troy horse.",
  "The Christmas Horse" => "Named for its green and red Christmas colors.",
  "The Parrot Horse" => "Named for the red-headed parrot beneath the rear edge of its saddle. Earlier gold and brown paint found during restoration suggested that the bird may once have represented an eagle."
}.freeze

seats = {
  "1A" => {
    name: "Geri Giraffe", slug_suffix: "giraffe", short_name: "Geri",
    type: "Giraffe", mount: "stander",
    description: "Named for Geri Sperling. The figure page estimates carving around 1895 and suggests, without confirming, that Charles Looff may have carved her personally."
  },
  "1B" => {
    name: "Dragon Chariot 1", type: "Chariot", mount: "fixed", rows_spanned: 2,
    description: "The first of two nearly identical dragon chariots, with a carved outer side and a flat inner side detailed in paint. The source's inside photograph shows this same figure."
  },
  "11A" => {
    name: "Sneaky the Tiger", slug_suffix: "tiger", short_name: "Sneaky",
    type: "Tiger", mount: "stander",
    description: "A standing tiger with realistic stripes and a pink nose. The figure page describes the pose as rare and identifies him in the outside ring of source row 11."
  },
  "11B" => {
    name: "Dragon Chariot 2", type: "Chariot", mount: "fixed", rows_spanned: 2,
    description: "The second dragon chariot, opposite the first, with a carved outer side and painted flat inner side. Its inside photograph is a reverse view, not another figure."
  }
}

horse_rows.each do |section, names|
  names.each_with_index do |name, index|
    code = "#{section}#{%w[ A B C ].fetch(index)}"
    seats[code] = {
      name:, type: "Horse", mount: "jumper",
      description: horse_descriptions.fetch(name, "A named jumping horse documented at wiki seat #{code} in the Spokane Carrousel figure directory.")
    }
  end
end

spares = [
  {
    name: "Billy Bob", slug_suffix: "spare-goat", type: "Goat",
    description: "A prancing goat acquired in 2006, estimated by the figure page to date from around 1885; the NCA census instead estimates approximately 1890. Used as a spare for standing animals or jumping horses, and displayed at the center when not in service.",
    source: "https://spokanecarrousel.org/21o.html"
  },
  {
    name: "Missoula Lilac", type: "Horse",
    description: "A spare horse given to Spokane by the carvers in Chuck's garage in Missoula in thanks for Spokane's assistance with their carousel. The figure page describes display at the center when not substituting for a figure undergoing maintenance.",
    source: "https://spokanecarrousel.org/21m.html"
  }
].freeze

ActiveRecord::Base.transaction do
  maker = Maker.find_or_initialize_by(slug: "charles-looff")
  maker.update!(
    name: "Charles Looff", kind: "person",
    body: <<~MD
      The craftsman who built Spokane's 1909 Looff Carrousel. The City of Spokane describes it as a wedding gift for his daughter Emma.

      Source: [City of Spokane: Looff Carrousel](https://my.spokanecity.org/riverfrontspokane/attractions/looff-carrousel/).
    MD
  )

  types = { "Horse" => "horse", "Giraffe" => "menagerie", "Tiger" => "menagerie", "Goat" => "menagerie", "Chariot" => "chariot" }.to_h do |name, category|
    type = FigureType.find_or_initialize_by(slug: name.parameterize)
    type.update!(name:, category:)
    [ name, type ]
  end

  carousel = Carousel.find_or_initialize_by(slug: "spokane-looff-carrousel")
  carousel.update!(
    name: "Looff Carrousel", city: "Spokane", region: "Washington", country: "United States",
    venue: "Riverfront Park", status: "operating", maker:, year_built: 1909, year_opened: 1909,
    sections_count: 20, rows_count: 3, rotation: "counterclockwise",
    body: <<~MD
      A hand-carved wooden Looff carousel in Spokane's Riverfront Park, first opened at Natatorium Park on July 18, 1909. The City of Spokane describes Charles Looff's carousel as a wedding gift for his daughter Emma.

      ## History

      The carousel operated at Natatorium Park before being stored and subsequently returning to service at Riverfront Park in 1975. The City dates Natatorium Park's closure to 1967; the NCA census lists the carousel's Natatorium tenure through 1968. These sources differ on that endpoint.

      The Riverfront building used from 1975 to 2016 had previously served as an Expo '74 beer garden. A replacement building provides climate-controlled protection for the carvings; the NCA gallery identifies it as the 2018 building.

      The NCA census records National Register of Historic Places recognition in 1977 and an NCA Historic Carousel Award in 1995.

      ## Documented collection

      The sources describe 54 jumping horses, 1 giraffe, 1 tiger, and 2 Chinese dragon chariots. The census notes four armored horses and an additional Looff prancing goat from approximately 1890 used as a spare, not an original carousel figure.

      The Spokane Carrousel figure directory identifies all 54 horses and their positions, Geri Giraffe, Sneaky the Tiger, and the two dragon chariots. Its inside chariot pages show the reverse sides of the same two figures, not two additional chariots. The chariot numbers distinguish the first and second chariot; they are not individual names.

      The directory also lists two spares: Billy Bob, a goat acquired in 2006, and Missoula Lilac, a horse given by the Missoula carvers in appreciation for Spokane's help. Neither is assigned a permanent seat. The directory dates Billy Bob approximately 1885, versus approximately 1890 in the NCA census.

      The City describes the original collection as intact, while a January 31, 2019 NCA photograph identifies a contemporary middle-row jumper. Individual carving dates and replacement histories therefore remain unverified.

      Geri's figure page estimates carving around 1895 and suggests possible personal attribution to Charles Looff. These are uncertain claims, not exact dates or confirmed individual carving credits.

      ## Music and ring machine

      A Ruth & Sohn band organ supplies the music; the census records its conversion to BAB 87-key rolls. The carousel has an operating ring arm. The City describes catching a brass ring and the census notes the use of plastic rings. The City also states that the attraction accommodates wheelchairs.

      ## Seating information

      The figure directory confirms twenty radial rows of three rings. Its numbered rows map to this wiki's sections 1-20, and its outside, middle and inside rings map to rows A, B and C. The City's description verifies counterclockwise rotation.

      Geri Giraffe anchors 1A using the directory's numbering, not a separately established historical lead-figure designation. Sneaky the Tiger is at 11A. The chariots begin at 1B and 11B and each span B-C. All 58 platform figures are placed according to the directory; this records the source's arrangement, not an independently dated current survey.

      ## Sources

      - [City of Spokane: Looff Carrousel](https://my.spokanecity.org/riverfrontspokane/attractions/looff-carrousel/): opening date, history, collection, accessibility, and rotation.
      - [NCA Spokane photo gallery](https://carousels.org/psp/SpokaneWA/): historical photographs and captions.
      - [NCA census entry 221](https://carousels.org/USACensus/census.pl?NCANo=221): three rows, inventory, spare goat, music, awards, and location history; entry last updated in 2020.
      - [Spokane Carrousel figure directory](https://spokanecarrousel.org/figurepics.html): twenty-section layout, individual names and positions, two spanning chariots, and two spares.
      - [2018 building](https://carousels.org/psp/SpokaneWA/DSCN4002.html), [contemporary middle-row jumper](https://carousels.org/psp/SpokaneWA/DSCN3965.html), and [dragon chariot](https://carousels.org/psp/SpokaneWA/DSCN3972.html): photographs dated January 31, 2019.
    MD
  )

  entries = seats.map do |code, entry|
    position = Seat.parse_code(code)
    source_ring = { "A" => "o", "B" => "m", "C" => "i" }.fetch(position.fetch(:row))
    source = "https://spokanecarrousel.org/#{format("%02d", position.fetch(:section))}#{source_ring}.html"
    entry.merge(code:, source:)
  end + spares

  inventory = entries.to_h do |entry|
    name = entry.fetch(:name)
    figure = Figure.find_or_initialize_by(slug: "#{carousel.slug}-#{entry.fetch(:slug_suffix, name.parameterize)}")
    SeatAssignment.new(figure.seat, nil).save! if figure.seat && figure.seat.carousel_id != carousel.id
    figure.update!(
      name:, short_name: entry[:short_name], carousel:, figure_type: types.fetch(entry.fetch(:type)), mount: entry[:mount],
      carver: nil, year_carved: nil, sponsor: nil, description: entry.fetch(:description),
      body: <<~MD
        Spokane Looff Carrousel inventory.

        #{entry[:code] ? "Source position mapped to wiki seat #{entry.fetch(:code)}. The directory's numbered rows are our sections, and its outside/middle/inside rings are our A/B/C rows." : "Role: spare figure, not a permanent platform assignment."}

        Individual carving dates and personal carving credits are not confirmed here. The source arrangement is not an independently dated current survey.

        Source: [Spokane Carrousel figure page](#{entry.fetch(:source)}).
      MD
    )
    [ name, figure ]
  end

  placed_figures = seats.transform_values { |entry| inventory.fetch(entry.fetch(:name)) }
  Placement.current.where(figure: inventory.values).or(Placement.current.where(seat: carousel.seats)).each do |placement|
    next if placement.seat.carousel_id == carousel.id && placed_figures[placement.seat.code] == placement.figure

    SeatAssignment.new(placement.seat, nil).save!
  end

  carousel.seats.where.not(section: 1..carousel.sections_count, row: carousel.row_letters).destroy_all
  carousel.seats.each do |seat|
    expected_span = seats.fetch(seat.code, {}).fetch(:rows_spanned, 1)
    seat.update!(rows_spanned: 1) if seat.rows_spanned != expected_span && seat.rows_spanned != 1
  end
  carousel.fill_missing_seats
  seats.each do |code, entry|
    seat = carousel.seats.find_by!(Seat.parse_code(code))
    seat.update!(confidence: "confirmed", rows_spanned: entry.fetch(:rows_spanned, 1))
    SeatAssignment.new(seat, placed_figures.fetch(code)).save!
  end
end
