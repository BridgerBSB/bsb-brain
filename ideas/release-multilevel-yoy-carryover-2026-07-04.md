---
created: 2026-07-04
type: idea
status: approved-pending-spec
tags:
  - promotion-release-models
  - modeling
  - release
  - feature-design
---
# Release Scoring — Multi-Level + Trajectory + Year-over-Year Carryover

**Approved design direction (Zac: "phenomenal", "this is gold", "what I've been asking for"). Born from the Jul 4 2026 FCL/DSL model-integration session. Next step: /spec parts B+C.**

Links: [[promotion-release-models]] · [[release-model-decomposition]] · [[release-v3-shipped-2026-07-02]] · [[fcl-complex-modeling-research-2026-07-04]] · [[MOC-baseball-analytics]]

---

## The problem that surfaced it

`score_all_v3.py` drops any HOU player whose **eBis current level** has no matching **pin** row:

```
Garret Guillemette   no pin row at eBis current level 'aaa' (pin has ['aax'])
```

Guillemette was promoted to AAA *today*; his only tracked stats are AA (`aax`), so he
**silently vanishes from BOTH the promote and release boards.** That violates the
"no player should disappear" rule the sample-size yield-sign and injury flags exist to honor.
His AA stats are literally sitting in the pin (`pin has ['aax']`) — we're throwing them away
via the current-level join.

Key framing: **absence ≠ information.** A dropped player looks identical to a player who was
never there. Missing must never be encoded as a *low grade*, or a just-promoted stud reads
like a scrub.

---

## Promote vs Release ask different questions

| | The question | Current-level gate? | Missing current-level stats → |
|---|---|---|---|
| **Promote** | "Should he move UP from where he is *now*?" | Correct — it IS the question | Show a visible **"NA — new level"** tag, NOT a number |
| **Release** | "Is his overall body of work trending toward a cut?" | Wrong — not a single-level question | Fall back to recent + prior work, level-adjusted |

Promote having no grade for a just-promoted guy is *fine* (you wouldn't promote him the day
he arrives). Release dropping him is *actively wrong* — the promotion itself is success signal.

---

## The three approved pieces

### (A) Immediate — promote visible "new-level" note
Swap the silent drop for a visible state on the promo-engine app. Player stays on the board
with an "NA — new level / insufficient current-level sample" tag (same philosophy as the
yield-sign + injury flag). Cleaned up, pinned, viewable.

