# Run after the inventory and directory seeds; address research never restores edits.
addresses = JSON.parse(Rails.root.join("db/seeds/carousel_addresses.json").read)

Carousel.transaction do
  addresses.each do |entry|
    carousel = Carousel.find_by!(slug: entry.fetch("slug"))
    facts = entry.slice("street_address", "postal_code").compact_blank
    if facts.empty?
      Rails.logger.warn("No verified address available for #{carousel.slug}; manual research required")
      next
    end
    if facts.any? { |attribute, value| carousel[attribute].present? && carousel[attribute] != value }
      Rails.logger.info("Preserving existing address for #{carousel.slug}; researched street or postal code differs")
      next
    end

    additions = facts.select { |attribute, _value| carousel[attribute].nil? }
    next if additions.empty?

    sources = <<~MD.strip
      Address reviewed October 26, 2026.

      #{entry.fetch("notes")}

      Source: [Public visitor address](#{entry.fetch("source_url")}).

      This address does not establish verified coordinates for the carousel itself.
    MD
    carousel.assign_attributes(additions)
    unless carousel.address_sources.to_s.include?(sources)
      carousel.address_sources = [ carousel.address_sources.presence, sources ].compact.join("\n\n")
    end
    carousel.save!
  end
end
