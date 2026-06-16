---
name: ullola-walk-analysis-shipped
description: Pitcher walk-pile-up + lose-the-K-zone analysis (originally Miguel Ullola AGM one-off May 19 2026, parameterized May 25 2026 with --gc-id flag). 3-cut pooled multi-season PDF/CSV on feature/pd-goals. Reusable for ANY pitcher via CLI swap.
metadata: 
  node_type: memory
  type: project
  originSessionId: eac6b7a7-0e38-4018-9a7b-2d54cdebfb30
---

# Pitcher Walk Analysis — shipped 2026-05-19 (Ullola), parameterized 2026-05-25

AGM (Gavin Dickey) one-off: "where do walks pile up by inning and pitch
count — when does he lose the K zone?" Originally built for Miguel Ullola
on `feature/pd-goals`. Shipped + iterated through user feedback to final
plain-tables version (`365bf4ab`). **Parameterized May 25 2026** to take
any pitcher's gc_id via CLI flag — no more script-copy required.

User signoffs:
- Ullola (May 19): "its a masterpiece."
- Ogando (May 25): "awesom rna it" — pulled on work laptop after `git pull`.

## Files

| Role | Path |
|---|---|
| Script + PDF/CSV | `pd-goals/scripts/generate_ullola_walk_analysis.py` |

CLI-only, not deployed to Connect. **Script name kept for git history
continuity** even though it's now reusable for any pitcher — rename to
`generate_pitcher_walk_analysis.py` if a third+ pitcher comes through
and the misleading name actually trips someone up.

## What it does

One pitcher (Miguel Ullola, gc_id 155659), pooled across N seasons,
three cuts on a 1-page portrait PDF + a stacked CSV:

1. **By Outing Inning** — Nth distinct inning HE pitched (relief-aware,
   NOT actual game inning)
2. **By Pitch Count in Outing** — 1-15, 16-30, 31-45, 46-60, 61-75, 76-90, 91+
3. **By Times Through Order** — 1, 2, 3, 4+

Per-bucket columns: `TBF | BB | K | BB% | K% | Zone% | FPinZ% | FPS% | CSW% | Pit/PA`.
Plain tables, bold TOTAL row, NO cell coloring (user explicit direction).

## Run

```powershell
# Default = Miguel Ullola (back-compat with original one-off):
python pd-goals/scripts/generate_ullola_walk_analysis.py                  # 2026 default
python pd-goals/scripts/generate_ullola_walk_analysis.py --season 2024
python pd-goals/scripts/generate_ullola_walk_analysis.py --seasons 2023-2026

# ANY pitcher via --gc-id (name auto-resolved from Astros.Players):
python pd-goals/scripts/generate_ullola_walk_analysis.py --gc-id 212631                       # Joan Ogando 2026
python pd-goals/scripts/generate_ullola_walk_analysis.py --gc-id 212631 --seasons 2023-2026

# Override the display name if needed:
python pd-goals/scripts/generate_ullola_walk_analysis.py --gc-id 212631 --player-name "Joan Ogando"
```

Output filenames slugged from the resolved name:
- `pd-goals/output/miguel_ullola_walk_analysis_<range>.{csv,pdf}` (Ullola default)
- `pd-goals/output/joan_ogando_walk_analysis_<range>.{csv,pdf}` (Ogando via `--gc-id 212631`)

gc_id lookup: `pd-goals/data/slack_channels.csv` (e.g. Ogando = 212631).

## Pooled semantics (BLOCKING for future adaptations)

Multi-season runs **pool all selected seasons into one set of aggregates**.
2023-2026 → ONE PDF, ONE page, three tables, cumulative across all 4
years. NOT per-year side-by-side.

History: shipped a YoY-combined version first (3 pages with Year column
stacking 2023-2026). User: "ruined the fucking visuals" — they wanted
the same one-page layout, just pooled. Reverted in `da5806f6`. Lesson:
when multi-season is asked for, default to POOLED unless the user
explicitly says "compare year-over-year."

## Key methodology decisions

- **Outing Inning, not game inning.** Earlier ship used actual game
  inning — but Ullola has relieved in some years, so "Inn 7" meant
  different things across years. Fixed in same session to map
  sorted-unique innings per `sched_id` → 1, 2, 3, ... so "Outing Inn 1"
  is always his first frame regardless of when in the game he entered.
- **Zone%** = `AVG(called_strike_chance_mlb)` × 100. Continuous,
  not binary `(csc > 0.5)`. Per `gc2-metrics.md` canon.