### (B) Release — level-adjusted rolling multi-level pool  *(chosen: "Option 2")*
Stop keying on current level. Combine **last-N PA/BF across ALL recent levels** into one line,
adjusting each to a common scale using machinery the models already carry (`level_coef`,
`age_for_level`). Weight by **recency + sample**.
- Handles the "3 levels in a month" case (don't pick one — blend them, adjusted).
- Handles the **demoted** player too (recent higher-level struggle stays in the pool instead
  of being masked by a current lower-level line).

### (B-bonus) Level-trajectory as a release feature  *(approved)*
"Days since last promotion" / level-movement direction as its own feature. **Upward movement
is direct evidence AGAINST a cut** — a guy promoted 3× in a month is succeeding by definition.
Encode trajectory as an anti-release signal.

### (C) Year-over-year carryover  *(NEW requirement — the big one)*
Release stature is a **career trajectory, not a single-season snapshot.** Incorporate
prior-season performance, not just the current stint / current year.
- Mashed last year + small slumping current-year sample → different release call than
  bad two years running.
- Biggest lift: needs prior-season data wired into the training + scoring path, then a retrain.

---

## Files in play (worktree `bsb-wt-modeling`)

- `pd-goals/modeling/score_all_v3.py` — the nightly entry point (drops happen here)
- `pd-goals/modeling/score_active_roster_release_v3.py`
- `pd-goals/modeling/score_active_roster_v3.py`
- `pd-goals/modeling/research/release_v3_model.py`
- `pd-goals/modeling/research/promote_v3_model.py`
- `pd-goals/promo-engine/app.py`

## Sequencing

Ship **A** (small, visible, immediate) → **spec B + C** together (B is medium; C needs
prior-season data + retrain). B and C share the "release isn't just the current stint" thesis.


---

## LOCKED DECISIONS (Jul 4 2026, brainstorming session)

### Code grounding — the gap is SERVE-side, not training
Read of `release_v3_model.py` + `score_active_roster_release_v3.py`:
- **Training already sees trajectory.** `_forward()` builds each player's future-value target
  from their later-season, cross-level rows. The model is fit on multi-season, multi-level careers.
- **Serve throws it away.** `score_active_roster_release_v3.py:54` does
  `L = L[L["level_code"] == L["cur"]]` — keeps ONLY the current-level row, scores that single
  point-in-time snapshot. Features are all single-row (`qual, age, age_for_level, lord` + process).
- ⇒ "Release ignores his lower level / last year" is a **serving problem**, not a model-target
  problem. Consequence: **multi-level pooling can be done at serve WITHOUT a retrain** (the model
  already understands `lord`/`age_for_level` per row — just feed it a better/blended row).
  **Trajectory + YoY are NEW features → require retrain** (must exist at train + serve).

### The plan: PHASE IT
- **Phase 1 — serve-side multi-level pooling. NO retrain.** Stop dropping players with no
  current-level row; score Release on a level-adjusted blend of their available recent rows,
  weighted by recency + sample. Only touches players currently dropped or scored on a thin
  current row ⇒ A-AAA numbers provably ~unchanged (verify byte-identical like the FCL/DSL
  band-local work). Ships fast.
- **Phase 2 — trajectory feature + YoY carryover. Retrain as a NEW version `v3.1`.**
  **NEVER overwrite v3.** v3 stays live until 3.1 is proven *right AND conceptually sound*
  (Zac: conceptual soundness beats a marginally-better-but-unsound model). If 3.1 isn't clearly
  better + sound, we don't adopt it and we haven't lost the good v3.

### Scope = ALL models
Promote + Release, H + P, and **both bands: milb (A-AAA) AND cx (FCL/DSL)**. "We are building
this for all models." Respect **PA/BF sample minimums** when pooling — never grade on a
sub-gate blob (current gates: H pa>=50, P bf>=40).

### Promote vs Release (answer to "wouldn't both sides need this?")
Both models share the disease (no player should disappear) but need different cures:
- **Release** → the multi-level POOLING (blend lower/prior rows into the graded line).
- **Promote** → must NOT pool into its grade (grading a just-promoted-AAA kid on his AA line
  answers the wrong question). Cure = Part A visible "NA — new level" tag + lower-level line
  shown in the **drawer as context**, not in the number.

### Known wrinkle for the Phase 1 spec
Models are **band-local** (separate cx + milb bundles). A DSL→A mover pooled into one line needs
a rule: which band's bundle scores him, and how his DSL row is level-adjusted (the milb bundle
carries no DSL median-age in its frozen `med_age` table). Phase 1 must define this safe rule.

### Still-open Phase 1 design forks (for the design doc)
1. Recency-weight function (linear by days? exponential half-life? sample-weighted only?).
2. How many levels / how far back to pool, and the cross-band rule above.
3. Whether pooling replaces the current-level row or supplements it when one exists.

Next: write `docs/plans/2026-07-04-release-multilevel-serve-pooling-design.md` (Phase 1) once
the 3 forks are picked; Phase 2 (v3.1) gets its own design doc + retrain/validation plan.


---

## ADDED REQUIREMENTS (Jul 4 2026, same session — Zac)

### R1. Cross-org SAME-LEVEL continuity — a trade must not reset the stint
Same `gcid` at the same level across orgs = **ONE continuous stint**. Include the player's rows
from his **former org** at that level, this season.
- **Live case: Sisneros** — AA (`aax`) at the Cubs, AA (`aax`) at HOU now. Same AA stint. His
  promote grade + release read must reflect the FULL AA sample, not just the post-trade HOU PAs.
