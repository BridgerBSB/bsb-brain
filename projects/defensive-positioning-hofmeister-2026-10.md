---
type: research
status: captured
created: '2026-10-13'
project: Mazzo OF + BR wishlist, item 1 (OF positioning stance)
tags:
  - fielding
  - outfield
  - positioning
  - modeling
  - mazzo
---
# Defensive positioning model (Colin Hofmeister, Oct 2026) - read for Mazzo item 1

**What it is.** A public Statcast-only model + Shiny app that recommends where all 7
fielders should stand for one PA (batter x pitcher x park x count x base-out), and
prices the move in runs and outs per 100 BIP. Built in R by Colin Hofmeister,
posted to LinkedIn, write-up on Medium (Oct 13 2026).

- LinkedIn post: <https://www.linkedin.com/posts/colinhofmeister_using-mlb-statcast-data-in-r-i-built-a-model-share-7515836650363482112-Zprh/>
- Article "Modeling Defensive Positioning": <https://medium.com/@colinhofmeister/where-should-the-defense-stand-4ea568dda964>
  (Medium blocks bots with Cloudflare; full text pulled through the author's RSS feed
  `medium.com/feed/@colinhofmeister`, 20.8k chars, 19 figures)
- App: <https://colinhofmeister.shinyapps.io/DefensivePositioning/>
- Same author, earlier: "Reverse-Engineering the Perfect Sinker" (Jan 2026).

Zac's framing: "a LinkedIn post of an idea we may want to copy."

## The app (from the hero image)

Top bar: Batter / Pitcher / Defense / Park / Outs / Runners / Count. Left: field with
wall drawn to 2026 dimensions (line width = wall height), blue density = where this
matchup's BIP land or get fielded, grey circles = MLB-average spots, red X = model
spots, arrows between them. Right: "Alignment value" tile (runs saved +0.41 held-out,
+0.80 in-sample; outs gained +0.48), "Predicted batted-ball mix" percentile bars
(GB 37.1% p48, LD 23.6% p33, FB 34.6% p84, PU 4.7% p6, Pull 48.7% p82), Defense card
with each fielder's sprint speed as a percentile bar, swappable. URL holds full state,
"Download PNG" for the field card.

## The method (7 stages, real numbers)

1. **Stage A batted-ball mix.** Two XGBoost classifiers: A1 type (GB/LD/FB/PU), A2
   spray in 8 bins given type. 114 PRE-PITCH features only; batter + pitcher rates as
   of the PA, shrunk to league on small samples; matchup columns via log5. Beat
   class-frequency log loss by only 1.6% (A1) and 5.3% (A2): small per ball, enough over
   hundreds of balls to separate a dead-pull from a spray hitter. Output = 4x8 grid.
2. **Real balls, reweighted.** 122,684 2026 BIP split by park x batter side (60 cells);
   each ball reweighted to match the matchup's type x direction mix, tilted toward
   harder contact for harder hitters. HRs stay in the weights but never pull a fielder.
3. **Out model + hit model.** Cross-fitted XGBoost (2 halves split BY GAME) on 148,616
   2024-25 BIP with standard alignment. Held-out log loss 0.295 (0.605 baseline), AUC
   0.930 (GB 0.84, LD 0.94, FB 0.96, PU 0.91). Calibrated mid-range, miscalibrated at the
   ends (bottom-decile GB hits: 26% predicted vs 22% observed) so GB + LD get isotonic
   recalibration fit on held-out games, which halved calibration error on unseen 2026.
   Hit model: run value of 1B/2B/3B by base-out, RMSE 0.106 vs 0.174 spread.
4. **Coverage model (physical, not learned).** Fly ball: hang time vs the fielder's
   time to the landing spot at his own sprint speed. Grounder: walk the ball's path and
   ask if a fielder cuts it off AND still throws the batter out. Soft max over the 7
   fielders. Standard spots = Savant's average starting spots by batter side + runners
   (2024-26). Held-out AUC 0.89. Range (OAA, prior season) mattered for OF on fly balls
   (+0.02 success rate = ~1 more out per 100 FB into his zone; z 4.2 in 2024-25, held at
   z 3.1 in 2026). **Arm strength and IF range made no measurable difference, so they are
   not in the model.** Only the CHANGE in coverage vs the average spots is added to the
   out model's log-odds: `P(out) = logistic(baseline + z(P) - z(average spots))`.
