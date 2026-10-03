# Swing Decision Grader — Design

**Date:** 2026-06-23
**Worktree / branch:** `bsb-wt-hitting` / `feature/barrelsville`
**Status:** v1 LOCKED (Jun 25 2026) — scoring curve resolved with Zac, see §9.
**Untested on live DB** — anchors are v1 defaults, baseline run pending.
**Owner:** Zac Bridger (PD analyst)

> DRAFT NOTE: This is the laid-out structure from the brainstorming session, not
> a frozen spec. Open questions are flagged inline; resolve them on the next pass.

---

## 1. Purpose

Grade each hitter's **swing decisions** against *his own* damage profile. Reward
swings where he does damage; dock swings (and especially 2-strike whiffs) that
deviate from his hot spot(s). Output a per-player PDF (exploration first), then
graduate to a Barrelsville app page once the grading behaves.

This is **distinct from and complementary to** GC2's existing
`swing_decision_grade_2080` (league-modeled). Ours is **damage-personalized** to
the individual hitter. Both are displayed side-by-side; we never overwrite GC2's.

---

## 2. The reference surface — the "damage field"

For each hitter, build one continuous **xwOBAcon-weighted Gaussian KDE** over his
**contact** locations `(plate_x, plate_z)`, `weights = xwOBAcon_per_BIP`. This is
his personalized damage field `D(x, z)`.

- **Why xwOBAcon, not raw EV:** values barrels (EV + ideal LA), not just heat — a
  100 mph barrel outranks a 105 mph topped grounder. (User decision 2026-06-23.)
- **Reuse, don't reinvent:** `hitter_analysis.py` already computes a weighted KDE
  in `_draw_contact_point_heatmap` (`kde_freq` + `kde_wt`, `gaussian_kde(...,
  bw_method=0.35)`, `:2709`). Per-PA xwOBAcon comes from `xwoba_canonical.py`
  (`compute_xwoba` / `xwoba_case_sql` / `xwoba_pa`). The 50×50 grid + strike-zone
  draw convention matches the postgame heatmaps (`x∈[-2,2]`, `z∈[0,4.5]`).

### 2.1 Two candidate surfaces (explore both)

| | Definition | Pros | Cons |
|---|---|---|---|
| **A. Weighted joint density** (v1, recommended start) | `gaussian_kde(x,z, weights=xwOBAcon)`, normalized | Smooth, already implemented, matches the visual heatmap exactly | Conflates "hits it often" with "hits it hard" |
| **B. Local-mean xwOBAcon** (refinement) | Nadaraya–Watson: `KDE(weights=xwOBAcon) / KDE(weights=1)` = expected xwOBAcon at each location | True "damage value if he swings here" | Noisy where contact is sparse; needs smoothing/min-obs floor |

Start with **A** as the reward surface (it *is* the heatmap). Prototype **B** in
parallel and compare — B is conceptually the "right" damage-value-per-location.

### 2.2 Self-calibrating location value `d`

Convert the field to a **percentile-normalized** value `d ∈ [0,1]` = the percentile
rank of `D(pitch_x, pitch_z)` among his offered pitches. Median = 0.5, so the
swing/take indifference line is self-calibrating and the deterioration gradient is
unit-free. Handles **multiple hot spots** (low-away + middle-in) for free, since we
score the field *value at the location*, not Euclidean distance to a single peak
(directly answers "most dense location**(s)**").

---

## 3. The grading model

Every **offered pitch** (swing OR take) is scored. Two coachable components:

### 3.1 Decision component (`Dec`)

How well swing/take matched the damage field:

- **Swing:** `Dec = 2d − 1` → swing in hot core (`+1`), swing in dead zone / chase (`−1`)
- **Take:** `Dec = 1 − 2d` → lay off a dead pitch (`+1`), take a hot-core pitch (`−1`, passive)

Symmetric; indifference at `d = 0.5`.

### 3.2 Execution component (`Exe`) — swings only

- **Whiff** → floor
- **Weak contact** (EV < 90 / low xwOBAcon) → low
- **Hard/damage contact** (EV ≥ 90 / high xwOBAcon) → high

