# Carousel map implementation plan

## Scope and current foundation

The directory currently contains 54 U.S. carousels. This pass adds optional
`street_address`, `postal_code`, and Markdown `address_sources` alongside the
existing city, state/region, and country. Postal codes are strings, preserving
leading zeros. The address seed fills missing values without replacing wiki
addresses or combining a conflicting street and ZIP code.

These are public ride or visitor-entrance addresses. A zoo or amusement-park
address is not necessarily the carousel's door or its precise position inside
the venue. Source notes must retain that distinction.

**This pass does not store coordinates, add a map library, or implement a map.**
Some postal codes have supplementary address-lookup evidence, disclosed in the
source notes. No geocoding runs in seeds or application requests. An address
alone is not a verified map point.

## 1. Collect and review coordinates

Add nullable latitude and longitude together, using decimal columns with enough
precision for venue-scale locations, for example `decimal(10, 7)`. Validate that:

- Both coordinates are present or both are absent.
- Latitude is between -90 and 90; longitude is between -180 and 180.
- Invalid, nonnumeric, or nonfinite values produce visible validation errors.
- Missing coordinates never become `(0, 0)` or a city/ZIP centroid.

Also record coordinate source notes, a verification date, and precision:
`ride`, `visitor_entrance`, `venue`, or `approximate`. Address provenance and
coordinate provenance are separate. A reviewer should inspect the actual ride
or entrance on an authoritative map before promoting a point to verified.

Preferred collection order:

1. Explicit operator or public-agency ride/entrance coordinates.
2. Manually reviewed points matched against the operator's venue map.
3. Geocoder candidates for review, never automatic assertions of ride precision.

Implement any geocoding as an explicit, resumable maintenance command with a
dry-run mode, timeouts, rate limiting, cached results, and a per-record outcome
report. Do not geocode during seeds, model saves, page requests, or browser
searches. An ambiguous or failed lookup stays unresolved; it must not return a
success-shaped fallback.

Choose and approve a provider and its storage/licensing terms before making
requests. **Do not default to the public Nominatim service.** Its
[usage policy](https://operations.osmfoundation.org/policies/nominatim/) imposes
application-wide limits, identification, attribution, caching, and restrictions
on bulk work and autocomplete. Any use requires an informed, deliberate provider
decision; a hosted provider or appropriately operated self-hosted service may
be a better fit.

When street, city, state/region, postal code, or country changes, mark existing
coordinates as needing review and exclude stale points from the map until
reverified. Keep their previous values and provenance for review/history rather
than silently moving a marker.

## 2. Add a map view without replacing the directory

Recommended first version: a **List / Map** switch on `/carousels`, with the list
remaining the default. Both views share the existing name and state filters and
their URL parameters. Changing views preserves filters; invalid view values
receive the same explicit parameter handling as invalid sort values.

Keep filtering server-side and reuse one filtered carousel relation for cards
and map data. At this directory size, a small allowlisted payload embedded in the
page is sufficient; a new API or spatial-search service is not necessary.

Map behavior:

- Show only verified, non-stale coordinate pairs from the filtered results.
- Display coverage explicitly: “X of Y carousels shown; Z await location review.”
- Keep all results accessible in the list, including those without coordinates.
- Fit bounds to actual results, including Alaska and any future Hawaii entries;
  do not silently restrict the view to the contiguous states.
- For one result, use a bounded, useful zoom; for none, show a clear empty state.
- Provide a “Fit all results” action. Panning should not silently change filters.
- Give each marker a name and a popup with the carousel name, address, precision
  caveat, and internal detail link.
- Distinguish approximate/entrance points in text, not solely by color.
- Handle identical coordinates with an accessible grouped popup/list rather than
  obscuring carousels beneath one another.

Do not add automatic viewport searches, distance ranking, visitor geolocation,
directions, or complex clustering in the first version. Add clustering only if
actual overlap warrants it.

## 3. Rendering, providers, and lifecycle

Use Leaflet with a Stimulus controller and the existing Rails asset/importmap
setup, rather than introducing a new frontend framework. At implementation time,
select a supported stable build and verify its loading format against importmaps.
The [official download documentation](https://leafletjs.com/download.html)
currently lists stable 1.9.4 and a 2.0 prerelease; do not select a prerelease just
to obtain a different module format.

Prefer locally served, pinned library assets with their license notices.
Leaflet's CSS and any referenced marker images must also be packaged correctly.
Initialize once on Stimulus connect, remove the map on disconnect, and handle
Turbo cache visits and resize events without duplicate maps or stale handlers.

Choose the production tile provider separately from the rendering library.
OpenStreetMap data is open, but the public tile service is capacity-limited and
best effort, not an unlimited production hosting agreement. If using it, follow
the [tile usage policy](https://operations.osmfoundation.org/policies/tiles/):
visible attribution, HTTPS, appropriate identification/referrer behavior,
normal caching, and no bulk download or prefetch. Make provider configuration
replaceable without rewriting the map UI.

Review costs, rate limits, attribution, browser privacy implications, and
availability before deployment. Restrict any public browser token by origin;
keep server credentials out of HTML and source control. Update CSP only for
the selected provider's required origins, not broad wildcard allowances.

## 4. Accessibility, safety, and failure handling

- Keep a usable server-rendered directory when JavaScript is disabled, the map
  library fails, or tiles are unavailable.
- Show map-loading errors explicitly while leaving the list and filters usable.
- Label the map region, controls, and keyboard-focusable markers.
- Support keyboard popup opening/closing, visible focus, and escape dismissal.
- Do not trap page scrolling, rely solely on hover, or require map gestures to
  reach a carousel detail page.
- Check mobile layouts, reduced motion, and light/dark contrast.
- Serialize only public marker fields with Rails' JSON escaping. Insert names
  and addresses into popups as text/DOM nodes, not interpolated HTML.
- Do not expose whole Active Record objects, private data, or unsanitized source
  notes through the map payload.

## 5. Tests and acceptance criteria

Coordinate/model tests:

- Paired optional coordinates, inclusive bounds, invalid inputs, and stale-point
  handling after each relevant address-field change.
- Exact decimal round trips and explicit source/precision/review metadata.
- Cached and repeatable maintenance imports that preserve reviewed wiki edits.

Request and browser tests:

- The same carousel IDs match name/state filters in both views.
- Only verified, non-stale points appear; missing points remain in the list.
- Correct coverage counts, empty/single-result behavior, and Alaska inclusion.
- Marker names, detail navigation, shared-coordinate handling, and keyboard use.
- Malicious names/addresses render as text, not executable markup.
- Turbo back/forward navigation does not duplicate maps or handlers.
- No-JavaScript and tile/provider failures leave a useful directory.
- Desktop/mobile layouts remain usable and attribution remains visible.
- Stub network/provider responses in tests; CI does not call live geocoders or
  depend on public tile-service availability.

Rollout order: coordinate schema and editing, reviewed coordinate collection
with a coverage report, then the optional map view. Do not claim all 54 are
mapped until every seeded location has a reviewed point; show partial coverage
honestly while review proceeds.
