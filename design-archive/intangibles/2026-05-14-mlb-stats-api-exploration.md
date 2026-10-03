# MLB Stats API — Integration Architecture (Design)

Status: **PROPOSED, not yet implemented.** Personal-laptop exploration on
2026-05-14 confirmed endpoint shapes; user decides architecture before any
app wires this in.

## UPDATE 2026-05-14 (afternoon) — probe results + OpenAPI inventory

User ran `sql-queries/mlbam-pbp-pregame-probe.sql`. **`MLBAM.PBP_PreGame`
is richer than expected**:

| Column | Type | Notes |
|---|---|---|
| `game_pk` | int (PK) | Joins to `Astros.Schedule_View.mlbam_game_pk` |
| `game_id` | varchar(50) | MLB string id like `1999/06/19/chnmlb-sfnmlb-1` |
| `rec_seq` / `rec_type` | int / varchar | `0` / `pre_game` for the canonical row |
| `away_team_id` / `home_team_id` | int | MLBAM team IDs |
| `game_date` | date | |
| `day_night` | char(1) | D/N |
| `venue_id` | int | |
| `playing_surface` | char(1) | G (grass) etc. |
| `datacaster_1_id` / `datacaster_2_id` | int / varchar | MLBAM datacaster IDs (joinable to `/jobs/datacasters`) |
| **`umpire_hp_id`** | int | HP umpire MLBAM ID |
| `umpire_1b_id` / `_2b_id` / `_3b_id` | int | Base umps |
| `umpire_lf_id` / `_rf_id` | int | OF umps (All-Star / postseason only — typically NULL) |
| `official_scorer_id` | int | Joinable to `/jobs/officialScorers` |
| `temperature` | int | F |
| `weather` | varchar(25) | Sunny/etc. |
| `windSpeed` | int | mph |
| `wind_direction` | varchar(25) | CF/RF/LF |
| `Designated_hitter` | char(1) | Y/N |
| `game_number` | tinyint | 1 / 2 for doubleheaders |
| `double_header` | varchar(25) | |
| `game_type` | varchar(25) | R/S/E/etc. |
| `sport_code` | varchar(25) | `mlb` |
| `league` | varchar(25) | AL/NL |
| `valid_pitch_sequence_data` | varchar(25) | B (quality flag — investigate) |

Coverage starts at game_pk 100 = 1999-06-19. Sample rows confirm 4-ump
crews are typical; LF/RF NULL outside All-Star/postseason. Datacaster_2
sometimes NULL.

**Strategic shift**: umpire IDs come from the DB. We no longer need MLB
Stats API for umpire ID lookup at all — only for name resolution when
`Astros.Players` is missing an ump.

### OpenAPI inventory — 178 paths total, 77 baseball-relevant

OpenAPI 3.0.1 spec pulled from `https://docs.statsapi.mlb.com/openapi.json`
(937KB, public, no auth). Most consequential paths beyond the four I
already documented:

| Endpoint | Use case |
|---|---|
| `/api/v1/jobs/umpires` | Brodie's corrected URL (plural). Same shape as `?jobType=UMPR`. Cleaner. |
| `/api/v1/jobs/umpires/games/{umpireId}` | Per-umpire game history — could power "what other games did this ump work?" UI |
| `/api/v1/jobs/datacasters` | Matches `pbp_pregame.datacaster_1_id` |
| `/api/v1/jobs/officialScorers` | Matches `pbp_pregame.official_scorer_id` |
| `/api/v1.1/game/{game_pk}/feed/live/diffPatch` | Incremental update — avoid re-fetching whole feed on polls |
| `/api/v1.1/game/{game_pk}/feed/live/timestamps` | Tells you which diffs to grab |
| `/api/v1/batTracking/game/{gamePk}/{playId}` | Bat tracking per play — could augment SCV pulls |
| `/api/v1/game/{gamePk}/{playId}/analytics/biomechanics/{positionId}` | Per-play biomechanics! Could be huge for our biomech-aware analyses |
| `/api/v1/game/{gamePk}/{playId}/analytics/skeletalData/chunked` | Skeletal pose data — KDE / mechanics deep dives |
| `/api/v1/game/{gamePk}/{guid}/homeRunBallparks` | "Would this HR have left park X?" — across all 30 parks |
| `/api/v1/game/{gamePk}/winProbability` | WPA per play |
| `/api/v1/game/{gamePk}/contextMetrics` | Game-level Statcast context metrics |
| `/api/v1/weather/game/{gamePk}/{playId}` | Per-play weather (matches pbp_pregame static columns at game-level) |
| `/api/v1/teams/{teamId}/coaches` | Coach roster — verified: returns Espada, López, Rodríguez for HOU |
| `/api/v1/teams/{teamId}/personnel` | Org staff — verified: returns "Director of Hitting" etc. |
| `/api/v1/teams/affiliates` | Org structure / affiliate map |
| `/api/v1/people/{personId}/stats/metrics` | Statcast-style metrics for a player |
| `/api/v1/people/{personId}/stats/game/{gamePk}` | Per-player per-game stats |
| `/api/v1/game/lastPitch` | Live last-pitch feed (real-time use case) |
| `/api/v1/game/changes` | Polling endpoint for game changes |
| `/api/v1/schedule/trackingEvents` | When HawkEye/Statcast is active |
| `/api/v1/statcastPositionTypes` | Statcast position taxonomy |
| `/api/v1/homeRunDerby/{gamePk}` | HR Derby specific |

