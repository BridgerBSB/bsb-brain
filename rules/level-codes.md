---
paths:
  - "**/*.py"
  - "**/*.sql"
---

# MLBAM Schedule SPORT Codes

| Code | Level | Astros Affiliate |
|------|-------|-------------------|
| mlb | MLB | Houston Astros |
| aaa | AAA | Sugar Land Space Cowboys |
| aax | AA | Corpus Christi Hooks |
| afa | A+ (High-A) | Asheville Tourists |
| afx | A (Single-A) | Fayetteville Woodpeckers |
| rok | Rookie (FCL/DSL/ACL) | All rookie ball — use `gc2_level_code` to distinguish DSL/FCL/ACL |
| int | Internal/Private | NOT real games — NULL teams, off-season dates. See exceptions below |

## DSL vs FCL — `--level rok` = FCL-only, `--level dsl` = DSL-only (BLOCKING, May 27 2026)

`sv.level_code='rok'` covers BOTH FCL and DSL games. `sv.gc2_level_code`
distinguishes them. **All user-facing CLIs + apps in this codebase MUST
treat `'rok'` as FCL-only and `'dsl'` as DSL-only.** No script bundles
the two anymore (postgame's old intentional-bundling exception was
removed May 27 2026 — see bug history).

### The canonical pattern (two halves)

| Path | Rule | Helper |
|---|---|---|
| **WHERE clause** | Use `_build_level_filter(level_code)` for any per-level filter. It emits `sv.gc2_level_code = 'rok'` for FCL and `sv.gc2_level_code = 'dsl'` for DSL. | `database.py::_build_level_filter` (4 copies, byte-identical) |
| **SELECT clause** | When a query returns a level for downstream Python use (display, channel routing, pool routing), alias `sv.gc2_level_code AS level_code` so the column name stays `level_code` but the value is the disambiguated one. | See "SELECT path — BLOCKING" subsection below |

### `--level` matrix — exact semantics across every CLI + app

| Invocation | Real FCL R games (gc2='rok') | Real DSL R games (gc2='dsl') | DSL Live AB intrasquads (level_code='int' + R + is_int_level=1) | Other levels (mlb/aaa/...) |
|---|---|---|---|---|
| `--level rok` | ✅ | ❌ | ❌ | ❌ |
| `--level dsl` | ❌ | ✅ | ✅ (admit-mask in postgame CLIs) | ❌ |
| `--level rok dsl` | ✅ | ✅ | ✅ | ❌ |
| `--level mlb aaa` (etc.) | ❌ | ❌ | ❌ | ✅ matching levels |
| no `--level` flag | ✅ | ✅ | ✅ | ✅ |

Bundling FCL + DSL uses the `nargs="+"` multi-value form — `--level rok dsl`.
No CLI auto-bundles anymore. The DSL admit-mask for Live AB is implemented in
`barrelsville/scripts/generate_postgame.py` + `bullpen-report/scripts/generate_postgame.py`;
see "Live AB postgame admit-mask" subsection below.

### BLOCKING contexts (must use the canonical pattern above)

- Per-player batch CLIs (postgame hitter/pitcher/catcher, BR, weekly)
- Streamlit app sidebars that expose a level dropdown
- Percentile pool builders (any file in `*percentiles*.py`)
- Per-level KPI / tracker / pin queries
- Org rollups that rank 30 orgs at a level
- Per-level SQL template substitution (see "Per-level template substitution" subsection below)

### Junk-exclusion clauses stay on `sv.level_code`

