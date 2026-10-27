# Editing and data model

[Back to the README](../README.md)

## Browsing and sorting

The carousel directory supports case-insensitive partial name searches and a
state/region filter. Choose **Filter** to apply either or both. Filters and sort
order stay in the URL for sharing; **Clear filters** restores the full directory
and default **Most complete** sort.

- **Most complete** measures seating documentation, not article completeness:
  most confirmed seats first, then most best-reading seats. Ties favor a known
  row or section count over neither dimension, then sort by name and record ID.
  Each current seat counts once, including empty or unidentified positions and
  seats spanning multiple rows. Earlier placements do not increase the count;
  carousels without seats count as zero.
- **Last updated** sorts newest first, including activity on figures (even
  unseated inventory), seats, and placements. Creating, removing, or transferring
  those records updates the affected carousels. Existing record timestamps count
  even if they predate activity tracking; timestamp-only activity does not add
  carousel or seat history entries. Ties sort by name and record ID.
- **Name (A-Z)** sorts alphabetically.

Cards show seating completeness as recorded counts or known dimensions, not an
invented percentage. Older `sort=confirmed_seats` links still select Most
complete; new links use `sort=completeness`.

Each card places a 112-pixel chart preview to the left of the figure-count
facts, keeping them side by side on narrow screens with wrapping labels.
Incomplete layouts show only known geometry, without inventing sections or
positions. The preview links to the carousel page.

## Access and history

Anyone can read; editing is invite-only. Admins invite editors from the
Invitations page. Invitation links work for 14 days. Outbound email is not yet
configured, so copy and send invitation links manually.

Create the first administrator with:

```sh
bin/rails users:create_admin EMAIL=you@example.com NAME="Your Name"
```

Reset an existing user's password locally or on the deployed server:

```sh
bin/rails users:reset_password EMAIL=you@example.com
bin/kamal app exec --interactive --reuse "bin/rails users:reset_password EMAIL=you@example.com"
```

Password resets prompt without echoing, require at least 12 characters, and
revoke that user's sessions. For a prepared production database, explicitly set
`DATABASE_URL`; see [deployment](deployment.md).

Records keep edit history through PaperTrail. History pages show earlier
versions, Recent changes lists edits, and admins can revert edits.

## Core records

- **Carousel**: location, operating status, website links, sourced published
  totals, optional rotation, and independently optional section and row counts.
- **Seat**: a position on a platform. A chariot or tub spanning several rows is
  one seat. Placement confidence distinguishes confirmed positions from best
  readings.
- **Figure**: a carved object belonging to a carousel, whether seated or not.
  Its figure type (such as horse, bison, or trout) determines its chart category:
  horse, other animal, or chariot/tub.
- **Placement**: the dated relationship between a figure and a seat, preserving
  movement history.
- **Maker**: a carver or company.

## Seating and inventory

Seat codes combine a section number and row letter: `5A` means section 5 at
the outer rail. Rows run from A inward; sections follow the order figures pass
someone standing at the rail. A spanning figure occupies one seat across
multiple rows, not multiple figure records.

Both section and row counts are needed to create seats and a full seating
chart. Until then, each known dimension can be recorded independently without
inventing the rest. Once both are recorded, platform size is fixed in the
editor. Rotation is optional and is never guessed.

A newly recorded layout starts with unknown seats. Click a seat to assign a
figure; choosing one already seated elsewhere moves it and leaves its old seat
empty. Occupied chart positions open the Figure page; empty and unknown
positions open the Seat page. Figure history and seat history remain separate.

Figures retain their carousel assignment when removed from a seat. The Figures
page includes unseated reserves and project figures and filters by carousel and
type. To transfer a figure through the editing forms:

1. Remove it from its current seat.
2. Change its carousel on the Figure edit page.
3. Assign it a seat on the destination carousel.

The placement service also transfers ownership for cross-carousel moves, but
seat-editing forms only offer figures from the current carousel.

## Counts, uncertainty, and sources

Summary cards prefer published totals for horses, other animals, and
chariots/tubs. If a total is blank, they use mapped counts when a layout is
known, or **Unknown** otherwise. A published zero is a verified value.
Published totals require Markdown source notes and never create placeholder
figures or seats.

Mapped counts exclude unseated inventory and ended placements and count a
spanning figure once. Charts always show mapped data, which can differ from
source-reported totals. Keep source dates, historical configurations, and
disagreements in **Summary sources**.

Independent ring research records total positions, horse counts, and horse
motion separately for each row. Unknown values stay blank; verified zero stays
zero. Only known total-position counts divide the research diagram into
positions. Horse counts alone do not establish ring geometry, and equal spacing
does not establish angular alignment. This research creates no figures, seats,
or placements and does not change an existing chart.

Charts use blue for horses, orange for other animals, and red for chariots/tubs.
Best-reading placements have uncertainty styling; unknown and empty positions
remain distinct. Mount symbols identify jumper, stander, spinning, and fixed
figures. The full chart includes a legend and clickable seats; wide layouts
offer an expanded dialog, closed with its close control or Escape.

## Text, addresses, and links

Carousel, figure, figure type, and maker text supports Markdown headings,
lists, emphasis, links, and fenced code blocks. Bare URLs become links, blank
lines start paragraphs, and single line breaks are preserved. Rendered HTML is
sanitized.

Street addresses and postal codes are optional. Postal codes are text to retain
leading zeros. Use **address sources and notes** to distinguish a visitor
entrance or venue address from the exact carousel location; mailing offices and
PO boxes are not ride addresses. An address is not a verified map point.

Official website and Wikipedia URLs must use HTTP or HTTPS without login
credentials. Other named links use sanitized Markdown, one per line, such as
`[NCA gallery](https://carousels.org/)`.
