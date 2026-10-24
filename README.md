# Carousel-pedia

A wiki for carousels, their carved figures, and their history.

Every seat has a code of section number plus row letter. Rows are lettered from the outside in, so `5A` is section 5, outer row. Sections are numbered in the order figures pass someone standing at the rail.

## Getting started

```sh
bin/setup          # installs gems, prepares the database, loads seeds
bin/dev            # http://localhost:3000
bin/rails test
```

The seeds load the Great Northern Carousel in Helena, Montana: 14 sections, 3 rows, 36 animals, a tea-cup and a chariot bench.

## Data model

- **Carousel**: location, status, rotation, and the size of its platform (sections × rows).
- **Seat**: one spot on a platform, addressed by its code. A tea-cup or chariot that fills several rows is one seat that spans them. Seats record whether their placement is confirmed or a best reading.
- **Figure**: one carved figure, with a **figure type** (bison, trout, horse) whose category (horse, other animal, chariot or tub) sets its chart colour and section count.
- **Placement**: which figure sits in which seat, with dates, so figures can move.
- **Maker**: carvers and companies.

Every record keeps its edit history through PaperTrail.