### Auth / rate limit / CORS

- **No auth required** for any endpoint we care about. Anonymous GET works.
- **`Access-Control-Allow-Origin: *`** — browser-callable from any origin.
- Standard methods exposed: `GET, POST, PUT, DELETE, OPTIONS`.
- Rate limits not surfaced empirically in this exploration — for our
  pin-once-daily cadence, irrelevant. KDB hits the API live from
  browsers without complaint, suggesting limits are generous.

### Revised architecture (simpler than before)

Old plan (deprecated): hybrid pbp_pregame + MLB Stats API for umpire IDs.

New plan:
- **Umpire IDs** → `MLBAM.PBP_PreGame` directly (no API call). 6 ump columns
  available on a single row keyed by `game_pk`.
- **Umpire names** → JOIN `Astros.Players` on `mlbam_id = umpire_X_id`,
  fall back to the `/api/v1/jobs/umpires` pin for missing entries.
- **Live game scores** → `/api/v1/schedule?sportId=N&date=...&hydrate=linescore,team`
  (already proven). Or `/api/v1.1/game/{gamePk}/feed/live` if we want
  inning-by-inning detail.
- **Video MP4s** → unchanged: live feed → playId → Fastball GraphQL.
- **Bonus columns we get for free from pbp_pregame**: temperature, weather,
  wind, DH flag, scorer ID, datacaster IDs. Surface these on the Umpire
  tab or game header without any new HTTP.

This means **Phase 2 (umpire helper code) needs ZERO MLB Stats API calls
for umpire IDs**. The API only fills the name-gap fallback (one daily
roster pin = ~98 entries, ~15KB).

Implementation order shifts:
1. **Phase 2A — Umpire tab (low-hanging fruit, no API needed)**
   Write `data/umpire.py` against `MLBAM.PBP_PreGame` + `Astros.Players`
   today. Probably DB-only is enough for v1; if name gaps appear, add API
   fallback in v1.1.
2. **Phase 2B — Live scores via API** (Scoreboard tab)
3. **Phase 2C — Video MP4s** via live feed + GraphQL (postgame V columns)

Keeps each phase shippable independently.

## TL;DR

One shared `mlb_stats_api.py` helper + one Connect-scheduled daily pin
job covers **all three current MLB Stats API needs** (umpires, live scores,
video URLs) plus opens the door to future ones (game-state, player metadata
augmentation) without per-app HTTP cost. The live game feed endpoint
(`/api/v1.1/game/{gamePk}/feed/live`) is the single multi-data primary —
it returns officials + linescore + plays + playIds in one call.

Architecture grade: low-medium lift, high reuse, mirrors the existing
tracker-pin pattern (`rules/tracker-parquet-pins.md`) that we've already
proven on Connect.

---

## 1. Confirmed endpoint inventory

All HTTP-only, no auth required. All `200 OK` with public CORS-friendly
JSON. Verified live 2026-05-14 from personal laptop.

### 1.1 Umpire league-wide roster

```
GET https://statsapi.mlb.com/api/v1/jobs?jobType=UMPR&sportId=1&date=YYYY-MM-DD
```

**Brodie's "umpire" shorthand returns 405** — must use the `/jobs?jobType=UMPR`
form. Returns ~98 umpires/active date.

