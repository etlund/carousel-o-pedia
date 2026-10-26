# Loaded after the directory seed; photographic identities do not establish seats.
Carousel.transaction do
  carousel = Carousel.find_by!(slug: "elitch-gardens-carousel-denver")
  notes = <<~MD.strip
    ## PTC #51 photographic inventory reference

    Reviewed October 26, 2026. NCA photographs dated August 5, 2003 identify two Roman-style chariots by their decorative subjects: Angel and Cherubs, and Miss Liberty and Bald Eagle. These are descriptive catalog labels, not verified personal names. The two records are a partial photographic inventory, not a complete list of the four chariots reported in the 2018 census.

    Their exact sections, rows, radial spans, and current placements remain unverified. No section count or seating chart is inferred from four rings or the published totals. Unplaced catalog records indicate unknown positions, not removal from the ride. The photographs' accompanying horses are not counted as additional independent figures.

    Sources: [Angel and Cherubs chariot](https://carousels.org/psp/ElitchGardensPTC/Elitch_08.html), [Miss Liberty and Bald Eagle chariot](https://carousels.org/psp/ElitchGardensPTC/Elitch_13a.html), and [NCA PTC #51 census, last updated 2018](https://carousels.org/USACensus/census.pl?NCANo=26).
  MD
  unless carousel.summary_sources.to_s.include?(notes)
    carousel.update!(
      summary_sources: [ carousel.summary_sources.presence, notes ].compact.join("\n\n"),
      body: carousel.body&.sub(
        "Individual figures and placements have not been researched for this directory entry. Published totals and any verified dimensions are recorded separately when available.",
        "Two chariot identities are documented in a partial photographic inventory. Published totals and research limits are recorded separately; exact seating remains unverified."
      )
    )
  end

  chariots = [
    [ "angel-and-cherubs", "Angel and Cherubs chariot", "Elitch_08.html", "an angel and cherubs" ],
    [ "miss-liberty-and-bald-eagle", "Miss Liberty and Bald Eagle chariot", "Elitch_13a.html", "Miss Liberty and a bald eagle" ]
  ]
  slugs = chariots.map { |slug, *| "#{carousel.slug}-#{slug}" }

  if carousel.figures.none? && Figure.where(slug: slugs).none?
    type = FigureType.find_or_create_by!(slug: "chariot") do |record|
      record.name = "Chariot"
      record.category = "chariot"
    end
    chariots.each do |slug, name, source, subject|
      Figure.create!(
        slug: "#{carousel.slug}-#{slug}", name:, short_name: name, carousel:, figure_type: type,
        description: "Roman-style chariot decorated with #{subject}, photographed on PTC #51 in 2003.",
        body: <<~MD
          Descriptive identity from an NCA photograph by Chris K. Benson, dated **August 5, 2003**, reviewed October 26, 2026. This label describes the decoration, not a verified personal name.

          The photograph documents the chariot on Elitch Gardens' PTC #51. Its present-day position, row, and radial span are unverified, so no seat is assigned. This does not imply that it has been removed. Horses accompanying the chariot in photographs are not separate additional catalog records here.

          Source: [NCA chariot photograph](https://carousels.org/psp/ElitchGardensPTC/#{source}).
        MD
      )
    end
  else
    Rails.logger.info("Preserving Elitch Gardens inventory; photographic chariot import requires an empty inventory and no existing source identities")
  end
end
