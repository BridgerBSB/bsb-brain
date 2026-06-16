---
name: paa-eo-direction-status
description: "PAA/EO by Direction PDF batch — IN PROGRESS, user will iterate. Current state, files, fixes shipped, known UX gaps. Updated May 24 2026 with horizontal-year-totals + Players_Games eligibility + parity diag."
metadata: 
  node_type: memory
  type: project
  originSessionId: e797f50d-f6d3-49f7-b6fa-76dfdcb68f09
---

# PAA/EO by Direction — Per-Fielder PDF Batch (IN PROGRESS, May 22-24 2026)

**Why:** User wanted a one-off PDF batch modeled on the catcher framing
hexbin, showing each HOU MiLB fielder's PAA/EO across the 8 HawkEye
direction bins. Two batches: `--position OF` and `--position IF`.
Will be re-run multiple times.

**How to apply:** When the user asks to tweak/extend the direction PDF
or comes back after running it. The script is wired but UX details
are still being iterated.

---

## Files (feature/astros-intangibles)

| File | Role |
|---|---|
| `intangibles/src/paa_eo_direction_data.py` | Roster query + per-(fielder,year,pos,direction_txt) SQL + aggregation helpers + star_count tier function |
| `intangibles/scripts/generate_paa_eo_direction.py` | CLI + per-fielder PDF renderer (polar rose + summary table) |

Commits (chronological):
- `52a3bc93` — initial
- `f9e36ec1` — direction_txt fix (was hitting NULL direction_bin column)
- `8b51fd3b` — top-right year-totals box: 2-row vertical stack → 1-row horizontal right-anchored
- `4312d31a` — eligibility = Players_Games actual-appearance (mirrors KPI snapshot fix); drops POSITION_LK whitelist that excluded utility/catcher-plays-1B
- `17380578` — `scripts/diag_paa_eo_direction_parity.py` for parity verification

---

## CLI

```powershell
cd C:\Users\zbridger\bsb-wt-intangibles\intangibles
git pull
python scripts/generate_paa_eo_direction.py --position OF
python scripts/generate_paa_eo_direction.py --position IF
# default seasons = prev + current (2025 + 2026); override with --seasons 2025 2026
```

Output: `output/PAA_EO_Direction_{OF|IF}_{YYYY-YYYY}.pdf`.

---

## Per-page layout (landscape letter, one page per fielder)

- Header: name + primary position (multi-pos breakdown if applicable) + current PP_MASTER level + per-year PAA/EO totals top-right
- Body: N year-columns (one per selected season). Each column = polar
  rose (8 bins, height=n_plays, color=PAA/EO red→white→blue gradient
  matching `of_weekly_report.py:1431-1437`) + summary table beneath
  (Direction / n / PAA/EO / ★ stars)
- Star tiers: ★★★ ≥ +0.020, ★★ ≥ +0.005, ★ ≥ 0.000, blank = negative.
  Configurable via `STAR_TIERS` constant in data module.

Title page = cohort overview table sorted by current-year PAA/EO DESC.

---

## Methodology (matches user-supplied canonical SQL)

- **No Tier 1 gate** — PAA/EO uses ALL `Defense_Combined_By_Pos` rows
  per `fielding.md` "Cumulative value metrics" exception, matches GC2
- `paa_cal` + `expected_outs` additive across `(year × level × position)`
  per calibration table's `(pos_id, positional, season)` keys →
  cross-level pooling clean
- direction_bin = NULL plays counted in `n_plays_total` only; rose +
  table show `n_plays_tracked` separately
- Roster (POST May 24 2026): HOU MiLB-rostered (`EMPLOYEE_FLG=0`,
  `LEVELOFPLAY_LK IN ('3a','2a','1a','1f','r','ds')`, Alvaro inactive
  exclusion) **AND** actually played a target pos_id in any of the
  requested seasons (JOIN Players_Games). POSITION_LK whitelist
  DROPPED — utility players + catchers-who-play-1B now correctly
  included. The per-fielder rendering already filters DCBP by pos_id
  IN target group so a catcher's IF page only sums his 1B plays.

---

## Bugs fixed (chronological)