Response shape:
```json
{
  "copyright": "...",
  "roster": [
    {
      "person": {"id": 596809, "fullName": "Ryan Additon", "link": "/api/v1/people/596809"},
      "jerseyNumber": "67",
      "job": "Umpire",
      "jobId": "UMPR",
      "title": "Umpire"
    },
    ...
  ]
}
```

Fields per entry: `person.id` (MLBAM ID), `person.fullName`,
`person.link`, `jerseyNumber`, `job` / `jobId` / `title`. No
crew-chief / position info from this endpoint alone — that comes from the
per-game live feed.

**Use case**: lookup table for ID → name, especially when `Astros.Players`
is missing an umpire (Brodie flagged this is common).

### 1.2 Live game feed — the multi-data primary

```
GET https://statsapi.mlb.com/api/v1.1/game/{gamePk}/feed/live
```

Verified for MLB game 824195 (HOU vs SEA 2026-05-13) AND AAA game 814782
(Sugar Land @ Tacoma) — works for both MLB and MiLB.

Top keys: `copyright, gamePk, link, metaData, gameData, liveData`.

**`liveData.boxscore.officials`** — the umpires block:
```json
[
  {"officialType": "Home Plate", "official": {"id": 577468, "fullName": "Roberto Ortiz", "link": "..."}},
  {"officialType": "First Base",  "official": {"id": 623945, "fullName": "Alex MacKay",   "link": "..."}},
  {"officialType": "Second Base", "official": {"id": 691042, "fullName": "Willie Traynor", "link": "..."}},
  {"officialType": "Third Base",  "official": {"id": 427554, "fullName": "Jim Wolf",       "link": "..."}}
]
```

MLB games typically have 4 umps (HP/1B/2B/3B). AAA observed with 3 (HP/1B/3B
— no 2B). Lower levels may have fewer.

**`liveData.linescore`** — the scoreboard data:
- `innings[]` — per-inning R/H/E by team
- `teams.home / .away` — runs, hits, errors totals
- `currentInning`, `inningState`, `isTopInning` — live state

**`liveData.plays`** — for video URL extraction (per-pitch `playId`s).

**Single call per gamePk = umpires + scores + plays + everything else.**
This is the right primary for a daily pin job.

### 1.3 Schedule (per-date, per-sport)

```
GET https://statsapi.mlb.com/api/v1/schedule?sportId=N&date=YYYY-MM-DD
GET https://statsapi.mlb.com/api/v1/schedule?sportId=N&teamId=T&date=...
GET https://statsapi.mlb.com/api/v1/schedule?sportId=N&startDate=...&endDate=...&hydrate=linescore,team
```

Returns `dates[].games[]` with: `gamePk`, `gameDate`, `status`
(abstractGameState/detailedState/codedGameState), `teams.home/away` with
team.id+name+score+isWinner+leagueRecord, `venue`, `doubleHeader`.

**sportId maps 1:1 to our `level_code`**:

| sportId | API code | Our level_code |
|---|---|---|
| 1 | mlb | mlb |
| 11 | aaa | aaa |
| 12 | aax | aax |
| 13 | afa | afa |
| 14 | afx | afx |
| 16 | rok | rok (covers FCL + ACL) |
| 22 | bbc | bbc |
| 586 | hsb | hsb |

**DSL gap**: no dedicated `dsl` sportId in the standard list. DSL games
may be queryable via `sportId=21` (broader Minor League) but coverage
needs separate validation. For v1 we accept that DSL umpires/scores
aren't covered by MLB Stats API.

Use case: yesterday's scoreboard slate with R/H, live game state.

### 1.4 Film Room GraphQL — video URLs

```
GET https://fastball-gateway.mlb.com/graphql?query=...&variables=...
```

**Query** (URL-encoded):
```graphql
query clipQuery($ids: [String], $languagePreference: LanguagePreference, $idType: MediaPlaybackIdType) {
  mediaPlayback(ids: $ids, languagePreference: $languagePreference, idType: $idType) {
    feeds {
      type
      playbacks { name url }
    }
  }
}
```

**Variables**: `{"ids": "<playId>", "languagePreference": "EN", "idType": "PLAY_ID"}`

