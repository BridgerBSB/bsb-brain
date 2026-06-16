---
name: session-2026-05-23-combo-precompute-shipped
description: May 23 2026 session — fielding raw-obs parity fixes + combo pre-compute architecture (in-memory Python from raw_obs). Currently in user backfill (IF/2022). 11 commits across 4 worktrees. Catcher + BR ports pending.
metadata: 
  node_type: memory
  type: project
  originSessionId: 34b52b73-2b74-4814-8fdf-06322e9da805
---

# Session 2026-05-23 — Combo Pre-Compute Architecture Shipped

## Status as of context clear

User running full fielding pin backfill on work laptop. Last visible
checkpoint: `IF/2022/all single-year combos x120 ...` — phase mid-execution
(~10-17 min expected). The TCP retry pattern fired and recovered once on
raw_dcbp. No multi-year ranges for 2022 (earliest pinned year). After
2022 finishes, 2023 → 2024 → 2025 → 2026 each adds one more multi-year
range, ending with 2026 having 4 multi-year ranges (2025-2026, 2024-2026,
2023-2026, 2022-2026).

## Resume here after /clear

1. **First, ask user**: did the pin backfill finish? Any errors?
2. **If finished, run verification** (full recipe below in §Verification).
3. **If verification green**: redeploy `connect_pins_fielding\deploy.ps1`.
4. **App test**: multi-year + multi-level pick in app should show
   `[PIN] orgs_pooled(...,years=YYYY-YYYY,...): SERVED FROM PIN` in
   Connect logs = instant lookup confirmed.
5. **If issues**: see §Known potential issues below.

After fielding deploy verified working, the NEXT work is **catcher port**
then **BR port** per migration plans in
`docs/plans/2026-05-23-catcher-pooled-percentile-port.md` +
`docs/plans/2026-05-23-br-pooled-percentile-port.md`.

## What shipped today (commit-by-commit)

All on `feature/astros-intangibles` unless noted.

### Phase 1: Parity fixes (after user ran parity diag and got failures)

| Commit | What |
|---|---|
| `2beafceb` | TRUE pooled PAA/RAA/expected_outs math. Carry sum_offset / sum_eo_scalar / n_offset_rows / n_eo_scalar_rows through groupby, re-derive pooled values at tier exit. Naive SUM-of-per-slice paa_cal drifted ~2% because each slice carried its own AVG(offset) baked in. Fixed both `_compute_pooled_from_raw_obs` (per-fielder) and `_compute_pooled_org_from_raw_obs` (org). |
| `d1a9b129` | Mirror SQL `min_plays >= 1` filter. Raw_obs path only filtered when `min_plays > 1`, leaving 5 edge-case fielders (0 comp_plays) that SQL drops. Last 5 per-fielder discrepancies cleared. |

User re-ran parity diag → **PARITY PASS all green** (831/831 fielders, 30/30 orgs).

### Phase 2: Combo pre-compute architecture (`dc96c669`)

User direction: "we got all the combos pretty much. Get us back to the combos a little bit fast." They wanted pre-computed combos for instant app reads, but built from in-memory raw_obs (NOT 720 separate SQL queries like the original 12-hour-build path).

**New helpers in `fielding_tracker_data.py`:**
- `year_range_tag(seasons)` → bundle-key year segment ("2026" or "2024-2026")
- `_compute_all_combos_for_year(raw_tdm, raw_dcbp, raw_games, year, domain, ha)` — iterates POOLED_LEVEL_COMBOS (120 combos) and returns 240 keys per (year, H/A)
- `_compute_all_combos_multi_year(...)` — same shape on concatenated multi-year raw_obs
- `_load_prior_year_raw_obs(domain, year, ha)` — load earlier-year raw_obs from pin (NO DB)
- `contiguous_ranges_ending_at(year, pinned_years)` — generates multi-year scopes per year

**Bundle key shape (May 23 2026):**
- Single year: `<prefix>_<year_tag>_<combo>_<ha>` → `orgs_pooled_2026_aaa+aax+afa+afx_all`
- Multi year: `orgs_pooled_2024-2026_aaa+aax_home` (lives in 2026 bundle — latest year owns range ending at it)

**`_try_pin_pooled_combo` extended** to accept multi-year seasons list, enforce CONTIGUOUS year range, build key with `year_range_tag`, plus backward-compat fallback to legacy single-year key shape.