- **Applies to BOTH promote AND release** (it's still his current level — just split across orgs).
  This is distinct from cross-LEVEL pooling, which stays release-only.
- Must be reflected in **model + app + visually + documented**.
- Machinery note: `score_active_roster_v3.py::_pool_multi_org_rows()` already pools same-player
  rows across orgs at the same level. **VERIFY (Phase 1):** does the live scoring frame actually
  carry the prior-org (Cubs) rows for a traded-in player, or only HOU rows? Must respect
  blocking rule #17 (org attribution is per-PA, `mlbam.teams` JOIN via `top_of_inning`, never
  majority-org collapse).

### R2. FCL ≠ DSL — two distinct levels, never merge
- `dsl` = Dominican Summer League (international rookie), `LORD 0`.
- `rok` = **FCL** = Florida Complex League (domestic rookie), `LORD 1`.
- Distinct rungs, distinct frozen median-age baselines, both in the `cx` bundle but never
  collapsed. The "FCL/DSL" shorthand in these notes = "both of them listed," NOT a merge.

### R3. Skip-level movement must be accounted for
Players skip rungs (e.g., DSL → A, skipping FCL). Pooling weights and the trajectory feature
must use **rung DISTANCE via `LORD` ordinals** (dsl=0 → afx/A=2 is a 2-rung skip), never assume
adjacent-level moves. A 2-rung jump is a stronger promote/anti-release signal than a 1-rung one.

### Confirmed: sequencing
Ship **Part A** (promote visible "NA — new level" tag) FIRST, per recommendation, then design
Phase 1 (serve pooling incl. R1 cross-org continuity). R1/R2/R3 all fold into the Phase 1 +
Phase 2 design docs.


---

## VERIFIED FROM DATA (Jul 4 2026 — local parquet inspection, personal laptop)

Local parquets present on the personal laptop: `Downloads/barrelsville_2026.parquet`,
`Downloads/armfarm_2026.parquet` (live pins) + `modeling/data/promo_features_{h,p}.parquet`
(training, seasons 2021–2025). Inspected directly.

### F1. Cross-org SAME-LEVEL continuity is ALREADY handled (serve + training)
- **Cameron Sisneros** (HITTER, not pitcher) in the live barrelsville pin has 3 rows:
  `CHC afa(A+) 158 PA` · `CHC aax(AA) 57 PA` · `HOU aax(AA) 42 PA`.
  `_pool_multi_org_rows` sums by `(player_id, level_code)` → his AA stint = **99 PA (57+42)**,
  used by BOTH promote + release. His A+ 158 PA is a LOWER level = the release cross-level
  pooling (Phase 1) — currently dropped. **Sisneros = the canonical Phase-1 test case.**
- **Training parquets:** rows where the same `(player_id, season, level_code)` appears under
  >1 org = **0 groups in BOTH H and P**. ⇒ the model never trained on org-reset stints;
  same-level stats are unified per player/season/level upstream. (The 44,996 / 65,903 duplicate
  rows are multiple `snapshot_date`s, NOT org splits.)
- **Residual check for the design doc:** "0 org-split rows" proves no double-count, but does NOT
  distinguish whether the upstream ETL POOLED both orgs' stats vs KEPT-one/DROPPED-the-other for
  historical trades. Confirm the feature-build ETL pools same-level cross-org (else historical
  traded players trained on a partial stint). Live board is confirmed correct regardless.

### F2. HEAD START — Phase 2 (YoY + trajectory) features already exist in training, unused by v3
The training parquet already carries the full feature family Phase 2 needs; the minimal v3
model just doesn't consume it:
- **C / year-over-year:** `delta_xwoba_yoy`, `delta_bat_speed_yoy`, `delta_barrel_pct_yoy`,
  `delta_k_pct_yoy`, `delta_whiff_pct_yoy`, `delta_avg_ev_yoy` (H); `delta_fb_velo_yoy`,
  `delta_stuff_plus_yoy`, `delta_k_pct_pitcher_yoy`, `delta_gcperf_yoy` (P); plus
  `delta_yoy_crosses_2023_boundary`.
- **B-bonus / trajectory:** `was_promoted_prior_year`, `was_demoted_prior_year`,
  `metric_jump_on_promotion_*`, `level_seasons_at_current`.
