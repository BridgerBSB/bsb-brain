---
name: mlb-stats-api-exploration
description: "Parking lot for MLB Stats API integration — surfaces multiple times in the codebase (umpires, video URLs, live scores, league-wide roster) and warrants a focused exploration session on the personal laptop. NOT yet implemented anywhere."
metadata: 
  node_type: memory
  type: project
  originSessionId: be437682-ab08-4c5c-8351-30bc48608616
---

# MLB Stats API — exploration parking lot

User flagged May 14 2026 that MLB Stats API "keeps getting brought up"
across multiple unrelated needs. Wants to do a focused exploration
session on the personal laptop (no DB access needed — HTTP only) to map
out what's possible BEFORE wiring it into any single app.

## Why this matters now

Three live needs are all "waiting on something MLB Stats API could
provide." Building per-need integrations would duplicate auth /
caching / pin scaffolding three times. Building ONE shared
`mlb_stats_api.py` helper + pin layer is the right shape if the API
covers more than one of them.

| Need | Surface | Current state | MLB Stats API endpoint (Brodie / known) |
|---|---|---|---|
| **Umpire names** | AC Dashboard Umpire tab | Structure shipped `17c66ea`; data layer empty. Brodie May 14: IDs in `MLBAM.pbp_pregame`, but not all in `Astros.Players` → fallback to API | `GET /api/v1/jobs/umpire` |
| **Video URLs (player-device safe)** | All postgame V-columns | Current 3-tier fallback in `rules/video-angles.md` (Astros.Video → Video_Network v → Video_Network a). RND ingestion misses V regularly. MLB API noted as future primary | `MLB Film Room GraphQL` (KDB uses this — per `intangibles/docs/kdb_catching.html`) |
| **Live / final game scores** | AC Dashboard Scoreboard tab | TBD per `memory/ac-dashboard-shipped.md` — Schedule_View score column probe pending | `GET /api/v1/schedule?sportId=1&date=YYYY-MM-DD` returns linescore with R/H/E |

Potentially-relevant secondary needs:
- League-wide roster (current we use `MLB_eBis.PP_MASTER` HOU-only; cross-org metadata sometimes needed)
- Game-state / play-by-play (live game feed at `/api/v1.1/game/{game_pk}/feed/live`)
- Statcast metric audit (compare Astros tracking vs MLB-published Statcast where it overlaps)

## Brodie's confirmed endpoint

```
GET https://statsapi.mlb.com/api/v1/jobs/umpire
```

Returns league-wide umpire roster with `id`, `firstName`, `lastName`,
maybe other fields. He uses it as a name lookup for the IDs he gets
from `MLBAM.pbp_pregame`.

## KDB's MLB Stats API usage (reference)

Per `intangibles/docs/kdb_catching.html` saved May 10 2026
(commit `aa61fda`), KDB hits the MLB Stats API at multiple endpoints:
- `/api/v1.1/game/{game_pk}/feed/live` — for HP umpire from `officials`
- `MLB Film Room GraphQL` for clip URLs (with Savant iframe fallback)
- KDE heatmap data + Savant stance leaderboard with `knee_code` grouping

So MLB Stats API is the connective tissue between several KDB pages
we either haven't built or have built with worse data. If we go this
direction, KDB's call patterns are a working reference.

## Architecture decision needed BEFORE implementation

**Live HTTP vs scheduled pin?**

- **Live HTTP per request**: simpler, no infra, but adds 200-500ms per
  page load per API call. Bad for any tab that needs umpire/video/
  score on every render.
- **Connect-scheduled pin** (recommended): pre-fetch + cache. Mirrors
  `rules/tracker-parquet-pins.md` Phase 12 pattern. Cron at hourly /
  daily, write to a pin, app reads pin. Adds ~1 piece of infra
  per surface but offloads HTTP entirely from user-facing pages.

For umpires specifically: the roster doesn't change daily — a daily
or weekly refresh is enough. Definitely pin-it.

For live game scores: scoreboard tab is a "what happened yesterday"
view, not real-time. A daily pin (or even Connect-scheduled fetch
per day) is fine. Real-time would need a different cadence.

For video URLs: per-game, not per-pitch. Could pin per-completed-game
once data lands.

