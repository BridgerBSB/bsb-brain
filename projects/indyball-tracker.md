---
type: project
domain: indy-baseball
status: live
source: 'C:/Users/Owner/indy-ball-scraper + session 2026-06-18/19'
created: '2026-06-19'
---
# IndyBall Tracker — independent-league stats app

**What it is:** Streamlit app on Posit Connect (app GUID `f37d76d5`) showing season
hitting + pitching for the 4 MLB-partner independent leagues — Atlantic, Frontier,
American Association (iScore JSON API) + Pioneer (PrestoSports HTML). Per-column
filters (text=contains, numeric `>1`/range), Hitting/Pitching toggle, CSV download.
Standalone repo `zbridger_astros/indyball-tracker` (NOT a bsb-resources branch).

**Architecture:** pin-backed. App READS pins `zbridger/indyball_hitting` +
`indyball_pitching`; a refresh job WRITES them. `store.py` mirrors the Astros pin
pattern (`_patch_ssl()` for connect2's internal cert + namespaced names). Hitting=OPS
desc, Pitching=WHIP asc (qualified first).

**Refresh wiring (hybrid, daily 3 AM):**
- iScore 3 leagues → Connect-scheduled notebook `connect_refresh/indyball_refresh.ipynb`
  (+ `deploy.ps1` mirroring `[[tracker-pin-connect-deploy]]`).
- Pioneer → work laptop `refresh.py` (see below).
- Both call `refresh_core.run_cycle()`; coordinate via a shared per-league freshness
  map in pin metadata. Coverage is monotonic — see [[merge-union-not-primary]].

**Four engineering lessons (the durable IP):**
1. [[datacenter-ip-waf-block]] — Pioneer's WAF 405s Connect's datacenter IP, so it can
   ONLY be scraped from a residential IP (laptop). NOT on the MLB Stats API either.
2. **Merge-by-league** → the pin never loses a league; a flaky run keeps prior rows.
3. **PrestoSports pitcher bug** — the players page caps at ~125 rows and the player SET
   is chosen server-side by `pos`+`sort`; reusing the hitter URL (`pos=h`) for pitching
   returned ~9 position players. Fix = `pos=p&sort=ip` → real 125 pitchers (top-125 by IP).
4. **Connect notebook gotchas** — code cells need `"outputs":[]`; Connect executes the
   notebook at deploy BEFORE Vars are set, so guard `CONNECT_API_KEY` and no-op cleanly.

**Recurring maintenance (calendar 2027):** iScore season UUIDs in `config.py` change every
season — re-pull from the SPA JS bundle. Pioneer keys off `SEASON_YEAR` (just bump it).

## Connected
Sibling scraper: [[og-pena]] · Pin/deploy canon: [[tracker-pin-connect-deploy]] · [[tracker-pin-daily-refresh]] · [[database-tcp-retry]]
Pattern: [[merge-union-not-primary]] · [[datacenter-ip-waf-block]]
Live memory: [[indy-ball-scraper-status]]
Maps: [[MOC-baseball-analytics]] · [[MOC-astros-engineering]]
