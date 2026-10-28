# Editing and data model

[Back to the README](../README.md)

## Browsing and sorting

The carousel directory supports case-insensitive partial searches of primary and
other names and a
state/region filter. Choose **Filter** to apply either or both. Filters and sort
order stay in the URL for sharing; **Clear filters** restores the full directory
and default **Most complete** sort.

State options include directory-wide carousel counts, such as **Montana (2)**.
These counts stay the same when name or state filters are applied.

Below the filter button, a count shows the total number of carousels listed.
When filtering, it shows the matching count alongside the directory total.

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

Leave **Email (optional)** blank and choose **Create invitation** to generate a
single-use link without knowing the recipient's email address. Copy the link from
**Waiting to be accepted** and send it privately, for example in chat. The
recipient must provide their email address, public display name, password, and
agreement to the contribution terms when creating an account. Failed submissions
do not consume the link. Anyone holding an unbound link can claim its configured
editing access, so share it with only one person. Withdraw a pending invitation
to revoke it. To restrict an invitation to a known email address, fill in that
address when creating it; the recipient cannot change it during acceptance.

Invitations offer **Site-wide editing** or **One carousel only**. For one-carousel
access, choose an existing carousel or leave the carousel blank to allow creation
of exactly one new carousel. The first successful creation assigns that carousel
to the editor; failed submissions do not consume the permission. A name is enough
to create the initial blank record; layout and inventory can be added later.
The editor can edit that carousel and create/edit its figures and seats, but
cannot edit shared makers or figure types, transfer figures to/from another
carousel, or create a second carousel. Reading other records and history remains
available. Existing accounts and the default invitation retain site-wide access.
Permissions are enforced server-side without an authorization gem.

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

### Contributor guidance and agreement

The public **About / Contribute** page (`/about`) explains the pilot and how to
contribute. The **Editor guide** (`/editor-guide`) covers first edits, sourcing,
uncertainty, seating conventions, and corrections. **Contribution terms &
privacy** (`/contribution-terms`) describes conduct, public attribution, account
data, and the prospective CC BY-SA 4.0 license for new original contributed text.
These pages are linked in every page's footer.

Invited editors must explicitly agree when accepting an invitation. Existing
editors and administrators must agree before opening editing forms or submitting
protected changes. Browsing, reading the terms, and signing out remain available
without agreement. Acceptance records the submitted terms version and
server-side timestamp; a stale version cannot be accepted. Earlier contributions
and third-party material are not automatically relicensed.

No existing accounts are marked as having agreed by the migration. When changing
the terms, preserve a copy of the previous policy, update the public text and
`User::CONTRIBUTION_TERMS_VERSION` together, and require renewed agreement.
Do not backfill acceptance on behalf of contributors.

Display names appear publicly with edits and do not have to be legal names.
Editors can work within the scope of their invitation. Saved changes are public
immediately, not held for approval. Admin reverts restore individual updated
records, not new records or an entire multi-record move.

A public contact address is deliberately not configured yet. The About page
directs existing contacts to their conversation with the inviter/site sharer and
asks other visitors to check back. Replace that interim guidance with the real
contact route in the About page, editor guide, and contribution terms when ready.

### Suspending and restoring editors

Admins manage access in the **Editors** section of **Invitations**:

- **Suspend** disables sign-in and editing and revokes all of the editor's
  sessions. The account, contributions, and public attribution remain intact.
- **Restore access** allows a fresh sign-in; old sessions remain invalid.
  Resetting a password does not lift suspension.
- Administrators cannot be suspended through these controls. No account-deletion
  action is provided; do not delete accounts to revoke editing access.

Pending invitations can still be withdrawn separately. Withdrawing an invitation
does not suspend an accepted account.

## Core records

The new and edit carousel forms put everyday details first: names, status,
maker and years, venue and address, then page text and website links. Platform
details, published totals and sources, and detailed ring research follow.

- **Other names**: on the carousel form, enter alternate or historical names for
  the same carousel, one per line. Blank lines and exact duplicates are removed.
  These optional names appear on its page and directory card and are searchable.
  They do not change its primary name or URL; edits are tracked in page history.
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

### Filling unknown seats in bulk

On a carousel with a recorded layout, editors can choose **Fill unknown seats**
when unknown seats remain. Place any known chariots (including their row spans)
and mark empty positions first. Choose an existing figure type and motion, add
source/research notes, then **Preview seats**. Review the affected seat codes,
provisional names, row spans, and notes before choosing **Create draft figures**.
You can change your choices or cancel without saving anything.

Applying creates one figure per unknown seat, with a seat-based name such as
**Horse 2A**, and copies the source notes to each figure's page. These are
placeholders for later identification; all new placements are **best readings**,
never confirmed. Existing figures, empty positions, and row spans are preserved.
The entire fill is saved together and appears in figure and seat history. If the
seats or figure type change after preview, or the preview expires after one hour,
preview again before applying; nothing is partially saved or silently skipped.
This tool does not infer a layout from published totals or reuse unseated figures.

Figures retain their carousel assignment when removed from a seat. The Figures
page includes unseated reserves and project figures and filters by carousel and
type. To transfer a figure through the editing forms:

1. Remove it from its current seat.
2. Change its carousel on the Figure edit page.
3. Assign it a seat on the destination carousel.

The placement service also transfers ownership for cross-carousel moves, but
seat-editing forms only offer figures from the current carousel.

## Drafting a layout from video

Admins, and editors an admin allows from the Invitations page, can open
**Analyze a video** on a carousel they can edit. They upload up to three clips,
each a little over one revolution: a side pass pointed straight in from the rail,
an oncoming pass angled toward approaching figures, and an inner pass from the
platform. At least one clip should be filmed while the ride runs, so jumpers can
be told from standers. The upload page explains the filming recipe.

The analysis produces a draft, not carousel data: section and row counts,
rotation, and for each seat the figure type, kind, motion, and a description,
each with a confidence. The reviewer corrects the draft and ticks the seats to
apply. Applying records the layout if the carousel has none, then fills only
seats that are still unknown. It never replaces a figure or an empty seat an
editor recorded, and every figure it adds is a best reading with a numbered name
such as Horse 3. A draft whose layout disagrees with the recorded one cannot be
applied. All changes appear in page history like any other edit.

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
The research wheel appears only when no mapped seating chart exists. Once a
chart exists, ring research remains available as a table alongside its sources.

Charts use blue for horses, orange for other animals, and red for chariots/tubs.
Best-reading placements have uncertainty styling; unknown and empty positions
remain distinct. Mount symbols identify jumper, stander, spinning, and fixed
figures. The mount key sits on a separate row below the category legend in both
regular and expanded views. The full chart includes clickable seats; wide layouts
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
Address sources appear below the Sections table, or below the main carousel
details when no seating layout is recorded.

Official website and Wikipedia URLs must use HTTP or HTTPS without login
credentials. Other named links use sanitized Markdown, one per line, such as
`[NCA gallery](https://carousels.org/)`.
