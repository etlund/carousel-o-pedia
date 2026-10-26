# carousel-o-pedia

A wiki for carousels, their carved figures, and their history.

The site's logo is a red ring with a transparent center, echoing the seating chart and replacing the middle "o" in the carousel-o-pedia header wordmark. The header and standard site favicon share the same SVG.

## Browsing and seating

The Carousels page supports case-insensitive partial name searches and a state filter. Use either filter alone or combine them, choose **Filter** to apply, and **Clear filters** to return to the full directory. Selections remain visible and are included in the page URL for sharing. The state dropdown lists the distinct states or regions recorded in the directory.

Every card includes a compact 112-pixel seat-chart preview linking to the carousel page. Complete recorded layouts use touching wedges: blue for horses, orange for other animals, and red for chariots/tubs. Confirmed placements use the base category colors; best-reading placements use faded fills mixed equally with white; unknown or empty seats remain unfilled. All wedges have uniform medium-gray 2-pixel outlines. Rows run from the outside in, with section 1 at the top. One wedge represents each seat, spanning every row covered by a vehicle. Incomplete layouts show a gray platform with inner and outer outlines and a transparent center hole. When the row count is known, evenly spaced concentric boundaries show those rows without inventing sections or seat positions. The full-size chart retains its existing symbols and dashed uncertainty markers.

Carousel detail pages with mapped figures also use that chart as their SVG favicon. At favicon sizes, all wedges are filled without outlines, using the same category colors regardless of placement confidence. Unknown and empty seats use neutral grays. Carousels without a recorded layout or mapped figures use a gray ring. The home page and other site pages keep the standard red-ring icon. Both rings have transparent centers matching the seating chart's hub proportions. The self-contained carousel icon updates with the page's seating data, including during Turbo navigation; the standard red-ring PNG and Apple touch icon remain as fallbacks.

Carousels default to **With data first**: entries with figure inventory (including unseated figures), any verified platform dimension, or published figure totals appear before directory-only entries. Both groups are alphabetical by name. Choose **Name (A-Z)** in the Sort dropdown for a single alphabetical list. Sorting works with the name and state filters; **Clear filters** also restores the default sort.

Every seat has a code of section number plus row letter. Seat badges put the red section number outside the wide left edge of the row-letter wedge. Row A is on the left at the outer rail; subsequent rows run inward toward the narrow right edge, with upright letters. Rows are lettered from the outside in, so `5A` is section 5, outer row. Sections are numbered in the order figures pass someone standing at the rail.

Carousel summary cards and detail pages list horses, other animals, and chariots and tubs **once**. Each category prefers its published total; when that value is blank, it falls back to the mapped-seat count if the layout is known, or **Unknown** otherwise. Published zero is a verified count and is never replaced by a mapped value.

Published totals describe source-reported riding figures and remain stored separately from placements; they never create placeholder figures or seats. Mapped counts exclude unplaced inventory and ended placements and count figures spanning multiple rows once. The seating chart and section table always use mapped data, which may differ from the displayed published totals. Editors must supply Markdown source notes for published totals. Source dates, historical configurations, and disagreements remain available in **Summary sources**.

Directory-only carousels can have an unknown or partially researched seating layout. Each dimension is independently optional: for example, a known row count is shown even while sections remain unknown. No full-size chart or seats are created until both dimensions are known; card previews show only the known level of detail. Once both are recorded, platform size stays fixed in the editor. Unmapped counts remain **Unknown** without a complete layout. Rotation is independently optional and does not default to a guessed direction.

Carousels have optional **street address**, **ZIP or postal code**, and Markdown **address sources and notes**. Cards and detail pages show the physical address alongside the existing city/state/country; unknown street addresses and postal codes remain blank. Postal codes are text so leading zeros are preserved. Public visitor-entrance or venue addresses are distinguished from exact carousel locations in the source notes; mailing offices and PO boxes are not substitutes for ride addresses.

