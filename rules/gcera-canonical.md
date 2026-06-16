# gcERA Canonical — BLOCKING

Every gcERA value across every surface MUST match GC2 within ±0.005
(rounding noise). Five surfaces compute gcERA today; all must produce
the same number for the same player + game(s) + season scope. Same
discipline as `xwoba-canonical.md`.

This rule exists because gcERA shipped four independent silent bugs
in 2026 — each one drifted the value by 0.05-0.25 in production and
went undetected until a coordinator caught it side-by-side with GC2.
The fixes were correct but the bug class kept recurring because the
implementation pattern (`if "col" in df.columns: apply_filter`)
silently no-ops when upstream SQL drops a column.

---

## The formula (memorize this)

```
gcERA = barrel_multiplier × bip_rate × pbarrel_rate
      + 3.5            × bip_rate × (1 - pbarrel_rate)
      - 3.3            × so_rate
      + 9.9            × bb_hbp_rate

where:
    barrel_multiplier  = 3.9 + 31.1 × MLB_HR_rate(season)
    so_rate            = SO / BF_no_IBB
    bb_hbp_rate        = (BB - IBB + HBP) / BF_no_IBB
    bip_rate           = max(1 - so_rate - bb_hbp_rate, 0)
    pbarrel_rate       = pbarrels / tracked_bip

    BF_no_IBB          = pa + ibb - ibb = pa  (GC2 BF removes IBB)
    BB_no_IBB          = bb - ibb
```

### What counts as `tracked_bip` (GC2 HitsNoBunts JOIN)

```
pitch_result_id IN (12, 13, 14)
AND hit_exit_speed IS NOT NULL
AND hit_exit_speed < 125
AND hit_trajectory_id NOT IN (2, 3, 4)  -- bunt exclusion
```

NO `EV > 0` filter. NO `is_pa = 1` filter. Use `hit_exit_speed_raw`
(pre-misread-cleaning) to match GC2 exactly — GC2 does NOT apply our
P95 misread filter on this metric.

### What counts as `pbarrel`

```
ev >= 0.011 × la² - 0.91 × la + 95.0
```

Same threshold across every surface.

---

## The five surfaces (all must match GC2)

| Surface | File | Function |
|---|---|---|
| Postgame app (Streamlit) | `bullpen-report/src/postgame_data.py` | `compute_statline` |
| Postgame CLI | `bullpen-report/scripts/generate_postgame.py` | calls `compute_statline` |
| Pitcher KPI weekly | `bullpen-report/src/pitcher_kpi_data.py` | `_compute_gcera` |
| Pitcher affiliate tracker | `bullpen-report/src/tracker_data.py` | per-pitcher SQL |
| PD Goals org KPI | `pd-goals/src/org_kpi_data.py` | pitching section |

**Cross-app audit verified May 21 2026**: `compute_statline` is only
used in `bullpen-report`. Barrelsville / Intangibles / PD-Goals do
NOT use this helper. The bug class below is confined to one worktree.

---

## The bug class (BLOCKING — internalize this pattern)

Every gcERA bug shipped in 2026 fits this shape:

```
upstream_query.SELECT  →  pitch_df  →  compute_statline(pitch_df)
                                       └─ if "col" in df.columns:
                                              apply_filter(df, col)
                                          # silently no-op if absent
```

When the upstream SQL drops a required column (because a refactor
forgot it, because two parallel queries drifted, because a JOIN
condition changed), `compute_statline` SILENTLY skips the filter and
returns a value that LOOKS reasonable. The drift is small enough
(typically 0.05-0.25) that nobody notices for weeks.

### Five real incidents (May 2026)

| Date | Bug | Where | Fix commit |
|---|---|---|---|
| 5/17 | `season=2025` hardcoded default in `compute_statline` — every caller defaulted to 2025 HR rate. McPherson 5/17 read 6.24 vs canonical 6.08. | `compute_statline` arg default | `fc495528` |
| 4/24 | `get_game_pitches_for_app` SELECT missing `cev.hit_trajectory_id`. Bunt filter silently skipped. McPherson 4/24 read 0.92 vs canonical 1.01. | App SQL drift from CLI sibling | `532aad8b` |
| Earlier | `EV > 0` filter on tracked_bip didn't match GC2 (GC2 has no such filter). | `compute_statline` BIP filter | (prior session) |
| Earlier | IBB not subtracted from BF / BB. | `compute_statline` PA math | (prior session) |
| 5/21 | UI empty-state: cleared multiselect persisted `[]` → statline / pitch char / pitch results sections rendered blank on next date change. | App layer (not the formula) | `3ec7a1e9` |

