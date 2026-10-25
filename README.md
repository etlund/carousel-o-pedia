# Carousel-pedia

A wiki for carousels, their carved figures, and their history.

## Browsing and seating

Every seat has a code of section number plus row letter. Rows are lettered from the outside in, so `5A` is section 5, outer row. Sections are numbered in the order figures pass someone standing at the rail.

Carousel summary cards show counts of currently placed horses, other animals, and chariots and tubs, matching the seating chart totals. Figures spanning multiple rows count once; unplaced inventory and ended placements are excluded.

Occupied seat pages also show the current figure's description, type, category, available carving and sponsor details, and Markdown notes and sources. Earlier figures remain listed separately.

Every figure belongs to a carousel, even when it has no seat. The Figures page filters by carousel, type, or both, and includes unseated reserves and project figures. Choose **Filter** to apply the selections or **Clear filters** to return to the full list. Carousel pages link to their full inventory with **View all figures**.

Removing or replacing a seated figure preserves its carousel assignment. A cross-carousel move through the placement service transfers that assignment automatically, but the editing forms restrict the choices to the current carousel. Unseated figures can be reassigned from their figure edit page.

The seat editor lists only figures belonging to that carousel, including unseated inventory. To transfer a figure through the editing forms, remove it from its seat, change its carousel on the figure edit page, then assign it a seat on the new carousel.

## Getting started

```sh
bin/setup --skip-server  # installs gems and prepares the database
bin/dev                  # http://localhost:3000
```

Preparing a new database loads the seed data described below. Preparing an existing database does not automatically refresh its seeded inventory.

In development, sign in as `admin@example.com` with password `carousel`.

### Updating an existing database

Apply schema changes after updating the checkout:

```sh
bin/rails db:migrate
```

The figure ownership migration backfills each figure's required carousel from its current or most recent placement history, then known seeded collection slugs. Migration stops with an explicit list if any figure's carousel cannot be determined; it does not invent an owner. Ownership is stored independently of placement, so clearing a seat no longer removes a figure from its carousel's inventory.

