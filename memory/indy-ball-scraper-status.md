---
name: indy-ball-scraper-status
description: "Independent pro baseball stats scraper (Pioneer/Frontier/Atlantic/American Assoc) — Python project status, data sources, decisions"
metadata: 
  node_type: memory
  type: project
  originSessionId: 9164e09b-d485-4cc5-b4ba-db2d2d3c365a
---

**Indy Ball Scraper** — standalone Python project at `C:\Users\Owner\indy-ball-scraper`
(sibling to bsb-resources, like astroworld). Scrapes season hitting + pitching
stats for the 4 MLB-partner independent leagues → sorted CSVs. Built 2026-06-18.
Run-on-demand now; goal is a Streamlit app on Posit Connect eventually.

**Data sources (the hard-won research — full notes in `docs/RESEARCH.md`):**
- **Pointstreak is DEAD** — every `*.pointstreak.com` URL 301-redirects to
  stacksports.com root. Stale links still on league sites; ignore.
- **3 leagues = iScore Central.** Atlantic(ALPB)/Frontier(FL)/American Assoc(AAPB)
  serve from `pro.iscorecentral.com` (React SPA, WAF-blocked). The OPEN backend
  JSON API needs no key: `https://api.microservices.iscoresports.com/api` —
  `GET /leagues/standings?seasonId=` (teams) then `GET /player-stats?teamId=&seasonId=`
  (per-team lines; OPS/ERA/WHIP pre-computed; IP = OUTS_PITCHED/3). League+season
  UUIDs are pinned in `indyball/config.py`, pulled from the SPA JS bundle's `Cr`
  config. **Season IDs change yearly** — re-pull from the JS bundle each season.
- **Pioneer(PBL) = PrestoSports** HTML. `pioneerleague.com/sports/bsb/<year>/players`
  returns 4 tables (hitting / hitting-extras r+sb / pitching / fielding) in ONE
  fetch; `pandas.read_html`. No OPS col → compute OBP+SLG. Full first names
  recovered FROM THE URL SLUG (`jordanhamberga0ra`=Jordan Hamberg) — 125/125, no
  per-player requests.

**Decisions (Zac, 2026-06-18):** pitching sorts by **WHIP asc** (qualified ≥10 IP
on top); **keep all players** by default (flags `--min-pa`/`--min-ip` for qualified
views); Pioneer full names ON. Hitting = OPS desc (fallback SLG→AVG).

**CLI:** `python scrape_indy.py --type hitting|pitching|both [--leagues ALPB FL AAPB PBL]
[--min-pa N] [--min-ip N] [--pitch-sort whip|era|k|k9|bb9|ip] [--year YYYY]`.
Output → `output/<type>_<scope>_<year>.csv` (utf-8-sig for Excel accents).
Works end-to-end: 734 hitters / 770 pitchers for 2026. Not a git repo yet.

**IndyBall Tracker app (Streamlit) — BUILT + VERIFIED 2026-06-18.** `app.py` +
`indyball/filters.py`. Hitting/Pitching radio, name-lookup search, and per-column
filters EXACTLY as Zac specced: text cols = contains (type 'Cle' → Cleburne only),
numeric cols = `>1`/`<1`/`>=0.3`/range `0.3-0.4` (bare number = `>=`). Live scrape
cached 24h (auto-refreshes daily) + 🔄 Refresh button + Clear filters + download
filtered CSV. Pure Streamlit (NO st_aggrid — not installed; pure is more
Posit-robust). Verified via `streamlit.testing.v1.AppTest`: 734 hitters / 770
pitchers, OPS>1→129 rows all>1, team~cle→16 Cleburne, WHIP<1→62 rows all<1. Filter
unit tests in-repo. Deploy: `DEPLOY.md` (rsconnect deploy streamlit, pin py3.11
like injury_tracker; whole dir bundles indyball/). First load each day ~45-90s
(spinner). NOT yet deployed to Connect (do on work laptop). `.streamlit/config.toml`
= Astros orange theme.

**Repo decision (Zac, Jun 18 2026):** STANDALONE private GitHub repo
`zbridger_astros/indyball-tracker` (own `main` branch), NOT a bsb-resources
branch/folder — like astroworld. Zac waffled toward "make it a feature" but chose
standalone when given the clean either/or. Rationale: not Astros DB work, cleaner
Posit deploy, bsb-resources branches eventually merge to Astros main. Future
modeling can still consume IndyBall CSVs/pins as a data source without moving the
repo. Do NOT keep dual copies if ever migrated.

