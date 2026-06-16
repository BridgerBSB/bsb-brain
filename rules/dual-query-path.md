---
paths:
  - "**/src/*.py"
---

# Dual Query Path Rule — BLOCKING

When ANY project has separate CLI/PDF and Streamlit app query paths, BOTH MUST stay in sync.

## Known Dual-Path Files

| Project | CLI/PDF Query | App Query | Status |
|---------|--------------|-----------|--------|
| Arm Farm (pitcher) | `postgame_data.py::get_game_pitches()` | `postgame_app_data.py::get_game_pitches_for_app()` | SYNCED |
| Barrelsville (hitting) | `postgame_data.py::get_game_pitches()` | `postgame_data.py::get_game_pitches_for_app()` | SYNCED |

## Single-Path Files (safe)

| Project | Data Module | Notes |
|---------|------------|-------|
| Intangibles BR | `br_data.py` | `br_app_data.py` only has sidebar queries |
| Intangibles Catcher | `catcher_data.py` | `catcher_app_data.py` only has sidebar queries |
| Intangibles OF | `of_data.py` | Single data path |

## Rules
1. When adding a column, JOIN, or filter to ANY pitch query, ALWAYS check if a parallel query exists and update it too
2. When creating a new `*_app_data.py` file, NEVER copy-paste SQL and diverge. Either reuse the same function or add `# MUST STAY IN SYNC` comment
3. Before any deploy, diff the SELECT columns of both queries

## Columns That Caused Silent Failures
`strikes_after` (R2K% = 0%), `stuffrelvelloc_grade_2080` (Loc Grade = NaN), `hit_exit_speed < 125` cap (pBarrel inflated), `sv.league` (DSL/FCL broken), `mlbam_league` (wOBA defaults)
