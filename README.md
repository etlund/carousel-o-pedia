# Carousel-pedia

A wiki for carousels, their carved figures, and their history.

Every seat has a code of section number plus row letter. Rows are lettered from the outside in, so `5A` is section 5, outer row. Sections are numbered in the order figures pass someone standing at the rail.

## Getting started

```sh
bin/setup          # installs gems, prepares the database, loads seeds
bin/dev            # http://localhost:3000
bin/rails test
```

In development, sign in as `admin@example.com` with password `carousel`.

The seeds load the Great Northern Carousel in Helena, Montana: 14 sections, 3 rows, 37 animals, a tea-cup and a chariot bench, with Titan the hippocampus as the lead figure in 1A.

They also load A Carousel for Missoula in Caras Park, with its May 27, 1995 opening and community-building history from the [carousel's official history](https://www.missoulacarousel.org/building-a-community-dream-a-carousel-for-missoula/). The seed includes all 41 named ponies (38 permanent and 3 replacements), both wheelchair-accessible chariots, the special-edition dragon Scaffi, and the ring-dispenser dragon Lucky Red Ringer. Descriptions, sponsors and contributor credits come from the [NCA photo captions](https://carousels.org/psp/Missoula/); inventory names and order come from the booklet contents image supplied by Eric. Inventory order is not a verified seating order. Scaffi's adoption is documented by Eric, but whether it ever rode on the carousel remains unknown.

Three Missoula rows are documented by the [National Carousel Association](https://carousels.org/USACensus/stdqueries/census-cNEW.html); **14 sections and counterclockwise rotation are provisional, unverified values**. Columbia Belle is the documented lead horse and anchors 1A by the wiki's numbering convention. All other positions and chariot spans remain unknown, so chart totals do not reflect the full inventory. Unplaced figures remain available in the figure catalog, with their carousel and role documented in their body text.

**Both carousel seeds are authoritative for now.** Run `bin/rails db:seed` to add missing seeded records and restore seeded attributes, chart shapes and known placements on existing records. This overwrites wiki edits to seeded data. Displaced placements are ended using the normal placement history; unrelated figures are not deleted. Rerunning unchanged seeds does not create duplicate records or history entries. All currently collected carousel data lives in `db/seeds/a_carousel_for_missoula.rb` and `db/seeds/great_northern_carousel.rb`; loading seeds requires no network access.

## Data model

- **Carousel**: location, status, rotation, and the size of its platform (sections × rows).
- **Seat**: one spot on a platform, addressed by its code. A tea-cup or chariot that fills several rows is one seat that spans them. Seats record whether their placement is confirmed or a best reading.
- **Figure**: one carved figure, with a **figure type** (bison, trout, horse) whose category (horse, other animal, chariot or tub) sets its chart colour and section count.
- **Placement**: which figure sits in which seat, with dates, so figures can move.
- **Maker**: carvers and companies.

Every record keeps its edit history through PaperTrail.

## Editing

Anyone can read. Editing is invite-only:

- Create the first admin on a new server with `bin/rails users:create_admin EMAIL=you@example.com NAME="Your Name"`. It asks for a password.
- Admins invite editors from the Invitations page. Each link works for 14 days. If email isn't configured yet, copy the link from that page and send it yourself.
- Every page has a History tab. Recent changes lists every edit, and admins can revert any edit.
- Page text supports Markdown headings, lists, emphasis, links, and fenced code blocks on carousel, figure, figure type, and maker pages. Bare URLs become links. Blank lines start paragraphs and single line breaks are preserved. Rendered HTML is sanitized before display.
- A new carousel starts with an unknown seat in every spot. To fill a seat, click it on the chart and choose a figure. Choosing a figure that already sits somewhere else moves it, and its old seat becomes empty.