Reseeding is a separate, intentional operation. Read [Seed behavior and preserving edits](#seed-behavior-and-preserving-edits) before running it against an edited database.

## Seeded carousels

The offline seeds contain **206 catalog records across four carousels**, with **171 placed figures and 35 unseated catalog records**. The category columns below count placed figures, matching the carousel summary cards; catalog totals also include reserves, project figures, and non-riding ring dispensers.

| Carousel | Sections | Rows | Catalog records | Horses | Other animals | Chariots and tubs |
|----------|----------|------|-----------------|--------|---------------|-------------------|
| Great Northern Carousel | 14 | 3 | 39 | 18 | 19 | 2 |
| A Carousel for Missoula | 14 | 3 | 45 | 37 | 1 | 2 |
| Spokane Looff Carrousel | 20 | 3 | 60 | 54 | 2 | 2 |
| Salem's Riverfront Carousel | 12 | 3 | 62 | 24 | 8 | 2 |

### Great Northern Carousel

The seeds load the Great Northern Carousel in Helena, Montana: 14 sections, 3 rows, 37 animals, a tea-cup and a chariot bench, with Titan the hippocampus as the lead figure in 1A.

### A Carousel for Missoula

The Missoula seed records the carousel in Caras Park, with its May 27, 1995 opening and community-building history from the [carousel's official history](https://www.missoulacarousel.org/building-a-community-dream-a-carousel-for-missoula/). The seed includes all 41 named ponies (38 permanent and 3 replacements), both wheelchair-accessible chariots, the special-edition dragon Scaffi, and the ring-dispenser dragon Lucky Red Ringer. Descriptions, sponsors and contributor credits come from the [NCA photo captions](https://carousels.org/psp/Missoula/); inventory names and order come from the booklet contents image supplied by Eric. Inventory order is not a verified seating order. Eric confirmed that the green riding dragon visible in the video is Scaffi.

Three Missoula rows are documented by the [National Carousel Association](https://carousels.org/USACensus/stdqueries/census-cNEW.html). A visual reading of the [June 29, 2024 video](https://www.youtube.com/watch?v=8E3DemQtIis&t=100s), matched against the named NCA photographs, supports **14 sections, counterclockwise rotation, and 40 placed figures**: 37 horses, Scaffi at 13A, and two chariots. Altrusa Chariot at 7A and Eagle Chariot at 14A span A-B; Avalon and Pal's Pal occupy their respective C positions. Columbia Belle anchors 1A by the wiki's lead-figure convention. All other placements are marked as best readings and include timestamped source links. This represents the arrangement seen in the 2024 footage, not a verified current survey. Silver, the three replacement ponies, and Lucky Red Ringer remain unplaced in the catalog; this does not imply retirement or permanent removal.

### Spokane Looff Carrousel

The Spokane Looff Carrousel seed records its July 18, 1909 opening, Charles Looff as maker, Riverfront Park location, history, and music from the [City of Spokane](https://my.spokanecity.org/riverfrontspokane/attractions/looff-carrousel/), [NCA gallery](https://carousels.org/psp/SpokaneWA/), and [NCA census](https://carousels.org/USACensus/census.pl?NCANo=221). The [Spokane Carrousel figure directory](https://spokanecarrousel.org/figurepics.html) supplies all 58 platform figures' names and positions across **20 verified sections and 3 rows**. Its numbered "rows" are our sections; its outside/middle/inside rings are our A/B/C rows. Geri Giraffe anchors 1A using that source's numbering, and Sneaky the Tiger is at 11A. The two dragon chariots span B-C at 1B and 11B; their inside photographs are reverse views, not separate figures. All 54 named horses are jumpers. Counterclockwise rotation is verified by the City.

Billy Bob (the spare goat) and Missoula Lilac (a gift horse from the Missoula carvers) remain unplaced, bringing Spokane's inventory to 60 figures. Earlier shell records are updated in place without duplicate identities. Approximate carving dates, uncertain attribution, and differences between source-era layouts and later photographs are documented rather than treated as exact current facts.

### Salem's Riverfront Carousel

Salem's Riverfront Carousel seed records its **June 2, 2001** opening and community history from the [official site](https://www.salemcarousel.org/about-us). Its [Meet the Herd directory](https://www.salemcarousel.org/meettheherd) supplies **62 catalog records**: the original 42 profiles, two wagons, 17 New Dream catalog/project figures, and Serendipity Salmon, the non-riding ring dispenser. Figure pages preserve sponsors, source poses, known rings, first-ride dates, brief paraphrased stories, and sources. First-ride dates are not carving dates; reserve, seasonal, traveling, and unfinished/project roles are kept distinct. Photographs identify Pancho as an elephant, Gigi as a horse, and Mr. Sprinkles as a unicorn.

The [NCA census](https://carousels.org/USACensus/stdqueries/census-cNEW.html) documents three Salem rings and a Chance mechanism with new carvings. A continuous revolution and its adjacent repeat in an [exterior ride video](https://www.youtube.com/watch?v=rSIXxKsNcXA&t=87s), uploaded October 29, 2022, support **12 sections and counterclockwise rotation**. This is a visual reading, not a manufacturer's plan or a current survey; the upload date is not a verified filming date. [The General](https://www.salemcarousel.org/general) anchors 1A by the documented lead-horse/outside-ring description and wiki convention.

Eric's saved Salem assignments on **October 24, 2026**, based on [this video](https://www.youtube.com/watch?v=YGSPO9XFu-8), supply a fully assigned chart of **34 figures: 24 horses, 8 other animals, and 2 wagons**. Chuck Wagon at 4A and Covered Wagon at 10A each span A-B, leaving 34 chart seats. All placements retain the confirmed confidence Eric entered. The other 28 catalog figures remain assigned to Salem without seats. Figure pages cite the placement video separately from official profile rings, which can differ from the captured arrangement. The review date is not a filming date, and the layout is not an independently verified current survey.

### Seed behavior and preserving edits

> **All carousel seeds are authoritative for now.** Running `bin/rails db:seed` overwrites wiki edits to seeded attributes, chart shapes, and known placements. Back up an edited database before intentionally reseeding it.

Seeds add missing records and restore seeded data on existing records. Displaced placements are ended using the normal placement history; unrelated figures are not deleted. Rerunning unchanged seeds does not create duplicate records or history entries.

Wiki edits are **not automatically written back to seed files**. To preserve a reviewed layout, backfill the final seat assignments, row spans, and confidence levels into the relevant seed, record the source and review date, and update the seed tests before reseeding. A review date is not necessarily the video's filming date.

All currently collected carousel data lives in:

- [Missoula seed](db/seeds/a_carousel_for_missoula.rb)
- [Great Northern seed](db/seeds/great_northern_carousel.rb)
- [Salem seed](db/seeds/salems_riverfront_carousel.rb)
- [Spokane seed](db/seeds/spokane_looff_carrousel.rb)

Seed files load automatically in filename order and require no network access.

## Data model

- **Carousel**: location, status, rotation, and the size of its platform (sections × rows).
- **Seat**: one spot on a platform, addressed by its code. A tea-cup or chariot that fills several rows is one seat that spans them. Seats record whether their placement is confirmed or a best reading.
- **Figure**: one carved figure belonging to a carousel independently of seating, with a **figure type** (bison, trout, horse) whose category (horse, other animal, chariot or tub) sets its chart colour and section count.
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

## Testing

```sh
bin/rails test
bin/rails test:system test/system/seat_chart_test.rb
bin/rubocop
```

The tests cover carousel inventories and seating maps, spanning figures, ownership and cross-carousel transfers, combined inventory filters, migration backfills, edit history, authoritative seed restoration, and unchanged-reseed idempotence. Browser tests exercise chart-to-seat-to-figure navigation and the inventory filtering workflow.
