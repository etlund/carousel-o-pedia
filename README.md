# carousel-o-pedia

A wiki for carousels, their carved figures, and their history.

Browse the carousel directory by name or state, explore interactive seating
charts, and follow individual figures and their placement history. Anyone can
read; invited editors can contribute sourced research, inventory, and layouts.
Edits are tracked with PaperTrail.

Built with Rails 8.1, SQLite, Hotwire, and server-rendered SVG seating charts.

## Getting started

Use Ruby 3.3.6 (see [.ruby-version](.ruby-version)) and Bundler.

```sh
git clone https://github.com/etlund/carousel-o-pedia.git
cd carousel-o-pedia
bin/setup --skip-server  # installs gems and prepares the database
bin/dev                  # http://localhost:3000
```

In development, sign in as `admin@example.com` with password `carousel`.
Never use these credentials in production.

A fresh database loads the offline seeds: 54 U.S. carousels, including four
detailed inventories, a historical Glen Echo layout, and partial Elitch Gardens
research. Preparing an existing database does not refresh its seeded inventory.

> **Back up before reseeding an edited database.** The four detailed inventory
> seeds overwrite seeded attributes and placements. See the
> [seed data guide](docs/seed-data.md) for safe, targeted imports.

### Environment and database updates

Rails and `bin/kamal` load local variables from `.env`; Rails also supports
environment-specific files such as `.env.development` and `.env.test`.
Existing process variables take precedence. Environment files are ignored by
Git: never commit secrets. Restart the server or console after changing them.

After updating an existing checkout, apply schema changes separately from seeds:

```sh
bin/rails db:migrate
```

## Editing

Admins invite editors from the Invitations page. Links expire after 14 days;
if email is not configured, copy and send the link manually.
Invitations also provides reversible editor suspension with session revocation.
New and existing editors must explicitly agree to the contribution terms before
editing. New original text submitted after agreement is licensed under
CC BY-SA 4.0; earlier and third-party material is not automatically relicensed.

Public About / Contribute, Editor guide, and Contribution terms & privacy pages
are linked in the footer. The public contact route is still pending.

To create the first administrator:

```sh
bin/rails users:create_admin EMAIL=you@example.com NAME="Your Name"
```

The command prompts for a password. For editing workflows, seat conventions,
and password resets, see the [editing and data guide](docs/editing.md).

## Testing

```sh
bin/rails test
bin/rails test:system test/system/seat_chart_test.rb
bin/rubocop
```

## Documentation

- [Editing and data model](docs/editing.md): browsing, sorting, figures, seats,
  sources, and history.
- [Seed data and imports](docs/seed-data.md): seed behavior and preserving edits.
- [Deployment and backups](docs/deployment.md): Kamal setup, launch precautions,
  and backup verification.
- [Carousel map plan](docs/carousel-map-plan.md): proposed mapping work; maps and
  coordinates are not implemented.
