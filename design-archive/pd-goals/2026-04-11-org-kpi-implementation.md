# MiLB Org KPI Aggregate Report — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a 7-page PDF (title + 6 domain tables) showing all 30 MLB orgs ranked across Pitching/Hitting/OF/IF/BR/Catcher, levels AAA/AA/A+/A combined, with red-white-green rank coloring.

**Architecture:** Two new modules in `pd-goals/src/` — `org_kpi_data.py` (6 query functions, one per domain) and `org_kpi_report.py` (PDF generation with title page + 6 table pages). CLI script for batch generation and Slack delivery. Queries mirror the existing org-level patterns from pitcher_kpi_data.py, hitter_kpi_data.py, of/if/br/c_kpi_data.py but combine 4 levels into one row per org.

**Tech Stack:** Python, pyodbc/SQLAlchemy, pandas, matplotlib, PdfPages, plottable (optional), same stack as all existing reports.

**Reference files (READ BEFORE CODING):**
- Pitcher org query: `C:/Users/Owner/bsb-wt-bullpen/bullpen-report/src/pitcher_kpi_data.py` — `_ORG_DAILY_QUERY`
- Hitter org query: `C:/Users/Owner/bsb-wt-hitting/barrelsville/src/hitter_kpi_data.py` — `_ORG_DAILY_QUERY`
- OF org query: `C:/Users/Owner/bsb-wt-intangibles/intangibles/src/of_kpi_data.py` — `_ORG_DAILY_TRACKING_QUERY` + `_ORG_DAILY_DCBP_QUERY`
- IF org query: `C:/Users/Owner/bsb-wt-intangibles/intangibles/src/if_kpi_data.py` — same pattern as OF
- BR org query: `C:/Users/Owner/bsb-wt-intangibles/intangibles/src/br_kpi_data.py` — `_ORG_DAILY_FT3_S2H_QUERY`
- Catcher org query: `C:/Users/Owner/bsb-wt-intangibles/intangibles/src/c_kpi_data.py` — `_ORG_MONTHLY_RAW_NETK_QUERY`
- PDF table rendering: `C:/Users/Owner/bsb-wt-bullpen/bullpen-report/src/pitcher_kpi_report.py` — `_draw_player_table()`, `percentile_to_color()`
- PDF cover page: same file — `_draw_level_cover_page()`
- Database connection: `pd-goals/src/database.py` — `get_engine()`, `sched_type_filter()`

---

### Task 1: Create `org_kpi_data.py` — Pitching + Hitting queries

**Files:**
- Create: `pd-goals/src/org_kpi_data.py`

**Step 1: Create the file with shared constants and DB setup**

```python
"""
Org KPI Data — MiLB Org Rankings
=================================
6 query functions returning 30-row DataFrames (one per org),
aggregated across AAA/AA/A+/A for the full season.

Reference implementations:
- Pitcher: bullpen-report/src/pitcher_kpi_data.py (_ORG_DAILY_QUERY)
- Hitter: barrelsville/src/hitter_kpi_data.py (_ORG_DAILY_QUERY)
- OF/IF: intangibles/src/of_kpi_data.py, if_kpi_data.py
- BR: intangibles/src/br_kpi_data.py
- Catcher: intangibles/src/c_kpi_data.py
"""
```

Contains:
- `_LEVELS = ('aaa', 'aax', 'afa', 'afx')` — the 4 MiLB levels
- `_build_multi_level_filter(alias)` — returns `"(sv.level_code IN ('aaa','aax','afa','afx'))"` 
- `_SCHED_FILTER = "sv.sched_type = 'R'"` — regular season only
- `_JUNK_LEVELS_SQL` — exclude junk codes (same as database.py)
- Shared `_run_query(sql, params, engine)` helper

Write the pitching query function `get_pitching_org_stats(season, end_date, engine)`:
- Copy the `_ORG_DAILY_QUERY` from pitcher_kpi_data.py EXACTLY
- Change `{level_filter}` to the multi-level filter (all 4 levels)
- Add `AND sv.sched_date <= :end_date` to support partial-season
- Aggregate: GROUP BY org (not org + game_date) for season totals
- For rate metrics: use weighted aggregation (e.g., `SUM(ew_numer) / NULLIF(SUM(ew_denom), 0)`)
- For average metrics: use `AVG()` across all pitches
- Return: DataFrame with columns matching TABLE_COLS from design doc
- Add PA-level subquery for K%, BB%, BF (same pattern as pitcher_kpi_data.py pa_kbb)
- Add gcERA computation (matches `_get_league_hr_rate_gc2()` pattern from tracker_data.py)
- Add gcPerf computation (run value formula from gc2-metrics.md)