## What we should NOT do yet

- **Don't** wire any MLB Stats API call into an app inline before the
  pin pattern is decided. Repeating the per-page HTTP anti-pattern is
  worse than the current placeholder.
- **Don't** assume the API stays stable — MLB has shifted endpoints
  before. Whatever we build needs a graceful fallback.
- **Don't** authenticate / register a key — the public API endpoints
  appear keyless (Brodie uses raw URLs). If we hit rate limits later
  we deal with it then.
- **Don't** scope-creep into Statcast / Savant comparisons in the
  first exploration round. Stay focused on the 3 live needs.

## Exploration complete (May 14 2026) — see design doc

**Design doc**: `intangibles/docs/plans/2026-05-14-mlb-stats-api-exploration.md`
on `feature/astros-intangibles`. Full endpoint shapes + architecture
proposal + 6 open user questions.

**Probe SQL**: `intangibles/sql-queries/mlbam-pbp-pregame-probe.sql` —
run on work laptop tomorrow. **BLOCKS** Phase 2 (helper implementation).

### Confirmed findings (HTTP verified May 14 personal laptop)

1. **Brodie's /jobs/umpire URL is shorthand** — actual endpoint is
   `/api/v1/jobs?jobType=UMPR&sportId=1&date=YYYY-MM-DD`. Returns ~98
   umpires with `person.id` (MLBAM), `person.fullName`, `jerseyNumber`.
2. **Live feed is THE multi-data primary**:
   `/api/v1.1/game/{gamePk}/feed/live` returns officials (HP/1B/2B/3B
   umps) + linescore + plays + playIds in ONE call. Works for MLB AND
   MiLB (AAA has 3 umps, no 2B).
3. **sportId maps 1:1 to our `level_code`** —
   1=mlb, 11=aaa, 12=aax, 13=afa, 14=afx, 16=rok (FCL+ACL),
   22=bbc, 586=hsb. **DSL has no dedicated sportId** — accept as
   known gap in v1.
4. **Film Room GraphQL** confirmed at
   `https://fastball-gateway.mlb.com/graphql` with `query clipQuery`
   pattern + `{ids: playId, languagePreference: "EN", idType: "PLAY_ID"}`
   variables. Returns `feeds[]` with type CMS/HOME/AWAY/NETWORK + mp4Avc
   playbacks. **Uses MLB `playId`, NOT our internal `pitch_id`** — chain
   is feed/live → playId → GraphQL → mp4 url. Savant iframe is
   documented fallback.

### Proposed architecture (in design doc)

- One shared `intangibles/src/mlb_stats_api.py` helper (8 functions)
- One Connect-scheduled daily pin job at `intangibles/connect_pins_mlb_api/`
- Pin bundle: `zbridger/mlb_stats_api_<year>` joblib with
  `umpire_roster`, `game_officials`, `game_linescores`, `game_playids`
- Pin pattern mirrors `rules/tracker-parquet-pins.md` exactly
- Retry pattern mirrors `rules/database-tcp-retry.md`
- App reads via thin lookups against the in-memory loaded bundle

### Phase 1 BLOCKER

User needs to run `sql-queries/mlbam-pbp-pregame-probe.sql` to confirm:
- pbp_pregame column names (especially umpire IDs)
- Whether `Astros.Schedule_View.sched_id` ↔ `pbp_pregame.game_pk`
  bridges via an existing column, or needs (date, away_team, home_team)
  join

After probe results, Phase 2 (helper code) is straightforward.

### 6 questions for user (deferred to next session)

1. Probe SQL timing (blocks Phase 2)
2. First app to wire — Umpire tab OR V-column videos?
3. Pin scope start — MLB-only OR include AAA?
4. Schedule cadence — daily 4 AM OR twice daily?
5. DSL gap — accept OR dig into sportId=21 coverage?
6. Pin location — intangibles-scoped OR top-level shared with
   barrelsville + arm-farm?

### What was committed

- `sql-queries/mlbam-pbp-pregame-probe.sql` (new, in worktree)
- `intangibles/docs/plans/2026-05-14-mlb-stats-api-exploration.md` (new design doc)
- This memory file updated

---

## UPDATE 2026-05-14 afternoon — probe results + OpenAPI inventory

