# Seed data and imports

[Back to the README](../README.md)

## Included data

Offline seeds contain 54 U.S. carousels: detailed inventories for Great Northern,
Missoula, Spokane, and Salem, plus 50 directory entries. Research also includes
Glen Echo's historical 1994 seating reference and two unplaced Elitch Gardens
chariots. Sources, dates, and uncertainty notes are stored with the records.

Historical layouts and video readings are not verified current surveys.
Catalog inventories can include reserves, project figures, and non-riding ring
dispensers, so catalog size, mapped counts, and published riding totals differ.
Do not infer sections from animal counts or treat an upload/review date as a
filming date. "Operating" directory status does not guarantee a ride is open
today; check the operator's website.

## Preserving wiki edits

> **The four detailed inventory seeds are authoritative for now.**
> `bin/rails db:seed` overwrites wiki edits to seeded attributes, chart shapes,
> and known placements. Back up an edited database before intentionally reseeding.

Detailed seeds add missing records and restore seeded data on existing records.
Displaced placements end through normal placement history; unrelated figures are
not deleted. Unchanged reruns create neither duplicate records nor history.

Wiki edits are not written back to seed files. To preserve a reviewed layout,
backfill seat assignments, spans, confidence, sources, and review dates into its
seed and update the seed tests before reseeding.

Other imports are deliberately narrower:

- **Directory:** creates missing entries by stable slug without replacing edited
  metadata. Researched totals and dimensions fill only nil values, preserving
  zero and conflicting existing dimensions. Source notes append without
  replacing earlier notes. No figures or placements are created.
- **Historical layout research:** imports Glen Echo only when sections, seats,
  and inventory are absent and rows are compatible or unknown. Conflicting
  partial data is logged for review. Other research retains unresolved geometry
  in source notes rather than inventing charts.
- **Addresses:** fills missing fields without replacing edits. If either the
  existing street or postal code conflicts, the whole existing pair is retained.
  Source notes are preserved; no geocoding or network requests run.
- **Elitch Gardens:** updates only this carousel, creating its directory entry
  if missing. Missing research values are filled without overwriting wiki
  values. Photographic figures import only into an empty inventory without
  existing source identities. The entire import is transactional; repeat runs
  preserve edits, placements, and timestamps.

The figure ownership migration backfills each figure's carousel from current or
recent placements, then known seeded collection slugs. If ownership cannot be
determined, migration stops and lists the unresolved figures instead of
inventing owners.

## Targeted updates

After updating the checkout, migrate first:

```sh
bin/rails db:migrate
```

Import the directory without rerunning detailed inventories:

```sh
bin/rails runner 'load Rails.root.join("db/seeds/us_operating_carousels.rb")'
```

Apply historical layout research or addresses to existing directory records:

```sh
bin/rails runner 'load Rails.root.join("db/seeds/us_researched_layouts.rb")'
bin/rails runner 'load Rails.root.join("db/seeds/zz_carousel_addresses.rb")'
```

These imports require their carousel records to exist. Normal seed loading on
a new database creates them in filename order.

Import only Elitch Gardens, including its summary, photographic inventory, and
partial ring research:

```sh
bin/rails carousels:import_elitch_gardens
```

This preserves the census/operator horse-count discrepancy and leaves unknown
positions unassigned. Output reports the environment, published totals,
inventory count, and figures added. Existing inventory is retained rather than
supplemented with possible duplicates.

For production, commit and deploy the import code and data first, then back up
and use the targeted Kamal alias:

```sh
bin/kamal app exec --reuse "bin/rails backups:create"
bin/kamal import-elitch-gardens
```

Do not substitute `db:seed` for a targeted production import.

## Source files

- [Great Northern](../db/seeds/great_northern_carousel.rb)
- [Missoula](../db/seeds/a_carousel_for_missoula.rb)
- [Spokane](../db/seeds/spokane_looff_carrousel.rb)
- [Salem](../db/seeds/salems_riverfront_carousel.rb)
- [U.S. operating directory](../db/seeds/us_operating_carousels.rb)
- [Historical layouts and ring research](../db/seeds/us_researched_layouts.rb)
- [Elitch Gardens research](../db/seeds/us_researched_elitch_gardens.rb)
- [Address data](../db/seeds/carousel_addresses.json) and
  [address import](../db/seeds/zz_carousel_addresses.rb)
