---
paths:
  - "**/src/*.py"
  - "**/scripts/*.py"
---
# Org Attribution — Per-PA, Never Majority-Org (BLOCKING)

Any per-player surface that attaches an **org** to a player and then groups,
filters, or displays by org MUST attribute **each observation (PA / pitch /
play / throw) to the org that actually had the player at that game**, and make
the row identity `(player_id, org)`.

**NEVER collapse a player to a single "primary" org** (the org with the most
PA/pitches/plays). That silently merges a mid-season-traded player's stats from
two orgs into one row under whichever org had more volume — and, on
window-scoped surfaces, makes the player flicker between orgs depending on the
date range.

---

## The fingerprint (grep for this before shipping any org surface)

```sql
ROW_NUMBER() OVER (PARTITION BY <id> ORDER BY n_pa DESC)      -- or n_pitches / n_plays / n_leads
...
WHERE rn = 1
```

Paired with a CTE usually named `org_primary` / `primary_org` and a downstream
`LEFT JOIN org_primary op ON ... = op.<id>` or a Python
`drop_duplicates("<id>", keep="first")`. Any of these = the bug.

Python form:
```python
org_primary = org_raw.sort_values("n_pa", ascending=False).drop_duplicates("<id>", keep="first")
```

---

## Why it's wrong (the Jack Moss case, verified live May 2026)

Moss was traded CIN → HOU mid-2026 and kept playing A+:
- A+ (afa): 41 PA for CIN (pre-trade) + 15 PA for HOU (post-trade)
- A (afx): 11 PA for HOU

| Surface | Window | majority-org pick | Result |
|---|---|---|---|
| Tracker A+ row | full season | CIN (41 > 15) | one row "CIN 56 PA" — HOU stats hidden, HOU filter shows nothing |
| KPI weekly **Season** | full season | CIN | dropped by `org == "HOU"` filter — **vanishes** |
| KPI weekly **L2W** | last 2 weeks | HOU (recent games all HOU) | survives — **shows** |

The window scoping is what makes it look intermittent: in a 2-week window a
traded player is all-one-org, so the majority pick is accidentally right; over
the season the pre-trade org wins and the player is mislabeled.

**It hits only mid-season-traded / acquired players at the same level.** Players
who stayed in-org, or who only changed *levels* within one org, are unaffected —
which is why it hid for so long.

---

## The canonical fix

Replace majority-org with **per-observation org** + group by `(id, org)`.

### Org-derivation snippet — OFFENSE vs DEFENSE (BLOCKING — don't flip it)

**You are only removing the majority-collapse, NOT changing how org is derived
per observation.** Read how the file already derives org in its existing
`org_raw` / `batter_org` / org-mapping CTE and MATCH that exact direction.

There are two correct forms depending on which side the player is on:

- **Offensive surfaces (hitter, baserunner)** — org = the player's BATTING
  team that game, via `top_of_inning`:
  ```sql
  JOIN mlbam.teams mt
      ON mt.team_id = CASE WHEN <ev>.top_of_inning = 1
                           THEN sv.away_team_mlbam_id
                           ELSE sv.home_team_mlbam_id END
      AND mt.season = sv.year
  ```
