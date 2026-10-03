# Org KPI Aggregate Report — Design

**Goal:** Single PDF (7 pages) showing all 30 MLB orgs ranked across 6 domains, levels AAA/AA/A+/A combined. Answers "where does HOU rank in every metric at the full-season MiLB level?"

**Architecture:** New report module in `pd-goals/` (lives in PD Engine). Reuses org-level query patterns from existing KPI data modules across all 3 worktrees. One PDF, CLI delivery to Slack.

---

## PDF Layout

**Page size:** Landscape 11x8.5" (matches all existing KPI reports)

### Page 1 — Title Page
- Astros logo (centered, spinning coin style or static)
- "HOUSTON ASTROS"
- "MiLB Org Rankings"
- Date range (e.g., "2026 Season through Apr 11")
- Levels included: "AAA | AA | A+ | A"
- "Houston Astros Player Development" footer

### Pages 2-7 — Domain Tables (one per page)

| Page | Domain | Sort Metric | Columns |
|------|--------|-------------|---------|
| 2 | Pitching | gcERA (asc) | Org, BF, FPinZ%, InZ%, R2K%, EW%, 2K Proj, K%, BB%, FB Velo, Whiff%, Proj, gcERA, gcPerf |
| 3 | Hitting | gcOBA (desc) | Org, PA, gcOBA, xwOBA, wRC+, K%, BB%, Avg EV, Dmg%, Ctct%, ZCtct%, ZSw%, OSw%, Whiff%, PullAir%, BS |
| 4 | OF | UseReact (asc) | Org, Plays, CP, ReRad, React, UseRe, ReAccRad, AcCD, AcCU, TopSpd, ExchOF, Arm, OAA, PAA/EO |
| 5 | IF | React (asc) | Org, Plays, CP, ReRad, React, AcCD, AcCU, TopSpd, Exch, Arm, OAA, PAA/EO |
| 6 | BR | SB (desc) | Org, Bases On, SB, CS, 1-3, 2-H, PL 1B, SL 1B, PL 2B, SL 2B |
| 7 | Catcher | NetK (desc) | Org, Pitches, CS%, NetK, Pop 2B, Arm, Exch, SurPP, AugPop, Depth, E Stl, Stl, Mid, Loss, B Loss, R2K%, FrmRAA, BlkRAA |

### Table Layout Per Page
- Page header: domain name + "MiLB Org Rankings (AAA/AA/A+/A)" + date range
- 30 rows (one per org), sorted by primary metric
- "Org" column replaces "Player" — 3-letter abbreviation (HOU, NYY, LAD, etc.)
- HOU row highlighted (bold or navy background)
- All metric cells colored by rank position among 30 orgs:
  - Rank 1 = deepest green, Rank 30 = deepest red (for higher_is_better=True)
  - Inverted for higher_is_better=False (Rank 1 green = lowest value)
  - Same red-white-green gradient as existing KPI percentile coloring
- Column widths tight to fit 14-18 cols in landscape

### Percentile Coloring (Org Rank)
```
rank_pctile = (30 - rank) / 29  # rank 1 → 1.0 (green), rank 30 → 0.0 (red)
# For higher_is_better=False metrics, flip: rank_pctile = (rank - 1) / 29
color = percentile_to_color(rank_pctile)
```
Uses the same `percentile_to_color()` function from existing KPI reports.

---

## Data Architecture

### Query Strategy
Each domain's org data query already exists in the respective KPI data modules. The org-level queries aggregate all players at a level into one row per org per game date, then roll up.

For this report, we aggregate across AAA+AA+A++A (4 levels combined) per org:
- **Rate metrics** (K%, BB%, FPinZ%, etc.): weighted average by denominator (PA, pitches, plays)
- **Counting metrics** (SB, OAA, NetK): sum across levels
- **Tracking metrics** (TopSpd, React, Arm): weighted average by play count

### Source Queries
Rather than importing from 3 different worktrees, we write **6 self-contained query functions** in a new `pd-goals/src/org_kpi_data.py`. These mirror the existing org-level queries but combine 4 levels:

```python
def get_pitching_org_stats(season, end_date, engine) -> pd.DataFrame
def get_hitting_org_stats(season, end_date, engine) -> pd.DataFrame
def get_of_org_stats(season, end_date, engine) -> pd.DataFrame
def get_if_org_stats(season, end_date, engine) -> pd.DataFrame
def get_br_org_stats(season, end_date, engine) -> pd.DataFrame
def get_catcher_org_stats(season, end_date, engine) -> pd.DataFrame
```

Each returns a DataFrame with 30 rows (one per org), columns matching the domain's table spec.

### Org Identification
Uses `MLBAM.Teams` joined on `batting_team_id` (hitting/BR) or `fielding_team_id` (pitching/fielding/catcher), season-aware. Same pattern as existing tracker_data.py org mapping.

---

## File Structure

```
pd-goals/
  src/
    org_kpi_data.py      # 6 query functions (one per domain)
    org_kpi_report.py     # PDF generation (title page + 6 domain pages)
  scripts/
    generate_org_kpi.py   # CLI: --end, --deliver, --logic-app-url
```

### CLI Interface
```bash
python pd-goals/scripts/generate_org_kpi.py --end 2026-04-11
python pd-goals/scripts/generate_org_kpi.py --end 2026-04-11 --deliver --logic-app-url URL
```

### Delivery
- Placeholder channel: `org_pd` (will update when user confirms)
- Single PDF per run (not per-level — all levels combined)

---

## Higher/Lower Is Better Reference

### Pitching
| Metric | Direction |
|--------|-----------|
| FPinZ%, InZ%, R2K%, EW%, 2K Proj, K%, FB Velo, Whiff%, Proj, gcPerf | Higher = better |
| BB%, gcERA | Lower = better |

### Hitting
| Metric | Direction |
|--------|-----------|
| gcOBA, xwOBA, wRC+, BB%, Avg EV, Dmg%, Ctct%, ZCtct%, ZSw%, PullAir%, BS | Higher = better |
| K%, OSw%, Whiff% | Lower = better |

### OF
| Metric | Direction |
|--------|-----------|
| AcCD, AcCU, TopSpd, Arm, OAA, PAA/EO | Higher = better |
| ReRad, React, UseRe, ReAccRad, ExchOF | Lower = better |

### IF
| Metric | Direction |
|--------|-----------|
| AcCD, AcCU, TopSpd, Arm, OAA, PAA/EO | Higher = better |
| ReRad, React, Exch | Lower = better |

### BR
| Metric | Direction |
|--------|-----------|
| SB, 1-3, 2-H, PL 1B, SL 1B, PL 2B, SL 2B | Higher = better |
| CS | Lower = better |

### Catcher
| Metric | Direction |
|--------|-----------|
| CS%, NetK, Arm, Depth, E Stl, Stl, Mid, R2K%, FrmRAA, BlkRAA | Higher = better |
| Pop 2B, Exch, SurPP, AugPop, Loss, B Loss | Lower = better |
