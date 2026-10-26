# Loaded after the directory seed. Research notes append once; seating imports only
# into an uncharted carousel with no figure inventory, never over existing wiki work.
habs_url = "https://tile.loc.gov/storage-services/master/pnp/habshaer/md/md1300/md1366/data/md1366data.pdf"
research_notes = {
  "glen-echo-dentzel-carousel" => <<~MD,
    ## Historical seating reference: summer 1994

    Layout research reviewed October 25, 2026. The National Park Service's HABS MD-1080-A survey documents eighteen sections and three rings, with every position catalogued in Appendix I (pages 22–27). Its A/B/C ring letters match this wiki's outside/middle/inside rows; its numbered positions map directly to sections 1–18.

    | Ring | Horses | Other animals | Chariots |
    |------|--------|---------------|----------|
    | A (outside) | 12 | 4 | 2 |
    | B (middle) | 14 | 4 | 0 |
    | C (inside) | 14 | 4 | 0 |

    Chariots occupy 8A and 17A, nine sections apart. Each occupies only A: the catalog independently lists ostriches at 8B, 8C, 17B, and 17C. The outer menagerie is a lion at 4A, giraffe at 9A, tiger at 13A, and deer at 18A. Both inner rings have rabbits at sections 4 and 13 and ostriches at sections 8 and 17.

    This chart reproduces a **1994 reference arrangement, not a verified current survey**. All imported placements are **best reading** pending present-day verification. Descriptive records such as "Unidentified horse at 2A" identify a source position and animal category, not a guessed personal identity. The source identifies 1A as its lead horse; no compass orientation relative to the building is asserted.

    Sources: [NPS HABS written history and position catalog](#{habs_url}), [measured floor plan](https://tile.loc.gov/storage-services/service/pnp/habshaer/md/md1300/md1366/sheet/00002v.jpg), and closer chariot photographs [8A](https://tile.loc.gov/storage-services/service/pnp/habshaer/md/md1300/md1366/photos/380100pv.jpg) and [17A](https://tile.loc.gov/storage-services/service/pnp/habshaer/md/md1300/md1366/photos/380112pv.jpg). The catalog, rather than roof panels or arithmetic on figure totals, supplies the seat positions.
  MD
  "cafesjians-carousel-st-paul" => <<~MD,
    ## Ring inventory reference

    Layout research reviewed October 25, 2026. The archived official horse-and-chariot roster groups the collection into four rings:

    | Ring | Horses | Chariots |
    |------|--------|----------|
    | A (outside) | 16 | 2 |
    | B (second) | 16 | 0 |
    | C (third) | 18 | 0 |
    | D (inside) | 18 | 0 |

    The outer-ring vehicles are called Red Chariot and Blue Chariot. The roster describes the Lead Horse and Knight Horse as opposite each other, but this does not establish exact chariot columns or radial footprints. Whether the chariots extend into ring B remains unverified. No regular-grid chart, empty positions, or chariot spans are invented from the differing ring counts.

    Sources: [archived official roster, January 20, 2018](https://web.archive.org/web/20180120065911/http://www.ourfaircarousel.org/our-horses-and-chariots/) and [current operator](https://ourfaircarousel.org/). These are historical inventory groupings, not a current position-by-position survey.
  MD
  "paragon-carousel-hull" => <<~MD,
    ## Layout research limits

    Reviewed October 25, 2026. The National Register description identifies twelve stationary horses in the outside row and describes horses pulling the two Roman-style chariots. This is not treated as a verified total of every outside-ring position. The four-ring alignment and the chariots' exact columns and radial spans remain unresolved. The twelve-sided pavilion is building geometry, not evidence of twelve seating sections.

    Source: [National Register nomination, section 7](https://npgallery.nps.gov/GetAsset/819f7dbe-4aef-42ab-9b24-8387b8d8c798). No chart is generated from building sides or from dividing total horses by rows.
  MD
  "bushnell-park-carousel-hartford" => <<~MD,
    ## Layout research limits

    Reviewed October 25, 2026. NCA photographs identify both outside-row jumpers and outside-row standers, so mount totals do not establish a simple ring assignment. Chariot photographs alone did not establish a complete angular sequence or radial spans. Seat-column counts and exact chariot positions remain unresolved; the pavilion's side count is not used as the carousel's section count.

    Source: [NCA Hartford photograph collection](https://carousels.org/psp/Hartford/), including a [chariot photograph](https://carousels.org/psp/Hartford/Bushnell_015.html). No positions are inferred solely from the published 48 horses and two chariots.
  MD
  "janes-carousel-brooklyn" => <<~MD
    ## Layout research limits

    Reviewed October 25, 2026. The three-ring inventory and two chariots are documented, but the reviewed photographs did not establish a complete seat-column sequence, per-ring riding-figure counts, or exact chariot spans. The chariots are not placed by dividing 48 horses by three rings.

    Sources: [operator history](https://janescarousel.com/history/) and [NCA Jane's Carousel photograph collection](https://carousels.org/psp/JanesCarousel/). Sections and individual positions remain unverified.
  MD
}

Carousel.transaction do
  research_notes.each do |slug, notes|
    carousel = Carousel.find_by!(slug:)
    notes = notes.strip
    next if carousel.summary_sources.to_s.include?(notes)

    carousel.update!(summary_sources: [ carousel.summary_sources.presence, notes ].compact.join("\n\n"))
  end

  carousel = Carousel.find_by!(slug: "glen-echo-dentzel-carousel")
  if carousel.sections_count.nil?
    if carousel.rows_count.in?([ nil, 3 ]) && carousel.seats.none? && carousel.figures.none?
      carousel.update!(
        sections_count: 18, rows_count: 3,
        body: carousel.body&.sub(
          "Individual figures and placements have not been researched for this directory entry. Published totals and any verified dimensions are recorded separately when available.",
          "A historical seating reference is recorded separately below the summary facts. See its source date and best-reading caveats before treating it as a current arrangement."
        )
      )

      outer_animals = { 4 => "Lion", 9 => "Giraffe", 13 => "Tiger", 18 => "Deer" }
      inner_animals = { 4 => "Rabbit", 8 => "Ostrich", 13 => "Rabbit", 17 => "Ostrich" }
      types = {}
      (1..18).each do |section|
        carousel.row_letters.each do |row|
          code = "#{section}#{row}"
          type_name = if row == "A" && [ 8, 17 ].include?(section)
            "Chariot"
          elsif row == "A"
            outer_animals.fetch(section, "Horse")
          else
            inner_animals.fetch(section, "Horse")
          end
          category = case type_name
          when "Horse" then "horse"
          when "Chariot" then "chariot"
          else "menagerie"
          end
          type = types[type_name] ||= FigureType.find_or_create_by!(slug: type_name.parameterize) do |record|
            record.name = type_name
            record.category = category
          end
          name = if code == "1A"
            "Lead horse (HABS A-1)"
          elsif type_name == "Horse"
            "Unidentified horse at #{code}"
          else
            "#{type_name} at #{code}"
          end
          mount = if type_name == "Horse"
            row == "A" ? "stander" : "jumper"
          elsif type_name == "Chariot"
            "fixed"
          end
          figure = Figure.create!(
            slug: "#{carousel.slug}-habs-#{code.downcase}", name:, figure_type: type, carousel:, mount:,
            short_name: code == "1A" ? "Lead horse" : type_name,
            description: "Descriptive record for #{type_name.downcase} at HABS position #{row}-#{section}, documented in summer 1994; not a verified present-day personal identity.",
            body: <<~MD
              Historical reference position: **#{row}-#{section}**, mapped to wiki seat **#{code}**.

              This descriptive catalog label is not an invented personal name. The 1994 HABS inventory documents the position and animal category; the current identity and arrangement have not been independently verified. Placement is marked **best reading**.

              Source: [NPS HABS MD-1080-A, Appendix I, pages 22–27](#{habs_url}).
            MD
          )
          seat = carousel.seat(code)
          seat.update!(confidence: "best_reading")
          SeatAssignment.new(seat, figure).save!
        end
      end
    else
      Rails.logger.warn("Skipping Glen Echo historical seating: existing row count, seats, or figure inventory need manual review")
    end
  end
end