Write the hitting query function `get_hitting_org_stats(season, end_date, engine)`:
- Copy the `_ORG_DAILY_QUERY` from hitter_kpi_data.py EXACTLY
- Same multi-level + end_date changes
- Aggregate to season totals per org
- xwOBA: PA-weighted (SUM numer / SUM denom), NOT mean of daily ratios
- Damage: computed from BIP-level sigmoid formula
- wRC+: requires league environment query (`_get_league_woba_env()`)
- gcOBA: separate query (matches gc2-metrics.md formula)
- Return: DataFrame with all 16 columns

**Org join patterns (CRITICAL — copy exactly):**
- Pitching: `JOIN mlbam.teams mt ON mt.team_id = CASE WHEN ev.top_of_inning = 1 THEN sv.home_team_mlbam_id ELSE sv.away_team_mlbam_id END AND mt.season = sv.year`
- Hitting: `JOIN mlbam.teams mt ON mt.team_id = CASE WHEN ev.top_of_inning = 1 THEN sv.away_team_mlbam_id ELSE sv.home_team_mlbam_id END AND mt.season = sv.year`

**Step 2: Verify syntax**

Run: `python -c "import ast; ast.parse(open('pd-goals/src/org_kpi_data.py', encoding='utf-8').read()); print('OK')"`

**Step 3: Commit**

```bash
git add pd-goals/src/org_kpi_data.py
git commit -m "feat(pd-engine): org KPI data module — pitching + hitting queries"
```

---

### Task 2: Add OF, IF, BR, Catcher queries to `org_kpi_data.py`

**Files:**
- Modify: `pd-goals/src/org_kpi_data.py`

**Step 1: Add `get_of_org_stats()`**

Two queries merged (same pattern as of_kpi_data.py):
- Tracking query: `Tracking_Defensive_Metrics` with Tier 1 gate, `pos_id IN (7,8,9)`, `fielding_team_id` join
- Value query: `Defense_Combined_By_Pos` for OAA/PAA/EO, same pos_ids
- Merge on org, aggregate to season totals
- Tracking metrics: AVG weighted by play count
- OAA/PAA: SUM across all plays
- Arm: filtered to 75-108 range (OF floor)
- Exchange: filtered to >= 0.4 AND arm >= 75

**Step 2: Add `get_if_org_stats()`**

Same as OF but:
- `pos_id IN (3, 4, 5, 6)`
- Arm floor = 70 (not 75)
- Exchange uses `exchange_dp` column (not `exchange`)
- No `useful_reaction` or `reaction_accuracy_radius` columns

**Step 3: Add `get_br_org_stats()`**

From br_kpi_data.py:
- SB query: `Events_StolenBases` gated by `Pitches_Baserunner_Leads` (runner_going=1, next_base_open=1) — see sb-gate-fix-apr10.md
- 1-3/2-H: `Events_View` advancement logic (copy UNION ALL pattern from `_ORG_DAILY_FT3_S2H_QUERY`)
- Lead lengths: `Astros.Pitches_Baserunner_Leads` AVG per org
- Batting team join: `CASE WHEN top_of_inning THEN away ELSE home`
- Aggregate: SB/CS = SUM, 1-3/2-H = SUM(success)/SUM(opps) * 100, leads = AVG

**Step 4: Add `get_catcher_org_stats()`**

