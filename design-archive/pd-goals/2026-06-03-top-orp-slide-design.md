# Top-25 ORP Bats Slide — Amateur-vs-Pro Deck Addition

**Date:** 2026-06-03
**Requested by:** Gavin (AGM) — "a graph showing the Top ~25 ORP Bats from those
classes and the traits that they possessed as amateurs and as pros."
**Deck:** `pd-goals/scripts/generate_amateur_vs_pro_slide_deck.py` (locked v5.16,
15 slides). This adds a 16th slide; **placement deferred** (build the slide
first, slot it into `build_deck` later).

---

## What ORP is + where it lives (CANONICAL — verified vs GC2 SQL, Jun 2026)

ORP = Offensive Runs Produced. The value GC2's player card DISPLAYS as
**"ORP-Bat" is the MLE (major-league-equivalent) figure**, NOT the raw
per-level RAR column. Per GC2's own player-card SQL:

| Metric | Canonical source | Notes |
|---|---|---|
| **ORP-Bat** (the rank metric) | `SUM(Proj.Batting_MLEs.mle_orp)` WHERE `pitcher_throws = '-'` | Keyed on `groundcontrol_id`, summed across `(year, team_id)` stints = cumulative. MLE-translated so DSL↔MLB are on one scale (the glossary "(650 PAs)" note). |
| **ORP-Run** (baserunning) | `SUM(MLBAM.YTD_Player_Batting_RAR_Produced.orp_run)` | mapped via `mlbam_id` |

`MLBAM.YTD_Player_Batting_RAR_Produced.orp_bat` is a raw per-level figure GC2
does **not** display — using it (v1/v2 of this work) was wrong. GC2 pulls only
`orp_run` from RAR.

**team_id=0 rollup trap:** both RAR and (likely) Proj carry a `team_id=0`
aggregate row alongside each real-team row, double-counting every stint.
GC2 filters `batting_team_id <> 0`; we mirror with `team_id <> 0`.

## Locked decisions

1. **Rank metric:** career **ORP-Bat = `SUM(Proj.Batting_MLEs.mle_orp)`**
   (`pitcher_throws='-'`, `team_id<>0`, `year >= draft_year`) across all of a
   player's pro stints. Cumulative (user: "orp-bat is cumulative"), matches
   what management sees on the GC2 card.