`WHERE sv.level_code NOT IN ('win','bbc','int','sum','nae','hsb','ind','jcb')`
keeps using `level_code` because junk codes live ONLY on `level_code`
(they don't have gc2 variants). Don't change those.

### `--level IL` synthetic level (May 26-27 2026)

`'IL'` is NOT a level in MLBAM.Schedule — it's a synthetic dispatch
value used by the 3 advance batch scripts (Barrelsville hitter, Arm
Farm pitcher, Intangibles hitter advance) and their Streamlit apps.

When the caller passes `'IL'`:
- Schedule lookup substitutes `'rok'` (rehab happens physically at FCL)
- Roster pool swaps to IL/REHAB status (any LEVELOFPLAY_LK)
- Percentile pool routes to `gc2_level_code='rok'` (pure FCL pool, no DSL)
- Delivery routes to `fcl_<domain>` channel (same as `--level rok`)

`'IL'` is an INTENT, not a real level. The `_build_level_filter` /
SELECT-alias rules below apply to its underlying FCL substitution
exactly the same way they apply to a direct `--level rok` call.

### The litmus test (when in doubt)

If `--level dsl` returns zero rows on a day where DSL kids played: **that's
a bug**, period. Either:
- The query filtered on raw `sv.level_code` (will never match `'dsl'` — DSL games carry `'rok'` raw) → switch to `_build_level_filter('dsl')` or alias the SELECT
- The Python filter excluded Live AB rows (Live AB has `level_code='int'`) → add the Live AB admit-mask (see "Live AB postgame admit-mask")

If `--level rok` returns DSL kids: **also a bug**. Either:
- Query bypasses `_build_level_filter` and filters on raw `level_code='rok'` (matches BOTH FCL and DSL because both carry the raw value) → switch to the helper or alias the SELECT
- Some other admit-mask is too permissive

The post-May-27 invariant: `--level rok` = FCL/ACL only, `--level dsl` =
DSL (real R + Live AB). Anything else is a bug.

---

## MLBAM.Schedule opponent schedules — DSL/FCL/ACL share `SPORT='rok'`, discriminate on `MLBAM.Teams.league` (BLOCKING, Jun 10 2026)

Everything above is the **`Astros.Schedule_View` / `gc2_level_code`** side
(our players' BIPs/pitches). The advance reports ALSO build an **opponent
schedule** from `MLBAM.Schedule` to find who we play next — a DIFFERENT
table family with its OWN DSL/FCL trap, and `gc2_level_code` does NOT exist
there.

In `MLBAM.Schedule`, **DSL, FCL, and ACL games all carry `SPORT='rok'`**.
The only team-level discriminator is **`MLBAM.Teams.league`** =
`'DSL'` / `'FCL'` / `'ACL'`.

**The trap:** the advance schedule queries join `MLBAM.Teams`
(sport_code='rok') → `mlb_ebis.gbl_club_lkup` on **org only**
(`org_abbrev = ORG_LK AND LEVELOFPLAY_LK = :ebis_level`). Because an org's
DSL *and* FCL/ACL teams are BOTH sport_code='rok', the org-level join pairs
BOTH team_ids with the DSL `CLUB_LK` → the FCL/ACL team passes the `'ds'`
filter → DSL advance shows ~50/50 DSL/FCL opponents (and every team
double-counts via 2 CLUB_LK rows per org). A naive `gbl_club_lkup` join
CANNOT split them — it is org-keyed.

**The fix — discriminate at the team level + dedup:**
```sql
INNER JOIN (
    SELECT DISTINCT bamt.team_id            -- DISTINCT kills the 2-CLUB_LK dup
    FROM MLBAM.Teams bamt
    INNER JOIN mlb_ebis.gbl_club_lkup ebisc
        ON <org remap> = bamt.org_abbrev
       AND ebisc.LEVELOFPLAY_LK = :ebis_level
    WHERE bamt.sport_code = :sport_code ...
      AND ( bamt.sport_code <> 'rok'                  -- AAA..A: league irrelevant
         OR (:want_dsl = 1 AND bamt.league =  'DSL')   -- DSL scouting → DSL only
         OR (:want_dsl = 0 AND bamt.league <> 'DSL') ) -- rok/IL → FCL/ACL only
) club ON club.team_id = <opp_team_id>
```
Caller: `params["want_dsl"] = 1 if level == "dsl" else 0`. This also fixes
the **reverse** leak (`--level rok` was pulling DSL opponents into FCL).

**Lives in exactly 3 files (fix one → fix all; `gbl_club_lkup` appears in
NO other .py — verified):**

| Advance app | File | Schedule functions |
|---|---|---|
| Hitting (opp pitchers) | `barrelsville/src/advance_data.py` | `get_upcoming_series` / `get_season_series` |
| Pitching (opp hitters) | `bullpen-report/src/advance_pitching_data.py` | `get_season_series` (upcoming wraps it; `_UPCOMING_GAMES_QUERY` is dead) |
| Fielding (opp hitters) | `intangibles/src/hitter_advance_data.py` | `get_upcoming_series` / `get_season_series` |

Both the **batch scripts** (`generate_*advance*.py`) AND the **Streamlit
advance pages** (`_load_season_series`) call these same data-layer
functions, so the one fix covers both surfaces — there is no separate
app-vs-script schedule query.

**What NOT to do:**
- Don't trust the `gbl_club_lkup` org-level join to split DSL/FCL — it's org-keyed; both teams are sport_code='rok'. You MUST add the `MLBAM.Teams.league` team-level filter.
- Don't reach for `gc2_level_code` here — it's an `Astros.Schedule_View` column; `MLBAM.Schedule` / `MLBAM.Teams` don't have it. `league` is the MLBAM-side discriminator.
- Don't drop `SELECT DISTINCT team_id` — without it each opponent double-counts (2 CLUB_LK rows per org inflate num_games).
- Don't fix one advance module and leave the others — the bug + query are byte-identical in all three.

---

## Canonical column reference

**`sv.gc2_level_code`** is the definitive DSL/FCL distinguisher. NOT `sv.league`.
- **DSL:** `sv.gc2_level_code = 'dsl'` (gc2_level_id=24)
- **FCL/ACL:** `sv.gc2_level_code = 'rok'` (gc2_level_id=20)
- **All other levels:** `gc2_level_code` = `level_code` (identical)

**DO NOT use sv.league for DSL detection.** The old `sv.league = 'DSL'` approach had NULL gaps.

### _build_level_filter() — ALL 4 database.py files use this:
```python
def _build_level_filter(level_code, sv_alias="sv"):
    if level_code in ("dsl", "rok"):
        return f"{sv_alias}.gc2_level_code = '{level_code}'"
    return f"{sv_alias}.level_code = '{level_code}'"
```

Lives in `bullpen-report/src/database.py`, `barrelsville/src/database.py`,
`intangibles/src/database.py`, and `pd-goals/src/database.py`. Single-
level scoped queries (one level at a time) import and call directly:
```python
from .database import _build_level_filter
level_filter = _build_level_filter(level_code)  # 'sv.gc2_level_code = "dsl"' for DSL
```

### Per-level template substitution — DO NOT roll your own that returns the IN-list (BLOCKING)

Some files (org KPI aggregator, per-level batch helpers) build SQL
templates with a baked-in default predicate like
`WHERE sv.level_code IN ('aaa','aax','afa','afx')` and then substitute
the IN-list at runtime when a specific level is requested. This is
fine as a pattern — but the local helper MUST route DSL/rok through
`gc2_level_code`. **Returning just an IN-list literal like `('dsl')`
silently breaks DSL** (matches zero rows because DSL games have
`sv.level_code='rok'`) and **silently pollutes FCL** (matches both
FCL and DSL games because both have `level_code='rok'`).

**Antipattern (do NOT copy this):**
```python
def _build_levels_sql(level_codes=None):
    """Returns just the IN-list."""
    if level_codes is None:
        return _LEVELS_SQL                   # ('aaa','aax','afa','afx')
    return "(" + ",".join(f"'{lv}'" for lv in level_codes) + ")"

# Caller (BROKEN for DSL):
query = query.replace(_LEVELS_SQL, _build_levels_sql(['dsl']))
# → "WHERE sv.level_code IN ('dsl')"  ← matches zero rows
```

**Canonical fix — full-predicate substitution:**
```python
def _build_levels_pred(level_codes=None, sv_alias="sv"):
    """Returns the full WHERE predicate, routes DSL/rok via gc2_level_code."""
    if level_codes is None:
        return f"{sv_alias}.level_code IN {_LEVELS_SQL}"
    clauses, plain = [], []
    for lc in level_codes:
        if lc in ("dsl", "rok"):
            clauses.append(f"{sv_alias}.gc2_level_code = '{lc}'")
        else:
            plain.append(f"'{lc}'")
    if plain:
        clauses.append(f"{sv_alias}.level_code IN ({','.join(plain)})")
    if len(clauses) == 1:
        return clauses[0]
    return "(" + " OR ".join(clauses) + ")"


def _apply_level_codes(query, level_codes=None, sv_alias="sv"):
    """Replace the baked-in default predicate substring with the right one."""
    if level_codes is None:
        return query
    old_pred = f"{sv_alias}.level_code IN {_LEVELS_SQL}"
    new_pred = _build_levels_pred(level_codes, sv_alias=sv_alias)
    return query.replace(old_pred, new_pred)
```

Reference implementation: `pd-goals/src/org_kpi_data.py::_build_levels_pred`
+ `_apply_level_codes` (commits `03101e3` + `68966bf` on `feature/pd-goals`,
May 14 2026). Used across ~14 per-level substitution sites — pitching,
hitting, OF, IF, BR, catcher.

**Audit checklist when adding a new per-level template helper:**

1. **Does the helper return just an IN-list?** If yes, callers will
   build `WHERE sv.level_code IN ('dsl')` → broken. Refactor to return
   the full predicate, route DSL/rok through `gc2_level_code`.
2. **Does the caller do a substring `.replace()` swap?** Make sure the
   `old_pred` includes the `sv.level_code IN` prefix, not just the
   IN-list literal. Otherwise the substitution shape is fragile.
3. **For inline f-string templates**, hoist a `level_pred` variable
   once at function-top and use `WHERE {level_pred}` in the f-string.
   Don't reach into `levels_sql` after deleting the local hoist —
   grep the full function for every reference before removing.
4. **Mixed level_codes** (e.g. `['aaa', 'dsl']`) need OR'd predicates:
   `(sv.level_code IN ('aaa') OR sv.gc2_level_code = 'dsl')`. Single-
   level helpers don't have to handle this, but multi-level helpers do.

### SELECT path — BLOCKING (use gc2_level_code, not level_code)

The `_build_level_filter()` rule is for **WHERE** clauses. There's a
parallel rule for the **SELECT** path: any query that returns the level
of a game (for display, routing, or downstream filtering) MUST select
`sv.gc2_level_code`, NOT `sv.level_code`.

Canonical alias pattern (so downstream code doesn't change):

```sql
SELECT sv.gc2_level_code AS level_code, ...   -- ← correct
FROM Astros.Schedule_View sv
WHERE sv.sched_id = :sched_id
```

NEVER:

```sql
SELECT sv.level_code, ...   -- ← returns 'rok' for BOTH FCL and DSL.
                              -- The game looks like FCL downstream and
                              -- gets routed to wpb_complex when it should
                              -- go to z8_dominican_academy.
```

Audit checklist when adding a new query that returns level:
1. Is this query going to drive display / channel routing / per-level
   conditionals? → SELECT `sv.gc2_level_code AS level_code`.
2. Is this query a percentile pool or display-tier filter? Then the
   WHERE goes through `_build_level_filter()` and the SELECT (if any)
   uses `gc2_level_code`.
3. Junk-exclusion WHERE (`NOT IN ('win','bbc','int',...)`) still uses
   `level_code` — junk codes are stored ONLY on `level_code`. Leave
   junk WHERE clauses alone.

### DSL Percentile Pools — ALWAYS SEPARATE
- Every percentile file across all 4 projects (Barrelsville, Arm Farm, Intangibles, PD Goals) gives DSL its own isolated percentile pool
- NEVER combine DSL with FCL/ACL for percentiles or level lists
- ALWAYS include DSL in level constants (BATCH_LEVELS, sidebar dropdowns, etc.)

### wOBA weights for DSL
DSL uses `level_code = 'rok'` in `Guts.woba_lwts` (not a separate code). Use `_woba_level_code()` helper.

## ADVANCE REPORTS — PERMISSIVE OVERRIDE

Advance reports (Barrelsville hitter advance; future pitcher advance;
future fielding advance) **intentionally allow** `bbc`, `ind`, `int`,
`sum`, `win`, `min` — they window on recency, not level-pool purity.
See `.claude/rules/advance-levels.md` for the full rationale.

The "Always exclude" directives below apply to **KPI / postgame /
tracker / Org Rankings / percentile pools** — not advance.

## Junk Level Codes — MUST EXCLUDE

| Code | What | Notes |
|------|------|-------|
| `bbc` | **College (4-year amateur)** — corrected Apr 28 2026 (NOT Baseball Canada, NOT Big League Camp) | Always exclude for pro reports; **ALLOW for draft / amateur-vs-pro analysis** |
| `sum` | Summer league (Cape Cod, Northwoods, etc. — amateur college) | Always exclude for pro reports; ALLOW for amateur analysis |
| `int` | Internal/private | **EXCEPTION: int/V = DSL bullpens — allow V through** |
| `hsb` | High school showcase (amateur HS) | Always exclude for pro reports; ALLOW for amateur analysis |
| `ind` | Independent league | Always exclude |
| `win` | Winter league | Always exclude |
| `jcb` | Junior college (amateur 2-yr) | Always exclude for pro reports; ALLOW for amateur analysis |
| `nae` | Unknown | Always exclude |
| `min` | MiLB minor/Exhibition | **NOT junk — has real E sched_type games** |
| `NULL` | No level assigned | Always exclude |

### BBC correction note (Apr 28 2026)
Multiple historical rules files referred to `bbc` as "Big League Camp" — that
is incorrect. `bbc` is **4-year college baseball** (amateur). This is the
authoritative meaning per user (zbridger). Spring training games are
`sched_type = 'S'` on `level_code = 'mlb'` (or affiliate level code) — not
`level_code = 'bbc'`. If any `_build_sched_filter()` virtual sched-type
labeled "BBC" is keying off `level_code = 'bbc'` AND `sched_type = 'S'` to
construct a "Big League Camp" pseudo-type, that logic is incorrect — those
are spring college games (rare) or potentially Astros-vs-college exhibition
games. Investigate per-app before relying on any BBC virtual sched_type filter.

The four amateur level codes — `bbc` (4-yr college), `jcb` (junior college),
`hsb` (HS showcase), `sum` (summer/Cape) — are intentionally excluded from
pro reports (KPI / postgame / tracker / percentile pools) because they pollute
the pro-stats distribution. They are intentionally INCLUDED in:
- Advance reports (per `advance-levels.md` recency override)
- Draft / amateur-vs-pro development analysis (`generate_amateur_vs_pro.py`)

**CRITICAL: Every junk code has `sched_type = 'R'` games.** `sched_type = 'R'` alone does NOT protect against contamination.

### `int` Level Exceptions

`int` is "internal/private" — normally junk. Two real-data exceptions:

**1. `int` + `sched_type='V'` (1,267+ games) = DSL bullpen sessions.** Block `int` for R-type pool queries, ALLOW for V/I. Arm Farm uses split junk lists: `_JUNK_LEVELS_R` (includes int) vs `_JUNK_LEVELS_NON_R` (excludes int).

**2. `int` + `sched_type='R'` + `is_int_level=1` = HOU DSL DR-Private intrasquad scrimmages (Live AB).** POSTGAME SURFACE ONLY (May 2026).

#### DSL Live AB (DR-Private) — Postgame Pattern

Players: HOU `PP_MASTER.LEVELOFPLAY_LK='DS' AND ORG_LK='HOU'` (Yensi De La Cruz, Albert Fermin, Christian Colon, etc. — ~17 kids per scrimmage). Description matches `'YYYYMMDD-DRAstros-Private-N'` or `'-DRHouston-Private-N'`. Team IDs are NULL — do NOT add an org-tenure JOIN gate (verified May 2026 against Yensi diagnostic). PP_MASTER level gate alone handles Yajure-style ex-NPB exclusion (he's currently ML, not DS).

**Pattern (apply ONLY in barrelsville hitter postgame + bullpen-report pitcher postgame):**

1. **Discovery filter** — `LEVEL_FILTER_SQL` constant in each worktree's `postgame_data.py` admits Live AB rows alongside the junk exclusion:
   ```python
   LEVEL_FILTER_SQL = (
       "(sv.level_code NOT IN ('win','bbc','int','sum','nae','hsb','ind','jcb') "
       "OR (sv.level_code = 'int' AND sv.sched_type = 'R' AND sv.is_int_level = 1))"
   )
   ```
   Replaces `AND sv.level_code NOT IN {EXCLUDE_LEVELS_SQL}` in 6 (Barrelsville) / 4 (Arm Farm) query sites.

2. **App sched_type filter** — `_build_sched_filter` in `postgame_app_data.py` admits Live AB ONLY when `'I'` or `'V'` is in `real_types`, NEVER `'R'`. Coaches see these games under "Live BP/Intrasquad" or "V" filter, NOT Regular Season.

3. **Default selector** — `get_most_recent_sched_types` returns `'I'` when most recent game is `sched_type='R' AND level_code='int'` (so the sidebar auto-selects "Live BP/Intrasquad" when a DSL kid is chosen).

4. **Pool routing** — Override `level_code` to `'dsl'` BEFORE calling `get_level_percentiles` when `level_code='int'`. DSL pool falls back to prior-year DSL automatically when current year is thin.

4b. **`--level dsl` admits Live AB rows** (May 27 2026). Live AB rows have `level_code='int'`, not `'dsl'`, so the straight Python `.isin({'dsl'})` filter would exclude them. The hitter + pitcher postgame CLIs explicitly OR in a Live AB admit-mask when `'dsl'` is in the level_set: `(level_code == 'int') & (sched_type == 'R')`. This means `--level dsl` matches BOTH real DSL R games AND DSL Live AB intrasquads — same kids, same pool routing, same coaches. `--level rok` does NOT admit Live AB (Live AB is HOU-DSL-only, not FCL complex).

5. **Header label** — `_report_title(..., is_live_ab=True)` returns `"Live AB - International (DSL INT) Postgame Report"`.

6. **Two-layer separation — Live AB pitches NEVER enter ANY percentile pool (BLOCKING)** —
   Live AB games surface in per-player postgame view (display layer) but
   NEVER get added to the DSL percentile pool DEFINITION nor the FCL pool
   nor any other pool. Both pools are built via `_build_level_filter`:
   - `_build_level_filter('dsl')` → `WHERE sv.gc2_level_code = 'dsl'`
   - `_build_level_filter('rok')` → `WHERE sv.gc2_level_code = 'rok'`

   Live AB rows have `sv.gc2_level_code = 'int'` — mutually exclusive with
   BOTH filters. The Live AB row's COMPARISON pool is DSL (via `is_live_ab`
   per-row routing in the loop: `pool_level_code = 'dsl' if is_live_ab`),
   but the row's own pitches do NOT contribute to that pool.

   **Audit verified May 27 2026:** every percentile builder across both
   postgame worktrees + hitter advance (`barrelsville/src/postgame_percentiles.py`,
   `barrelsville/src/advance_percentiles.py`,
   `bullpen-report/src/postgame_percentiles.py`) routes through
   `_build_level_filter`. Zero raw-level-code DSL filters exist outside the
   helper. Zero queries admit `'int'` alongside `'dsl'` or `'rok'`.
   Pool integrity is locked in by SQL structure.

   Adding Live AB data to any pool would compare players against themselves
   AND contaminate next year's distribution. Don't do it. The display vs
   pool-definition separation is a core invariant.

**Delivery:** uses existing `pd-goals/data/slack_channels.csv` zzz_ routing — no special handling needed.

#### What NOT to Do

- DON'T extend Live AB admit to KPI weekly / trackers / org KPI / advance reports. Postgame-only by design (May 2026). Other surfaces still exclude `'int'` and that's correct for their semantics.
- DON'T admit Live AB on the `'R'` sched_type filter branch — surface under `'I'`/`'V'` instead.
- DON'T add Live AB games to the DSL percentile pool definition (two-layer rule).
- DON'T treat as a general international-games admit pattern. WBC / NPB / KBO use different sched_types (not 'R') and would route to different pools.
- DON'T modify `EXCLUDE_LEVEL_CODES` to drop `'int'` — that loosens it everywhere. Use the LEVEL_FILTER_SQL admit-clause pattern so the change stays local to postgame.
- DON'T require a min-PA gate. Even 1-pitch / 1-PA Live AB postgames generate a PDF.

**Reference impl files (May 2026 commits):**
- Barrelsville: `685a5d2` (initial), `e18c365` (filter route fix), `83a4e85` (default selector fix)
- Arm Farm: `5ffb788` (initial), `4ce0150` (filter route fix), `71a8c36` (default selector fix)

**Future expansion candidates** (deferred — require explicit user direction): KPI weekly hitter/pitcher reports, affiliate trackers (catcher / OF / IF / BR — three-surface parity rules apply), org KPI report DSL section, MLB-rostered international R games (WBC pattern).

## Safe Query Patterns (use one of these)
1. **Whitelist:** `sv.level_code IN ('mlb','aaa','aax','afa','afx','rok')` — scripts querying all data
2. **`_build_level_filter()`** — tracker, KPI data, percentile queries
3. **`EXCLUDE_LEVELS_SQL`** — full 8-code list in postgame_data.py (for R-type queries)
4. **`sched_id` constraint** — postgame apps query by specific game
5. **Split junk lists** — `_JUNK_LEVELS_R` (with int) for R, `_JUNK_LEVELS_NON_R` (without int) for V/I/S/E

## UNSAFE Pattern
`WHERE pv.batter_id = :id AND sv.sched_type = 'R'` with NO level constraint → all junk codes leak through.

## Bug history

- **Jun 10, 2026 — Advance opponent schedules leaked FCL/ACL teams into DSL series (and vice versa).** All 3 advance schedule queries (`barrelsville/src/advance_data.py`, `bullpen-report/src/advance_pitching_data.py`, `intangibles/src/hitter_advance_data.py`) built the opponent list from `MLBAM.Schedule WHERE SPORT='rok'` and relied on a `gbl_club_lkup` INNER JOIN to keep DSL and FCL apart — but the join matched ORG-level, so every org's FCL/ACL `team_id` (also sport_code='rok') got paired with the DSL `CLUB_LK` and passed the `LEVELOFPLAY_LK='ds'` filter → DSL advance reports showed ~50/50 DSL/FCL opponents, every team double-counted (2 CLUB_LK rows/org). Confirmed via diagnostic (`1998 FCL Astros … DS` passing the DSL filter). Fix: team-level `MLBAM.Teams.league` discriminator via a `want_dsl` param + `SELECT DISTINCT team_id`. Covers app + batch (shared data-layer functions). See "MLBAM.Schedule opponent schedules" section above. Commits on `feature/astros-intangibles`, `feature/barrelsville`, `feature/bullpen-reports`.

- **May 27, 2026 — Two-part postgame `--level` fix: SELECT-alias for FCL/DSL split + Live AB admit-mask for `--level dsl`.**

  **Part 1: SELECT-alias (the in-season fix).** Hitter + pitcher postgame
  CLIs (`barrelsville/scripts/generate_postgame.py`,
  `bullpen-report/scripts/generate_postgame.py`) and their sibling
  Streamlit pages bypassed `_build_level_filter()` and SELECTed raw
  `sv.level_code`. Because DSL games carry `level_code='rok'`, the
  Python-side filter `batters_df["level_code"].isin(['rok'])` matched
  both FCL AND DSL rows → bundled. The same filter for `'dsl'` matched
  zero rows because no row has `level_code='dsl'`. Result: postgame's
  `--level rok` had different semantics than every other CLI (which
  routes through `_build_level_filter` and gets the gc2 split), and
  `--level dsl` was effectively broken on postgame. Fix: alias every
  SELECT to `sv.gc2_level_code AS level_code` in
  `barrelsville/src/postgame_data.py` (6 sites) +
  `barrelsville/src/postgame_app_data.py` (5 sites) +
  `bullpen-report/src/postgame_data.py` (2 sites) +
  `bullpen-report/src/postgame_app_data.py` (4 sites) +
  `intangibles/src/br_data.py::get_games_for_date` (used by catcher +
  BR CLIs). Deleted the now-redundant per-row `gc2_lc == "dsl"`
  rewrite in `bullpen-report/scripts/generate_postgame.py:277-279`
  (the SELECT alias does that translation upstream). Same fix pattern
  as `boxscore_report.py` (commit `789ef0e` May 12 2026).
  Commits: `a643109a` (barrelsville), `e0e0dd04` (bullpen-reports),
  `bff16e27` (intangibles BR/catcher), `a9db4193` (pd-goals rule sync).

  **Part 2: Live AB admit-mask for `--level dsl` (the preseason fix).** After
  Part 1 shipped, user testing on 5/24-5/26 revealed `--level dsl` still
  returned zero rows for those dates — because the only DSL games in
  preseason are Live AB intrasquads (`R + level_code='int' + is_int_level=1`),
  which carry `gc2_level_code='int'` (not `'dsl'`) and so didn't pass the
  Python filter `.isin({'dsl'})`. Fix: hitter + pitcher postgame CLI's
  `--level` filter ORs in a Live AB admit-mask when `'dsl'` is in level_set:
  ```python
  if "dsl" in level_set:
      live_ab_mask = (lvl_lower == "int") & (sched_type == "R")
      mask = mask | live_ab_mask
  ```
  Same criteria as the existing per-row `is_live_ab` detection at line 431
  (which routes the Live AB row to the DSL pool for comparison). `--level rok`
  intentionally does NOT admit Live AB (Live AB is HOU-DSL-only, not FCL).
  Catcher + BR scripts NOT included — they don't have Live AB handling at
  all, separate decision if needed.
  Commits: `92d1c500` (barrelsville), `319f14be` (bullpen-reports),
  `9eb78559` (intangibles rule sync), `1730e7fe` (pd-goals rule update).

  **Audit performed same session, confirmed clean:** zero DSL-pool leakage.
  Every percentile builder (`postgame_percentiles.py` × 2, `advance_percentiles.py`)
  routes through `_build_level_filter`. Live AB rows are mutually exclusive
  with the DSL pool filter (`gc2='int'` ≠ `gc2='dsl'`). The display-vs-pool
  two-layer separation (DSL Live AB section point 6) holds.

  **Outcome:** post-fix matrix:
  - `--level rok` → FCL/ACL only (no DSL, no Live AB)
  - `--level dsl` → real DSL R games + Live AB intrasquads
  - `--level rok dsl` → both (FCL + DSL + Live AB)
  - no `--level` → everything (unchanged)

  And: Live AB pitches never enter any percentile pool, ever. Per-player
  display routes Live AB kids to compare against DSL pool, but their own
  pitches don't contribute to that (or any) pool.

- **May 14, 2026 — PD Goals org KPI per-level path used roll-your-own
  IN-list helper, broke DSL + silently polluted FCL.**
  `pd-goals/src/org_kpi_data.py` had a local `_build_levels_sql()` that
  returned just `('dsl')` and got substituted into
  `WHERE sv.level_code IN ('dsl')` — matches zero rows because DSL games
  have `sv.level_code='rok'`. Every domain page returned 0 rows for DSL
  and the report was skipped (`Skipped DSL (no data)`). Same query
  shape silently pulled DSL data into the FCL PDF
  (`level_codes=['rok']` → `WHERE sv.level_code IN ('rok')` matches
  both FCL and DSL games). Fix `03101e3` introduced `_build_levels_pred()`
  + `_apply_level_codes()` and migrated ~14 substitution sites
  (pitching, hitting, bat-speed, OF, IF, BR, catcher). Follow-up
  `68966bf` wired the new `level_pred` variable into three inline
  f-string sub-queries in `get_hitting_org_stats` (per-level wRC+,
  gcOBA, barrel/EV) that referenced the deleted `levels_sql` hoist
  — symptom: `Hitting: no data, skipping page` on every level until
  the f-strings were patched. Root cause: this file rolled its own
  per-level helper instead of using `_build_level_filter()` from
  `pd-goals/src/database.py`. The new "Per-level template substitution"
  section above codifies the canonical full-predicate substitution
  pattern + audit checklist so future agents don't reintroduce the
  roll-your-own antipattern.

- **May 12, 2026 — Barrelsville boxscore mislabeled DSL as FCL.**
  `barrelsville/scripts/boxscore_report.py` SELECTed `sv.level_code` in
  both `get_game_info` and the date-mode meta query. DSL games have
  `level_code='rok'` (same as FCL/ACL) — only `gc2_level_code='dsl'`
  distinguishes them. DSL boxscore PDF rendered with "FCL Astros" team
  name AND delivered to `wpb_complex` (Slack #zX FCL channel) instead
  of `z8_dominican_academy`. Fix `789ef0e` on `feature/barrelsville`:
  SELECT `sv.gc2_level_code AS level_code` in both SQLs; added 'dsl'
  entries to `AFFILIATE_NAMES` + `AFFILIATE_NICKNAMES` (routing dict
  `AFFILIATE_CHANNEL_IDS` already had it). Comments in both SQLs now
  reference this rules file. Root cause: SELECT path was never on the
  checklist — only the WHERE path (`_build_level_filter()`) was. The
  "SELECT path — BLOCKING" subsection above was added in the same
  commit to close the loop.

- **Mar 19, 2026 — DSL/FCL refactor from `sv.league` → `gc2_level_code`.**
  Original DSL detection used `sv.league = 'DSL'`, which had NULL gaps
  on Astros DB rows. Migration to `gc2_level_code` documented in DSL vs
  FCL section above. Pre-refactor `level_code = 'rok' AND league = 'DSL'`
  patterns in `scripts/exploration/` are legacy but still functionally
  correct (both checks are present, so it picks the right rows).
