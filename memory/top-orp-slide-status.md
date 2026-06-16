---
name: top-orp-slide-status
description: "Top-25 ORP-Bat slide for the amateur-vs-pro deck — built, awaiting CSV run + placement"
metadata: 
  node_type: memory
  type: project
  originSessionId: f1fa6ed9-2b1d-4af6-b188-335393992575
---

**Gavin (AGM) ask:** add a slide to the amateur-vs-pro deck — "Top ~25 ORP
Bats from those [2022-25 draft] classes and the traits they possessed as
amateurs and as pros." Status as of Jun 4 2026: **slide built + verified
(synthetic), data script pushed; OPEN = run the real CSV + pick placement.**

## Locked decisions
- **ORP-Bat = `SUM(Proj.Batting_MLEs.mle_orp)`** (`pitcher_throws='-'`,
  `team_id<>0`, cumulative across stints since draft) — the CANONICAL GC2
  player-card source (verified vs GC2 SQL). NOT `MLBAM...RAR_Produced.orp_bat`
  (a raw per-level figure GC2 doesn't display; RAR is used only for `orp_run`).
  `team_id<>0` drops the rollup row that double-counted every stint.
- Pool: league-wide all 30 orgs, 2022-25 drafted+UDFA hitters. Rank by career
  ORP-Bat (counting total, user's "option 2"). Per-650 dropped (surfaced
  tiny-sample flukes).
- **Visual = stacked-square grid like the amateur-vs-pro draft-class detail
  pages** (user: "like the pages from the original contact exploration with all
  the squares"). Each metric column = Amat square (top) + Pro square (bottom),
  red→green vs the full drafted+UDFA population. 6 metrics: Ctct%, SwDec,
  Whiff%, Barrel%, AvgEV, LA10-30. Left block: # | Player | Org | Rd-Pk | Pos |
  School | Age | **PRO ORP** (bold, leader orange).
- Verified sane: Kurtz 48.5 #1, Crews correctly OUT (-11.2), Bazzana 6.2.
  Switching to mle_orp shifted the board a lot (Schanuel #2→#14).

## Files / state
- **DATA (pushed, `feature/barrelsville`, `bsb-wt-hitting`):**
  `barrelsville/scripts/generate_amateur_vs_pro.py` — `fetch_pro_orp()` +
  `main()` writes `<stem>_top_orp.csv` (top 25 by mle_orp) with amat_<k>/pro_<k>
  trait values + precomputed `amat_<k>_color`/`pro_<k>_color` hex + age. Commits
  thru the mle_orp fix + color precompute.
- **SLIDE (UNCOMMITTED on disk, `bsb-resources`, `feature/pd-goals`):**
  `pd-goals/scripts/generate_amateur_vs_pro_slide_deck.py` — `slide_top_orp_table()`
  + `_ORP_TRAIT_SPECS` (bare keys) + `_orp_rdpk()` + `DeckData.hitter_top_orp`
  + `load_data()` optional load of `<run_date>_amateur_vs_pro_weighted_top_orp.csv`.
  **NOT wired into `build_deck()` yet** — placement deferred. Left uncommitted
  because the deck file carries the user's in-progress v5.4-v5.16 work.
- **Diagnostic (pushed):** `sql-queries/orp-top25-diagnostic.sql` (v3, GC2 mle_orp).
- **Design doc (committed):** `pd-goals/docs/plans/2026-06-03-top-orp-slide-design.md`.

## RESUME HERE (next session)
1. Work laptop: `cd bsb-wt-hitting && git pull` → re-run the deck's hitter-CSV
   command **with `--weighted`**: `python barrelsville/scripts/generate_amateur_vs_pro.py --weighted`
   → produces `…_amateur_vs_pro_weighted_top_orp.csv`. Drop into personal-laptop
   `Downloads` with the other deck CSVs.
2. **Pick placement** (the actual open question). `build_deck()` is 15 slides
   ending in the closing trio (underperform→outperform→action, pages 13/14/15).
   Wire one `slide_top_orp_table(pdf, data, total_pages, page=N)` call in
   `build_deck()` + bump `total_pages`. Candidates discussed: new page 13 (before
   closing trio), or after hitter league view (page 7), or last (appendix 16).
3. Rebuild deck (personal laptop, no DB): `python pd-goals/scripts/generate_amateur_vs_pro_slide_deck.py`.
4. pptx twin (`generate_amateur_vs_pro_slide_deck_pptx.py`) — mirror once PDF placement locked.

## Notes
- Amateur side includes `hsb` (base AMATEUR_LEVELS), so HS draftees appear with
  showcase traits (thin 10-30 PA — footnoted on slide).
- Deck `load_data` expects the `_weighted` CSV name; run with `--weighted` to match.
- See [[amateur-vs-pro-slide-deck-status]] for the parent deck (locked v5.16).