2. **Pool:** league-wide, all 30 orgs. 2022–2025 drafted + UDFA hitters (the
   deck's existing pool via `fetch_roster`). Top 25 by career ORP-Bat.
3. **Not org-tenure-gated.** Full pro career counts regardless of trades —
   player-level question, mirrors how the stickiness pro side already works.
4. **Visual:** a **table**, sorted desc by Pro ORP (the emphasized focus column),
   amateur makeup beside it. Columns:
   `# | Player | Org | Rd-Pk | Pos | School | Age@Draft | PRO ORP | Ctct% | SwDec | Whiff% | Barrel% | AvgEV | LA10-30`
   — the 6 amateur trait cells percentile-shaded red→white→green vs the league
   pool. (User: "table first sorted by orp ... focus is pro orp, but amateur
   metrics/school/other makeup stuff.")
5. **Amateur side includes `hsb`** (base `AMATEUR_LEVELS = bbc/hsb/jcb/sum`), so
   HS draftees appear with showcase traits. Footnote the thin-sample caveat.

## Data pipeline (work laptop / DB) — `generate_amateur_vs_pro.py`

New `fetch_pro_orp(roster, draft_years)`:
- gc_id list from roster → chunked.
- `JOIN Astros.Players pl ON gc_id` to map → `pl.mlbam_id` + `pl.birthdate`.
- `JOIN MLBAM.YTD_Player_Batting_RAR_Produced rar ON rar.player_id = pl.mlbam_id`,
  `WHERE rar.season >= min(draft_years)` and trimmed `rar.level IN PRO_LEVELS`.
- `GROUP BY gc_id` → `SUM(orp_bat) AS pro_orp_bat`, `SUM(orp_run) AS pro_orp_run`,
  `SUM(pa) AS pro_orp_pa`, `MAX(birthdate) AS birthdate`.

In `main()` after `player_table` is built:
- merge `fetch_pro_orp` onto `player_table` by `groundcontrol_id`.
- compute `age_at_draft` = floor-1-decimal of `(date(draft_year,7,15) − birthdate)/365.25`
  (NEVER round up, one decimal — CLAUDE rule #9 / `feedback_age_formatting`).
- sort desc `pro_orp_bat`, `.head(25)`, add `rank`.
- write `<stem>_top_orp.csv` (alongside `_players.csv`/`_orgs.csv`). For the deck
  run, stem = `<date>_amateur_vs_pro_weighted` → `<date>_amateur_vs_pro_weighted_top_orp.csv`.

Only confirmed columns used (`Astros.Players.mlbam_id`/`birthdate`/`groundcontrol_id`,
RAR `orp_bat`/`orp_run`/`pa`/`season`/`level`). No reliance on the uncertain
`R4_Draft_Query.age_at_draft` column.

## Slide (personal laptop, no DB) — `generate_amateur_vs_pro_slide_deck.py`

- `DeckData.hitter_top_orp` (Optional) + load in `load_data` (graceful None if the
  CSV is absent, so existing decks still build before the data run lands).
- `slide_top_orp_table(pdf, data, total, page)` — hand-drawn grid (mirrors
  `_draw_league_table`): navy header, alternating row bg, Pro ORP column in
  Astros navy/orange, 6 amateur trait cells shaded via the existing
  `_rank_to_continuous_color` / percentile helper against the league pool.
- **Not yet wired into `build_deck`** — placement TBD per user.
- pptx twin (`_pptx.py`) deferred until placement is set.

## Verification

- Slide render smoke-tested on personal laptop with a synthetic 25-row CSV
  (no DB needed).
- Real data + numbers verified on work laptop after the `generate_amateur_vs_pro.py`
  run produces the real `_top_orp.csv`. Spot-check a known masher's career
  ORP-Bat and that HS draftees show showcase traits.

## FINAL STATE — Jun 4 2026 (supersedes the visual note above)

**Visual is the stacked-square grid**, matching the amateur-vs-pro draft-class
detail pages (user: "like the pages from the original contact exploration with
all the squares"). Per metric column: Amat square (top) + Pro square (bottom),
each red→green shaded vs the full drafted+UDFA population. 6 metrics: Ctct%,
SwDec, Whiff%, Barrel%, AvgEV, LA10-30. Left block: `# | Player | Org | Rd-Pk |
Pos | School | Age | PRO ORP` (PRO ORP bold, leader orange).

**Colors are precomputed in the pipeline** (`_percentile_color` vs full
population) and written to the CSV as `amat_<k>_color` / `pro_<k>_color` hex —
the slide renders squares straight from those, no pool logic at render time.

### Built / pushed
- `barrelsville/scripts/generate_amateur_vs_pro.py` (`feature/barrelsville`,
  PUSHED): `fetch_pro_orp()` (GC2 mle_orp) + `main()` writes `<stem>_top_orp.csv`
  with traits + precomputed square colors + age.
- `pd-goals/scripts/generate_amateur_vs_pro_slide_deck.py` (`feature/pd-goals`,
  UNCOMMITTED on disk — deck carries in-progress v5.x work): `slide_top_orp_table()`
  + `DeckData.hitter_top_orp` + optional `load_data` load. **NOT wired into
  `build_deck()` yet.**
- `sql-queries/orp-top25-diagnostic.sql` (v3, GC2 mle_orp) — PUSHED.

### RESUME → 2 steps to land the slide
1. Work laptop: `git pull` in `bsb-wt-hitting`, re-run the deck's hitter-CSV
   command **with `--weighted`** → `…_amateur_vs_pro_weighted_top_orp.csv`; copy
   to personal-laptop `Downloads`.
2. **Pick placement** + wire one `slide_top_orp_table(pdf, data, total_pages,
   page=N)` into `build_deck()` (bump `total_pages`); rebuild. Candidates: new
   page 13 (before closing trio), after hitter league view (7), or last (16).
   Then mirror in the `_pptx.py` twin.

## Open / deferred

- Placement in `build_deck` (page number) — user deciding after seeing the slide.
- pptx version.
- Whether to also surface ORP-BR or a per-650 rate as a secondary column (not now).
