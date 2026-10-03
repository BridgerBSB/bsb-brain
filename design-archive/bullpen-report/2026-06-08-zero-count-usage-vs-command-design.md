# 0-0 & 0/1 Usage vs. Command — Batch MiLB PDF (Design)

**Date:** 2026-06-08
**Worktree:** `bsb-wt-bullpen` / `feature/bullpen-reports` (Arm Farm)
**Requested by:** DJ Engle (via Zac)

## Purpose

DJ's coaching question: **"On the first pitch (and in 0/1-strike counts), are
our pitchers throwing the pitch they actually command best in the zone — or
something they locate worse?"**

Put **usage** next to **command** per pitch type, by count bucket, and flag
where they don't align ("are we throwing the right pitch").

## Scope / pool

Reuses the **exact** `count_usage_data._COUNT_USAGE_QUERY` scope:

- HOU org pitchers, currently rostered **FCL → AAA** per `MLB_eBis.PP_MASTER`
  (`ORG_LK='hou'`, `EMPLOYEE_FLG=0`, `POSITION_LK IN ('RHS','RHR','LHS','LHR','TWP','SHS','P')`,
  active status, `LEVELOFPLAY_LK <> 'ml'`).
- Levels `aaa, aax, afa, afx, rok` (MLB + DSL + junk excluded via `_build_level_filter`).
- **2026 R season only** (`sched_type='R'`, `YEAR(sched_date)=:season`).
- All of a pitcher's pitches **pooled across levels** (callup/demote/rehab) into one page.
- `pitch_id > 0`, `ignore_flag = 0`, non-null `pitch_type` / `balls_before` / `strikes_before`.

## Metrics (from DJ's GC2 SQL — ground truth)

- **InZ%** = `avg(called_strike_chance_mlb)` (ABS/CSC probability, not binary).
- **0-0 bucket** = `balls_before=0 AND strikes_before=0` (first pitch).
- **0/1 bucket** = `strikes_before IN (0,1)` (zero-or-one **strike**, any ball count — NOT the 0-1 count).
- **Usage%** = pitch-type count ÷ total pitches in that bucket.
- **Eligibility gate:** a pitch type appears only if its **total 2026 pitch count ≥ 30** (overall, across all counts).
- No bat-side split (LHH + RHH combined) for v1.

## Page layout (one page per pitcher)

Spitting image of postgame zones (`_draw_pa_zone`): plain-white ABS-tone strike
zone (`_SZ_*` bounds), home plate pentagon, pitcher's-POV `plate_x` flipped,
real-size dots colored by `PITCH_TYPE_COLORS`.

```
[ navy header: F. Last  ·  Level  ·  Throws  ·  2026  ·  N pitches ]

0-0 COUNT (FIRST PITCH)
[zoneFF][zoneSL][zoneCH]...(one mini-zone per eligible pitch, ordered by usage)   | Ideal Order (InZ%)
 Usage% / InZ% above each                                                          | Actual Order (Usage%)
                                                                                   | ⚠ misalignment flag

0 OR 1 STRIKE (0/1)
[zoneFF][zoneSL][zoneCH]...                                                         | Ideal Order (InZ%)
                                                                                   | Actual Order (Usage%)
```

- **Mini-zones:** one per eligible pitch type, ordered left→right by usage% desc.
- **Side tables:** *Ideal Order* = pitches ranked by InZ% desc (what you should throw most);
  *Actual Order* = ranked by Usage% desc.
- **Highlight:** the #1-usage pitch is flagged **red** if it is not also the
  #1-InZ pitch; the #1-InZ pitch flagged **green** ("locate-best — throw more").
  Per-row rank-delta coloring shows over-/under-thrown pitches.

## Files

- `src/zero_count_data.py` — sibling of `count_usage_data.py`; same WHERE scope,
  adds `called_strike_chance_mlb`, `-plate_x AS plate_x`, `plate_z`, `pitch_result_id`.
  `fetch_zero_count_rows(season)` + `aggregate_pitcher_zero_count(df, pid, min_pitches=30)`.
- `src/zero_count_report.py` — `generate_zero_count_page(pdf, bundle, season)`.
- `scripts/generate_zero_count.py` — CLI (`--season`, `--pitcher`, `--min-pitches 30`,
  `--individual`, `--out`). Mirrors `generate_count_usage.py`. **No delivery in v1.**

## v1 limits / phase 2

- v1: batch PDF to `output/zero_count/`, no Slack, no bat-side split.
- Phase 2 (future): fold into Arm Farm "displays" (replace daily tracker), mirroring
  the Barrelsville postgame page-2 approach.

## Weekly mode + later changes (Jun 16 2026 — SHIPPED, user-iterated)

> Canonical live state: `memory/zero-count-report-status.md`. Summary here:

- **`--weekly`** week-vs-YTD mode + **`--last-week`** (only pitchers who threw in
  the trailing-7d window; `--week-ending` sets the end). Cover page +
  Overall/RHH/LHH per pitcher. Delivers (`--deliver`, `--logic-app-url` or
  `LOGIC_APP_URL` env) to `#weekly-iz-vs-usg` + `weekly-player-updates`. Wired
  into `run_monday.ps1` (`--weekly --last-week`).
- **Per-bucket eligibility gate** `BUCKET_MIN_PITCHES={"00":15,"01":30}` (in-bucket
  season count). `min_pitches=None` → per-bucket; int overrides both.
- **Roster scope**: batch gate no longer pitcher-only — any current HOU-org MiLB
  player clearing the gate shows; released/non-HOU dropped via ORG_LK + status.
- **Cover** (`build_cover_figure`): square logo, title, dates/season, color KEY.
- **Coloring** (`_week_assessment`/`_line_color`, top-2 order-sensitive): RED needs
  3+ pitches (2 caps yellow, <2 neutral). Week line green=ideal / yellow=located-
  best-this-week / red=neither; summary green if week usage matches week-iZ OR
  ideal. Two-lens by design (yellow line can pair with green sentence).
- Table + zones ordered by season iZ% desc.