---

## The five places that MUST stay in sync

When ANY of these changes, audit ALL FIVE in lockstep. Same
discipline as `slack-channels-sync.md` and `three-surface-parity.md`.

1. **`compute_statline`'s pitch_df column expectations** —
   `_REQUIRED_PITCH_COLS` tuple (May 21 2026 added). Updating this
   forces every upstream SQL to SELECT those columns or the
   assertion fires.
2. **`compute_statline`'s pa_df column expectations** —
   `_REQUIRED_PA_COLS` tuple.
3. **`get_game_pitches`** (CLI path) — SELECT must include every
   `_REQUIRED_PITCH_COLS` entry.
4. **`get_game_pitches_for_app`** (Streamlit path) — same. Docstring
   already says "MUST STAY IN SYNC" with `get_game_pitches`; the
   assertion now enforces it at runtime.
5. **`get_game_pa_outcomes`** — SELECT must include every
   `_REQUIRED_PA_COLS` entry.

---

## Defensive patterns (REQUIRED for every gcERA surface)

### 1. Pass `season` explicitly at every call site

```python
# WRONG
statline = compute_statline(pitch_df, pa_df)  # falls back to default

# RIGHT
_season = game_dates[0].year if len(game_dates) > 0 else datetime.now().year
statline = compute_statline(pitch_df, pa_df, season=_season)
```

The default falls back to the FIRST sched_date in pitch_df, then
current year. Cross-year analysis silently uses the wrong HR rate
if you don't pass explicitly. See `compute_statline` docstring.

### 2. Crash loudly on missing columns

`compute_statline` now asserts required columns are present. If you
add a new column dependency, add it to `_REQUIRED_PITCH_COLS` or
`_REQUIRED_PA_COLS`. The assertion fires immediately on first call
with a clear error pointing to the upstream SQL that needs a fix.

DO NOT replace assertions with `try/except` or silent `if col in df`.
The whole point is to fail loudly so the upstream SQL gets fixed.

### 3. Pair every formula change with all 5 surfaces in one commit

When changing the gcERA formula or BIP filter:

1. Update `compute_statline` (postgame surface — both CLI + app).
2. Update `_compute_gcera` in `pitcher_kpi_data.py`.
3. Update `tracker_data.py` per-pitcher SQL.
4. Update `pd-goals/src/org_kpi_data.py` pitching block.
5. Verify with `sql-queries/gcera-mcpherson-diagnostic.sql` —
   add the test player + date to the diagnostic for permanent
   regression coverage.

Single commit across the 4-5 file touchpoints. If the commit
covers only one surface, drift is guaranteed.

### 4. Diagnostic scripts are reusable

Two diagnostics shipped May 21 2026 — keep them current:

| Tool | Path | Purpose |
|---|---|---|
| SQL | `sql-queries/gcera-mcpherson-diagnostic.sql` | Per-game gcERA from canonical SQL (matches GC2). |
| Python | `bullpen-report/scripts/diag_mcpherson_gcera.py` | Per-game `compute_statline` inputs + final value. Parametric date via `--date YYYY-MM-DD`. |

When a new gcERA bug surfaces:
1. Run both diagnostics for the same player + date.
2. If SQL matches GC2 but Python doesn't → bug is in `compute_statline` or upstream pitch_df / pa_df.
3. If SQL doesn't match GC2 → bug is in the SQL itself (filter / JOIN / scope).
4. If both match but app shows different value → bug is downstream (rendering, cache, different code path).

---

## Streamlit app rendering — companion rule

The May 21 2026 fix also addressed a parallel UI bug. `st.session_state.get(key, default)` returns the persisted value (which may be `[]` after a user clears a multiselect) — the `default` kwarg only fires when the key is MISSING entirely. Once cleared, `[]` sticks across every subsequent rerun, including date changes.

**Symptom**: section header renders (data is present), but the cards / tables below are blank because the for-loop iterates an empty list.

**Pattern**: use `or default` fallback at every `.get()` site that drives a render loop:

```python
# WRONG — sticks at [] after first clear
active_sl = st.session_state.get('statline_cols', default_statline)

# RIGHT — empty falls back to default
active_sl = st.session_state.get('statline_cols') or default_statline
```

Applies to ALL `*_cols` multiselects in `pages/2_Postgame.py`:
- `statline_cols` (4 sites: PDF setup + in-page render)
- `pitch_char_cols` (2 sites)
- `pitch_result_cols` (2 sites)

