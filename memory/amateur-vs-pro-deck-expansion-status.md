---
name: amateur-vs-pro-deck-expansion-status
description: "RESUME HERE — amateur-vs-pro slide deck: ORP slide shipped + Gavin metric-swap deck-wide + contact-floor slide(s) planned. Run/rebuild loop + open items."
metadata: 
  node_type: memory
  type: project
  originSessionId: cacf2d79-74f7-4bab-ad31-8cfa1c912716
---

# Amateur-vs-Pro Slide Deck — Expansion (Jun 9 2026)

**Status:** ORP slide SHIPPED + whole-career fix SHIPPED (both pushed).
Next: Gavin's metric swap deck-wide + contact-floor slide(s) + fully-current rebuild.
Paused mid-expansion to /clear (context was orange).

## SHIPPED this session (all pushed)
- **Top-25 ORP-Bat slide** = page 13/16, wired into BOTH `build_deck` (PDF) and
  `build_pptx` (PPTX); closers renumbered 14/15/16; `total_pages` 15→16.
- **Metric set (Gavin):** dropped LA10-30, added **ZCon% + MaxEV** on the ORP slide
  (7 cols: Ctct% · ZCon% · SwDec · Whiff% · Barrel% · AvgEV · MaxEV).
- **HS draftees excluded** from ORP ranking AND color pool (college/JUCO only).
  25 rows, real ages, colored vs 1,035 non-HS pool.
- **Whole-career pro fix:** ORP slide pro-stat squares were org-tenure-gated
  (drafting org only) → Sirota (CIN draftee, all 510 PA post-trade) rendered blank.
  Pipeline now adds an UNGATED `fetch_pro_aggregates(org_tenure_gated=False)` +
  `player_table_career`, feeding the ORP pool. ORP value was already whole-career;
  squares now match. Org-comparison/quadrant/draft-class pages KEEP the tenure gate.
- **"Org" → "Org (draft)"** header on ORP slide + footnote now says ORP+pro = whole-career.
- **PPTX synced to PDF** so PowerPoint matches exactly (imports `slide_top_orp_table`).

### Commits
- `f678b5d5` (feature/barrelsville) — HS removal + ZCon/MaxEV metric swap (top_orp)
- `ffc93559` (feature/barrelsville) — whole-career pro-stats fix (ungated agg)
- `6307f1dd` (feature/pd-goals) — deck renderer (ORP wiring + metric swap + Org(draft) + footnote) + PPTX sync

## DECISIONS LOCKED (Jun 9 AskUserQuestion)
1. **Metric swap reach = ALL hitting slides incl. consolidated-focus 11.** Drop
   LA10-30, add ZCon% on quadrant(5) + league(6) + consolidated-focus(11). Slide 11
   has 4 hand-written takeaway sentences (Contact/Barrel/SwDec/AvgEV) that MUST be
   rewritten to match the new focus metrics. (Slides 5/6 are mechanical list edits,
   code-only, NO re-run — orgs CSV already carries zctct + max_ev.)
2. **Contact floor = new dedicated slide (maybe 2). DEFINE AT THE VERY END** —
   build from `2026-06-09_power5_contact_floor.csv` (~62% college-contact floor story).
   Do this last, after metric swap + current rebuild land.
3. **Priority = get current hitting + pitching data in + remove LA10-30.** User: "we
   may have to edit these PDFs some."

## OPEN VERIFICATION ITEMS (user flagged, unresolved)
- **Is `amateur_vs_pro --weighted` using the CORRECT weighting?** User unsure. Verify
  what `--weighted` does vs unweighted (per-player vs pool agg — see draft-projects.md
  "ALWAYS ASK per-player vs pool"). Confirm it matches intent before trusting numbers.
- **CB (Competitive Balance) rounds labeled correctly in the Rd-Pk column?** Check the
  `draft_round`/`overall_pick` → "Rd-Pk" formatting on the ORP slide handles CB-A/CB-B
  rounds (and supplemental/comp picks) right, not just integer rounds.

