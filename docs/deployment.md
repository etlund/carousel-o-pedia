# Deployment and backups

[Back to the README](../README.md)

## Kamal configuration

[config/deploy.yml](../config/deploy.yml) targets the Ubuntu x64 Droplet at
`201.79.38.100`, using SSH as root with `~/.ssh/id_ed25519`. The image is built
for `amd64`, including on Apple Silicon. Kamal Proxy obtains HTTPS certificates
for `carouselopedia.org`; Rails trusts the proxy and uses secure cookies.

The Rails namespace is `CarouselOPedia`, the Kamal service is `carousel_o_pedia`,
and the image is `ghcr.io/etlund/carousel-o-pedia`. The existing
`carousel_pedia_storage` volume and `_carousel_pedia_session` cookie name are
retained to preserve data and sessions. When upgrading an old deployment, stop
the `carousel_pedia` service before starting `carousel_o_pedia` against the
shared volume. Renaming the volume requires a separate data migration.

### Prerequisites

- Point the domain's A record at the Droplet. Publish AAAA only if IPv6 works.
- Allow public inbound TCP 80/443 and TCP 22 from the deployment computer.
  Do not expose port 3000. Allow outbound image and certificate traffic.
- Verify the SSH host fingerprint through DigitalOcean's console and confirm
  key-based access.
- Run Docker locally; Kamal's first setup can install Docker on the server.
- Create a GitHub classic personal access token with `write:packages` for
  `etlund`. Keep it private and confirm the GHCR package remains private.
- Generate `SECRET_KEY_BASE` once with `bin/rails secret` and store it in your
  password manager. Keep it stable across deployments; never use a validation
  placeholder in production.

Set `KAMAL_REGISTRY_PASSWORD` and `SECRET_KEY_BASE` in the deployment environment
or local `.env`, using your password manager or hidden terminal prompts.
`bin/kamal` loads `.env`, with existing process values taking precedence.
The tracked secrets file references variables, never their values.

Production uses environment variables for secrets, not Rails encrypted
credentials, and does not require `RAILS_MASTER_KEY`. Before adopting encrypted
credentials, recover the matching key or deliberately provision a new encrypted
file and key.

## First launch and subsequent deploys

**Decide the data import and administrator credentials before `bin/kamal setup`.**
Setup starts a public app whose entrypoint runs `db:prepare`, seeding a fresh
database with known development credentials.

To preserve development edits and history:

1. Prepare a consistent SQLite backup using SQLite's backup facility, not a
   direct copy of a live database. Retain the unmodified backup separately.
2. Prepare a private launch copy. Review imported accounts, remove the known
   development password, and invalidate imported sessions and invitation links.
3. Import that same prepared artifact as `storage/production.sqlite3` in the
   persistent volume before application startup. Never commit backups or private
   data, or rerun inventory seeds over edited data.
4. Configure off-server backups and test upload and restore before launch.

Set the administrator password against the **prepared launch copy** explicitly:

```sh
DATABASE_URL=sqlite3:/absolute/path/to/launch/production.sqlite3 \
  bin/rails users:reset_password EMAIL=you@example.com
```

The command prompts without echoing, requires at least 12 characters, and
revokes that user's sessions. Omitting `DATABASE_URL` operates on development,
not the prepared launch copy.

Once credentials, import, and backups are ready:

```sh
bin/kamal setup    # first deployment; installs Docker and starts the app
bin/kamal deploy   # subsequent deployments of committed changes
bin/kamal logs
curl --fail https://carouselopedia.org/up
```

SQLite persists in `carousel_pedia_storage`. Separate production queue, cache,
and cable databases are created by `db:prepare`. There are currently no photo
attachments or Active Storage tables. If uploads are introduced, migrate and
back up their files with the database while uploads are paused.

Outbound email is not configured: send invitation links manually and do not
rely on password-reset email until SMTP and a verified sender are ready.
Other registered domains are not yet aliases or redirects.

The editor-access migration adds nullable suspension and contribution-agreement
fields without changing existing accounts' access or asserting consent.
After deploying it, existing editors and admins must explicitly agree to the
published terms before protected editing/admin actions. Public browsing and
sign-out remain available. Confirm that the prospective CC BY-SA 4.0 policy
is ready to publish before deploying; the public contact route remains deferred.

## Web traffic statistics

Cloudflare Web Analytics provides a free dashboard for visits, page views,
referrers, and page performance. No DNS or proxy change is required.

The public site token for `carouselopedia.org` is configured as
`CLOUDFLARE_WEB_ANALYTICS_TOKEN` in Kamal's `env.clear`. This is a browser-visible
site identifier, not a Cloudflare API credential. Production loads the beacon
only when this variable is present; development and test do not enable it.
Remove the variable or set it to an empty string and redeploy to disable it.