- **Defensive surfaces (pitcher, catcher, fielder)** — org = the player's
  FIELDING team that game, via `fielding_team_id` (this is the OPPOSITE side;
  do NOT use the batting `top_of_inning` CASE here):
  ```sql
  JOIN mlbam.teams mt
      ON mt.team_id = <ev>.fielding_team_id
      AND mt.season = sv.year
  ```
  (Confirmed May 2026: Arm Farm pitcher, Catcher, and Fielding all derive org
  via `ev.fielding_team_id`. Match it — don't introduce the batting CASE.)

`<ev>` = whatever Events_View alias carries the field in that query (`ev`,
`ev1`, `ev2`, `aev`). Select `UPPER(mt.org_abbrev) AS org`. Use a `LEFT JOIN`
when the Events_View join is a LEFT JOIN (pitch-anchored queries), otherwise a
plain `JOIN`. If a query has no Events_View, add one on
`pv.ab_event_id = ev.event_id` first (the bat-speed / attack-angle tracking
queries need this).

Then: every aggregate query `GROUP BY <id>, UPPER(mt.org_abbrev)`; every
Python groupby `["<id>", "org"]`; every merge `on=["<id>", "org"]`. Drop the
`org_primary` CTE entirely.

### Two structural shapes

| Shape | Reference impl (DONE + verified) | Fix |
|---|---|---|
| **Separate queries merged in Python** (every tracker) | `barrelsville/src/tracker_data.py` (commit `f989af8c`) | add org to each query + `GROUP BY id, org`; every `.merge(... on=["batter_id","org"])`; helper groupbys add org |
| **Monolithic CTE chain** (every KPI weekly) | `barrelsville/src/hitter_kpi_data.py` | add org to each stat CTE's SELECT + GROUP BY; **drive the final SELECT FROM the per-(id,org) `batter_org` CTE, not `primary_org`**; join stat CTEs `ON id AND org`; supplemental queries + Python merges + percentile-pool merge all key on `(id, org)` |

---

## Site inventory + status (May 2026)

### ✅ DONE (verified or compiled)
| Site | File | Status |
|---|---|---|
| Barrelsville hitter tracker — season | `barrelsville/src/tracker_data.py` | SHIPPED `f989af8c`, **live-DB verified** (Moss splits CIN 41 / HOU 15 / HOU 11) |
| Barrelsville hitter KPI weekly | `barrelsville/src/hitter_kpi_data.py` | fixed + compiles; verify on work laptop |

### 🟡 PORTED May 2026 — compiles clean, PENDING work-laptop verify + re-pin/redeploy
All 5 other trackers + all 6 KPI modules had the season path ported this
session (Arm Farm pitcher tracker+KPI; BR tracker+KPI; Catcher tracker+KPI;
Fielding tracker + `fielding_duckdb.py` + OF/IF KPI). Each compiles; none are
DB-verified yet. Verify each with a traded player before re-pin/redeploy.
Defensive modules (pitcher/catcher/fielder) correctly attribute via
`fielding_team_id`. Monthly/weekly variants + page `_combine_multi_level`
remain deferred (see below).

### ⏳ PENDING — same fix, mechanical (monthly/weekly + batch)
| Site | File | Shape |
|---|---|---|
| Barrelsville tracker — monthly + weekly | `barrelsville/src/tracker_data.py` (`_MONTHLY_*`, `_WEEKLY_*`, `_get_single_level_monthly`/`_weekly`) | separate-query (+ `game_month`/`week_start` in keys) |
| Barrelsville page multi-level combine | `barrelsville/pages/2_Affiliate_Tracker.py` `_combine_multi_level` | groupby `batter_id` → consider `(batter_id, org)` |
| Arm Farm pitcher tracker | `bullpen-report/src/tracker_data.py:512` | separate-query |
| Arm Farm pitcher KPI | `bullpen-report/src/pitcher_kpi_data.py:488` | monolithic |
| BR tracker | `intangibles/src/br_tracker_data.py:461` | separate-query |
| BR KPI | `intangibles/src/br_kpi_data.py:715` | monolithic |
| Catcher tracker | `intangibles/src/catching_tracker_data.py:473` | separate-query |
| Catcher KPI | `intangibles/src/c_kpi_data.py:674` | monolithic |
| Fielding tracker (OF+IF) | `intangibles/src/fielding_tracker_data.py:621, 1456` + Python rollup `:4272` | separate-query + Python |
| Fielding DuckDB | `intangibles/src/fielding_duckdb.py:302` | DuckDB SQL |
| OF KPI | `intangibles/src/of_kpi_data.py:621` | monolithic |
| IF KPI | `intangibles/src/if_kpi_data.py:602` | monolithic |
| Batch: heart zone | `barrelsville/scripts/heart_zone_report.py` (×9) | lower priority |
| Batch: heart-sw corr | `barrelsville/scripts/heart_sw_correlations.py` | lower priority |
| Batch: PD flag drift | `pd-goals/src/drift_hitting.py:141` | lower priority |

### Org rollup queries are ALREADY CORRECT — do not "fix"
The `_ORG_*` per-org aggregate queries (e.g. `tracker_data.py` line ~2180+)
group by actual per-PA org already, so a traded player's stats land in the
right org's totals. Only the **per-player leaderboard** path has the bug.

---

## Re-pin / redeploy after each fix
Tracker fixes need a re-pin (`pin_*_seasons.py`, ~80 min/tracker) + redeploy
before the live app reflects them — the app reads the pin, not live DB. The
verify-before-repin shortcut is the `_TRACKER_PINS_AVAILABLE = False` bypass
(see `barrelsville/scripts/verify_moss_orgsplit.py`). KPI weekly regenerates
on demand (no pin) — just redeploy.

---

## Verification (every site)
Use a known mid-season-same-level-traded player (Jack Moss, gc_id 107148,
2026, afa/afx). Pass = he appears as **separate org rows** with **distinct
per-org metrics** (not the same combined value duplicated onto both rows —
that means a supplemental query/merge was missed). On KPI weekly: pass = his
HOU row appears in the **Season** table, not just L2W.

---

## What NOT to do
- **Don't** keep `org_primary` / `primary_org` / `drop_duplicates(id)` for org.
- **Don't** fix only the spine (PA/pitch) and leave a supplemental query
  (bat speed, xwOBA, swing-dist, AACon, PoC) keyed on `id` alone — it attaches
  the same combined value to both org rows. All-or-nothing per surface.
- **Don't** "fix" the `_ORG_*` org-rollup queries — they're already per-PA org.
- **Don't** solve it by relabeling a player's combined stats to his current org
  (Option B) — that mixes pre-trade data under the new org. Split the rows.
- **Don't** drop the `org == "HOU"` filter in KPI reports to "let him through" —
  that breaks the affiliate scoping. The fix is correct org attribution so his
  HOU row exists and passes the filter.
- **Don't** write a new org-attribution path without this snippet. Copy a
  reference impl.

---

## Cross-references
- `three-surface-parity.md` — tracker / KPI weekly / PD-Goals must match; org
  attribution is part of that invariant.
- `org-codes.md` — canonicalize OAK/ATH + CHI/LA/NY when comparing org strings
  across sources (applies to the `mt.org_abbrev` value).
- `kpi-roster-filter.md` — KPI Season-table roster filter (separate concern;
  it filters by `batter_id`, this bug drops the row earlier via `org == "HOU"`).
- `merge-union-not-primary.md` — sibling anti-pattern (primary-frame row
  universe); same "don't let one source define the universe" lesson.
- `slack-channels-sync.md` — cross-worktree sync discipline for this rule file.

---

## Bug history
- **May 2026** — Jack Moss disappeared from the Barrelsville hitter tracker A+
  HOU view, then from the Weekly KPI Season table (but not L2W). Root cause:
  window-scoped `org_primary` majority attribution across ~14 sites. Barrelsville
  tracker season fixed + live-verified (`f989af8c`); hitter KPI fixed same
  session. Rule created to drive the systemic rollout + prevent reintroduction.
  The pattern was *documented as intended* in multiple docstrings
  (`_get_org_mapping`: "picks the org with the most PAs as primary";
  `fielding_tracker_data.py:1441`), which is why it propagated to every new
  surface — those comments are now wrong and should be corrected as each site
  is fixed.