**Cross-app risk**: `barrelsville/pages/1_Postgame.py` has the same
pattern at line 1595 (and `kpi_damage_cols`, `kpi_contact_cols`,
`kpi_approach_cols`, `kpi_ball_flight_cols`, `kpi_proj_outcome_cols`).
Apply the same `or default` fix if the symptom appears there.

---

## What NOT to do

- **Don't** add `EV > 0` to the tracked_bip filter. GC2 doesn't have
  it. Adding it shrinks the denominator on rare HawkEye EV=0 reads
  and inflates pbarrel_rate by ~10% on AA / FCL / DSL outings.
- **Don't** use `cleaned hit_exit_speed` for gcERA. GC2 uses raw EV.
  The misread P95 cleanup we apply elsewhere is OUT of scope here.
- **Don't** add `is_pa = 1` to the gcERA BIP filter. GC2 counts every
  BIP, not just PA-ending pitches.
- **Don't** silently skip the bunt filter. If `hit_trajectory_id` is
  missing from upstream SQL, the assertion now fires — fix the SQL,
  don't add a defensive `if col in df.columns`.
- **Don't** change the formula coefficients. 3.9, 31.1, 3.5, 3.3, 9.9
  are from GC2's product-of-averages model. Any "improvement" must
  pair with the same change on GC2's side (which is not us).
- **Don't** drop the `_REQUIRED_PITCH_COLS` / `_REQUIRED_PA_COLS`
  assertions. They're the only thing preventing the next silent
  upstream SQL drift from shipping.
- **Don't** call `compute_statline` without passing `season=` when
  you know the game year. Cross-year analysis (e.g. comparing 2025
  to 2026) silently uses the wrong HR rate if you let it fall back.
- **Don't** add a future `compute_gcera(pitch_df, pa_df, ...)` helper
  that accepts DataFrames. Pass raw counts (`bf`, `so`, `bb`, `ibb`,
  `hbp`, `tracked_bip`, `pbarrels`, `hr_rate`) — same model as
  `compute_xwoba` post-May-18 migration. DataFrame inputs are the
  root cause of the "silently skipped filter" bug class.

---

## Cross-references

- `gc2-metrics.md` — gcERA formula + GC2 product-of-averages model
- `three-surface-parity.md` — sibling rule (tracker / KPI weekly /
  PD-Goals must match per metric)
- `xwoba-canonical.md` — same discipline, different metric. Read for
  the "Pattern A SQL JOIN" + "Pattern B Python helper with per-PA
  weights" architecture template.
- `slack-channels-sync.md` — five-place sync discipline; same shape
  as this rule's five-surface sync.
- `feedback_never_defer_to_tomorrow.md` — paired behavioral rule from
  this session's debugging spiral.
- `sql-queries/gcera-mcpherson-diagnostic.sql` — canonical SQL
  diagnostic; add new test cases here.
- `bullpen-report/scripts/diag_mcpherson_gcera.py` — Python diag with
  `--date` flag; reuse for any new bug.

---

## Bug history

- **May 21 2026 (evening)** — Documented the bug class in this rule
  after shipping commit `3ec7a1e9` (column assertions + UI empty-state
  fix). Cross-app audit confirmed compute_statline only used in
  bullpen-report; documented `barrelsville/pages/1_Postgame.py` UI
  pattern as similar-risk (not patched without explicit direction).

- **May 21 2026 (afternoon)** — UI empty-state bug. Statline / Pitch
  Char / Pitch Results sections rendered blank when user changed
  dates after clearing a `*_cols` multiselect. Root cause:
  `st.session_state.get(key, default)` returns persisted `[]` not
  default. Fixed in `3ec7a1e9` via `or default` fallback.

- **May 21 2026 (morning)** — `hit_trajectory_id` missing from
  `get_game_pitches_for_app` SELECT. Bunt filter silently skipped.
  McPherson 4/24 read 0.92 vs canonical 1.01. Fixed `532aad8b`.

- **May 21 2026 (morning)** — `compute_statline` defaulted to
  `season=2025` when caller didn't pass season. App's 3 call sites
  weren't passing season. McPherson 5/17 (2026 game) used 2025 MLB
  HR rate → +0.16 drift. Fixed `fc495528`.

- **Earlier 2026** — `EV > 0` filter on tracked_bip differed from
  GC2 (GC2 has no such filter). Fix in prior commit; trying to
  understand WHY GC2 doesn't have it surfaced this rule's "Don't
  add EV > 0" guidance.

- **Earlier 2026** — IBB not subtracted from BF / BB in gcERA math.
  Fix in prior commit; the BF_no_IBB / BB_no_IBB convention here
  documents the canonical form.