- **BB% includes IBB** (FanGraphs canon — `ev.bb=1` on IBB rows).
  CSV also exposes `ubb_pct` for unintentional-only.
- **TBF gate** = `cur_event_id IS NOT NULL AND (cur_pa=1 OR cur_ibb=1)`.
  The OR clause is required — IBBs have `pa=0` per `db-columns.md`.
- **Pitch in Outing** = `groupby('sched_id').cumcount() + 1` after
  `ORDER BY game_pitch_number`. Correct for starters and relievers.
- **Multi-season pooled in SQL** via `WHERE sv.year IN ({inlined int list})`
  — pyodbc rejects tuple IN params per `pitfalls.md` so seasons are
  inlined as int literals (no injection risk since `_parse_seasons`
  bounds them to int).

## Reuse for ANY pitcher — no script copy needed (May 25 2026 update)

Original instructions said "copy the script, swap constants" — replaced
May 25 2026 by `--gc-id` + `--player-name` flags. Just run with the
target pitcher's gc_id:

```powershell
python pd-goals/scripts/generate_ullola_walk_analysis.py --gc-id <X>
```

The existing player-verification block at the top of `main()` resolves
the name from `Astros.Players` automatically and prints throws / birthdate /
ebis / mlbam for sanity check before running the heavy query.

`DEFAULT_GC_ID = 155659` / `DEFAULT_NAME = "Miguel Ullola"` constants
are kept ONLY for back-compat with the original `--season`-only
invocations. Don't edit them — pass the flag.

### When to actually fork the script

For a **different question entirely** (e.g. "where does he get hit
hardest by EV/LA", "swing/whiff breakdown by count"), the SQL skeleton
+ `_enrich` + per-bucket aggregation pattern carries over but the
per-bucket metric columns need swapping. In that case copy to a new
`generate_<question>_analysis.py`, keep the `--gc-id` parameterization,
and replace the metric definitions in `_agg_*` functions. The walk-
specific Zone% / FPinZ% / FPS% / CSW% / Pit/PA column set is unique
to "where do walks pile up."

For a similar question on **hitters** (zone swing breakdown by pitch
group × count state), the sibling already exists:
`barrelsville/scripts/hitter_whiff_analysis.py --batter <gc_id>`.

## Commit chain

| Commit | What |
|---|---|
| `d70e7298` | Initial ship — 3-cut PDF + CSV, single-season `--season` flag |
| `534b06e8` | Add player-identity verification (Astros.Players lookup) + scope summary |
| `e04866f2` | Add `--seasons 2023-2026` multi-year flag — first version produced one PDF per year |
| `8d641c44` | Outing-inning fix + YoY combined PDF (overshoot — user wanted pooled, not per-year) |
| `da5806f6` | REVERT — back to 1-page layout, multi-season POOLED into one set of aggregates |
| `365bf4ab` | Strip cell colors per user direction ("no colors plaese") |
| `f1ca9872` | (initial docs landing — `docs/one-offs/`, migrated to this memory file) |
| `55e5e1f5` | **May 25 2026 — `--gc-id` + `--player-name` flags; output filenames slugged from name; back-compat with Ullola defaults preserved.** Second concrete ask = Joan Ogando (gc_id 212631). |

## Future direction (UPDATED May 25 2026)

Original note: "wait for the second concrete ask to confirm the
abstraction is worth building." That happened — Joan Ogando. CLI
parameterized in `55e5e1f5`. Future runs are now zero-code: just pass
`--gc-id <X>`.

If a third+ pitcher comes through and the misleading filename
(`generate_ullola_*`) actually trips someone up, rename to
`generate_pitcher_walk_analysis.py` (single git mv + update this memory
file + the MEMORY.md index line).

## What NOT to do

- Don't ship a YoY combined-Year-column version when "multi-season" is
  requested. Default = pooled, single 1-page layout.
- Don't add cell coloring. User explicit direction: plain tables.
- Don't use game `inning` for the inning cut. Use `outing_inning`
  (sorted unique innings per sched_id mapped to 1-N).
- Don't filter to a single level by default. Junk levels excluded but
  multi-level games are pooled. Add `--level` if a future ask needs
  the slice.

## Cross-references

- `gc2-metrics.md` — Zone%/InZ%/FPinZ% canon (continuous AVG, never binary)
- `db-columns.md` — Events_View PA semantics + IBB pa=0 gotcha
- `pitch-codes.md` — BALL_CODES / WHIFF_CODES / CALLED_STRIKE_CODES
- `pitfalls.md` — pyodbc IN-tuple rejection (inline int literals instead)
- `slack-channels-sync.md` — gc_id source of truth