**Response**: `data.mediaPlayback[0].feeds[]` with `type` in
`{CMS, HOME, AWAY, NETWORK}` and `playbacks[]` with `name == "mp4Avc"`
being the cross-origin-safe mp4.

**Fallback**: `https://baseballsavant.mlb.com/sporty-videos?playId={playId}`
(iframe embed when GraphQL fails or returns no feeds).

**Critical**: this uses `playId` (MLB-side), NOT our internal `pitch_id`.
The chain is: live feed `plays[].playId` → GraphQL → mp4 url. So any pin
job pulling video URLs MUST first pull plays from `/feed/live`.

### 1.5 Other useful endpoints (for future use)

- `/api/v1/people/{playerId}/stats?stats=gameLog&group=fielding&season=Y` — per-player game log
- `/api/v1/teams/{teamId}/roster` — current MLB-level rosters
- `https://baseballsavant.mlb.com/leaderboard/poptime?year=Y&csv=true` — KDB uses this for catcher pop-time comparison baseline (CSV format)

---

## 2. Mapping our needs to endpoints

| Internal need | Surface | Endpoint | Refresh cadence | Pin needed? |
|---|---|---|---|---|
| HP umpire name + ID per game | AC Dash Umpire tab | `/api/v1.1/game/{gamePk}/feed/live` → `liveData.boxscore.officials` | After each completed game (daily ok) | **YES** — too slow to fetch per page load |
| All-umpire name lookup | (fallback for missing in Astros.Players) | `/api/v1/jobs?jobType=UMPR&sportId=1` | Weekly | **YES** — small, cheap |
| Live/final R/H by game | AC Dash Scoreboard | `/api/v1.1/game/{gamePk}/feed/live` → `liveData.linescore` OR `/schedule?hydrate=linescore` | Hourly during game day | **YES** — same daily pin pre-completion + live pull for current day |
| MP4 URL by pitch | Postgame V column (all 5 reports) | Fastball GraphQL with `playId` from feed/live | Per-game once data lands | **YES** — pin per-game playIds + their mp4 urls |
| Future: Statcast comparison baseline | TBD | Savant CSV leaderboards | Weekly | YES |

**All five entries say "pin needed"** — the API is fast enough but per-page
HTTP would add 200-1000ms per render. The pin pattern from
`rules/tracker-parquet-pins.md` is the right shape.

---

## 3. Proposed architecture

### 3.1 One shared helper module

**`intangibles/src/mlb_stats_api.py`** (new) — single source of truth for:
- Endpoint URL constants
- `fetch_umpire_roster(date) -> dict[id, name]`
- `fetch_live_feed(gamePk) -> dict` (raw, full)
- `extract_officials(live_feed_dict) -> list[{official_type, mlbam_id, name}]`
- `extract_linescore(live_feed_dict) -> dict` (compact R/H/E)
- `extract_plays_with_playid(live_feed_dict) -> list[{pitch_id, playId, ...}]`
- `fetch_schedule(sport_id, date) -> list[game_summary]`
- `fetch_film_room_mp4(play_id) -> dict {type, url}` with Savant fallback
- Sport-id mapping from `level_code` (constant dict)
- Internal `requests` session with timeout + retry (mirror
  `rules/database-tcp-retry.md` pattern: 3 retries, 5s backoff, log to print
  so Connect logs catch it)

Why one file, not per-need: caching, retry logic, error handling, sport-id
mapping, base URL constants — duplicating across 3 apps means 3x maintenance.

### 3.2 One Connect-scheduled pin job (per app initially)

**`intangibles/connect_pins_mlb_api/`** — mirror of the
`connect_pins_catcher/` shape:
- `pin_mlb_api_daily.ipynb` — notebook wrapper
- `deploy.ps1` — PowerShell deploy automation
- Calls `scripts/pin_mlb_api_daily.py` (new)

The pin job runs daily at ~4 AM CT (after most games complete) and writes
to a single pin:

**`zbridger/mlb_stats_api_<year>`** — joblib bundle:
- `umpire_roster_<year>` — `{mlbam_id: full_name, jerseyNumber}` (~98 entries)
- `game_officials_<year>` — DataFrame keyed by `gamePk` with HP/1B/2B/3B umpire IDs
- `game_linescores_<year>` — DataFrame keyed by `gamePk` with R/H by team
- `game_playids_<year>` — DataFrame keyed by `(gamePk, pitch_id)` → `playId`
  (then mp4 url resolved on-demand from Film Room, cached per-playId in
  a separate file-pin for stability)