**Deploy (architecture):** app reads a pin if <24h old (instant) else live-scrapes
+ re-pins → AUTO-REFRESHES DAILY on its own. Optional 3am scheduled `refresh.py`
job = pure pre-warm to kill the ~45s first-load. Pin board = `pins.board_connect()`
when CONNECT_SERVER+CONNECT_API_KEY env set, else local folder board. Two-phase
deploy in `DEPLOY.md`. NOT yet deployed to Connect (work laptop: `git clone` +
`rsconnect deploy streamlit . --entrypoint app.py`; manifest+py3.11 fallback like
injury_tracker). Local test server was on :8501/:8502 personal laptop.

**DEPLOYED to Posit Jun 18 2026** — content GUID `f37d76d5-4c88-464b-8ef5-91c6bd5423a4`
(ID 937) on connect2. Deploy = `rsconnect.exe` (work laptop `...Roaming\Python\Python314\Scripts\`)
`write-manifest streamlit --override-python-version 3.11 --entrypoint app.py --overwrite .`
then `deploy manifest . --server https://connect2.astros.com --api-key <DEPLOY_KEY> --title "Indyball Tracker"`
(NO `--new` after first). `manifest.json` is gitignored (machine-generated; line-ending sensitive).
Deps MUST cap `streamlit<1.50, pandas<3, numpy<2` (mirrors injury_tracker; streamlit 1.50+ drops
tornado → crash). 3 dupe content items exist from `--new` retries — delete all but f37d76d5.

**PIONEER PROBLEM + FIX (the saga):** PrestoSports (Pioneer's host) WAF-blocks Connect's
Azure datacenter IP (52.248.93.189) with **405** — the other 3 leagues (iScore JSON API)
work from Connect, only Pioneer 405s. Fix = work laptop (residential IP, reaches Pioneer)
runs `refresh.py` → writes shared pin to connect2 board → app READS pin (Connect never
scrapes Pioneer). store.py mirrors `pd-goals/src/pins_config.py`: `_patch_ssl()` (connect2
internal cert) + `zbridger/indyball_{hitting,pitching}` namespaced pins + `CONNECT_API_KEY`
board_connect. App prefers pin if present; `_live_scrape` only warms pin if all 4 leagues
present (never clobbers). `refresh.py` refuses to write incomplete pins (DNS-flake guard,
needs all 4 leagues + ≥200 rows).

**DNS-FLAKE FIX (Jun 18 2026, commit `4d1f880`):** The all-or-nothing pin guard was a DEAD END —
work-laptop DNS is flaky enough that all 4 leagues NEVER resolve in one pass (8-attempt auto-retry
still failed every time; pin left unchanged, app stuck showing whatever the last partial write held —
Pioneer-only or 3-league, flipping by run). **Replaced with per-league scrape + merge-with-pin**
(`merge_by_league()` in `indyball/scrape.py`, the merge-union-not-primary pattern): each league is
scraped INDEPENDENTLY with its own retry budget, then merged into the existing pin — leagues that
succeed THIS run are refreshed, leagues that fail keep their PRIOR pin rows. Pin coverage is
**monotonic** (only improves, never regresses); a run that lands 3 of 4 still updates those 3 and
preserves the 4th. Re-sorts canonically after merge (OPS desc / WHIP asc qualified-first). Same
helper applied to the in-app 🔄 Refresh `_live_scrape` so a Connect scrape (Pioneer 405) carries
Pioneer from the pin instead of dropping it. Proven offline w/ synthetic frames (carryover + fresh-wins
+ sort + empty/no-prior edge cases all pass). `refresh.py` now prints per-kind `fresh this run` /
`carried from pin` / `⚠ still MISSING` summary. **NEXT STEP: work laptop `git pull` + `py refresh.py`
(set `$env:CONNECT_API_KEY` first) — re-run until no `⚠ MISSING`; pin can no longer be wiped.** App
already reads the pin correctly (proven). Redeploy app only if you want the Refresh-button merge live
(not required to see all 4 leagues). Minor: `use_container_width` deprecation warning, non-blocking.
ROTATE the API keys (lbMc…, H9MB…) pasted in chat once stable.

**FULLY LIVE Jun 18 2026** — both pins complete (734 hitting / 770 pitching, all 4 leagues).
Day-to-day reliability layered in: per-league retry + merge-with-pin (monotonic), `write_pin`
guarded against Connect blips (commit after `4d1f880`), app degrades to stale-but-complete data
+ warning banner (never a hard crash). Hands-off scheduling = `refresh_daily.ps1` (repo root):
work laptop sets `CONNECT_API_KEY` as a USER env var once, then `schtasks /create /tn "IndyBall
Pin Refresh" ... /sc daily /st 06:00` (full cmd in the script header). Logs to `logs\`, keeps 14
days, always exits 0 (a flaky day = pin preserved, task stays green).

**SCHEDULED-REFRESH ARCHITECTURE (Jun 18 2026, commit `e7d36da`):** Zac wanted the
bsb-resources connect-pin-notebook pattern, not a fragile work-laptop Task Scheduler.
Verified Pioneer canNOT run on Connect (PrestoSports WAF 405s every datacenter IP; NOT on
MLB Stats API either — sportId 23 lists all 4 leagues but only Mexican League has 2026 stat
splits, Pioneer/Atlantic/Frontier/AmAssoc return 0). So HYBRID: **3 iScore leagues auto-refresh
on Connect; Pioneer rides the laptop.** Shared engine `indyball/refresh_core.run_cycle()`:
business day rolls at 3 AM Central (`cycle_key`), each run scrapes only leagues not yet fresh
today (per-league LOCK stored as JSON in pin metadata `freshness`), success locked till next
3 AM, failure retried next run; merges monotonically. `connect_refresh/indyball_refresh.ipynb`
+ `deploy.ps1` (mirrors connect_pins_defense; jupyter-static manifest, copies indyball pkg in)
→ deploy + schedule EVERY 15 MIN in Connect UI + set CONNECT_API_KEY in Vars → that gives 3am
refresh + 15-min-retry + daily-lock automatically. `refresh.py` (laptop) now calls
run_cycle(ALL, respect_lock=False) for Pioneer + manual full refresh. The shared freshness map
coordinates both jobs (laptop skips iScore leagues Connect already did today). Lock + freshness
round-trip TESTED offline (local board, AAPB). `refresh_daily.ps1` (laptop Task Scheduler) still
exists as the all-laptop fallback. **CONFIRMED LIVE Jun 19 2026** — Connect content
`indyball-pin-refresh` (GUID `5981840f-97ae-492e-91a0-2af5e75d609e`, ID 940) deployed; first
render scraped the 3 iScore leagues and wrote pins showing **4 leagues** (735 hitting / 776
pitching) — Pioneer carried forward by the merge. Two deploy-time fixes were needed: hand-written
ipynb code cell missing `"outputs": []` (nbconvert `'outputs' is a required property`), and a
no-key graceful-skip guard because Connect executes the notebook at deploy BEFORE Vars are set
(commit `b2c113d`). **Pioneer can never go MISSING** (merge carries it forward every Connect run);
it can only go STALE if the laptop never runs `refresh.py` (Connect can't reach Pioneer to update).
CADENCE (Zac, Jun 19): **once daily at 3 AM**, not every 15 min — season stats are fine once/day.
Because there's no 15-min re-tick to catch a flake, the single run retries each league hard
(`attempts=5`, sleep 12s ≈ 15 HTTP tries/league over ~1 min; commit after `b2c113d`). A league that
still fails keeps yesterday's rows (stale, never missing). LEFT TO DO: redeploy to pick up attempts=5;
confirm Connect Schedule = daily 3 AM; point `refresh_daily.ps1` laptop task at 3 AM for Pioneer
freshness (laptop-asleep night = Pioneer holds last value, acceptable at once/day). Deploy execution-policy = use documented tracker pattern
`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` (the `powershell -File -ExecutionPolicy
Bypass` one-liner is equivalent but off-convention). **Pioneer pitchers were also fixed same session** (commit
`151e297`): presto.py reused the hitter URL for pitching → only 8 pitchers; now `pos=p&sort=ip`
→ ~125 real pitchers (page caps ~125, so it's top-125 by IP — sub-IP cameos beyond that dropped).

**THE ONE RECURRING MAINTENANCE (calendar it for 2027):** iScore season UUIDs are hardcoded in
`indyball/config.py` and change EVERY season. When 2027 starts, the 3 iScore leagues silently
return empty (UUIDs stop matching) and the app keeps serving stale 2026 data WITHOUT firing the
missing-league banner (old rows still "present"). It's a correctness failure, NOT a crash. Fix =
re-pull each league's season_id from the iScore SPA JS bundle (procedure in `docs/RESEARCH.md`
"League / season IDs"), update config.py, commit. Pioneer (presto) keys off `SEASON_YEAR` so just
bump that.

**Open / next:** prior-season history for iScore (needs each year's UUIDs). Runs locally (public
web APIs, no DB) per [[feedback_run_locally_when_data_is_local]].