From c_kpi_data.py:
- NetK: cumulative raw framing credits from `_ORG_MONTHLY_RAW_NETK_QUERY` pattern
- Pop time, arm, exchange: from `Tracking_Defensive_Metrics` catcher positions
- SurPP: `passed_pitches - x_passed_pitches` from `CatcherDefense_Blocking`
- Framing buckets (E Stl, Stl, Mid, Loss, B Loss): from `CatcherDefense_Framing`
- R2K%: from Pitches_View (pitcher metric but attributed to catcher's org)
- Fielding team join: `mt.team_id = ev.fielding_team_id`

**Step 5: Verify all 6 functions parse**

Run: `python -c "import ast; ast.parse(open('pd-goals/src/org_kpi_data.py', encoding='utf-8').read()); print('OK')"`

**Step 6: Commit**

```bash
git add pd-goals/src/org_kpi_data.py
git commit -m "feat(pd-engine): org KPI data — OF, IF, BR, catcher queries"
```

---

### Task 3: Create `org_kpi_report.py` — PDF rendering

**Files:**
- Create: `pd-goals/src/org_kpi_report.py`

**Step 1: Create file with constants and shared rendering functions**

Copy these EXACTLY from pitcher_kpi_report.py:
- `_PAGE_W, _PAGE_H = 11, 8.5`
- `_DPI = 100`
- `_NAVY = "#002D62"`
- `_ORANGE = "#EB6E1F"`
- `percentile_to_color()` function (red-white-green gradient)
- `_format_value()` function (str/int/pct1/f1/f2/f3 formatting)
- `_load_logo()` and `_place_logo()` helpers

**Step 2: Define TABLE_COLS for all 6 domains**

```python
# Each tuple: (key, display_label, format_spec, higher_is_better)
PITCHING_COLS = [
    ("org", "Org", "str", None),
    ("bf", "BF", "int", None),
    ("fpinz_pct", "FPinZ%", "pct1", True),
    ("inz_pct", "InZ%", "pct1", True),
    ("r2k_pct", "R2K%", "pct1", True),
    ("ew_pct", "EW%", "pct1", True),
    ("proj_2k", "2K Proj", "f1", True),
    ("k_pct", "K%", "pct1", True),
    ("bb_pct", "BB%", "pct1", False),
    ("fb_velo", "FB Velo", "f1", True),
    ("whiff_pct", "Whiff%", "pct1", True),
    ("proj", "Proj", "f1", True),
    ("gc_era", "gcERA", "f2", False),
    ("gc_perf", "gcPerf", "f1", True),
]
# ... same for HITTING_COLS, OF_COLS, IF_COLS, BR_COLS, CATCHER_COLS
```

**Step 3: Write `_draw_title_page(pdf, season, end_date)`**

- Astros logo centered (base64 from assets/astros_logo.png)
- "HOUSTON ASTROS" — 32px bold navy
- "MiLB Org Rankings" — 24px bold navy
- Date: f"{season} Season through {end_date}" — 16px grey
- "AAA | AA | A+ | A" — 14px grey
- "Houston Astros Player Development" — 12px footer

**Step 4: Write `_draw_domain_page(pdf, domain_name, df, col_defs, sort_col, sort_asc)`**

- Header bar: navy rect at top with domain name + "MiLB Org Rankings"
- Sort df by sort_col (ascending or descending)
- Compute rank per metric: `df[f'{col}_rank'] = df[col].rank(ascending=ascending)`
- Convert rank to percentile: `rank_pctile = (30 - rank) / 29` (or inverted for lower-is-better)
- Draw 30-row table using the existing `_draw_player_table()` pattern but:
  - "Org" column instead of "Player" — 3-letter abbreviation, bold
  - HOU row: bold text or light navy background tint
  - All metric cells colored by rank percentile
- Org column width: 0.06 (shorter than Player name column)
- Volume column (BF/PA/Plays/Pitches/Bases On): 0.05, no coloring
- Metric columns: equal split of remaining width

**Step 5: Write `generate_org_kpi_report(season, end_date, engine)` — main entry point**

```python
def generate_org_kpi_report(season, end_date, engine=None) -> bytes:
    """Generate the 7-page org KPI PDF. Returns PDF bytes."""
    if engine is None:
        engine = get_engine()
    
    buf = BytesIO()
    with PdfPages(buf) as pdf:
        _draw_title_page(pdf, season, end_date)
        
        # Page 2: Pitching
        pitch_df = get_pitching_org_stats(season, end_date, engine)
        _draw_domain_page(pdf, "Pitching", pitch_df, PITCHING_COLS, "gc_era", sort_asc=True)
        
        # Page 3: Hitting
        hit_df = get_hitting_org_stats(season, end_date, engine)
        _draw_domain_page(pdf, "Hitting", hit_df, HITTING_COLS, "gcoba", sort_asc=False)
        
        # ... OF, IF, BR, Catcher
    
    return buf.getvalue()
```

**Step 6: Verify syntax**

Run: `python -c "import ast; ast.parse(open('pd-goals/src/org_kpi_report.py', encoding='utf-8').read()); print('OK')"`

**Step 7: Commit**

```bash
git add pd-goals/src/org_kpi_report.py
git commit -m "feat(pd-engine): org KPI report — PDF rendering (title + 6 domain pages)"
```

---

### Task 4: Create CLI script `generate_org_kpi.py`

**Files:**
- Create: `pd-goals/scripts/generate_org_kpi.py`

**Step 1: Write CLI script**

Follow the exact pattern from `pd-goals/scripts/generate_goals_batch.py` and `bullpen-report/scripts/generate_pitcher_kpi_report.py`:

```python
#!/usr/bin/env python3
"""
Org KPI Aggregate Report — CLI
================================
Generate 7-page PDF with all 30 MLB orgs ranked across 6 domains.

Usage:
    python pd-goals/scripts/generate_org_kpi.py --end 2026-04-11
    python pd-goals/scripts/generate_org_kpi.py --end 2026-04-11 --deliver --logic-app-url URL
"""

import argparse
import os
import sys
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent.parent))

from src.org_kpi_report import generate_org_kpi_report
from src.deliver import send_reports_via_logic_app


def main():
    parser = argparse.ArgumentParser(description="Generate Org KPI Aggregate Report")
    parser.add_argument("--end", type=str, required=True, help="End date (YYYY-MM-DD)")
    parser.add_argument("--season", type=int, default=None, help="Season year (default: from --end)")
    parser.add_argument("--output", type=str, default="reports/org_kpi", help="Output directory")
    parser.add_argument("--deliver", action="store_true", help="Deliver to Slack via Logic App")
    parser.add_argument("--logic-app-url", type=str, default=None, help="Logic App URL")
    args = parser.parse_args()

    end_date = datetime.strptime(args.end, "%Y-%m-%d")
    season = args.season or end_date.year

    print(f"\n{'='*60}")
    print(f"  Org KPI Aggregate Report")
    print(f"  Season: {season}  |  Through: {args.end}")
    print(f"  Levels: AAA, AA, A+, A")
    print(f"{'='*60}\n")

    pdf_bytes = generate_org_kpi_report(season, end_date)

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    filename = f"Org_KPI_{args.end}.pdf"
    pdf_path = str(output_dir / filename)
    with open(pdf_path, "wb") as f:
        f.write(pdf_bytes)
    print(f"  Saved: {pdf_path}")

    if args.deliver:
        logic_app_url = args.logic_app_url or os.environ.get("LOGIC_APP_URL")
        if not logic_app_url:
            print("  ERROR: --logic-app-url or LOGIC_APP_URL required")
            sys.exit(1)
        print(f"  Delivering to org_pd channel...")
        send_reports_via_logic_app([pdf_path], logic_app_url, channel_col='channel_id')

    print("\nDone!")


if __name__ == "__main__":
    main()
```

**Step 2: Verify syntax**

Run: `python -c "import ast; ast.parse(open('pd-goals/scripts/generate_org_kpi.py', encoding='utf-8').read()); print('OK')"`

**Step 3: Update manifest.json**

Add `"scripts/generate_org_kpi.py": {"checksum": ""}` to files section.

**Step 4: Commit**

```bash
git add pd-goals/scripts/generate_org_kpi.py pd-goals/manifest.json
git commit -m "feat(pd-engine): org KPI CLI script + manifest update"
```

---

### Task 5: Test end-to-end on work laptop

**Step 1: Pull and run**

```bash
git pull origin feature/pd-goals
cd pd-goals
python scripts/generate_org_kpi.py --end 2026-04-11
```

**Step 2: Verify PDF**

Open `reports/org_kpi/Org_KPI_2026-04-11.pdf` and check:
- Title page renders correctly
- All 6 domain pages have 30 org rows
- HOU row is highlighted
- Cells are colored red-white-green by rank
- Sort order is correct per domain
- No missing data or NaN display issues

**Step 3: Fix any issues, commit, push**

---

## File Inventory

| File | Action | Lines (est.) |
|------|--------|-------------|
| `pd-goals/src/org_kpi_data.py` | CREATE | ~800 (6 query functions) |
| `pd-goals/src/org_kpi_report.py` | CREATE | ~500 (title page + 6 domain pages) |
| `pd-goals/scripts/generate_org_kpi.py` | CREATE | ~80 (CLI) |
| `pd-goals/manifest.json` | MODIFY | +1 line |

**Total: ~1,380 new lines across 3 files + 1 manifest update**