`Exe` is realized result quality given that he chose to swing. (v1: map whiff→0,
foul→neutral, contact→its xwOBAcon scaled. Tune the anchors during exploration.)

> OPEN Q: final weighting of `Dec` vs `Exe` in the net per-pitch score. Start
> roughly equal; the user wanted both "swung in the right area" AND
> "whiffed/weak beyond the hot spot" represented.

---

## 4. The 2-strike / chase structure

Uses the **Tango Heart / Shadow / Chase / Waste** classifier
(`abs_zone_bounds(height_ft)` in `src/plots.py`) for the in/out-of-zone structure.
Heart/Shadow ≈ "the zone you protect"; Chase/Waste ≈ "outside."

| Situation | Pre-2-strike | **2-strike** |
|---|---|---|
| Swing · Chase/Waste · **whiff** | dock (chase miss) | **MAX penalty** — the strikeout, the cardinal sin |
| Swing · Chase/Waste · **foul** | mild dock | **neutral / +** — battle, survival |
| Swing · Shadow (borderline) | scored by `d` | **softened** — protecting the zone is allowed |
| Take · Shadow/Heart that's a strike (`called_strike_chance_mlb` high) | small dock | **docked** — passive K risk |
| Take · Chase/Waste (ball) | `+` lay-off | `+` lay-off |

Net effect at 2 strikes: the acceptable swing zone **expands** (chase penalty
softens — you must protect) while the **whiff** penalty **hardens**. This is exactly
"docked on 2 strikes for whiffing outside the zone," and it correctly stops
penalizing a defensive foul-off.

> OPEN Q: "outside the zone" boundary = Chase ring vs. Shadow outer edge vs. ABS
> rectangle. Default: Chase/Waste = "outside," Shadow = "borderline/protect."

---

## 5. Aggregation → player grade

- **Overall grade:** mean net per-pitch points over all offered pitches, scaled to
  **20–80** to sit alongside GC2's `swing_decision_grade_2080`. (Per
  `never-round-until-display.md`: carry full float precision; round once at display.)
- **Sub-grades / rates:**
  - **Damage-Zone Attack%** — swing rate at high-`d` locations
  - **Chase%** — swing rate at Chase/Waste
  - **2K Chase-Whiff%** — the cardinal-sin rate (2-strike, outside, swing-and-miss)
  - **Execution** — damage-contact rate on swings
- Show **our grade vs GC2 SwDec** together (complementary, not redundant).

---

## 6. The visual (per-player PDF, postgame style)

Reuse `hitter_analysis.py` KDE + strike-zone helpers. Panels:

1. **Damage field** — xwOBAcon-weighted KDE heatmap + ABS strike zone + Tango overlay (his hot spot(s)).
2. **Swing map** — his swings scattered over the field, colored **green→red by net points** (chase whiffs read as red dots far from the core).
3. **2-strike panel** — same field, 2-strike pitches only, chase-whiffs flagged.
4. **Grade card** — overall + sub-grades, ours vs GC2 SwDec.

Per BLOCKING `render-and-look.md`: render every panel to PNG with synthetic +
worst-case data and **visually inspect** before claiming done.

---

## 7. Data — one Pitches_View query

All per-pitch columns live in `Astros.Pitches_View` (one row/pitch):
`plate_x`, `plate_z`, `did_swing` (recover NULL via `pitch_result_id IN SWING_CODES`),
`pitch_result_id` (→ whiff/contact via `WHIFF_CODES`/contact codes; **`is_whiff`
gated by `did_swing==1`**), `hit_exit_speed` (EV), `hit_vertical_angle` (LA),
`balls_before` / `strikes_before` (count state), `called_strike_chance_mlb`,
`swing_decision_grade_2080` (GC2 reference). Per-PA xwOBAcon via `xwoba_canonical`.
T-SQL: `ISNULL` not `COALESCE`, `TOP` not `LIMIT`, `SUM(CAST(bit AS int))`.

---

## 8. Build plan (exploration-first)