In Cloudflare's **Web Analytics**, add or open `carouselopedia.org` and use
**Manage site → Enable with JS Snippet installation** for manual installation.
Do not also enable automatic script injection: the app supplies the script.
If replacing the site, copy the new snippet's `token` value into Kamal's config.

The beacon lives in the document head so Turbo loads it once, with SPA tracking
enabled for history-based navigation. No custom events or analytics cookies
are added. The public privacy page describes this service.

After deploying, visit the production site without an ad blocker. In browser
developer tools, confirm `beacon.min.js` loads once, browse between a few pages
using Turbo, then switch tabs to flush the last measurement. Confirm successful
beacon requests to `cloudflareinsights.com` and check Cloudflare's Web Analytics
dashboard after a few minutes. Ad blockers can prevent collection, so the counts
are approximate. See Cloudflare's [setup guide](https://developers.cloudflare.com/web-analytics/get-started/)
and [SPA measurement notes](https://developers.cloudflare.com/web-analytics/faq/).

## Carousel video analysis

Trusted users can upload carousel video for a draft seating layout (see
`docs/editing.md`). The job pulls still frames with `ffmpeg`, which the
Dockerfile installs, and sends them to Claude through the `ruby_llm` gem's
Anthropic provider. Set `ANTHROPIC_API_KEY`
locally before deploying; Kamal passes it to the app like the backup keys. Without
it, uploads still work but each analysis fails with a message saying the key is
missing. `VIDEO_ANALYSIS_MODEL` overrides the model (default `claude-opus-5-5`).
Requests use structured JSON output, adaptive thinking at high effort, and
Anthropic's server-side fallback. They wait for a complete response (up to ten
minutes) so refusals and token-limit truncation can be detected before saving a draft.
Completed analyses store RubyLLM's point-in-time USD cost estimate, calculated
from the response's token usage and the model pricing registry. This is an
estimate rather than a reconciliation with the Anthropic invoice.

A run reads up to 36 pairs of frames per clip (each pair a third of a second
apart, so jumpers can be told from standers), so three clips are about 216
images. Expect roughly $1 to $1.50 per three-clip analysis, less for one clip. Uploaded clips sit in Active Storage on the
`storage` volume until the analysis succeeds, then they are deleted; a failed
analysis keeps its clips so it can be retried.

## Database backups to DigitalOcean Spaces

`DatabaseBackupJob` runs daily at 03:00 in the application's time zone (UTC by
default). It uses SQLite's online backup API, includes committed WAL data, checks
integrity and foreign keys, and uploads the primary database privately to
`carouselopedia-backups` in `mkc1`.

The endpoint is `https://mkc1.digitaloceanspaces.com`, not a bucket-prefixed or
CDN URL. The SDK uses `us-east-1` for signing; the endpoint selects the storage
location.

Store `BACKUP_ACCESS_KEY_ID` and `BACKUP_SECRET_ACCESS_KEY` locally with the
deployment secrets or export them. Use a dedicated Spaces key restricted to
this bucket with upload, download, listing, and deletion permissions. Kamal
passes these secrets to the app; do not track their values.

Backups use unique timestamped names under `database/production/` with SHA-256
metadata. Only matching backup filenames older than 30 days are deleted, and
only after a successful upload. Temporary local files are removed automatically.
Backups contain accounts, sessions, catalog data, and history: treat them as
sensitive. Queue/cache/cable databases are not backed up and can be recreated.

### Test upload and restore

Before launch, back up the prepared copy:

```sh
BACKUP_BUCKET=carouselopedia-backups \
BACKUP_ENDPOINT=https://mkc1.digitaloceanspaces.com \
DATABASE_URL=sqlite3:/absolute/path/to/launch/production.sqlite3 \
  bin/rails backups:create
```

Use the exact object key printed by the command to verify it:

```sh
BACKUP_BUCKET=carouselopedia-backups \
BACKUP_ENDPOINT=https://mkc1.digitaloceanspaces.com \
  bin/rails backups:verify KEY=database/production/KEY_FROM_PREVIOUS_COMMAND.sqlite3
```

Verification downloads into a temporary restored database and checks SHA-256,
SQLite integrity, foreign keys, and catalog/history counts. It never replaces
the live or development database. Compare counts against the source and keep
the object key and checksum with the launch record.

After deployment:

```sh
bin/kamal app exec --reuse "bin/rails backups:create"
bin/kamal app exec --reuse "bin/rails backups:verify KEY=database/production/EXACT_BACKUP_FILENAME.sqlite3"
```

Failures propagate to command exit status or Solid Queue failed-job records
and application logs. External failure/staleness alerts are not configured.
Check logs and the bucket's latest backup timestamp, and arrange external
alerting before relying on unattended backups: a stopped app or queue cannot
run its own backup job. Keep Droplet backups as another layer, not a substitute
for tested application restores.