## NEXT-SESSION TASK LIST (in order)
1. **Metric swap on slides 5, 6, 11** (drop LA10-30, add ZCon%). Metric lists at:
   - `slide_quadrant_hitting` line ~1166-1172 (has la_10_30 to drop, no zctct yet)
   - the metric-row list at ~1740-1746 (identify which slide — read first)
   - `_HITTER_FOCUS_SPECS` line ~1908 (consolidated-focus 11 spotlight metrics)
   - **Rewrite the 4 hand-written takeaways** on slide 11 for the new metric set.
2. **Verify weighted + CB-round labels** (open items above).
3. **Fully-current rebuild** once all 6-09 CSVs are in Downloads (commands below).
4. **Contact-floor slide(s)** — LAST. Define content with user first.

## RUN → REBUILD LOOP
### A. Regenerate data — WORK LAPTOP (has DB)
```
cd C:\Users\zbridger\bsb-wt-hitting && git pull
python barrelsville/scripts/generate_amateur_vs_pro.py --weighted        # hitter orgs/players/top_orp (NOW whole-career ORP)
python barrelsville/scripts/generate_stickiness_analysis.py --weighted   # hitter stickiness r2 + players
python barrelsville/scripts/generate_power5_contact_floor.py             # contact floor CSV + PDF

cd C:\Users\zbridger\bsb-wt-bullpen && git pull
python bullpen-report/scripts/generate_amateur_vs_pro_pitchers.py --weighted
python bullpen-report/scripts/generate_stickiness_analysis_pitchers.py --weighted
```
Copy every `2026-06-09_*` CSV → personal `C:\Users\Owner\Downloads\`.

### B. Rebuild deck — PERSONAL LAPTOP (no DB)
```
cd C:\Users\Owner\bsb-resources && git pull
python pd-goals/scripts/generate_amateur_vs_pro_slide_deck.py        # PDF
python pd-goals/scripts/generate_amateur_vs_pro_slide_deck_pptx.py   # PPTX — CLOSE any open .pptx first (file-lock silently fails)
```
Claude can rebuild from Downloads CSVs (no DB needed for the deck build).

## DECK NEEDS 6 CSVs (load_data, run_date_str)
`amateur_vs_pro_weighted_orgs` · `amateur_vs_pro_pitchers_weighted_orgs` ·
`stickiness_weighted_{r2_summary,players}` · `stickiness_pitchers_weighted_{r2_summary,players}` ·
(optional) `amateur_vs_pro_weighted_top_orp`. As of Jun 9 only the HITTER amat-vs-pro +
top_orp are at 6-09; pitcher + stickiness still 5-21 (preview used 5-21 stand-ins).

## FILES
- Pipeline (data): `bsb-wt-hitting/barrelsville/scripts/generate_amateur_vs_pro.py`
- Deck PDF renderer: `bsb-resources/pd-goals/scripts/generate_amateur_vs_pro_slide_deck.py`
  (`slide_top_orp_table` ~3057; ORP meta cols ~3087; `_ORP_TRAIT_SPECS` ~3026; build_deck ~3180)
- Deck PPTX renderer: `bsb-resources/pd-goals/scripts/generate_amateur_vs_pro_slide_deck_pptx.py`
- Local helper scripts (personal laptop, NOT committed): `C:\Users\Owner\_render_orp_real.py`,
  `_build_full_deck_preview.py`
- Last preview built: `pd-goals/output/2026-06-09_amateur_vs_pro_slide_deck_PREVIEW.pdf` (hybrid)

## NOTE
Current `2026-06-09_top_orp.csv` in Downloads still has GATED pro metrics (Sirota blank)
— it predates the whole-career fix. Re-run `generate_amateur_vs_pro.py --weighted` to
regenerate with whole-career squares. Supersedes [[top-orp-slide-status]].
