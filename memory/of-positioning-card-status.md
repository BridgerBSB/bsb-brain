---
name: OF Positioning Card — PoC Built, Waiting on Coordinator Feedback
description: May 2 2026. Manager / Dev Coach OF positioning card for opposing hitters. Sketch + mock card delivered to OF coordinator (Mazzo) for review of Isotopes series (next AAA opp). PoC built on intangibles. Waiting on Mazzo feedback before iterating.
type: project
originSessionId: c0bb79da-67cb-471a-9f9d-349e1195ea7d
---
## Status: PoC SHIPPED, awaiting OF coordinator feedback

May 2 2026. Manager / Dev Coach OF positioning card. Two deliverables
sent to Mazzo (OF coordinator):

1. **OF positioning reference sketch PDF** (4 pages) — for him to mark
   up his team's lingo per cell. Located at
   `intangibles/reports/of_positioning_sketch.pdf`.
2. **Isotopes (Albuquerque, AAA) mock manager card** — generated from
   the actual data using the locked spec. Located at
   `intangibles/reports/of_positioning/Sugar_Land/abq_<dates>/abq_Sugar_Land_OF_Positioning_<date>.pdf`.

Iterate after Mazzo's response.

## Where this fits in the bigger picture

Manager / Dev Coach card replicates `Manager_Dev Card.png` — 20-column
landscape PDF, one row per opposing hitter, with positioning labels
per OF zone (LF/CF/RF) per stance (RHH/LHH).

## Three scopes (we are at scope 2)

| Scope | Status |
|---|---|
| 1. PDF structure | Locked — 20-column layout matching the manager card image |
| 2. **OF positioning logic** | **PoC built, waiting feedback** |
| 3. App + drag-lineup → PDF | Future work |

Infield, SAC B, B HIT, Spd, uniform numbers all deferred — focus is OF
positioning only for now.

## Files built (all on `feature/astros-intangibles`)

| File | Purpose |
|---|---|
| `intangibles/src/of_positioning_data.py` | Data layer — pulls BIPs, applies plurality/density bucketing, returns labels |
| `intangibles/src/of_positioning_report.py` | Reportlab PDF rendering — 18-column manager card table |
| `intangibles/scripts/generate_of_positioning.py` | Batch CLI — auto-detects upcoming series, generates PDFs |
| `intangibles/scripts/generate_of_positioning_sketch.py` | 4-page reference sketch (zoom panels + grid view, RHH + LHH) for coordinator markup |

## Locked decisions

### Source data
- **Ball-flight**, NOT catch position. `hit_bearing` + `hit_distance` from `Astros.Hits`.
- Catch position was diagnostic only (see `if-catch-position-exploration.md` memory). Lower MiLB has sparse HawkEye coverage, can't rely on catch position there.

### OF zone definition
- `hit_vertical_angle > 15` AND `hit_distance >= 150` (in air past IF)
- Equal 30° bearing zones:
  - **LF**: `bearing < -15°`
  - **CF**: `-15° ≤ bearing ≤ +15°`
  - **RF**: `bearing > +15°`