1. **"Only Going Back" rendering bug** (commit `f9e36ec1`, May 22).
   Initial SQL used `fd.direction_bin`, that column doesn't store
   the 0-7 integer — only NULL + some default-0. Every bin rendered
   at "Going Back" only. Fix: GROUP BY `fd.direction_txt` + map to
   0-7 in Python via `_DIR_TXT_TO_IDX`. Mirrors
   `of_weekly_report.py::_DIR_TXT_TO_IDX`.

2. **Top-right year-totals overlap** (commit `8b51fd3b`, May 24).
   Was: header at y=0.945 + per-year rows stacking at y=0.91, 0.88,
   0.85. 3+ seasons → year rows crashed into position line at
   y=0.905. Fix: single horizontal row right-anchored at y=0.94,
   cursor walks right-to-left. Most-recent year is rightmost on page.
   Format: `PAA/EO (year):  YYYY +X.XXX (N)  ·  YYYY +X.XXX (N)`.

3. **Eligibility whitelist dropping utility players** (commit
   `4312d31a`, May 24). `_ROSTER_QUERY` filtered by
   `POSITION_LK IN ('1B','2B','3B','SS','IF','UTL','UN')` for IF.
   Bush (`POSITION_LK='C'`) plays 1B regularly → missing from IF PDF.
   Same bug class as KPI snapshots (see `kpi-snapshot-fixes-shipped.md`
   eligibility fix `5ade27a7`). Fix: JOIN Players_Games for actual
   pos_id appearance in any of `seasons`. Currently MiLB-rostered
   still required. Drops POSITION_LK whitelist entirely.

---

## Parity diagnostic — `scripts/diag_paa_eo_direction_parity.py` (May 24)

Verifies direction PDF's per-fielder year totals match the canonical
no-direction PAA/EO query within tolerance. Greenlight script to run
before circulating the PDF.

```powershell
python intangibles/scripts/diag_paa_eo_direction_parity.py --position OF
python intangibles/scripts/diag_paa_eo_direction_parity.py --position IF
python intangibles/scripts/diag_paa_eo_direction_parity.py --position OF --tolerance 0.001
python intangibles/scripts/diag_paa_eo_direction_parity.py --position OF \
    --fielder-id 174203 --show-pass
```

Exit 0 = all rows within ±tolerance. Exit 1 = any row exceeds (printed
sorted by |Δ| desc). Default tolerance 0.005; expected actual |Δ|
typically <0.001 from per-direction AVG(offset) micro-approximation.
User will run **tonight** (May 24) as secondary task.

---

## Known open UX items (pending user decision after they re-run)

1. **Tables: one per rose vs one consolidated per page.** Current = one
   small 4-col table (Direction / n / PAA/EO / ★) under each rose
   column, so a 2-year page has two tables side-by-side. User said
   "if you'd rather have ONE consolidated table per page (Direction /
   2025 n / 2025 PAA/EO / 2025 ★ / 2026 n / 2026 PAA/EO / 2026 ★),
   one-line change in the morning." Wait for their call.
2. **Star tier thresholds** in `STAR_TIERS` (data module). User said
   "if star thresholds are off, ping me." Default: ★★★ ≥ +0.020,
   ★★ ≥ +0.005, ★ ≥ 0.000. Easy to retune.
3. **Per-position split.** Currently one page per fielder pools across
   all their positions for that year. If a utility infielder plays
   1B + 2B + SS in 2025, all those plays roll into one rose. Could
   add per-position pages if the pooled view masks position-specific
   tendencies. Not yet asked for.

---

## What NOT to do

- **Don't** revert to `fd.direction_bin` in the SQL. That column is the
  bug. Always use `fd.direction_txt` + `_DIR_TXT_TO_IDX` map.
- **Don't** add a Tier 1 gate to the SQL. PAA/EO is the no-gate
  metric per `fielding.md`.
- **Don't** assume coverage is universal. HawkEye `Fielder_Direction`
  is venue-dependent — opposing parks vary. `n_plays_tracked` /
  `n_plays_total` columns surface coverage on the page.

---

## Cross-references

- `.claude/rules/fielding.md` — PAA/EO no-gate rule
- `.claude/rules/tracking-schema.md` §HawkEye coverage caveat
- `intangibles/src/of_weekly_report.py:1384-1452` — canonical
  `_DIR_TXT_TO_IDX` map + direction rose visual language we mirror
- `intangibles/scripts/generate_catcher_framing_hexbin.py` — script
  structure template (header, page layout, delivery, title page)