Coordinates and a map are deferred to the [carousel map implementation plan](docs/carousel-map-plan.md). An address is not a verified map point. The plan covers reviewed coordinates, geocoding/provider decisions, shared directory filters, accuracy labels, accessibility, and failure handling.

Carousels have optional **official website**, **Wikipedia**, and **other links** fields. On the carousel index, the city/state/country remains plain text, and the official website URL appears as a separate clickable link when one is set; the carousel name still links to its wiki page. Carousel detail pages display the full address, including the street and postal code, and the available website links in the facts card.

Official and Wikipedia URLs must use HTTP or HTTPS and cannot contain login credentials. Additional named links use the existing sanitized Markdown format, one per line, such as `[NCA gallery](https://carousels.org/)`. The seeds include the known official sites and reference links, including [Great Northern's live website](https://www.greatnortherncarousel.com/); unverified Wikipedia URLs are left blank.

Occupied seats in charts and section tables open the canonical Figure page directly. Existing occupied-seat URLs temporarily redirect to the current figure, so bookmarks follow the position if its occupant changes. Empty and unknown seats retain a focused Seat page with status, position, confidence, and earlier figures.

Figure pages show a carousel backlink above the figure name to preserve the navigation hierarchy, followed by the figure's description, type, category, available carving and sponsor details, and Markdown notes and sources. **Edit figure** and **Figure history** apply to the carved object. Seated figures have a secondary **Current seat** panel with the seat badge, carousel, position, confidence, **Edit placement**, **Seat history**, and earlier occupants. The figure's own **Seats over time** remains separate from the position's earlier figures. On narrow screens the seating panel follows the figure content. Unseated figures retain their carousel link without inventing a current seat. Placement editing and seat history keep their existing URLs; saving an occupied placement returns to its figure, while saving an empty/unknown placement returns to the seat. Edit controls are shown only to signed-in editors.

Every figure belongs to a carousel, even when it has no seat. The Figures page filters by carousel, type, or both, and includes unseated reserves and project figures. Choose **Filter** to apply the selections or **Clear filters** to return to the full list. Carousel pages link to their full inventory with **View all figures**.

Removing or replacing a seated figure preserves its carousel assignment. A cross-carousel move through the placement service transfers that assignment automatically, but the editing forms restrict the choices to the current carousel. Unseated figures can be reassigned from their figure edit page.

The seat editor lists only figures belonging to that carousel, including unseated inventory. To transfer a figure through the editing forms, remove it from its seat, change its carousel on the figure edit page, then assign it a seat on the new carousel.

## Getting started

```sh
git clone https://github.com/etlund/carousel-o-pedia.git
cd carousel-o-pedia
bin/setup --skip-server  # installs gems and prepares the database
bin/dev                  # http://localhost:3000
```

The Rails application namespace is `CarouselOPedia`, the Kamal service is `carousel_o_pedia`, and the production image is `ghcr.io/etlund/carousel-o-pedia`. The existing `carousel_pedia_storage` volume and `_carousel_pedia_session` cookie key intentionally retain their names to preserve stored data and browser sessions. For an existing Kamal deployment, stop the old `carousel_pedia` service before starting `carousel_o_pedia` against the shared SQLite volume; changing the volume name requires a separate data migration.

Preparing a new database loads the seed data described below. Preparing an existing database does not automatically refresh its seeded inventory.

In development, sign in as `admin@example.com` with password `carousel`.

### Local environment variables

Rails automatically loads environment variables from `.env` in the project root
using `dotenv-rails`. Add entries in `KEY=value` format, then read them with
`ENV.fetch("KEY")` (required) or `ENV["KEY"]` (optional). Restart the Rails server
or console after editing the file.

Environment-specific files such as `.env.development` and `.env.test` are also
supported. Variables already set in the process environment take precedence.
Environment files are ignored by Git; do not commit secrets.

The project's `bin/kamal` entrypoint also loads `.env` before running Kamal, so deployment secrets do not need to be exported separately. Existing process environment values still take precedence.

### Production deployment with Kamal

[Kamal configuration](config/deploy.yml) targets the Ubuntu x64 Droplet at `201.79.38.100`, using SSH as root with `~/.ssh/id_ed25519`. The image is built for `amd64`, including when deploying from an Apple Silicon Mac. Kamal Proxy obtains HTTPS certificates for `carouselopedia.org`; Rails trusts the HTTPS-terminating proxy and uses secure cookies.

Prerequisites:

- Point the domain's A record at the Droplet. Publish an AAAA record only if server IPv6 works.
- Allow inbound TCP 80 and 443 publicly, and TCP 22 from the deployment computer's public IP. Do not expose port 3000. Allow outbound traffic for Docker images and certificates.
- Verify the server's SSH host fingerprint through DigitalOcean's console, then confirm key-based SSH works.
- Run Docker locally. Kamal's first setup can install Docker on the Droplet.
- Create a GitHub personal access token (classic) with `write:packages` for the `etlund` account. Store it locally, not in Git or chat. Confirm the resulting GHCR package remains private.
- Generate a production `SECRET_KEY_BASE` once with `bin/rails secret`, store it in your password manager, and export it into the deployment shell. Keep this value stable across deployments; do not reuse a validation placeholder or generate a new value on every deploy.

Set `KAMAL_REGISTRY_PASSWORD` and `SECRET_KEY_BASE` in the deployment shell using your password manager or hidden terminal prompts. The tracked secrets file references the environment variables; it must never contain the values themselves.

Production currently uses environment variables for all secrets; it does not read Rails encrypted credentials and does not require `RAILS_MASTER_KEY`. The checked-in encrypted credentials file is left untouched. If encrypted credentials are adopted later, recover the corresponding key or deliberately provision a new encrypted credentials file and key before enabling that configuration.

**Before the first deploy**, decide the production data import and administrator credentials. `bin/kamal setup` starts a publicly reachable app, and its entrypoint runs `db:prepare`, which seeds a fresh database. To preserve development edits and history, prepare a consistent SQLite backup using SQLite's backup facility and import it as `storage/production.sqlite3` in the persistent volume before application startup. Do not copy a live SQLite file directly or rerun inventory seeds over edited data. Review imported accounts, remove the known development password, and invalidate imported login sessions and invitation links before going live. Never commit database backups or private data.

The current application has no photo-attachment feature or Active Storage tables; no uploaded photos need migrating for this launch. If attachments are introduced later, copy and back up their files together with the database while uploads are paused.

To set the administrator password in a **separate prepared launch database**, use its absolute path:

```sh
DATABASE_URL=sqlite3:/absolute/path/to/launch/production.sqlite3 \
  bin/rails users:reset_password EMAIL=you@example.com
```

This prompts without echoing the password, requires at least 12 characters, and revokes that user's sessions. Do not omit `DATABASE_URL` when preparing the launch copy: without it this command operates on development. Keep the prepared database private and use the same artifact for the initial import. The unmodified development backup should be retained separately.

Once credentials, the data import, and off-server backups are ready:

```sh
bin/kamal setup    # first deployment; installs Docker and starts the application
bin/kamal deploy   # subsequent deployments of committed changes
bin/kamal logs     # inspect application logs
curl --fail https://carouselopedia.org/up
```

SQLite and uploaded files persist in `carousel_pedia_storage`; the queue, cache, and cable databases are separate production files created by `db:prepare`. Schedule consistent off-server database and upload backups and test a restore. Droplet snapshots alone are not a tested application backup.

Outbound email is not configured yet. Until SMTP and a verified sender are configured, send invitation links manually from the Invitations page and do not rely on password-reset email. The other registered domains are not configured as aliases or redirects yet.

### Database backups to DigitalOcean Spaces

Production schedules `DatabaseBackupJob` daily at 03:00 in the application's time zone (UTC by default). It uses SQLite's online backup API, including committed WAL data, checks SQLite integrity and foreign keys, and uploads the primary database privately to `carouselopedia-backups` in `mkc1`. The regional endpoint is `https://mkc1.digitaloceanspaces.com`, not the bucket-prefixed URL or CDN endpoint. The SDK uses the conventional `us-east-1` signing region; the endpoint determines the actual storage location.

Store `BACKUP_ACCESS_KEY_ID` and `BACKUP_SECRET_ACCESS_KEY` locally alongside the other deployment secrets, or export them in the deployment terminal. Use a dedicated Spaces key restricted to this bucket, permitting object upload, download, listing, and deletion. Kamal passes these secrets to the application; no secret values belong in tracked files.

Objects are written under `database/production/` with unique timestamped names and SHA-256 metadata. Only matching backup filenames older than 30 days are deleted, and deletion runs only after a successful upload. Temporary local files are removed automatically. The primary database includes accounts, sessions, catalog data, and history; treat backups as sensitive. Queue/cache/cable databases are not backed up and can be recreated. There are currently no uploaded attachments.

Before launch, test upload and restore against the prepared launch copy:

```sh
BACKUP_BUCKET=carouselopedia-backups \
BACKUP_ENDPOINT=https://mkc1.digitaloceanspaces.com \
DATABASE_URL=sqlite3:/absolute/path/to/launch/production.sqlite3 \
  bin/rails backups:create
```

The command prints the uploaded object key. Use that exact key to download and verify it:

```sh
BACKUP_BUCKET=carouselopedia-backups \
BACKUP_ENDPOINT=https://mkc1.digitaloceanspaces.com \
  bin/rails backups:verify KEY=database/production/KEY_FROM_PREVIOUS_COMMAND.sqlite3
```

Verification checks the downloaded SHA-256, SQLite integrity, foreign keys, and catalog/history counts in a temporary restored database. It never replaces the live or development database. Compare the reported counts with the source; keep the object key and checksum with the launch record.

After deployment, trigger and verify backups with:

```sh
bin/kamal app exec --reuse "bin/rails backups:create"
bin/kamal app exec --reuse "bin/rails backups:verify KEY=database/production/EXACT_BACKUP_FILENAME.sqlite3"
```

Failures propagate to the command or Solid Queue failed-job records and application logs; no failure is reported as success. External failure/staleness alerts are not yet configured. Check `bin/kamal logs` and the bucket's latest backup timestamp, and arrange external alerting before relying on unattended backups. A stopped application or queue cannot run its own backup job. Keep Droplet-level backups as an additional layer.

### Updating an existing database

Apply schema changes after updating the checkout:

```sh
bin/rails db:migrate
```

The figure ownership migration backfills each figure's required carousel from its current or most recent placement history, then known seeded collection slugs. Migration stops with an explicit list if any figure's carousel cannot be determined; it does not invent an owner. Ownership is stored independently of placement, so clearing a seat no longer removes a figure from its carousel's inventory.

Reseeding is a separate, intentional operation. Read [Seed behavior and preserving edits](#seed-behavior-and-preserving-edits) before running it against an edited database.

## Seeded carousels

The offline seeds contain **54 U.S. carousels**: four detailed inventories and **50 additional operating-carousel directory entries**. Glen Echo also has a historical seating reference, and Elitch Gardens has two photographically identified chariots with unknown seats. Together they contain **262 catalog records**, with **225 placed figures and 37 unseated catalog records**. The category columns below count placed figures; published summary totals can differ. Catalog totals also include reserves, project figures, and non-riding ring dispensers.

| Carousel | Sections | Rows | Catalog records | Horses | Other animals | Chariots and tubs |
|----------|----------|------|-----------------|--------|---------------|-------------------|
| Great Northern Carousel | 14 | 3 | 39 | 18 | 19 | 2 |
| A Carousel for Missoula | 14 | 3 | 45 | 37 | 1 | 2 |
| Spokane Looff Carrousel | 20 | 3 | 60 | 54 | 2 | 2 |
| Salem's Riverfront Carousel | 12 | 3 | 62 | 24 | 8 | 2 |
| Glen Echo Park Dentzel Carousel (1994 reference) | 18 | 3 | 54 | 40 | 12 | 2 |
| Elitch Gardens Carousel (partial photographic inventory) | Unknown | 4 | 2 | 0 | 0 | 0 |

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

> **The four detailed inventory seeds are authoritative for now.** Running `bin/rails db:seed` overwrites wiki edits to their seeded attributes, chart shapes, and known placements. Back up an edited database before intentionally reseeding it.

The [U.S. operating-carousel directory seed](db/seeds/us_operating_carousels.rb) is **create-only for directory metadata**: it adds missing entries by stable slug without replacing later name, website, operating-status, or wiki-note edits. Researched summary counts and dimensions **fill only nil values**; existing values, including zero, are preserved. New source notes are appended without replacing earlier notes. Conflicting existing dimensions are retained rather than mixed into an invented layout. Figure inventories and placements are never created or changed by this seed.

The first summary-research pass covers ten carousels, using the [NCA classic wood carousel census](https://carousels.org/USACensus/stdqueries/census-cCLA.html) and operator context reviewed October 25, 2026:

| Carousel | Published horses | Other animals | Chariots and tubs | Rows |
|----------|-----------------:|--------------:|------------------:|-----:|
| Jane's Carousel | 48 | 0 | 2 | 3 |
| Paragon Carousel | 66 | 0 | 2 | 4 |
| Bushnell Park Carousel | 48 | 0 | 2 | 3 |
| Glen Echo Park Dentzel Carousel | 40 | 12 | 2 | 3 |
| Pullen Park Carousel | 29 | 23 | 2 | 3 |
| Kit Carson County Carousel | 25 | 21 | 4 | 3 |
| Cafesjian's Carousel | 68 | 0 | 2 | 4 |
| Dorothea Laub Balboa Park Carousel | 27 | 25 | 3 | 3 |
| Santa Cruz Beach Boardwalk Looff Carousel | 73 | 0 | 2 | 4 |
| Oaks Park Carousel | 24 | 26 | 4 | 3 |

The census summaries alone do not establish section counts; none is inferred from animal counts or row counts. Separate position-level research now supplies Glen Echo's historical chart, described below. The other nine still have no seating charts. Several census entries are tagged 2020; Pullen's is tagged 2021. These are published snapshots, not current physical surveys. Oaks Park's four vehicles comprise two chariots and two tubs. Balboa's figures are explicitly **as reported**: NCA lists 25 other animals but its species breakdown sums to 26, and inclusion of the operator's four miniature horses is unresolved. Those caveats are retained on its page.

Directory sources were reviewed on **October 25, 2026**. "Operating" means the operator lists the carousel as a ride or visitor attraction, including seasonal operation; it does not guarantee it is open today or rule out temporary maintenance closures. Check the linked operator website for current hours. Source evidence is included on each carousel page.

### Elitch Gardens Carousel (Denver, PTC #51)

An additional summary reviewed **October 26, 2026** uses the [NCA census record last updated in 2018](https://carousels.org/USACensus/census.pl?NCANo=26): **four rows, 44 jumping and 18 standing horses (62 total), no other animals, and four chariots**, built in 1928. The [operator](https://elitchgardens.com/attractions/carousel/) instead advertises **64 horses**; this discrepancy remains explicit rather than silently combining the sources. Neither source establishes section count or exact seating.

The [Elitch Gardens research seed](db/seeds/us_researched_elitch_gardens.rb) adds two descriptive chariot records from NCA photographs dated August 5, 2003: [Angel and Cherubs](https://carousels.org/psp/ElitchGardensPTC/Elitch_08.html) and [Miss Liberty and Bald Eagle](https://carousels.org/psp/ElitchGardensPTC/Elitch_13a.html). These are decorative descriptions, not verified personal names, and remain **unplaced**. They do not resolve all four census vehicles or their radial spans. No horse placeholders or seating chart are invented. This is not PTC #6 in Burlington, the subject of Wikipedia's “Elitch Gardens Carousel” article.

The photographic import requires an empty inventory and no existing source identities, preserving existing wiki figures and subsequent edits or transfers. Source notes append once. The targeted import updates **only Elitch Gardens**, creates its directory entry if missing, and applies its summary and photographic inventory together in one transaction. It does not run other seeds or restore authoritative inventories. Repeated runs preserve edits, placements, and timestamps; failures roll back the entire import and exit unsuccessfully.

Run locally:

```sh
bin/rails carousels:import_elitch_gardens
```

For production, first commit and deploy these changes so the command and data are present in the running image. Take a database backup, then use the Kamal alias:

```sh
bin/kamal app exec --reuse "bin/rails backups:create"
bin/kamal import-elitch-gardens
```

The alias runs `bin/rails carousels:import_elitch_gardens` inside the existing production container against its persistent database. Output reports the environment, stored published totals, inventory count, and how many figures were added (zero on an unchanged repeat run). Existing values take precedence over research values. If an existing inventory prevents the photographic import, it is retained rather than supplemented with potentially duplicate figures. Do **not** run `db:seed` as a substitute.

### Historical seating research

The [researched-layout seed](db/seeds/us_researched_layouts.rb) records a five-carousel research pass:

- **Glen Echo:** the [summer 1994 NPS HABS survey](https://tile.loc.gov/storage-services/master/pnp/habshaer/md/md1300/md1366/data/md1366data.pdf) explicitly numbers all 54 positions in eighteen sections and three rings. Outside-to-inside horse counts are **12/14/14**, with **4 other animals per ring**. Chariots occupy **8A and 17A**, each only in the outer ring; independently catalogued ostriches occupy their B and C positions. The source's lead horse anchors 1A. Descriptive labels such as "Unidentified horse at 2A" are not guessed personal identities. **Every placement is best reading: this is a historical reference, not a verified current arrangement.**
- **Cafesjian's:** the [archived official roster](https://web.archive.org/web/20180120065911/http://www.ourfaircarousel.org/our-horses-and-chariots/) lists **16/16/18/18 horses**, with Red Chariot and Blue Chariot in the outside ring. Exact chariot columns and whether they extend into the second ring remain unverified, so the source notes retain these ring counts without inventing a regular-grid chart or empty seats.
- **Paragon, Bushnell Park, and Jane's:** additional source notes explain the remaining geometry gaps. Building sides, standing/jumping totals, and partial photographs are not treated as seat-column counts or exact placements.

The seating import runs only when Glen Echo has no section count, no seats, no figure inventory, and a compatible or unknown row count. Existing charts, figures, placements, and subsequent wiki edits are not restored or overwritten. Conflicting partial data is logged for manual review. Research notes append once and retain existing source notes.

To apply this research to an existing directory without restoring the four detailed inventories:

```sh
bin/rails runner 'load Rails.root.join("db/seeds/us_researched_layouts.rb")'
```

The directory records must already exist; for a new database, normal seed loading creates them first.

### Applying seed updates

The [address data](db/seeds/carousel_addresses.json) includes public visitor addresses, ZIP codes, source links, and venue/entrance caveats reviewed October 26, 2026. The [address seed](db/seeds/zz_carousel_addresses.rb) runs after the other seeds and fills only missing address fields. If either the existing street or postal code differs, it preserves the entire existing pair instead of mixing a new ZIP with an edited street. It retains existing source notes and does not change seating or inventory.

To apply only addresses to an existing directory after migrating:

```sh
bin/rails db:migrate
bin/rails runner 'load Rails.root.join("db/seeds/zz_carousel_addresses.rb")'
```

All seeded carousel records must already exist. The address import makes no geocoding or other network requests.

To import only the directory into an existing database, without rerunning the detailed inventories:

```sh
bin/rails db:migrate
bin/rails runner 'load Rails.root.join("db/seeds/us_operating_carousels.rb")'
```

Detailed inventory seeds add missing records and restore seeded data on existing records. Displaced placements are ended using the normal placement history; unrelated figures are not deleted. Rerunning unchanged seeds does not create duplicate records or history entries.

Wiki edits are **not automatically written back to seed files**. To preserve a reviewed layout, backfill the final seat assignments, row spans, and confidence levels into the relevant seed, record the source and review date, and update the seed tests before reseeding. A review date is not necessarily the video's filming date.

All currently collected carousel data lives in:

- [Missoula seed](db/seeds/a_carousel_for_missoula.rb)
- [Great Northern seed](db/seeds/great_northern_carousel.rb)
- [Salem seed](db/seeds/salems_riverfront_carousel.rb)
- [Spokane seed](db/seeds/spokane_looff_carrousel.rb)
- [U.S. operating-carousel directory](db/seeds/us_operating_carousels.rb)
- [Sourced historical layouts and ring research](db/seeds/us_researched_layouts.rb)
- [Physical address data](db/seeds/carousel_addresses.json) and [fill-only address import](db/seeds/zz_carousel_addresses.rb)

Seed files load automatically in filename order and require no network access.

## Data model

- **Carousel**: physical address with source notes, city/state/country, status, website links, published figure totals with source notes, optional rotation, and independently optional section/row counts. Both dimensions are required to draw a seating chart.
- **Seat**: one spot on a platform, addressed by its code. A tea-cup or chariot that fills several rows is one seat that spans them. Seats record whether their placement is confirmed or a best reading.
- **Figure**: one carved figure belonging to a carousel independently of seating, with a **figure type** (bison, trout, horse) whose category (horse, other animal, chariot or tub) sets its chart colour and section count.
- **Placement**: which figure sits in which seat, with dates, so figures can move.
- **Maker**: carvers and companies.

Every record keeps its edit history through PaperTrail.

## Editing

Anyone can read. Editing is invite-only:

- Create the first admin on a new server with `bin/rails users:create_admin EMAIL=you@example.com NAME="Your Name"`. It asks for a password.
- Reset an existing user's password with `bin/rails users:reset_password EMAIL=you@example.com` (or `bin/kamal app exec --interactive --reuse "bin/rails users:reset_password EMAIL=you@example.com"` on the deployed server). It prompts for a password of at least 12 characters and revokes that user's sessions.
- Admins invite editors from the Invitations page. Each link works for 14 days. If email isn't configured yet, copy the link from that page and send it yourself.
- Every page has a History tab. Recent changes lists every edit, and admins can revert any edit.
- Page text supports Markdown headings, lists, emphasis, links, and fenced code blocks on carousel, figure, figure type, and maker pages. Bare URLs become links. Blank lines start paragraphs and single line breaks are preserved. Rendered HTML is sanitized before display.
- A carousel with a recorded layout starts with an unknown seat in every spot; directory entries have no seats until a layout is added. To fill a seat, click it on the chart and choose a figure. Choosing a figure that already sits somewhere else moves it, and its old seat becomes empty.

## Testing

```sh
bin/rails test
bin/rails test:system test/system/seat_chart_test.rb
bin/rubocop
```

The tests cover carousel inventories and seating maps, directory seed completeness and non-destructive imports, unknown layouts and later chart creation, spanning figures, ownership and cross-carousel transfers, combined inventory filters, migration backfills, edit history, authoritative seed restoration, and unchanged-reseed idempotence. Browser tests exercise directory-to-chart transitions, chart-to-seat-to-figure navigation, and the inventory filtering workflow.