The pin job iterates: for each `gamePk` in scope (configurable: last 7 days
+ current year season), fetch `/feed/live`, extract the 4 chunks, write.

**Initial scope**: just MLB (sportId=1). Add MiLB sport-ids as second pass
once MLB works.

### 3.3 App-side reads

`intangibles/src/ac_dashboard/data/umpire.py`:
```python
from src.mlb_stats_api_pins import load_mlb_api_bundle

def get_game_umpires(sched_id: int, season: int) -> dict:
    bundle = load_mlb_api_bundle(season)
    # Sched_id → gamePk via MLBAM.pbp_pregame join (or sv.mlbam_game_pk column,
    # confirm via probe SQL)
    game_pk = _resolve_game_pk(sched_id)
    officials_df = bundle.get("game_officials", pd.DataFrame())
    row = officials_df[officials_df["game_pk"] == game_pk]
    if row.empty:
        return {}
    return {
        "hp_umpire_id":   int(row["hp_umpire_id"].iloc[0]),
        "hp_umpire_name": _lookup_name(int(row["hp_umpire_id"].iloc[0]), bundle),
        ...
    }
```

Standard tracker-pin pattern — bundle loaded once per session, in-memory
lookup after.

### 3.4 Failure modes + fallbacks

| Failure | Detection | Fallback |
|---|---|---|
| MLB API rate limit / 5xx | HTTP status not 200 | Retry 3x w/ backoff (per `database-tcp-retry.md`), then return cached value if pin has older copy |
| GraphQL feed returns no mp4 | Empty `feeds[]` | Use Savant iframe URL |
| Umpire ID not in jobs/UMPR roster | Lookup miss | Show "#{id}" placeholder, log for future investigation |
| Game pk not yet in feed | Game in progress, pre-game data only | Pin job re-runs hourly during game days; show "Pending" |
| pbp_pregame schema query fails | Probe SQL needed | (Tomorrow's blocker — see `sql-queries/mlbam-pbp-pregame-probe.sql`) |

### 3.5 Sched_id ↔ game_pk bridge

**The one piece we still don't know**: how do `Astros.Schedule_View.sched_id`
and `MLBAM.pbp_pregame.<game_pk>` map?

Three candidates to probe (in `sql-queries/mlbam-pbp-pregame-probe.sql`):
1. `Astros.Schedule_View` may already have an `mlbam_game_pk` or similar column
2. `MLBAM.pbp_pregame` may have a `sched_id` column we can JOIN on directly
3. Worst case: JOIN on (date, away_team_id, home_team_id) tuple

Whichever it is, the helper `_resolve_game_pk(sched_id)` encapsulates it
once.

---

## 4. Trade-offs vs alternatives

### 4.1 Considered: per-need inline HTTP, no pin

Pros: simplest, zero infra.
Cons:
- 200-1000ms per page load per call
- Hits MLB API on every Streamlit rerun (users with `?view=dashboard` open across multiple tabs would each retrigger)
- No cache invalidation discipline
- Game-day "live" updates would need page-refresh anyway

**Rejected**. The pin pattern is already proven and cheaper to operate.

### 4.2 Considered: per-app pin job (3 separate Connect deploys)

Pros: each app independently re-deploys; minimal coupling.
Cons:
- 3x deploy.ps1 + 3x notebook wrapper + 3x manifest = 3x maintenance
- Same data fetched 3x (one for Catcher Dash umpires, one for Scoreboard
  scores, one for V-column videos) → API hit volume triples
- Inconsistent freshness across apps

**Rejected**. Shared pin is the right shape.

### 4.3 Considered: live-feed-only (skip the Umpire Roster endpoint)

The live feed already has umpire name + id in the officials block. The
separate jobs/UMPR endpoint is redundant.

Pros: one less endpoint, simpler.
Cons:
- Need ALL games' feeds to get full umpire coverage (any ump who hasn't
  worked HOU games won't be in our pin)
- Future cross-org dashboards would miss umps from non-HOU games
- jobs/UMPR roster is one cheap call/week

**Recommendation**: keep both. jobs/UMPR for the canonical name lookup,
live feed for the per-game assignment.

### 4.4 Considered: DSL coverage via MiLB sportId=21

Could work but DSL games sometimes don't appear in MLB Stats API even
under broader sport filters. For v1, accept DSL gap. Add to v2 if it
becomes a coordinator pain point. Document as known limitation in the
data layer.

---

## 5. Implementation phases

### Phase 1 — Schema probe (BLOCKER, user runs)
- [ ] User runs `sql-queries/mlbam-pbp-pregame-probe.sql` on work laptop
- [ ] Reply back with the column names + sched_id ↔ game_pk bridge mechanism

### Phase 2 — Shared helper (Claude implements)
- [ ] Create `intangibles/src/mlb_stats_api.py` with all 8 helper functions
- [ ] Add `pins>=0.8.0` to `intangibles/requirements.txt` (probably already there)
- [ ] Unit-smoke test via `python -c "from src.mlb_stats_api import fetch_umpire_roster; print(len(fetch_umpire_roster('2026-05-14')))"`

### Phase 3 — Pin job (Claude implements)
- [ ] Create `intangibles/scripts/pin_mlb_api_daily.py` mirroring `pin_catching_tracker_seasons.py` shape
- [ ] Initial scope: MLB only, single year, all completed games
- [ ] Cache file pin for Film Room mp4 results (avoid re-querying GraphQL for unchanged plays)

### Phase 4 — Connect deploy (Claude builds, user deploys)
- [ ] Create `intangibles/connect_pins_mlb_api/` with deploy.ps1 + notebook
- [ ] User deploys, sets schedule daily 4 AM CT

### Phase 5 — App wire-up (one app at a time)
- [ ] AC Dash Umpire tab — closes one of the 6 TBDs
- [ ] AC Dash Scoreboard live R/H — closes another TBD
- [ ] Postgame V columns (5 reports) — replaces 3-tier fallback with API primary, keeps internal fallback in place

### Phase 6 — Expand MiLB coverage
- [ ] Add sportId iterator to pin job (11, 12, 13, 14, 16)
- [ ] DSL: skip — known gap, document

---

## 6. What we do NOT do in v1

- **Don't** auth / register an API key. Public endpoints work without one. If rate limits hit, deal with it then.
- **Don't** integrate Savant CSV leaderboards. Separate need, separate decision.
- **Don't** rebuild any internal models from MLB Stats API data. We keep our tracking sources canonical; MLB Stats API fills *complementary* gaps (umps, scores, videos).
- **Don't** start with broad MiLB scope. MLB first, prove the pin pattern, then expand.
- **Don't** abandon the existing `rules/video-angles.md` 3-tier fallback. The Film Room URL becomes a 4th tier (preferred when available) — the internal Astros.Video sources stay as fallback for player-device safety.
- **Don't** scope-creep into "rebuild KDB on our side". The reference patterns are useful; the implementation stays focused on our 3 live needs.

---

## 7. Open questions for user

1. **Phase 1 timing** — when can you run the probe SQL? Blocks Phase 2.
2. **First app to wire** — AC Dash Umpire tab (immediate user impact), or
   start with V-column video URLs (highest cross-app benefit but bigger
   change)?
3. **Pin scope start** — MLB-only first as proposed, or include AAA HOU
   immediately? AAA is highest-value MiLB level for the coordinator.
4. **Schedule cadence** — daily 4 AM CT, or twice daily (4 AM + 4 PM CT for
   live scoreboard during game days)?
5. **DSL umpire/score gap** — accept as known limitation, or want me to
   dig deeper on whether sportId=21 covers it?
6. **Where does the new pin live** — `intangibles/connect_pins_mlb_api/`
   or a top-level `connect_pins_mlb_api/` so it can serve barrelsville +
   arm-farm + intangibles all from one place? (Cross-app pin requires
   thinking about how each app's data layer reads from the same pin name.)

---

## 8. Reference

- This doc — design + decision points
- `sql-queries/mlbam-pbp-pregame-probe.sql` — schema probe (run on work laptop)
- `memory/mlb-stats-api-exploration.md` — parking lot + cross-reference index
- `intangibles/docs/kdb_catching.html` — KDB's working reference patterns (~983 KB)
- `.claude/rules/video-angles.md` — existing 3-tier video fallback (becomes 4-tier with this work)
- `.claude/rules/tracker-parquet-pins.md` — pin pattern this design mirrors
- `.claude/rules/database-tcp-retry.md` — retry pattern for resilient HTTP
