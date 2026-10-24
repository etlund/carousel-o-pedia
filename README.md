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

The seeds load the Great Northern Carousel in Helena, Montana: 14 sections, 3 rows, 36 animals, a tea-cup and a chariot bench.

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
- A new carousel starts with an unknown seat in every spot. To fill a seat, click it on the chart and choose a figure. Choosing a figure that already sits somewhere else moves it, and its old seat becomes empty.
