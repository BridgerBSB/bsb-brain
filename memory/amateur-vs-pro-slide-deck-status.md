---
name: amateur-vs-pro-slide-deck-status
description: DELIVERED + CLOSED Jun 11 2026 — amateur-vs-pro development deck. Presentation went great. Resume/reference record for the one-off deck.
metadata: 
  node_type: memory
  type: project
  originSessionId: 578b8f6c-947a-4585-a8eb-e81002f74bc2
---

# Amateur-vs-Pro Development Deck — DELIVERED + CLOSED (Jun 11 2026)

**Presentation delivered, went great (user signoff). Project closed.** This is the
reference record if the deck is ever revisited — it's a one-off, not a cross-app
pattern. The one durable lesson (SwDec direction) graduated to
`.claude/rules/gc2-metrics.md` (synced all 4 worktrees).

## Files
- PDF builder: `pd-goals/scripts/generate_amateur_vs_pro_slide_deck.py` (`feature/pd-goals`)
- PPTX builder: `pd-goals/scripts/generate_amateur_vs_pro_slide_deck_pptx.py`
- Hitter/pitcher data generators: `barrelsville/scripts/generate_amateur_vs_pro.py`
  + `bullpen-report/scripts/generate_amateur_vs_pro_pitchers.py`
- Deck reads CSVs from `C:/Users/Owner/Downloads`, `run_date="2026-06-09"`.

## Final delivered structure (17 slides, total_pages=17)
1 title · 2 methodology · 3 framework · 4 ctct_residual · 5 naive_vs_adjusted ·
6 league_view_hitter · 7 quadrant_hitting · 8 dev_leaders(hitter) · 9 focus(hitter) ·
10 quadrant_pitching · 11 league_view_pitcher · 12 dev_leaders(pitcher) ·
13 focus(pitcher) · 14 top_orp · 15 underperform · 16 outperform · 17 bottom_line.
(lingo_reference + several `slide_*` fns are DEAD/uncalled — left in file.)

- Title: "Dev & Acquisition / Strengths / & Opportunities"; right column "WHAT WE
  DEVELOP BEST" leads with dev-rank data (Hitters Power Barrel#1/AvgEV#3/MaxEV#4;
  Pitchers Whiffs #6), orange accents, small THE METHOD footnote.
- Dev-leaders cards = Option C: GREEN strength cards = BEST developers, RED
  deficiency cards = WORST developers (regressed most vs the league line).
- Final slide closing cards 2+2: Potential Opportunity? = Ctct/ZCon(H) + FB Velo(P);
  Strong Development = Barrel/AvgEV(H) + Whiff%(P).

## THE durable lesson (now in gc2-metrics.md "SwDec — Direction Is Side-Specific")
Pitcher SwDec = `AVG(pv.swing_decision_grade_2080)` = the HITTER's decision grade
against the pitcher → **lower is better (hib=False)**. Hitter SwDec = higher better
(batter's own selectivity). The deck shipped pitcher SwDec `True` in ~6 places and
INVERTED HOU's conclusion (rendered "develop it best" when truth = draft-elite 2/30,
develop-worst 29/30). Direction only affects rank/color/residual — raw grades +
regression slopes are direction-neutral → fix was presentation-layer, NO data re-run.
Canonical ref: `bullpen-report/scripts/pitcher_analysis.py:215` (`False`).

## Deck-build gotchas (if revisited)
- **PPTX builder duplicates the slide SEQUENCE + total_pages** (NOT a call into
  build_deck — its "mirrors build_deck exactly" comment lies). Any REORDER/ADD/
  REMOVE slide or total_pages change MUST be edited in BOTH build_deck (PDF) AND
  build_pptx (~L112-139). Slide-fn body changes DO auto-propagate (PPTX imports the fns).
- A few slides hardcode their own footer page number — fix per-slide on reorder.
- PowerPoint file-lock: PPTX build silently `PermissionError`s if the file is open;
  `--out` flag is parsed but ignored. Workaround: inline `build_pptx(output=Path(...))`
  to a distinct filename via `python -c`.
- ORP slide CSV: run the hitter generator with `--weighted` to produce
  `…_amateur_vs_pro_weighted_top_orp.csv` (the name `load_data` expects).
- ORP-Bat canonical = `SUM(Proj.Batting_MLEs.mle_orp)` (`pitcher_throws='-'`,
  `team_id<>0`, cumulative since draft) — the GC2 player-card source, NOT
  `RAR_Produced.orp_bat`.

## Pool means amat→pro (verified Jun 11 from Downloads CSVs, volume-weighted)
Hitters (n=863): Ctct% 78.8→72.6, ZCon% 86.1→80.9, Barrel% 9.7→5.6, AvgEV 91.1→87.5
(all regress); SwDec 43.3→46.4 + MaxEV 109.7→111.3 (gain). Pitchers (n=1044): FB Velo
91.9→92.5, InZ% 44.4→46.8, Whiff% 28.4→28.6, Stuff+ 48.6→50.4, Proj 35.8→41.2 (all gain);
SwDec-allowed 46.7→54.9 (worst move; lower=better). Contact slope ≈0.79 (sub-1 RTM:
high-amat-contact guys drop more in points but stay the best in pro).

## Leftover polish — shipped as-is, intentionally NOT pursued (deck delivered fine)
- Slide 16 + green dev-leaders still tag FB Velo as a pitcher "strength" (it's only
  dev-rank #13); title + final slide call Whiff% the lone pitcher strength. Minor
  internal inconsistency; never reconciled because the deck shipped and presented well.
- Takeaways → 2 bullets: never built ("discuss more").
- Raw-pool-average alongside residual: user wanted to SEE it; placement undecided.
- Bottom-of-squares clarifier on slides 15/16: never added.

These were live discussion threads at delivery; moot now unless the deck is reopened.