User ran the probe. **`MLBAM.PBP_PreGame` is richer than I expected** —
not just umpire IDs but full game-conditions row keyed by `game_pk`:

- **All 6 umpire columns**: `umpire_hp_id`, `umpire_1b_id`, `umpire_2b_id`,
  `umpire_3b_id`, `umpire_lf_id`, `umpire_rf_id` (LF/RF NULL outside All-Star/postseason)
- `official_scorer_id`, `datacaster_1_id`, `datacaster_2_id` (all joinable
  to MLB Stats API `/jobs/*` endpoints if needed)
- Weather block: `temperature`, `weather`, `windSpeed`, `wind_direction`
- Venue context: `venue_id`, `playing_surface`, `day_night`
- Game meta: `Designated_hitter`, `game_number`, `double_header`, `game_type`,
  `sport_code`, `league`, `valid_pitch_sequence_data`
- PK: `game_pk` (int), joins directly to `Astros.Schedule_View.mlbam_game_pk`

Coverage starts at game_pk 100 = 1999-06-19. Pre-game record = `rec_seq=0, rec_type='pre_game'`.

**Strategic shift**: umpire IDs come from the DB, NOT the API. Phase 2A
can ship with **zero MLB Stats API dependency for the Umpire tab**.

### OpenAPI spec pulled — 178 paths, 77 baseball-relevant

OpenAPI 3.0.1 at `https://docs.statsapi.mlb.com/openapi.json` (937KB, no
auth). Saved locally at `~/mlb_openapi.json`. Key newly-discovered paths
beyond what we already knew:

- `/api/v1/jobs/umpires` — Brodie's URL with `s` added. Same shape as
  `?jobType=UMPR`. Cleaner endpoint.
- `/api/v1/jobs/umpires/games/{umpireId}` — per-umpire game history
- `/api/v1/jobs/datacasters` + `/jobs/officialScorers` — match pbp_pregame columns
- `/api/v1.1/game/{game_pk}/feed/live/diffPatch` + `/timestamps` — incremental
  feed updates (avoid re-fetching full feed)
- `/api/v1/batTracking/game/{gamePk}/{playId}` — bat tracking per play
- `/api/v1/game/{gamePk}/{playId}/analytics/biomechanics/{positionId}` — per-play biomechanics
- `/api/v1/game/{gamePk}/{playId}/analytics/skeletalData/chunked` — skeletal pose
- `/api/v1/game/{gamePk}/{guid}/homeRunBallparks` — "would have HR'd in park X?"
- `/api/v1/game/{gamePk}/winProbability` — WPA per play
- `/api/v1/game/{gamePk}/contextMetrics` — game-level Statcast context
- `/api/v1/weather/game/{gamePk}/{playId}` — per-play weather
- `/api/v1/teams/{teamId}/coaches` — verified returns Espada, López, etc.
- `/api/v1/teams/{teamId}/personnel` — org staff
- `/api/v1/people/{personId}/stats/metrics` — Statcast-style player metrics
- `/api/v1/people/{personId}/stats/game/{gamePk}` — per-player per-game
- `/api/v1/schedule/trackingEvents` — HawkEye/Statcast schedule

**Auth/CORS**: No auth on anything we care about. CORS `*`. Anonymous GET
works. Rate limits not surfaced; for our pin-once-daily cadence,
irrelevant.

### Implementation order revised

1. **Phase 2A — Umpire tab** (DB-only, no API). Ship today/tomorrow.
2. **Phase 2B — Live scores** via `/api/v1/schedule?hydrate=linescore`.
3. **Phase 2C — Video MP4s** via live feed → playId → Fastball GraphQL.

Each phase ships independently. Pin job only needed for 2B + 2C.

## Cross-references

- `rules/video-angles.md` §"Status: interim fix while we wait on RND
  + MLB API" — already documented that MLB Stats API is the long-term
  video primary
- `memory/ac-dashboard-shipped.md` — Umpire tab + Scoreboard
  needs, schema probe status
- `intangibles/docs/kdb_catching.html` — KDB's full MLB Stats API
  usage patterns (saved verbatim, ~983 KB)
- `rules/tracker-parquet-pins.md` — pin pattern for scheduled refresh