- v3 uses only `qual + age + age_for_level + lord + 3 process` (deliberately minimal —
  serve-safe, anti-leak per release_v3_model docstring). So **Phase 2 training side = "select
  these existing features + retrain as v3.1," NOT "build a YoY pipeline."** Major de-risk.
- **BUT the LIVE pin lacks them** — `armfarm_2026`/`barrelsville_2026` carry only current-season
  metrics (no `delta_*_yoy`, no `was_promoted_prior_year`). So Phase 2's real serve work =
  **compute those same yoy/trajectory features into the live tracker pin** so train/serve match
  (train/serve skew risk — council-ml-engineer gate). That is the honest Phase 2 scope.

### Data-hygiene item (R2 follow-up)
Verify the feature pipeline EXCLUDES ROK/FCL `Int` sched-type games (HOU-only intrasquad
scrimmages) — they are not real competition and must not count. Per `sched-types.md` /
level whitelist.


---

## RESIDUAL RESOLVED — the ETL DROPS cross-org same-level, it does NOT pool (code-confirmed)

`run_feature_etl.py` default path reads the tracker PINS (SQL path is legacy/deferred). In
`merge_labels_to_features` line ~230:
```python
pin_dedup = pin_renamed.drop_duplicates(subset=["player_id","season","modal_level"], keep="first")
```
The pin carries one row per (player, season, level, **ORG**). This keeps the FIRST org and
**drops the rest** — so a historical same-level traded player trained on a PARTIAL one-org stint.
The earlier "0 multi-org rows in training" was the **fingerprint of this drop**, not pooling.

**⇒ TRAIN/SERVE SKEW:** serve POOLS cross-org same-level (`_pool_multi_org_rows`, Sisneros→99 PA);
training DROPPED one org. Model learned one distribution, served another, for the cross-org
same-level subpopulation. (council-ml-engineer red flag.)

**Fix = Phase 2 / v3.1** (do NOT touch v3): patch the ETL to POOL cross-org same-level BEFORE the
dedup — mirror `_pool_multi_org_rows` (sum pa/bf/ip; size-weight rates; prefer HOU identity) —
then regenerate `promo_features_{h,p}.parquet` and retrain as v3.1.

**Quantifier written:** `pd-goals/modeling/research/quantify_crossorg_stint_drop.py` — READ-ONLY,
reads 2021–2025 pins, counts affected stints + median dropped share. Work laptop, CONNECT_API_KEY
only, no rerun/retrain. Runbook printed to Zac Jul 4.

This makes the earlier "residual check" item CLOSED (answer: drops), and folds the ETL-pooling fix
into the Phase 2 v3.1 scope alongside YoY + trajectory.


---

## PART A — SHIPPED (Jul 4 2026, commit 86bc8e90, feature/promotion-models)

Promote board keeps just-promoted players VISIBLE instead of silently dropping them.
- **Scorer** (`score_active_roster_v3.py`): captures a roster player at a level with no pin
  row there but WITH a lower-level row → emits `board_status='new_level'`, GRADE/odds NULL
  (never a fake low number), + pooled cross-org `new_level_context`. Tested vs live parquet:
  Sisneros forced to AAA → 1 new_level row, GRADE null, context "just promoted from AA · 99 PA
  · gcOBA 0.366" (99 = pooled CHC 57 + HOU 42), other 90 scored intact.
- **App** (`promo-engine/app.py`): board row marker "🔼 new level", dedicated drawer branch
  (NA card + most-recent line, no fake grade/bars), legend footnote. Both drawers
  render-and-looked via headless Edge (new_level + normal regression) — clean, no overlap.
- **Release scorer untouched** — intentional (gets Phase 1 cross-level pooling, not this tag).

**Work-laptop deploy runbook printed to Zac** (re-pin the scoring job + redeploy promo-engine).
The new_level tag shows for GENUINELY just-promoted players (e.g. Guillemette: roster=AAA,
pin=AA). Sisneros still shows normally at AA (99 PA) since he hasn't been moved up.