1. `src/swing_decision_data.py` — query + damage-field build (surface A) + `d` +
   Tango classification + per-pitch net scoring + aggregation. Reuse
   `xwoba_canonical`, `plots.abs_zone_bounds`, `hitter_analysis` KDE helpers.
2. `scripts/generate_swing_decision_grade.py` — per-player PDF (4 panels above),
   `--batter-ids` flag mirroring `hitter_analysis.py`.
3. Render to PNG, eyeball, tune anchors/weights with Zac on 2–3 real hitters.
4. Compare surface A vs B; lock the grading curve.
5. Graduate to a Barrelsville app page (App↔Report parity) once proven.

---

## 9. v1 LOCKED decisions (Zac, Jun 25 2026)

Resolved with Zac and shipped in `swing_decision_data.py` + the batch script:

1. **Surface = B (Nadaraya–Watson rate field).** `KDE(weights=xwOBAcon)/KDE(weights=1)`
   = average xwOBAcon per location, NOT the weighted-sum density. Elite contact
   defines the red; weak-contact frequency does not inflate it. Adaptive blur
   (Scott's rule) + 5%-of-peak density floor.
2. **Field window decoupled from the grade.** Field = his **most recent ~500 BBE**
   across levels/seasons (a stable trait). Grade + pre-2K/2K maps = the **selected
   `--year` only**. `grade_one_hitter(score_df, bounds, field_pitch_df=...)`;
   `_collect_for_grade` in the batch script builds both.
3. **Score is pure LOCATION, no Execution term.** Whiff/weak/damage do NOT change
   the score (the design's `Exe` was dropped). The ONLY outcome rule is the
   2-strike chase (below).
4. **TAKE penalty is GEOMETRIC — `csc` dropped from the score.** Driven by distance
   from the zone (zone dims + 1 ball radius: width ±0.83, height `0.27h..0.535h`
   ±0.121), not GC2's called-strike probability:
   - take a **ball** → `+outside_frac` (0 at the edge, **+1** in the dirt — outskirts good)
   - take a **strike** → `−(0.3 + 0.7·d)` (cold-zone strike ≈ −0.3, **damage-zone meatball ≈ −1**)
   - **+2 strikes** on a taken strike → extra **−0.3** (called-K), clips to −1
   - `csc` still drives the DISPLAYED O-Sw/Z-Sw only (industry-standard stat), never the score.
5. **SWING base = `2d−1`** (hot core +1, median 0, cold −1), all counts.
   - **2 strikes + IN-ZONE swing** → `max(2d−1, +0.4)`: protecting the zone is
     **rewarded** (floor +0.4), worth **more in his damage zone**. Limited to in-zone.
   - **2 strikes + chased a ball** → whiff `−outside_frac` (chase-and-miss = cardinal sin);
     foul/contact = small survival credit (≤ +0.2, scaled by closeness).
6. **Min-obs:** field needs ≥15 BBE today (raise to ~50 + league-field fallback is
   the next refinement, §below); grade gate = `--min-offered` selected-year pitches.

### Still open (next passes)
- **Baseline calibration** (§7): run `--baseline` per level/year → wire fixed
  scaling so 50 = the average pro at that level (replaces pool-relative scaling).
- **Small-sample field:** raise field floor to ~50 BBE + **league/level pooled
  field fallback** below it (instead of the 15-BBE personal field).
- **Coach/player-facing simple postgame surface** — SEPARATE / bridge project (not here).
- **v2:** out-of-zone foul-vs-whiff density model for the 2-strike chase (parked —
  per-hitter sample too thin; would be a league model).

---

## 10. Part 2 (parked) — how our hitters are being pitched

Separate exploration the user flagged for "soon": pitch-usage / location / sequence
profiling of how opposing pitchers attack HOU-org hitters. Not in scope here;
spin up its own design doc when it comes up.

---

## 11. The postgame product (SHIPPED Jun 27–28)

`scripts/generate_postgame_swing_decisions.py` → one card per HOU hitter from a
real game; page 1 = a simple "how to read this" cover (`draw_cover_page`).
`draw_postgame_card` (in `swing_decision_plots.py`, shared = app/report parity):

- **Top, compact (~half height):** "Today's Decisions" — a 4-category × (Pre-2K, 2K)
  count table + big **GOOD / OK / POOR** summary. Categories split on `d ≥ 0.5`
  (his damage half) vs cold half: **DZ Swing / DZ Take / Cold Take / Cold Swing**.
- **Bottom:** two **tall** decision maps side by side — *Pre-2 Strikes* and
  *2 Strikes* — pitches over his damage field, dots colored by net (green→red),
  2K chase-whiffs ringed. Map box sized to data aspect (4:4.5) so the zone isn't
  smooshed.
- **No season grade on the card** (a single game is too few pitches for a stable
  20-80; the graded Score is a season/rolling number, lives on the season report).
- Reuses `_collect_for_grade` (field) + `grade_one_hitter`, filters the scored
  season frame to the game date. No new SQL. Run:
  `--level aax --date YYYY-MM-DD`.

### 11.1 Color = decision, not result (the recurring teaching point)
Dot color is the per-pitch `net` (where he offered vs his damage field + count),
NOT whether he hit it. A whiff in a good spot stays green. Stated on the card +
cover.

## 12. Field-quality decisions (Jun 28, Zac) — SHIPPED

- **Color** = diverging blue→white→red, **white at half his peak** (lots of blue
  in cold zones, red hot pocket) via shared `_imshow_field`. NOTE: tried
  mean-centering (`DamageField.center_norm = mean/peak`) Jun 28 — it skewed
  red/dark-rim, Zac reverted to half-peak. `center_norm` left on the class if we
  want mean/median centering back. (Coloring only — scoring uses percentile `d`.)
- **Minimum BBE per area (BLOCKING for trust):** `DamageField.grid(min_bbe=4,
  radius=0.4)` blanks (NaN → transparent) any cell with **< 4 actual batted balls
  within 0.4 ft**, so a lone barrel can't paint a deep-red pocket where he rarely
  hits. Both params tunable. This is the "don't show red in an inappropriate
  spot" guard.

## 13. Roadmap (designed Jun 28, build next)

1. **Cold-start below 100 BBE (Zac #1).** A hitter with < ~100 BBE is graded
   against a **level-pooled damage field** (avg xwOBAcon-by-location across his
   EBIS level), blended into his own as he accumulates: weight `n/(n+K)`. Build a
   per-level pooled field once (reuse the `--baseline` level-wide pull), use it as
   the prior. Below the floor → mostly the level field; above → mostly his own.
2. **`--explore` CLI mode (Zac, replaces the Streamlit idea for now).** Adds, per
   hitter: the **per-pitch net value labelled** (a side table so he can read each
   pitch's score), the **distribution** (real per-pitch net + per-player Score,
   feeding `swing_decision_distribution.py` with real grades), and the **season
   grade**. Purpose: he + director set the **good/ok/poor + A-F thresholds off the
   real spread** (today's ±0.2 / tier bands are placeholders, NOT data-grounded).
3. **Whiff field + combined swing-value surface (research, own track).** Build a
   second field = **P(contact) by location**; multiply by the damage field →
   **expected damage if he swings here = P(contact)·xwOBAcon|contact**. Test
   whether that "swing-value surface" correlates to wOBA / wRC+ better than
   xwOBAcon alone. Thoroughly document before building; this becomes a rendition.
4. **Page 2 per player = his hitter_analysis xwOBAcon box** (absolute / vs-league
   colormap), complementing swdec's self-relative field — shows whether his "red"
   is actually elite. Reuses `_draw_contact_point_heatmap`.

### 13.1 Open knobs to set with real data
- good/ok/poor net thresholds (now ±0.2) and A-F tier bands (now 65/55/45/35).
- DZ boundary `d ≥ 0.5` (could tighten to `0.66` hot-third).
- `min_bbe` / `radius` for the coloring gate (now 4 / 0.4 ft).
- cold-start BBE floor (~100) and blend `K`.
