# Matchup Pitch Optimizer — Full Documentation

Source of truth for what the optimizer is, who it's for, how to use
it, how to read it, and how the math works underneath.

Read top-to-bottom for a complete picture, or skip to the section that
matches what you need:

| If you want to... | Skip to |
|---|---|
| Get to the optimizer + generate report PDFs | [§A — Quick start](#a-quick-start) |
| Understand what the tool does and why | [§B — What it is and why it matters](#b-what-it-is-and-why-it-matters) |
| Walk through the Streamlit UI | [§C — Using the app](#c-using-the-app) |
| Generate bulk PDFs from PowerShell | [§D — Generating bulk reports](#d-generating-bulk-reports) |
| Read the output | [§E — Reading the report](#e-reading-the-report) |
| Understand the math | [§F — How it works under the hood](#f-how-it-works-under-the-hood) |
| Tune thresholds, see the file map, or extend | [§G — Reference](#g-reference) |
| Troubleshoot or check an edge case | [§H — FAQ + limitations](#h-faq--limitations) |

---

## A — Quick start

### Get to the Optimizer

1. Click **"Pitching Advance"** in the sidebar (page 4)
2. Pick **level** + **series** + **pitcher** in the filter row
3. Click the **"Optimizer"** tab (third tab after Heatmap / Lookup)

### Get the bulk PDFs

Inside Pitching Advance, the sidebar has a button:

```
Download Pitch Optimizer Summaries -- vs SEA (Jun 12-15)
```

Click it → status panel shows live per-pitcher progress (~3-5 min for
one AAX series) → a "Save Summary ZIP" button appears → click it → the
ZIP downloads to your browser's download folder.

For the same bulk PDFs from PowerShell instead of the app, see
[§D — Generating bulk reports](#d-generating-bulk-reports).

---

## B — What it is and why it matters

### The one question the optimizer answers

> **"Of the pitches this pitcher actually throws, which one — in which
> location — gives him the biggest run-value edge against this specific
> hitter, in this specific count?"**

That's the whole product. Every design choice in the optimizer flows
from it:

- It must use only pitches the pitcher actually throws (no
  hypotheticals — a recommendation for a pitch he doesn't have in his
  arsenal is noise).
- It must score per-pitch *and* per-location (FB up vs FB down are
  different recommendations).
- It must respect game-theory eligibility (you don't throw a 1-2 CH
  in the upper third — the pitch physics make it a bad recommendation
  regardless of what the surface says).
- It must value counts correctly (a whiff at 0-2 ends the at-bat; a
  whiff at 0-0 just gets you a strike — those aren't worth the same).

### Why this provides real value

| User | What they get | Replaces |
|---|---|---|
| Pitching coordinator pre-series | A 1-page sheet per pitcher of best (pitch × zone) per hitter, broken into Early / Ahead / Behind | Hand-built scouting notes; gut + memory |
| Pitcher pre-start | A targeted attack plan grounded in his own arsenal and that night's lineup | Generic "pound the zone" instructions |
| Pitching coach mid-game | A reference for what to call in a key spot vs a specific batter | Recall of recent at-bats |
| Player development | A consistent framework for evaluating attack-plan execution league-wide | Per-coordinator subjective process |

**The unifying value:** the recommendation grounds in *this pitcher's*
historical stuff + location, *this hitter's* historical swing-decision
quality, and *this count's* run expectancy. Each component exists
individually in other tools. Combining all three into one ranked
recommendation per matchup is what the optimizer adds.

### What it explicitly is NOT

- Not a "best pitch in baseball" recommender — it scores within this
  pitcher's actual arsenal.
- Not a sequencing tool — top 2 picks per bucket are ranked
  independently, not as a setup→putaway pair.
- Not real-time — outputs are based on season-to-date data; no
  mid-game updating.
- Not a substitute for the coach — the optimizer says "the math
  points here." The coach decides whether to call it.

---

## C — Using the app

### Navigation

1. **Sidebar → Pitching Advance** (4th menu item)
2. **Level filter** — pick the affiliate (AAA / AA / A+ / A / FCL / DSL)
3. **Series filter** — pick the upcoming series (or leave on "All Series" for the bulk download flow)
4. **Pitcher filter** — pick one of our pitchers from the affiliate roster

The page renders three tabs:

| Tab | What it shows |
|---|---|
| **Heatmap** | Per-batter pages with combined-RV heatmaps (the existing flagship view) |
| **Lookup** | Free-form pitcher-vs-batter lookups across the league (cross-level matchup probing) |
| **Optimizer** | The flagship optimizer view — per-batter heatmap with the top zones highlighted, plus the recommendation table per bucket |

### Within the Optimizer tab

For each opposing batter, you'll see:

- A **header** with the batter's name, handedness, PA count vs this pitcher
- A **2×3 grid of heatmaps** (rows = Early/Ahead/Behind, cols = pitch types)
- **Top zones overlaid** on each heatmap — the optimizer's actual recommendations
- A **recommendation list** below each batter summarizing the top 2 (pitch × zone) picks per bucket
- **Click-to-video** on every pitch dot in the heatmaps (opens MLBAM / Astros internal video in a new tab)

This is the deep-dive view. A coach reads it before a series, or with
the pitcher in advance prep.

### Bulk download (sidebar)

Two buttons in the right sidebar depending on which mode you're in:

| You're in... | Button | What it does |
|---|---|---|
| A specific series selected | "Download Pitch Optimizer Summaries -- vs OPP (Jun X-Y)" | Builds a ZIP of summary PDFs for that one series only |
| All-Series mode (no series selected) | "Download All Pitch Optimizer Summaries (N series)" | Builds a ZIP across every upcoming series at every selected level |

Either button triggers a **two-step flow**:

1. **Generate**: live status panel shows per-pitcher progress (`Pitcher 3/19: Cristian Javier vs SEA (12 batters) | elapsed 38s, ETA 195s`). The ZIP builds in memory.
2. **Save**: once generation completes, a second button appears — "Save Summary ZIP (N PDFs)". Click that to trigger the actual browser download.

**Where it downloads:** wherever your browser's default download folder
is — usually `C:\Users\cquick\Downloads\`. Filename:
`adv_pitch_optimizer_summary_<startdate>_<enddate>.zip`.

**How long it takes:** the diagnostic confirms ~0.6 sec per
(pitcher × batter) matchup. From that:

| Scope | Pitchers × batters | Expected wall time |
|---|---|---|
| One series, single level (AAX) | ~19 × ~15 | ~3–5 min |
| Multiple upcoming MiLB levels | ~70 × ~15 | ~15–20 min |
| All-series, all-level full season | varies | **hours** — only pick this if you mean it |

**Do not close the browser tab while generating.** Streamlit's
progress is tied to the tab. Closing it kills the run mid-way.

---

## D — Generating bulk reports

When Streamlit is slow, flaky, or you just want a clean PowerShell
run, the CLI does the same thing without the browser:

### Single AAX series, default opponent

```powershell
cd bullpen-report
python scripts\generate_optimizer_summary_zip.py --level aax
```

The script picks the next upcoming series for AAX automatically.

### Specific opponent

```powershell
python scripts\generate_optimizer_summary_zip.py --level aax --opp SEA
```

### One pitcher only (testing or one-off)

```powershell
python scripts\generate_optimizer_summary_zip.py --level aax --pitcher-id 72760
```

(Pitcher gc_ids: look up in `pd-goals/data/slack_channels.csv`)

### Multiple levels

```powershell
python scripts\generate_optimizer_summary_zip.py --level aaa aax afa afx
```

### Every series in the season

```powershell
python scripts\generate_optimizer_summary_zip.py --level aaa aax afa afx --all-series
```

(Long run — walk away.)

### Output

The ZIP lands in the worktree's `bullpen-report\` directory as
`adv_pitch_optimizer_summary_<startdate>_<enddate>.zip`. Inside,
PDFs are organized by affiliate folder:

```
adv_pitch_optimizer_summary_20260612_20260615.zip
├── Sugar_Land/
│   ├── aaa_LastName_FirstName_vs_OPP_20260612_optimizer_summary.pdf
│   └── ...
├── Corpus_Christi/
│   └── aax_LastName_FirstName_vs_OPP_20260612_optimizer_summary.pdf
└── Asheville/
    └── ...
```

### Per-step diagnostic (when something feels off)

```powershell
python scripts\diag_optimizer_summary.py --limit-batters 3 --skip-pdf
```

That runs ONE pitcher × 3 batters with timing per step. Tells you
whether the bottleneck is DB queries, NW kernel compute, or a specific
matchup. Expected output: ~3-4 seconds total. If it takes 60+, paste
the output and dig from there.

---

## E — Reading the report

### Anatomy of the summary PDF

One page per pitcher. Per-page layout:

```
┌──────────────────────────────────────────────────────────────────┐
│  Cristian Javier (RHP)  vs.  Arkansas Travelers     ← header     │
│  Matchup Pitch Optimizer Summary  │  AA  │  2026   ← subtitle    │
│                                                                  │
│  Arsenal: FF 38% (n=812)  ·  SL 28% (n=598)  ·  CH 22% (n=470)  │
│                                                                  │
│   Early (0-0,1-0,1-1)  │  Ahead (0-1,...)  │  Behind (2-0,...)  │
│  ┌────────┬─────┬─────────┬─────┬─────┬────────┬──────┬──────┐  │
│  │ Batter │ E1  │ E2      │ AIZ │ AOOZ│ Be1    │ Be2  │      │  │
│  ├────────┼─────┼─────────┼─────┼─────┼────────┼──────┤      │  │
│  │ Smith  │ FF  │ SL      │ CH  │ FF  │ CH     │ SL   │      │  │
│  │ (R)    │ Out │ Mid(Hz) │ Low │ Up- │ Mid(Hz)│ Inner│      │  │
│  │        │-0.05│-0.03    │-0.07│-0.04│-0.42   │-0.06 │      │  │
│  ├────────┼─────┼─────────┼─────┼─────┼────────┼──────┤      │  │
│  │ Jones  │ ... etc ...                                  │      │  │
│  └────────┴─────┴─────────┴─────┴─────┴────────┴──────┘      │  │
│                                                                  │
│  Cell color: blue = pitcher winning, red = hitter winning.       │
│  — = no qualifying pitch.            Generated 2026-06-08        │
└──────────────────────────────────────────────────────────────────┘
```

### Each cell shows

```
<pitch_type>      ← FF, SL, CH, etc.
<zone_label>      ← Upper, Mid (Horz), Outer, Up-And-Away, etc.
<loc_rv>          ← e.g. -0.096 (signed to 3 decimals)
```

### Color encoding (gradient by magnitude)

| RV value | What it means | Visual |
|---|---|---|
| ≤ -0.15 | Strongly pitcher-favored | Deep navy blue |
| -0.05 | Moderately pitcher-favored | Medium blue |
| -0.01 | Barely pitcher-favored | Faint blue |
| 0 | Neutral | White |
| +0.01 | Barely hitter-favored | Faint red |
| +0.05 | Moderately hitter-favored | Medium red |
| ≥ +0.15 | Strongly hitter-favored | Deep red |

The gradient is symmetric on both sides and capped at |RV| = 0.15 —
so a -0.50 outlier and a -0.20 cell both render at full saturation.
That's intentional; you want differentiation in the typical -0.02 to
-0.15 working range, not crushed by rare extreme values.

### The em dash (—)

A cell that says "—" means no qualifying pitch fits that slot. Two
possible reasons:

1. **Low sample**: the pitcher hasn't thrown enough of any pitch type
   in that bucket to score (any pitch type needs `n ≥ 8` in that
   bucket × pitch type combination).
2. **No eligible zone**: the eligibility rules filtered every
   candidate out. Most common case: Ahead 0-2 requires OOZ-only for
   changeups, and the pitcher's CH data is sparse OOZ. Or no breaking
   ball was thrown with enough sample.

The expanded footer in the new version of the report says this
explicitly. If you see lots of em dashes for one pitcher, drop to the
heatmap view in the app to see WHY.

### Reading a single recommendation

Take Daniel Amaral's row:
```
Ahead IZ:  CH  Mid (Horz)  -0.096
```

Decoded:
- **Pitcher should throw**: CH
- **Where**: Middle Third Horizontal (i.e. across the middle of the zone, horizontally)
- **Expected RV**: -0.096 — meaningfully in the pitcher's favor (each pitch averages 0.096 RE units of pitcher gain)

What you do with that:
- It's the strongest single-pitch recommendation against Amaral when
  the pitcher is Ahead AND wants to stay in the zone (vs chase OOZ).
- The arsenal strip tells you Javier throws CH 22% of the time
  (n=470) — so this isn't recommending a pitch he doesn't have.

### Reading the bucket structure

The three buckets aren't equally important to every coach. Common
workflow:

| If you care about... | Look at... |
|---|---|
| Getting the strikeout | Ahead IZ + Ahead OOZ |
| Establishing the count without giving in | Early 1st + Early 2nd |
| Not losing the at-bat | Behind 1st + Behind 2nd |

A pitcher in trouble in a 3-1 count cares about Behind 1st. A pitcher
trying to put away a 0-2 hitter cares about Ahead OOZ.

### The arsenal strip

The line right below the subtitle:
```
Arsenal: FF 38% (n=812)  ·  SL 28% (n=598)  ·  CH 22% (n=470)  ·  CU 12% (n=256)
```

Shows the pitcher's top 6 pitch types by usage with sample size in
the scope. Why it matters:
- Sanity-check the recommendations against actual usage. If the
  optimizer recommends a SC (screwball) in 4 cells but his SC sample
  is `n=5`, that's noise — be skeptical.
- See which pitches DIDN'T qualify. A 4-pitch pitcher whose 5th pitch
  is missing from the strip throws it less than what `top 6` would
  show.

---

## F — How it works under the hood

### Data inputs

Two data fetches per matchup:

| Input | Source | Scope |
|---|---|---|
| Pitcher pitches | `get_pitcher_pitch_data(pitcher_id, season, level)` | All current-season R-game pitches by this pitcher at the selected level (auto-widens to WIDE mode if recent IP is thin — see `advance-levels.md`) |
| Hitter pitches | `get_hitter_pitch_data(hitter_id, season, level)` | All current-season R-game pitches against this hitter at the same level |
| Roster | `get_opposing_hitters_roster(org, level)` | Active hitter roster from PP_MASTER for the opponent affiliate |

Each pitch row carries: `pitch_type`, `bat_side`, `pitcher_throws`,
`plate_x`, `plate_z`, `balls_before`, `strikes_before`,
`pitch_result_id`, `hit_exit_speed`, `hit_vertical_angle`, `game_date`.

Coordinate convention: catcher's view in the database, flipped to
**pitcher's view** before scoring (`plate_x = -plate_x`). See
`coordinates.md`.

### Core scoring: RE288 run value

Every pitch gets a per-pitch run value using **RE288** — Tom Tango's
288-state run-expectancy table for `(balls, strikes, outs, runners)`
combos. The optimizer uses the 12-state slice for `(outs=0, no
runners on)` because that strips noise from base/out state and
isolates the count-state value of the pitch itself.

#### Run-expectancy table (per count, 0 outs, no runners)

| | 0 strikes | 1 strike | 2 strikes |
|---|---:|---:|---:|
| **0 balls** | 0.51 | 0.41 | 0.41 |
| **1 ball** | 0.56 | 0.47 | 0.42 |
| **2 balls** | 0.62 | 0.52 | 0.49 |
| **3 balls** | 0.89 | 1.26 | 0.89 |

Terminal states (strikeout / walk):
- **Strikeout** → 0.27 (new PA starts, 1 out, no runners)
- **Walk** → 0.89 (runner on 1B, 0 outs)

#### Per-pitch run value formula

```
rv = RE(new_count) − RE(old_count)
```

Sign convention:
- **Negative rv** → RE went down → pitcher won the pitch → **blue**
- **Positive rv** → RE went up → hitter won the pitch → **red**

#### How outcomes map to count transitions

| Pitch outcome | Count effect | Notes |
|---|---|---|
| Whiff or called strike | `s += 1`, or strikeout if `s == 2` | Big payoff late in count |
| Foul ball | `s += 1`, or 0 if `s == 2` | 2-strike foul: no count change |
| Ball | `b += 1`, or walk if `b == 3` | Punishes 3-0, 3-1 |
| HBP | walk-equivalent regardless of count | |
| BIP — barrel | `+0.09` (gcPerf constant) | Independent of count |
| BIP — non-barrel | `−0.02` (gcPerf constant) | Independent of count |

Barrel definition (matches GC2 gcPerf):
`EV ≥ 0.011 × LA² − 0.91 × LA + 95.0` with `EV < 125` cap to filter
HawkEye misreads.

#### Why count-state matters (not just outcome)

| Whiff at... | rv | Translation |
|---|---:|---|
| 0-0 | -0.10 | Just a strike |
| 0-2 | -0.14 | Ends at-bat |
| 3-2 | -0.62 | Maximum value — terminates the PA in a dangerous count |

| Ball at... | rv | Translation |
|---|---:|---|
| 0-0 | +0.05 | Minor |
| 2-0 | +0.27 | Dangerous — one ball from 3-0 |

A recommendation that ignores count state can't rank "FF middle"
properly: the value depends entirely on whether a non-strike gets the
pitcher to 3-1 or 1-1.

### Count buckets

The optimizer groups the 12 counts into three buckets that mirror how
pitchers think about an at-bat:

| Bucket | Counts | Pitcher's goal |
|---|---|---|
| **Early** | 0-0, 1-0, 1-1 | Establish, get ahead. Save best putaway for later. |
| **Ahead** | 0-1, 0-2, 1-2, 2-2 | Putaway. Throw the unhittable thing. |
| **Behind** | 2-0, 2-1, 3-0, 3-1, 3-2 | Must throw a strike, but cheap to give up. |

These buckets drive the report's three column groups.

### Zone system: 17 zones in pitcher's view

```
       10 | 11 | 12         ← above zone (OOZ)
       ____________
   17 | 1  2  3  | 13       ← Zone 13 = right OOZ (inside to LHH for RHP)
      | 4  5  6  |
      | 7  8  9  |
       ------------
       16 | 15 | 14         ← below zone (OOZ)
```

**In-zone (1–9)** is the standard 3×3 grid bounded by SZ left/right
`±0.708 ft` and SZ bottom/top `1.5–3.5 ft`.

In-zone scoring uses **bands** not cells — a pitch is scored against:
- **Horizontal thirds**: `upper` (1-3), `mid_h` (4-6), `lower` (7-9)
- **Vertical thirds**: `glove` (1,4,7), `mid_v` (2,5,8), `arm` (3,6,9)

Why bands not cells: a 9-cell in-zone + 8 OOZ gives 17 options to rank
— too granular for a single-line recommendation. Bands give 6 in-zone
choices + 8 OOZ = 14, which fits cleanly.

Vertical-third labels (`glove` / `arm`) are bat-side aware:

| Pitch zone | RHH label | LHH label |
|---|---|---|
| `glove` | Outer Third | Inner Third |
| `arm` | Inner Third | Outer Third |

OOZ labels (10–17) are likewise bat-side aware:

| Zone | RHH label | LHH label |
|---|---|---|
| 10 | Up-And-Away | Up-And-In |
| 11 | Up | Up |
| 12 | Up-And-In | Up-And-Away |
| 13 | In | Away |
| 14 | Low-And-In | Down-And-Away |
| 15 | Down | Down |
| 16 | Down-And-Away | Low-And-In |
| 17 | Away | In |

### Eligibility rules

Most of the "intelligence" of the optimizer is in this filter, not the
math. The rules encode three principles:

1. **Pitch physics** — a CH/FS doesn't have business in the upper third
   or on the glove-side OOZ. Forcing those locations is a bad
   recommendation regardless of run-value math.
2. **Game theory** — throwing the heart of the zone in 0-2 is forbidden
   regardless of what the surface says.
3. **Pitch-type-by-count specifics** — a FB high glove-side means
   something different from a SL low glove-side; the rules apply per
   pitch type per count.

#### Per-pitch-type, per-bucket forbidden zones

```
RHP arm-side OOZ = {12, 13, 14}     LHP arm-side OOZ = {10, 16, 17}
up_OOZ           = {10, 11, 12}

Breaking balls (SL, CU, KC, CS, ST, SV, SC) + CH/FS:
    forbidden = {upper} ∪ arm_OOZ ∪ up_OOZ

CH/FS additionally:
    forbidden += glove_shadow_OOZ
    (changeups never land glove-side OOZ — breaks their tunnel)

Fastballs (FF, FC, FT, SI):
    no per-pitch-type forbidden zones (can go anywhere eligible)
```

#### Per-bucket zone-set selection

| Bucket | Specific count | Eligible base set (minus forbidden) |
|---|---|---|
| Early | any | in-zone only |
| Behind | any | in-zone only |
| Ahead | 0-2, 1-2 | OOZ only (chase pitches) |
| Ahead | 0-1, 2-2 | in-zone + OOZ, minus `mid_v` (heart of zone) |

The Ahead bucket having OOZ-only sub-rules is what makes the
report's "Ahead IZ + Ahead OOZ" split meaningful: 0-2 / 1-2 forbid
in-zone entirely, but 0-1 / 2-2 allow both — the report shows the
best of each.

### Combined NW surface

For each `(count_bucket, pitch_type)` combo per matchup, the optimizer
builds a **combined run-value surface**:

```
combined_surface(x, z) = pitcher_NW(x, z) − hitter_NW(x, z)
```

Both surfaces are 80×80 grids over `(plate_x ∈ [−1.56, 1.56],
plate_z ∈ [0.25, 4.10])` smoothed by a Gaussian kernel of bandwidth
0.35 ft.

**Recency weighting:** every pitch's contribution to its surface is
scaled by an exponential time decay with a **35-day half-life**
(`weight = exp(−ln 2 / 35 × days_ago)`, normalized so the most recent
pitch = 1.0). A pitch ~35 days old counts half as much as the newest
one, ~70 days a quarter, and so on. So both surfaces lean toward
current form rather than weighting an April pitch the same as a pitch
from last week. (The raw per-zone pitch *counts* used for the ≥3 / ≥8
sample gates are NOT time-weighted — only the smoothed rv surface is.)

- **Pitcher NW** = Nadaraya-Watson estimate of the pitcher's per-pitch
  RE288 rv at every grid point, based on his actual pitches of that
  type in that count bucket.
- **Hitter NW** = same construction on the hitter's per-pitch RE288 rv
  vs all pitches of that type in that bucket against him.
- **Combined** = pitcher minus hitter. Negative = both sides agree
  this is a pitcher-favored location.

#### Why combined (not just pitcher)

A FF down-the-middle has a great pitcher rv (lots of called strikes /
weak contact) for many pitchers. But against a hitter who pulverizes
fastballs middle-middle, the hitter rv is even worse. The combined
surface correctly demotes that pitch.

Conversely, an OOZ chase pitch may have a flat pitcher rv (the pitcher
hasn't thrown many to that exact spot historically) but a hugely
negative hitter rv (this hitter chases there). The combined surface
elevates it.

#### Per-zone scoring

For each eligible zone:
1. Grab all combined-surface values inside the zone rectangle.
2. Take their mean — that's the zone's `loc_rv`.
3. Also count `n_pitcher` (how many pitches the pitcher actually threw
   inside that zone in that count bucket). Zones with `n_pitcher < 3`
   are skipped (sparse-pool noise).

The zone with the most-negative mean `loc_rv` is the best zone for
that `(pitch_type, count_bucket)` combo.

### Ranking + selection

For each `(pitcher, hitter, count_bucket)`:

1. Loop over every pitch type the pitcher throws.
2. For each pitch type, build the combined surface and score every
   eligible zone.
3. Take the BEST zone per pitch type — gives one `(pt, zone, loc_rv)`
   tuple per pitch type.
4. Rank all those tuples per bucket by `loc_rv` ascending (most
   negative wins).
5. Take top 2 for Early and Behind. For Ahead, take the best
   in-zone-only and the best OOZ-only separately (one of each).

Sample-size gates applied in order:
- `n_pitcher_in_(bucket × pitch_type) ≥ 8` to enter the loop
- `n_pitcher_in_zone ≥ 3` to score a zone

---

## G — Reference

### Configurable thresholds

| Constant | Value | File | Purpose |
|---|---|---|---|
| `_OPT_GRID_N` | 80 | `advance_pitching_data.py` | NW grid resolution |
| `_OPT_BW` | 0.35 ft | `advance_pitching_data.py` | NW kernel bandwidth |
| `_MIN_PITCHES_ZONE` | 3 | `advance_pitching_data.py` | min pitches in a zone to score it |
| `_MIN_PITCHES_TYPE` | 8 | `advance_pitching_data.py` | min pitches of a pitch type in a bucket to recommend |
| `_SUMMARY_RV_REF` | 0.15 | `advance_pitching_report.py` | rv magnitude where gradient saturates |
| `_BIP_CODES` | `(12,13,14,18,19,20)` | `advance_pitching_data.py` | per `pitch-codes.md` |
| `_WHIFF_CODES_SET` | `(10,16,21,22,23,25)` | `advance_pitching_data.py` | per `pitch-codes.md` |
| RE288 table | 12 cells | `advance_pitching_data.py` | per Tango RE288 |
| Strikeout RE | 0.27 | `advance_pitching_data.py` | Tango |
| Walk RE | 0.89 | `advance_pitching_data.py` | Tango |
| Barrel multiplier | `+0.09` | `advance_pitching_data.py` | matches GC2 gcPerf |
| Non-barrel BIP | `-0.02` | `advance_pitching_data.py` | matches GC2 gcPerf |
| Barrel formula | `EV ≥ 0.011×LA² − 0.91×LA + 95.0` with `EV < 125` cap | `advance_pitching_data.py` | matches GC2 gcPerf |

### File map

| File | Role |
|---|---|
| `bullpen-report/src/advance_pitching_data.py` | Data layer: `get_matchup_recommendations`, `build_summary_row`, `_compute_zone_rv_scores`, RE288 table, zone definitions |
| `bullpen-report/src/advance_pitching_report.py` | PDF rendering: `_eligible_third_ids`, `generate_optimizer_summary_pdf_bytes`, `generate_optimizer_pdf_bytes` (heatmap) |
| `bullpen-report/pages/4_Pitching_Advance.py` | Streamlit app — third tab is the Optimizer view |
| `bullpen-report/scripts/generate_optimizer_summary_zip.py` | CLI for bulk summary PDF generation, bypasses Streamlit |
| `bullpen-report/scripts/diag_optimizer_summary.py` | Per-step timing diagnostic |
| `sql-queries/mlb-rv-by-pitch-zone-count.sql` | Reference SQL — MLB 2025 gcperf rv by pitch/zone/count/split |

### Visual conventions on the summary PDF

| Element | Convention |
|---|---|
| Title handedness | `(RHP)` / `(LHP)`, derived from `pitcher_throws` |
| Opponent | MiLB team name ("Arkansas Travelers"), not parent org abbrev |
| Cell color | Blue/red intensity scales with `\|loc_rv\|`, capped at 0.15 |
| Cell text | 3 lines: `pitch_type` / `zone_label` (short form) / `±0.0NN` |
| Zone label | "Mid (Horz)" / "Mid (Vert)" / "Upper" / "Lower" / "Inner" / "Outer" / 8 OOZ names |
| Column dividers | Navy vertical lines split Early │ Ahead │ Behind |
| Group labels | Count list shown above each bucket: `Early (0-0, 1-0, 1-1)` etc. |
| Em dash bbox | Hidden — em-dash cells render flat white |

### What's NOT in the engine (intentionally)

- **Stuff grades** — shown alongside the optimizer in the heatmap
  report but don't enter scoring math. The pitcher's RV already
  encodes execution; layering stuff grade on top would double-count.
- **Aggregate vs same-handed pitchers** — uses *this pitcher's*
  surface, not a league-average pitcher's.
- **Catcher / umpire effects** — out of scope.
- **Hitter swing decisions** — implicitly included via hitter RV
  (chase whiffs show up as negative hitter rv at OOZ), but no
  swing-decision metric is featured directly.
- **Sequencing** — pitches assumed independent; no setup→putaway logic.

---

## H — FAQ + limitations

### FAQ

**Q: Why does this batter have all em dashes?**
A: Either the pitcher has thrown fewer than 8 pitches of every pitch
type in every count bucket against him (low sample), or no eligible
zone passed the targeting rules. Drop to the heatmap tab and inspect.

**Q: A recommendation says CH but the pitcher rarely throws CH. Why?**
A: Look at the arsenal strip at the top — if CH sample is small
(`n < 30`), the recommendation is noisier. The optimizer ranks based
on what's eligible; small samples make small differences in mean
loc_rv look bigger than they are. Trust higher-sample recommendations
more.

**Q: The same recommendation appears for many different batters. Is
that wrong?**
A: No. If a pitcher's CH-low-zone is genuinely his best putaway
pitch, it'll show up as best vs most batters. The point is that the
optimizer confirms what a coach intuits — not that every batter
gets a unique recommendation.

**Q: How is "best" determined when two recommendations have similar
loc_rv?**
A: Strictly by most-negative loc_rv. If two are within rounding
distance (e.g. -0.087 vs -0.091), they're functionally the same
recommendation; pick whichever the pitcher executes better in
practice.

**Q: Can I get a recommendation that uses a pitch the pitcher doesn't
throw?**
A: No. The optimizer scores within the pitcher's actual arsenal. If
he doesn't throw a sweeper, no sweeper recommendation will appear.

**Q: How often is the data refreshed?**
A: Live DB query every time you run the report. There's no caching at
the data layer (Streamlit caches the result for the session). Re-run
the report after a game to get the latest. Within that data, recent
pitches count more — each pitch is weighted by a 35-day-half-life
exponential decay (see §F → "Recency weighting"), so the
recommendations track current form, not season-opening form.

**Q: Why does my report show "(RP)" instead of "(RHP)"?**
A: Old version. Pull the latest from `feature/bullpen-reports` branch
and re-run. The current version always says (RHP) / (LHP).

**Q: Why does it use the MiLB team name for the opponent now?**
A: Pulled from `MLBAM.Schedule.AWAY` / `.HOME` (the actual MiLB
affiliate name). Reads cleaner than "SEA" when the opposing affiliate
is Arkansas Travelers.

### Limitations (honest list)

| Limitation | What it means | Mitigation |
|---|---|---|
| No real-time updates | Recs are based on season-to-date data; no in-game adjustment | Acceptable — this is pre-series prep |
| No level adjustment | A AAA pitcher's recs vs a AA hitter assume both surfaces are at the same level | Mostly hidden because we only query within-level data |
| Sparse early-season data | First 30 IP of a season, surfaces are noisy | Auto-widens to WIDE mode per `advance-levels.md` |
| No platoon-split aware surfaces | The NW surface uses all pitches of a type in a bucket, not just vs LHH or vs RHH | Eligibility rules use handedness; surface scoring does not |
| No tunneling / sequencing | Each rec is independent — doesn't account for "set up the slider with a high fastball" | Real limitation; covered by coach's judgment |
| No catcher view | Recs don't account for the catcher's framing strength | Out of scope |
| Em dashes are silent | Em dash doesn't tell coach *why* there's no recommendation | Footer text expanded; deeper diagnosis is a manual heatmap look |
| No multi-pitch sequences | Top 2 pitches in Early ranked independently — not "best opener + best follow-up" | Real limitation; future direction |

### Future directions worth considering

Ranked by impact / effort:

1. **Distinguish em-dash reasons** (low-sample vs no-eligible-zone) on
   the summary PDF — actionable signal for the coach
2. **Show sample size per cell** (`n=N`) — currently hidden; coaches
   would benefit from knowing whether a -0.45 cell rests on 6 pitches
   or 60
3. **Platoon-split surfaces** — score the combined surface only on
   vs-LHH or vs-RHH pitches
4. **Per-hitter zone bounds** — currently uses generic SZ `(1.5, 3.5)`;
   per-hitter height adjustment would tighten the in-zone bands
5. **Sequencing intelligence** — best 2-pitch combos per bucket
6. **In-game adjustment hook** — recompute mid-game with the day's
   pitches added to the pitcher's surface

---

## I — References

- Tango RE288 — https://tangotiger.com/index.php/site/article/the-re24-of-pitching
- SmartPitch / Otremba 2022 — `docs/refs/smartpitch.pdf` (TBD; cite paper if added)
- GC2 gcPerf — `.claude/rules/gc2-metrics.md`
- Astros DB column reference — `.claude/rules/db-columns.md`
- Coordinate convention — `.claude/rules/coordinates.md`
- Advance scouting level policy — `.claude/rules/advance-levels.md`
- Non-EBIZ pitcher one-off pattern — `.claude/rules/advance-non-ebiz-pitchers.md`
- Pitch result codes — `.claude/rules/pitch-codes.md`