- CF is dead-centered at 0° (overruled Mazzo's "off CF" comment per user)

### Lateral buckets within each zone (Mazzo-shaped, 3°/5°)
At ~290 ft OF depth: 1° ≈ 5 ft, so:

| Bucket | Offset from zone center |
|---|---|
| Straight | within ±3° / ±15 ft |
| Slight Pull / Slight Oppo | 3-5° / 15-25 ft |
| Pull / Oppo | beyond 5° / 25+ ft |

LHH labels flip Pull ↔ Oppo at output time (same bearing, different label per stance).

### Depth thresholds
| Position | In | Straight | Back |
|---|---|---|---|
| LF / RF | ≤ 280 ft | 280-300 | > 300 ft |
| CF | ≤ 300 ft | 300-320 | > 320 ft |

Centerlines from Mazzo: LF/RF = 270/290/310, CF = 290/310/330.
Boundaries are at midpoints.

### Sample threshold: 80+ BIPs (matches existing advance scope)
**NOT YET IMPLEMENTED** — current PoC uses flat 2024-2026 R-game pool with no scope walk-back. Cells render whatever they have. To implement: walk back like `_get_batter_scope_sched_ids` in `hitter_advance_data.py` does, except by OF BIP count (per zone × stance) instead of total PA. PUNT until after Mazzo feedback.

### Plurality / density labeling (NOT centroid)
- Each BIP individually bucketed into one of 5 lateral cells and one of 3 depth cells
- Per (zone × stance), the bucket with MOST BIPs wins (independent for lateral and depth)
- Output exposes `lateral_count`, `lateral_pct`, `depth_count`, `depth_pct` for confidence context
- I drifted to centroid mid-conversation — corrected to plurality May 2 2026 (commit `072a44e`)

### Switch hitter handling
- Filter by `pv.bat_side`. RHH column = bat_side='R', LHH column = bat_side='L'.
- Switch hitters get both columns populated (they bat L vs RHP, R vs LHP)
- Non-switch: only relevant column populates, other side blank
- Yellow row tint on PDF for switch hitters

### Pitcher handedness filter
- **NOT applied in v1.** Pool all opposing pitchers regardless of handedness.
- Card splits by BATTER stance, not pitcher handedness.
- May add later if Mazzo requests granularity (e.g. "vs LHP only" view).

### Label format
- Mazzo's words: Pull / Slight Pull / Straight / Slight Oppo / Oppo (lateral)
- In / Straight / Back (depth)
- Combined cell: drop "Straight" depth (default implied)
  - "Slight Oppo Back" → renders as "Slight Oppo Back"
  - "Straight Straight" → renders as "Straight"
  - "Straight In" → renders as "In"
  - "Straight Back" → renders as "Back"
- Both axes use "Straight" because Mazzo's vocab does (could rename Center / Normal if confusing later)

## Open items / waiting on Mazzo feedback

1. **Sketch markup**: Mazzo to fill out the 4-page sketch PDF with his team's lingo per (zone × lateral × depth) cell. Use his markup to build the actual deployment vocabulary.
2. **Mock card review**: Mazzo to evaluate the Isotopes mock card. Issues likely:
   - Are the labels matching what coordinators would actually call?
   - Are too many cells "Straight"? (Plurality should fix the over-Straight issue from centroid version)
   - Sample size concerns at AAA?
3. **Centroid vs plurality preference**: locked in plurality but Mazzo may prefer centroid for some metrics (less aggressive labeling on bimodal hitters). Re-evaluate after his feedback.

## Open items NOT waiting on Mazzo (we know we need to do these)

- **Scope walk-back for 80+ BIPs.** Current PoC uses flat 2024-2026 pool. Need to walk back by zone × stance until both buckets have ≥80 BIPs. Mirror `_get_batter_scope_sched_ids` from `hitter_advance_data.py`.
- **Min-sample handling.** What to render when a zone has <80 even after walk-back. Options: blank cell, italic flag, or fall-back to 80+ from longer time range.
- **Uniform # source.** No canonical DB source identified yet. Skip for v1, lookup later.
- **Lineup ordering.** Currently sequential (1, 2, 3...) by roster order. Drag-drop app is scope 3.
- **Visual styling.** User mentioned the future app should be all light grey with thick black lines. PDF lines were thickened May 2 (commit `ac3e8c6`).

## How to resume

When coordinator feedback comes in:

1. `git pull` on `feature/astros-intangibles` worktree
2. Read this memory + `tracking-schema.md` (data layer reference)
3. Review feedback — likely will affect:
   - Bucket boundaries (loosen / tighten 3°/5° prescription)
   - Depth thresholds (tweak the 280/300/300/320)
   - Label vocabulary (rename "Slight Pull" if needed)
   - Centroid vs plurality preference
4. Update `intangibles/src/of_positioning_data.py` constants + bucketing logic
5. Update `intangibles/scripts/generate_of_positioning_sketch.py` to match
6. Regenerate sketch + mock card, send back

## Key files / commits

| Commit | What |
|---|---|
| `072a44e` | Plurality/density labeling switch (was centroid) |
| `fd3f537` | Show bearing ranges + ft offsets on sketch labels (3°/5° fix) |
| `d104b54` | Add zoom-panel + grid-view layouts (4-page sketch) |
| `ac3e8c6` | Thicker grid lines on PDF |
| `46e4b49` | Initial OF positioning PoC (3 files) |
| `6db8274` | OF positioning sketch (initial) |

## Conversation context summary

We started this session focused on IF catch-position exploration (see
`if-catch-position-exploration.md`), proved the bearing-divergence
point with 5.5° / 9.45 ft headline finding, then pivoted to OF
positioning per Mazzo's parameters. Several drifts and corrections
along the way:

- I tried catch position for OF too — user corrected: ball-flight, lower MiLB has no HawkEye coverage
- I drifted from plurality to centroid — user corrected: density was always the spec
- I built the sketch with 2°/4° boundaries by mistake — user caught the missing degree/ft labels, fixed to 3°/5°
- I overengineered the sketch into one cramped page — user said make it 4 pages, did zoom panels + grid view
- I used "deep / shallow" terminology for LATERAL bearing within LF zone — user correctly called out, those words mean depth not lateral
- User initially thought Drew Avans LHH-LF "Pull" label was a bug, then realized the highest BIP count was actually at bearing -25 to -15 (CF-side of LF) which correctly flips to LHH "Pull"

Lessons:
- Match Mazzo's exact prescription (3°/5°, 270/290/310 / 290/310/330)
- Don't drift from spec mid-implementation
- Show concrete numerical thresholds on every reference sketch
- Plurality/density is the labeling math, NOT centroid
- "Deep" / "shallow" = DEPTH only. Use "toward foul" / "toward CF" for lateral.
- LHH flip math is correct: bearing -45 (toward LF foul) = LHH "Oppo"; bearing -15 (toward CF) = LHH "Pull"

## LHH/RHH label semantics — IMPORTANT for Mazzo follow-up

Our labels are **OF-shift-direction relative to hitter's pull/oppo**, NOT hitter tendency. This caused user confusion mid-session and may cause Mazzo confusion.

| Convention | LHH-LF "Pull" means |
|---|---|
| **Current (OF-shift)** | LF should shade toward LHH's pull direction (toward CF). His LF balls cluster on the CF-side of the zone. |
| Alternative (hitter tendency) | "He hits LF a lot" → label "Oppo" since LF is oppo for LHH |

Drew Avans is the working example — his data plurality lands at bearing -25 to -15 (CF-side of LF), so OF-shift label = "Pull" for LHH. Coordinator may instinctively expect "Oppo" (he goes to LF a lot). If Mazzo asks to switch to hitter-tendency framing, the change is small: rename labels at output time but the underlying bucketing stays the same. NOT yet decided — waiting on his response.

## Drew Avans diagnostic query (saved for re-use)

When debugging individual hitters, this query returns his lateral bucket counts in RHH-orient (with LHH-flip note):

```sql
DECLARE @gcid INT = ???;   -- look up first

SELECT
    CASE
        WHEN h.hit_bearing < -35 THEN '1. RHH:Pull / LHH:Oppo (-45 to -35, toward foul)'
        WHEN h.hit_bearing < -33 THEN '2. RHH:Slight Pull / LHH:Slight Oppo'
        WHEN h.hit_bearing < -27 THEN '3. Straight (-33 to -27)'
        WHEN h.hit_bearing < -25 THEN '4. RHH:Slight Oppo / LHH:Slight Pull'
        ELSE                          '5. RHH:Oppo / LHH:Pull (-25 to -15, toward CF)'
    END AS bucket,
    COUNT(*) AS n_bips
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
JOIN Astros.Hits h ON pv.sched_id = h.sched_id AND pv.pitch_id = h.pitch_id
WHERE pv.batter_id = @gcid
  AND sv.year IN (2024, 2025, 2026)
  AND sv.sched_type = 'R'
  AND pv.pitch_id > 0
  AND pv.pitch_result_id IN (12, 13, 14)
  AND h.hit_vertical_angle > 15
  AND h.hit_distance >= 150
  AND h.hit_bearing BETWEEN -45 AND -15
  AND pv.bat_side = 'L'      -- adjust for hitter's stance
GROUP BY ...
ORDER BY 1;
```

## Pivot to IF — contingencies + considerations

User clearing context next. Will work on **IF version** of this card. Likely contingencies / things to remember:

1. **Same card structure** — manager card layout already established (`Manager_Dev Card.png`). The IF section has `RHH` / `LHH` columns with NUMBERS (1/2/3) per the example image, not lateral/depth labels like OF.
2. **What do the IF numbers mean?** Need to ask Mazzo. Maybe categorical IF positioning levels (1=normal, 2=shifted, 3=extreme shift)? Or speed-adjacent? Pull this question forward when starting IF.
3. **Same source: ball-flight** — `hit_bearing` + `hit_distance` from `Astros.Hits`. NOT catch position (lower MiLB sparse coverage). User has been clear about this.
4. **IF zone definition** — already in use elsewhere: `LA < 15 AND dist < 150`. Same as the existing IF wedge chart def. 4 IF positions (1B/2B/3B/SS) instead of 3 OF positions.
5. **IF wedge labels (existing)** — current IF wedge chart uses 4 lateral wedges per IF zone (22.5° each = 90° / 4). New manager card IF logic might use different bucket count.
6. **Pull/Oppo flip** — same LHH flip applies to IF labels.
7. **80 BIP scope walk-back** — same TODO punted from OF. Probably implement once for both at the same time.
8. **Plurality/density labeling** — user already locked this for OF. Apply same logic to IF.
9. **Reuse OF infrastructure** — `of_positioning_data.py` `_lateral_label_rhh_orient` + `_flip_for_lhh` + `_combine_label` + `_depth_label` are reusable. May want to refactor to a shared `positioning_data.py` module.

## Files / commits since prior memory write

| Commit | What |
|---|---|
| `072a44e` | Plurality/density labeling switch (was centroid) |
| `fd3f537` | Show bearing ranges + ft offsets on sketch labels (3°/5° fix) |
| `d104b54` | Add zoom-panel + grid-view layouts (4-page sketch) |
| `ac3e8c6` | Thicker grid lines on PDF |
| `46e4b49` | Initial OF positioning PoC (3 files) |
| `6db8274` | OF positioning sketch (initial)
| Prior memory write captured up through `fd3f537` |

No new commits since — diagnostic queries discussed in chat but not committed.

## References

- `Manager_Dev Card.png` — visual target the card mimics
- `if-catch-position-exploration.md` — sister memory for the IF catch position work
- `.claude/rules/tracking-schema.md` — full Tracking schema reference
- `intangibles/src/hitter_advance_data.py` — scope walk-back pattern + series detection (reuse)
- `intangibles/src/of_positioning_data.py` — current OF positioning data layer
- `intangibles/scripts/generate_of_positioning.py` — current batch CLI
- `intangibles/scripts/generate_of_positioning_sketch.py` — current 4-page sketch