5. **The wall.** 2026 walls traced from BallparkPal every 0.25 deg with heights; match
   real wall catches to ~6 ft. Flight sim (gravity, drag, backspin lift) gives height at
   the wall plane; 92% of wall-plane balls called HR/not correctly. **Half the out rate at
   the wall is gone by 11.8 ft = leaping reach.** Balls crossing below 11.8 ft can only be
   caught 3 ft in front of the wall; higher = out of reach and stop pulling the OF back.
   Fenway: LF plays 20 ft off the Monster (8 ft when every ball was treated catchable).
   Wall features moved held-out log loss on past-wall balls from 0.621 to 0.422.
6. **Situation.** 1B holds runner when 2B open; DP modeled as a timing race fit on 10,166
   GB outs (AUC 0.69). Uncapped it put middle IFs ON second base with bases loaded, so a
   placement may move any grounder's DP chance by at most 4 pts. Outs priced by RE24
   (Statcast run value treats DP = force out). Infield never comes in.
7. **Search.** L-BFGS-B from 3 starts, exact gradient, then a repair step so rules hold:
   2 IF each side of 2B, all 4 on the dirt; OF >= 105 ft from mound and >= 8 ft inside
   the wall; no two fielders within 18 ft; natural order kept; max move 45 ft IF / 50 ft
   OF; no IF >10 ft shallower than standard depth; 1B within 45 ft of first; 2B/SS >= 15 ft
   from second.

**Validation.** 160 random matchup-states, optimize on half the games, score on the other
half, both ways: held-out gain = **56% of in-sample** (90% interval 52-60%); 91% of
matchups still gained on unseen games. Discount by state: bases empty 52%, runner on
1st <2 outs 69%, runner on 3rd 1st open 45%, else 48%. Gains are UPPER bounds; best MLB
positioning clubs save about 1 run per 100 BIP per season.

**His own stated limit:** the red X's are never checked play by play, because public data
has no fielder starting positions.

## Takeaways for us

1. **We have the one thing he is missing.** `Play_Starting_Positions` gives actual fielder
   starting coordinates per play (HawkEye; ~50% sparse at non-HawkEye MiLB venues, see
   `tracking-schema.md`). So we can do the step he cannot: score real starting spots
   against model spots play by play, and grade our OFs' positioning, not only recommend.
   This answers the open question in Mazzo item 1 ("where to stand" vs "grade where our
   OFs stood"): his architecture does the first, our data unlocks the second.
2. **Leakage rule worth adopting verbatim:** no model may use WHERE A BALL WAS FIELDED.
   For grounders the fielded spot gives the answer away (fielding depth alone = AUC ~0.8)
   and it moves with the alignment. His earlier version used it "and looked far better
   than it was." Our `Hits` coordinates need the same split: landing point vs fielded point.
3. **Copy the held-out discount display.** Show held-out beside in-sample, per state.
   This is the same honesty our `tautological-display.md` / council-data-scientist push.
4. **Physical coverage on top of a learned baseline** keeps the optimizer honest near
   standard spots (only the delta is added). Same shape as our Range & Difficulty work;
   we already store per-fielder sprint speed and reaction for the coverage race.
5. **Realism caps are product decisions, not math.** The 4-pt DP cap exists because the
   uncapped model fooled its own held-out test (same error in both halves). Note for our
   golden set: a held-out split cannot catch a mistake that is identical in both halves.
6. **MiLB gap:** Savant average spots are MLB-only. For our levels the "standard
   alignment" must come from our own `Play_Starting_Positions` by level x batter side x
   runners. Walls: see [[venue-fences-reference]] (memory), and never draw a fence flat.
7. **App UX to steal:** URL holds full state (shareable view), one-click PNG of the card,
   percentile bars for the predicted mix, swappable fielders with sprint-speed bars.

## Action steps

- [ ] Put this in front of Mazzo as the reference for "take a stance" on OF positioning;
      decide recommend vs grade (or both) before any build.
- [ ] Probe: share of 2026 OF plays with a non-null starting position per level (the
      denominator decides whether grading is possible below MLB/AAA).
- [ ] If greenlit: Stage A (type x spray grid) for our hitters first; it is useful alone
      (feeds the advance spray grid and the PoC positioning card) before any optimizer.

Related: [[mazzo-of-br-wishlist-2026-10]] · [[savant-fielding-visuals-research]] ·
[[fielding-advance-spray-grid]] · [[of-positioning-card-status]] · [[agent-harness-research-2026-10-13]]
