# Loaded after the directory seed; research does not establish exact seats.
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

  video_notes = <<~MD.strip
    ## PTC #51 video and independent ring research

    Reviewed October 26, 2026: [Elitch Gardens Carousel, Themeparkfanatic](https://www.youtube.com/watch?v=i7DB_NySglU). The public video description reports four concentric rows: 18 standing horses in the outside ring and 44 jumping horses across the three inner rings, plus four chariots, some with non-riding horses pulling them. These are source-reported ring facts, not a new independent census. The NCA 2018 census agrees on the aggregate 18 standers and 44 jumpers but does not allocate them to rings.

    The available two-second storyboard frames, including approximately 0:50-1:20 and 1:50-3:20, show horses and chariots passing the camera. Full playback was unavailable during this review; the frames do not establish an exhaustive inventory, the individual inner-ring counts, chariot spans, a lead figure, or exact angular alignment. The filming date is unverified, so these are not confirmed present-day placements.

    Four rows means four concentric rings, not four numbered radial sections. Counts need not be equal across rings. Eighteen outer-ring horses does not prove eighteen total outer-ring positions: chariots and their associated non-riding horses must be resolved separately. The 44 inner-ring jumpers are not divided equally or assigned invented positions. Ring A records 18 standers; B, C, and D record jumping horses with individual counts unknown. The schematic does not create horse placeholders, seats, or placements.

    The description's 1925 installation claim also differs from the NCA account of an order in 1925 and delivery in 1928; it is not used to replace the construction date. The operator's advertised 64 horses versus the census's 62 remains unresolved.

    Sources: [video and author description](https://www.youtube.com/watch?v=i7DB_NySglU) and [NCA PTC #51 census, last updated 2018](https://carousels.org/USACensus/census.pl?NCANo=26).
  MD
  unless carousel.summary_sources.to_s.include?(video_notes)
    carousel.summary_sources = [ carousel.summary_sources.presence, video_notes ].compact.join("\n\n")
  end
  if carousel.rows_count == 4
    facts = {
      "A" => { "horses_count" => 18, "mount" => "stander" },
      "B" => { "mount" => "jumper" },
      "C" => { "mount" => "jumper" },
      "D" => { "mount" => "jumper" }
    }
    carousel.ring_details = facts.merge(carousel.ring_details) do |_, researched, existing|
      researched.merge(existing)
    end
  else
    Rails.logger.info("Preserving Elitch Gardens row count; video ring research requires four rows")
  end
  carousel.save! if carousel.changed?

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