**Cascade order REVERSED** in `get_org_rankings_pooled` + `get_indiv_leaderboard_pooled`:
1. Tier 1: `_try_pin_pooled_combo` (INSTANT pin lookup)
2. Tier 2: `_try_pin_raw_obs` (compute from raw rows, ~1-2 sec)
3. Tier 3: live SQL via PERCENTILE_CONT

**`pin_fielding_tracker_seasons.py` updated** to call combo helpers after raw_obs writes. Per (year, H/A) now also writes:
- 240 single-year combo keys (~6-17 min compute depending on data volume)
- For each multi-year range ending at this year (0 for 2022, up to 4 for 2026): load prior years from pin + concat + 240 multi-year combo keys per range

### Phase 3: Bug fixes during user backfill

| Commit | What |
|---|---|
| `96320713` | **BR org rollup bug** — `aggregate_org_across_levels` summed `n_on_base` (Pitches column) but never summed `n_times_on` (Bases On column). Different SQL queries (`_BR_PITCH_QUERY` vs `_ORG_TIMES_ON_QUERY`), merged separately, easy miss because of similar names. "Bases On" came back as None on All-Levels view. Page-side fix, NO re-pin needed. |
| `ee1c98f9` | **Pandas FutureWarning noise** — `groupby("org").apply(_org_agg)` triggered deprecation warning. Was 1-2 calls per app session pre-combo-pre-compute. After dc96c669: ~thousands of calls per pin job, flooding log. Fix: `include_groups=False` (with try/except for older pandas <2.2). No behavior change. |
| `f9cf0da2` | **`_TRACKER_PINS_AVAILABLE` flag conflict** — Pin CLI sets this False to force DB on canonical get_*. But `_load_prior_year_raw_obs` ALSO checked this flag, blocking it from loading prior year pins during multi-year combo build. Every multi-year range got `SKIP multi-year range [YYYY, YYYY]: cannot load prior year YYYY pin`. Fix: removed flag check, kept import-error handling. Added diagnostic prints so future "cannot load" surfaces actual reason. |

### Documentation updates (synced 4 worktrees)

- `rules/pooled-percentile-pattern.md` — promoted to 6-piece implementation, 3-tier cascade documented, status table updated.
- `rules/blocking-rules.md` — added Blocking Rule #16.
- `rules/multi-level-rollup.md` — promoted raw-obs pattern, struck "catchers don't move levels" rationale per user correction.
- `rules/tracker-new-metric-checklist.md` — expanded from 5 to 7 places for percentile metrics.
- `skills/tracker-new-metric/SKILL.md` — new Q7(d) percentile branch with hand-dependence sub-question, 9-place checklist.
- `docs/plans/2026-05-23-catcher-pooled-percentile-port.md` — migration plan.
- `docs/plans/2026-05-23-br-pooled-percentile-port.md` — migration plan.

Sync commits: `4a2dc6ab` / `271c055b` / `59376c9c` / `6bdf8046` (first round) + `686df20c` / `67900cf9` / `f27ce4f1` / `cf1827fd` (after combo pre-compute landed).

## Verification recipe (run after backfill finishes)

```powershell
cd C:\Users\zbridger\bsb-wt-intangibles\intangibles
python -c "
from src.tracker_pins import load_tracker_bundle
for domain in ('OF', 'IF'):
    for year in (2022, 2023, 2024, 2025, 2026):
        bundle = load_tracker_bundle(domain, year)
        if bundle is None:
            print(f'{domain}/{year}: NO BUNDLE')
            continue
        keys = list(bundle.keys())
        per_level = [k for k in keys if not any(s in k for s in ('raw_', 'pooled_'))]
        raw_obs   = [k for k in keys if k.startswith('raw_')]
        single_yr = [k for k in keys if f'pooled_{year}_' in k]
        multi_yr  = [k for k in keys if 'pooled_' in k and '-' in k.split('pooled_')[1].split('_')[0]]
        print(f'{domain}/{year}: total={len(keys)}, per_level={len(per_level)}, '
              f'raw_obs={len(raw_obs)}, single_yr_combos={len(single_yr)}, '
              f'multi_yr_combos={len(multi_yr)}')
"
```

**Expected output per (domain, year):**

| Year | per_level | raw_obs | single_yr_combos | multi_yr_combos | Total |
|---|---|---|---|---|---|
| 2022 | 21 | 9 | 720 | **0** | ~750 |
| 2023 | 21 | 9 | 720 | **720** | ~1,470 |
| 2024 | 21 | 9 | 720 | **1,440** | ~2,190 |
| 2025 | 21 | 9 | 720 | **2,160** | ~2,910 |
| 2026 | 21 | 9 | 720 | **2,880** | ~3,630 |