### Roadmap state after Part A
- ✅ Part A (promote new-level tag) — shipped, pending Zac's work-laptop deploy.
- ⏳ Phase 1 — release cross-level serve pooling (Sisneros's A+ 158 PA is the test case).
- ⏳ Phase 2 / v3.1 — YoY + trajectory features (already in training parquet, unused) + the
  ETL cross-org-pool fix (drops today) + retrain as v3.1. Quantifier `quantify_crossorg_stint_drop.py`
  (commit 8c5213c3) sizes the ETL fix; Zac runs it at home.


---

## QUANTIFIER RESULTS (Jul 4 2026, work laptop, 2021–2025 pins)

Two different shapes:

| | Affected stints | Damage when hit | Shape |
|---|---|---|---|
| **Hitters** | 5,319 / 26,293 = **20.2%** | median **0%**, mean 3% | broad but shallow |
| **Pitchers** | 849 / 32,667 = **2.6%** | median **29%**, mean 28% | narrow but deep |

- **H:** 1-in-5 stints touch 2 orgs but most 2nd orgs are a sliver (median 0% lost); a long tail is
  genuinely split (Wynton Bernard 2023 aaa: pooled 571, kept 307, DROPPED 264 PA).
- **P:** only 1-in-40, but split ~evenly — median 29% of sample dropped (Strotman 2021 aaa: 253 kept,
  251 dropped, near-50/50 trained on half a season).
- **Worst cases are almost all `aaa`** — org churn concentrates at AAA, which is the promote/release
  DECISION zone. Small % but disproportionately the players the model is used to judge → raises priority.
- **Caveat:** "kept" = biggest org, but ETL `keep="first"` keeps an ARBITRARY org (sometimes the
  smaller) → real damage is a LOWER BOUND; actual is worse.

**Verdict:** real, worth-doing v3.1 correctness win — NOT an emergency (won't move the bulk of the
board), but fixes a decision-relevant AAA tail + every meaningfully-split pitcher. Cheap fix (pool
before dedup, mirror `_pool_multi_org_rows`). Bundle into v3.1 with YoY + trajectory as planned.


---

## PHASE 1a — SHIPPED (Jul 4 2026, commit 73f7309a)

Release cross-level serve pooling for players WITH a current-level row. `_pooled_no_future()`
in `score_active_roster_release_v3.py` blends a player's gated cross-org level-rows into one
no-future score, weighted by sample × current-level bump (`CUR_BUMP=2.0`). Serve-only, no retrain.

- **Recency correction (important):** the pin is season aggregates with NO per-game dates, so
  "days-since-game" decay isn't buildable at serve. "Recency" == the level he's at NOW (current-
  level bump). True time-decay → v3.1 pin feature. CUR_BUMP is a tunable constant.
- **Score-level pooling** (blend `rel`, not raw stats) so the model's own `lord`/`age_for_level`
  does the level-adjustment per row. Cross-band (dsl+A) blends both "1−future-value" reads.
- **Verified:** single-level byte-identical (0/2325 mismatches), 207/218 multi-level changed,
  Sisneros AA-only 0.368 → pooled 0.452 (his 158-PA A+ folds in, reads as stalled), end-to-end
  std 0.167. Design doc: `docs/plans/2026-07-04-release-multilevel-serve-pooling-design.md`.
- **Deploy:** RELEASE pin contents change → re-pin the scoring job (no app redeploy needed for
  1a; the app already reads no_future_raw/RELEASE). Bundles with Part A's re-pin.

### Phase 1b (fast follow, not yet built)
No-current-row players (just-promoted in RELEASE, e.g. Guillemette): give them the pooled lower-
level release read, ranked at their current level. Fiddlier (rank + cross-band edge cases). Part A
already keeps them visible on the PROMOTE board, so release-side injection is a clean separate pass.

### Roadmap
- ✅ Part A (promote new-level tag) — commit 86bc8e90
- ✅ Phase 1a (release cross-level pooling, current-row players) — commit 73f7309a
- ⏳ Phase 1b (no-current-row release injection)
- ⏳ Phase 2 / v3.1 (YoY + trajectory + ETL cross-org pool fix + retrain)


---

## PHASE 1b + BUG-2 FIX — SHIPPED (Jul 5 2026, commit 3799d8b8)

Two live bugs found after the Part A + Phase 1a deploy:
- **Bug 1** — new-level players had NO release grade (release scorer dropped no-current-row
  players). **Fix = Phase 1b:** surface them from the already-computed `pooled_rel`, ranked at
  their current level via a NON-DISRUPTIVE percentile insert (existing ranks untouched), badged
  `NEW LEVEL`. Sisneros→AAA test: RELEASE 27, badge NEW LEVEL, 158-PA A+ folds in.
- **Bug 2** — release-ONLY players (promote-gated, release-scored: Waner, Aguilar) rendered
  null age/pos/PA because the release pin never carried them. **Fix:** output `age`/`position`/
  `pa`/`ip` + populate the app's union `_add` block. Verified age/pos/pa 100% non-null.
- Phase-1a single-level byte-identical guarantee intact (Phase 1b only appends). Deploy = re-pin
  the scoring job + redeploy promo-engine (both scorer + app changed).

### Deploy notebook bug (also fixed this session, 489cdfac)
`score_prospects.ipynb` cell-1 had `print(f'<newline>...')` — literal newline in a single-quoted
f-string → nbconvert SyntaxError, whole scoring job wouldn't launch. Escaped to `\n`.

### Roadmap
- ✅ Part A (86bc8e90) · Phase 1a (73f7309a) · notebook fix (489cdfac) · Phase 1b + Bug-2 (3799d8b8)
- ⏳ Phase 2 / v3.1 — YoY + trajectory + ETL cross-org pool fix + retrain (the deliberate big one)


---

## FUTURE IDEAS (Zac, Jul 5 2026 — discussion, not yet built)

### FI-1. MLB-established players optioned down = NOT release candidates (easy)
Guys like Jake Meyers (mlb 148 PA + aax 16 PA) get no release grade — MLB excluded, MiLB sample
too thin. **The fix is a RULE, not a model change:** the player's MLB line is ALREADY in the live
pin (we filter `mlb` as a junk level). Detect "has a meaningful MLB stint this season" (mlb pin row
clears a PA/BF bar) → tag **"MLB — established"** and floor/skip Release instead of minting a noisy
grade off 16 MiLB PA. Do NOT feature the model on career-MLB-PA — it's already in the release
target (`0.25×min(career_mlb_pa,500)/500`), so using it as a feature is a leak. Data availability:
EASY (MLB rows already loaded, just excluded). Whenever Zac wants it.

### FI-2. Snapshot grades AT promote/demote transitions (model report card)
When the org actually promotes/demotes a player, log his Promote + Release grade that day. Later,
evaluate: did high-Promote guys who got the call succeed? did high-Release guys wash out? This is
the model's own feedback loop / validation. Feasible: cross the `promo_v3_score_history` pin
(already logs daily grades) against transaction events (TR_HISTORY / PP_MASTER level changes) to
capture the grade at the transition date. Future analytics build.

### Logging note (sparklines)
`_append_history` already appends a per-player snapshot every scoring run (idempotent per date).
To actually accumulate, the Connect job `promo-models-nightly-score` needs a SCHEDULE set (every
6h / daily). Then the drawer sparkline builds a rolling line forward from now — NO March backfill
possible (only season-aggregate pins exist, no historical daily scored snapshots).

### Settled this session
- Nunez stays blank (36 BF < 40-BF gate) — Zac OK with as-is.
- New-level Promote shows "—" (dash), not "NA" or "0" (dash = "no grade yet", honest).


---

## FI-1 REFINED (Jul 5 2026) — MLB time = anti-release WEIGHT, not just an exclude

Ryan Weiss case grounded the idea: HOU MLB 26 IP (131 BF) + HOU AAA 26.3 IP (147 BF). His AAA
clears the gate so he's NOT blank — but Release is computed off AAA ONLY; his 131 MLB BF are
discarded (mlb excluded). Wrong for a shuttle arm: MLB innings are a loud "this arm has value"
signal that should pull Release DOWN.

**Refined rule:** don't just exclude MLB guys — **discount/floor Release proportional to MLB
time this season.** Meyers (mostly MLB, thin AAA) → floors to ~0 (established). Weiss (split
MLB/AAA) → his AAA release gets pulled down by his MLB innings.
- Applied as a RULE on top of the model output (`release ← release × discount(mlb_time)`), NOT a
  model feature (career-MLB is already in the release target → featuring it is a leak).
- Data is EASY: the player's `mlb` pin row (with PA/BF) is already loaded, just filtered as a junk
  level. Read it, don't drop it.
- Still contained + no retrain. This is the concrete "weigh former MLB performance" ask.

Waner Luciano illustrates the OTHER principle (not a bug): FCL 16 PA + A 100 PA. Promote gates on
the CURRENT level (thin at FCL → blank); Release pools the body of work. If eBis calls A his
current level he SHOULD have a promote grade (91 in local run) — verify after deploy.

## Bug fixed this session (883d04c7)
release-only union rows showed "-" PA/IP: `_stint` read `r.get("stint_ip", default)` but the
`stint_ip` column exists-but-NaN for union rows, and `Series.get` returns NaN (not the default)
when the key is present. Explicit NaN-guard fallback to pa/ip. Fixes Cuevas/McLoughlin/Cassedy.


---

## SESSION STATE @ Jul 5 2026 (wrap point) — where we are + open items

### Shipped this session (all on feature/promotion-models, pushed)
- `86bc8e90` Part A — promote "new level" tag (Guillemette kept visible, no fake grade)
- `73f7309a` Phase 1a — release cross-level pooling (current-row players; single-level byte-identical)
- `489cdfac` fix notebook f-string SyntaxError (deploy blocker)
- `3799d8b8` Phase 1b (no-current-row release read) + Bug-2 (age/pos/stint on release pin)
- `595ff2f4` UX: DSL off by default, expander renames, new-level emoji-left + drawer shows Release
- `883d04c7` fix `_stint` .get NaN-shadow → release-only rows show PA/IP
- `76dce978` two-way players (gid,side) merge/union + labels; IP baseball notation (.0/.1/.2)
- `d5d437cd` **pooled-TOTAL release gate** (Reylin Perez 77 PA/3 levels was vanishing) + stripped
  ALL disclaimers (→ memory `feedback_no_disclaimers_in_outputs`)
- `2d36d60f` drawer fixes for release-only players (removed 2 sentences, "Promote grade" label +
  hide bars when no grade, "—" not "nan")

### Two CORRECTIONS Zac made to me (I was wrong)
1. **CUR_BUMP / weighting:** boosting the current level is JUSTIFIED when current is the HARDER level
   (A+ > FCL) — higher-level performance is more informative about true ability. My "statistically
   backwards / trust noisy sample less" critique was WRONG because it ignored level difficulty. The
   weight should key on **level difficulty (`lord`)**, not "is current" (which conflates difficulty
   with recency + wrongly boosts a demoted guy's easier level). → data-scientist to formalize.
2. Disclaimers — took multiple reminders; now documented as a rule.

### OPEN — apply next session (Zac approved a + b, then MLB)
- **(a) Weighting formula → council-data-scientist stress-test** BEFORE changing CUR_BUMP. Direction:
  reliability(sample)-weighted + **level-difficulty (lord) weighting** + mild recency; NOT the flat
  2× current bump. Must handle promoted (current=harder) AND demoted (current=easier) correctly.
- **(b) Drawer feature-section redesign** (the real "side page" ask): per parameter show TWO things —
  **model weight (global importance)** vs **his contribution/standing** — so a big red bar on a
  low-importance feature (Areinamo bat speed) reads correctly ("dominating his number BUT model barely
  uses it"). Current bars show only per-player SHARE, which misleads when a guy is neutral except one
  feature. This also fixes Bug B (empty release drivers for pooled players). Mock the G redesign
  (percentile bullets + level-blend + feature model-weight-vs-contribution) and show Zac.
- **(c) MLB-into-release** (Weiss/Cole/Meyers) — discount/floor Release by MLB time; refined FI-1.
- **G redesign** approved in concept (percentile-bullet mockup at `projects/promo-engine-ux-audit-2026-07-05.md`);
  build after (a)/(b) land. Set Connect SCHEDULE for sparkline logging (D).