**If 2023+ shows multi_yr_combos=0 → the `f9cf0da2` fix didn't take. Re-pull and re-run.**

## Deploy + app verification (after pin verification green)

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$env:CONNECT_API_KEY = "<key>"
.\connect_pins_fielding\deploy.ps1
```

App test: open OF or IF tracker → pick `2025 + 2026` years + `AAA + AA + A+` levels + `Home`. Watch Connect logs.

**Success signal:**
```
[PIN] orgs_pooled(IF,years=2025-2026,combo=('aaa', 'aax', 'afa'),ha=0): SERVED FROM PIN
```

**Fallback signals (math correct but slower):**
```
[PIN] raw_obs(IF,seasons=[2025, 2026],ha=0): SERVED FROM PIN
```
→ Means combo key not present (re-pin issue). App falls through to raw_obs compute (1-2 sec). Still works.

## Known potential issues

1. **Pin job killed mid-run** → restart with `python scripts/pin_fielding_tracker_seasons.py`. The CLI processes years in ascending order (2022 → 2023 → 2024 → 2025 → 2026), so multi-year ranges only work if prior years finished first. If a year died mid-run, that year's bundle is partially written (per-level + raw_obs done, combo keys partial). Re-running that year overwrites cleanly.

2. **TCP drops** during raw_obs queries → auto-retry handles via `database-tcp-retry.md` pattern. Watch for `[DB-RETRY] attempt 3/3` followed by error — that means retries exhausted. Wait for network, restart.

3. **Per-level query times slower than estimated** → IF 2022/2023 took 13-17 min per H/A on per-level fielders alone (vs ~6 min estimated). Larger raw_tdm volumes (200K-365K rows). Math is right, build time is long. Total backfill maybe 12-18 hours instead of original 10-12 estimate. Overnight should still complete.

4. **Multi-year combo skip for years 2023+** → means `_load_prior_year_raw_obs` failed. Should be fixed by `f9cf0da2`. If user sees `SKIP multi-year range [YYYY, YYYY]: cannot load prior year YYYY pin` for years 2023+, pull again and verify the f9cf0da2 commit is on the work laptop. Diagnostic prints I added will surface WHY (bundle missing vs keys missing vs import error).

## Future work (after fielding deploy verified)

1. **Catcher port** — Arm P99, Exch P10, Pop2B P01, Pop3B P01, AugPop P01.
   Plan: `docs/plans/2026-05-23-catcher-pooled-percentile-port.md`.
   Mirrors fielding architecture exactly. Catcher keeps hand split on
   FRAMING metrics (real platoon effect) but skips hand split on the
   raw_obs pin for arm/pop/exch (hand-agnostic physical metrics).
   Same combo pre-compute pattern applies.

2. **BR port** — TopSpd P95, React P25, T22 P25, Split1 P25, Accel P75.
   Plan: `docs/plans/2026-05-23-br-pooled-percentile-port.md`.
   Same architecture. BR keeps hand split on LEAD metrics (pitcher-hand
   genuinely changes runner lead posture) but skips hand split on
   tracking percentile pin (hand-agnostic).

3. **For both ports** — IMPORTANT: when implementing `_load_prior_year_raw_obs`
   equivalents, do NOT copy the `if not _TRACKER_PINS_AVAILABLE: return None`
   check. That was the bug fixed by `f9cf0da2` — flag has two different
   meanings (module-importable vs app-time-pin-first-toggle) and the
   pin-load helper needs to ignore the app-time toggle. Add this as a
   hard rule when porting.

## Cross-references

- [[fielding-raw-obs-refactor-handoff]] — broader refactor story (May 22-23)
- `.claude/rules/pooled-percentile-pattern.md` — canonical pattern (updated May 23)
- `.claude/rules/multi-level-rollup.md` — Iron Rule for weighting + 2-tier architecture
- `.claude/rules/database-tcp-retry.md` — TCP retry pattern (worked during this session)
- `.claude/rules/tracker-parquet-pins.md` §10 (sparse-pin recovery) — references
  `_TRACKER_PINS_AVAILABLE = False` pattern that caused the f9cf0da2 bug
- `docs/plans/2026-05-23-catcher-pooled-percentile-port.md` — next port
- `docs/plans/2026-05-23-br-pooled-percentile-port.md` — second next port
