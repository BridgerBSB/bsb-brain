# AC Dashboard — Parity Test Plan

**Date:** 2026-05-07
**Status:** Verification protocol — required before any tab ships
**Audience:** Build-time verification + future regression suite

---

## 1. Why this doc exists

AC dashboard is a **4th surface** that displays metric values which
already live on three canonical surfaces (Tracker / KPI weekly /
PD-Goals org KPI). Per `.claude/rules/three-surface-parity.md`:

> Catcher metrics live in 3 surfaces. Any change to one MUST propagate
> to the other two before the commit ships.

AC must show the SAME values for the same selection. Different values
= bug. The bug is always at the data assembler, never "fix it at the
display."

This doc defines the verification ritual for each tab: open AC next
to its source surface, compare cell-by-cell, document the protocol so
the same checks can be re-run as regression tests later.

---

## 2. General protocol

For every tab ship-readiness check:

```
1. Pick a known catcher with a meaningful sample size (e.g. Diaz, AAA, 2026 — 1000+ pitches)
2. Open the AC tab in one browser tab
3. Open the source surface (tracker / postgame / KPI) in another
4. Apply matching filters (year, level, sched_type)
5. Compare every numeric value cell-by-cell
6. Document mismatches in a checklist
7. NEVER ship a tab with any unresolved mismatch
```

If any mismatch:
- DO NOT change AC display formatting to "match" — that hides bugs
- Trace the divergence in the data assembler (`ac_dashboard/data/*.py`)
- Fix at the source of the divergence
- Re-run the check

---

## 3. Per-tab verification

### 3.1. Catcher Cards

**Source surface:** `?view=tracker` (Affiliate Tracker)
**Source selection:** Same year + level + catcher selected on AC

Per-row verification (Catcher Cards card → tracker row):

| Card field | Tracker column | Match required? |
|---|---|---|
| FramRAA value | `framing_raa` | ✓ exact |
| FramRAA percentile | `framing_raa_pctile` | ✓ exact |
| FramRAA Lvl rank | rank column or compute from sorted column | ✓ exact |
| FramRAA Org rank | filter to HOU + same level then rerank | ✓ exact |
| NetK value | `netk` | ✓ exact |
| NetK percentile + ranks | as above | ✓ exact |
| R2K% value | `r2k_pct` | ✓ exact |
| Arm value | `arm` (P99) | ✓ exact |
| Pop 2B value | `pop_2b` (P01) | ✓ exact |
| Exch value | `exchange` (P10) | ✓ exact |
| BlockRAA value | `block_raa` | ✓ exact |
| Bounce% Save | `bounce_save_pct` (or equivalent) | ✓ exact |
| Framing 7 buckets % | `compute_framing_buckets` output | ✓ exact |
| Pop time table cells | `_THROWING_AGG_QUERY` per-hand pop | ✓ exact |

**Defensive grade composite:** marked `[PROVISIONAL]` in UI, no parity
check required (no canonical source). Document the formula in build
notes.

### 3.2. Gameday

**Source surface:** `?view=postgame` (Catcher Postgame Dashboard)
**Source selection:** Same catcher + sched_id

| Gameday element | Postgame element | Match required? |
|---|---|---|
| Game NetK | NetK header value | ✓ exact |
| Frm bucket counts | Framing breakdown buckets | ✓ exact (cell counts) |
| Throws table | Throws section | ✓ exact (rows + summary) |
| Blocks table | Blocks section | ✓ exact |
| AugPop game value | AugPop in throws panel | ✓ exact |
| FIP | FIP header | ✓ exact |
| PA outcomes | PA outcomes | ✓ exact (each row) |
| Zone plot pitch positions | Postgame zone plot | ✓ exact (every dot in same place) |
| Click-to-video URLs | Postgame video click | ✓ same URL opens |

This tab has the highest parity surface — `_render_postgame()` is the
canonical existing renderer. Any divergence = bug in the panel
extraction (§8 of gameday tab spec).

### 3.3. Pitch Calling

**Source surface:** NONE — first new aggregation
**Verification:** internal consistency only

| Check | Pass condition |
|---|---|
| Count distribution | Every row sums to 100% (within 0.1pp rounding) |
| Total pitches | Sum across all counts equals total pitches caught at level |
| Handedness pivot | Sum of all 4 handedness combos equals total pitches |
| Zone heatmaps | Pitch counts per type sum to total caught of that type |
| Sequencing matrix | Each row (prev type) sums to 100% |

No external surface to compare against. Spot-check sample sizes
against `catching_tracker_data.get_catcher_leaderboard()` "n_pitches"
column for the same selection.

### 3.4. Pitchers

**Source surface:** PARTIALLY — pitchers list rows have an existing
counterpart in `catcher_data.get_pitchers_caught()`. Per-pitcher
arsenal is NEW.

| Check | Source / pass condition |
|---|---|
| Pitchers list count | Matches DISTINCT pitcher_ids in catcher's caught pitches |
| Pitches-caught per pitcher | Sums correctly per (catcher, pitcher) |
| Whf% per pitch type | Whiffs / swings (NOT whiffs / pitches!) — gated by `did_swing` per `pitfalls.md` |
| Usage% sums to 100 | All pitch types + Other column sum to 100% per pitcher |
| Velocity / IVB | Match per-pitch averages from `Pitches_View` |

Whiff% is the most error-prone metric here. Verify by manually
computing on a known small sample (e.g. France's CB pitches: count
swings, count whiffs, divide).

### 3.5. Stats

**Source surface:** `?view=tracker` (yearly view) +
`?view=kpi` (cumulative metrics)

| Check | Source |
|---|---|
| Per-year defensive row | `get_yearly_catcher_stats(catcher_id)` output for that year |
| Career rollup | Per-metric weighted by per-metric n_obs (NOT n_pitches!) per `multi-level-rollup.md` |
| Hitting | DEFERRED if hitting data layer not built |

### 3.6. Scoreboard

**Source surface:** `Astros.Schedule_View` direct query

| Check | Source |
|---|---|
| Game count for date | Direct SQL: `SELECT COUNT(*) FROM Schedule_View WHERE sched_date = X AND HOU affiliate involved` |
| Score | `home_score / away_score` columns |
| Catcher attribution | Match `get_catcher_game_sessions()` output |
| Per-game NetK | Match `?view=postgame` for same sched_id |

---

## 4. Cross-tab navigation tests

Beyond per-tab parity, verify the navigation flows produce consistent
selections:

| Flow | Test |
|---|---|
| Catcher Cards "Recent Games" row → Gameday | Same catcher + sched_id loaded; values match postgame |
| Scoreboard game card → Gameday | Same |
| Stats year row → Catcher Cards (year+level) | Card values match tracker for that year+level |
| Tab switching with selectors persisted | Year + catcher persist across tabs via session state |
| URL deep-link `?view=dashboard&tab=cards&catcher_id=X&year=Y` | Loads correct selection without manual interaction |

---

## 5. Pool-gate hide-vs-show tests

Per `.claude/rules/kpi-roster-filter.md` and existing pool-gate
patterns:

| Scenario | Expected AC behavior |
|---|---|
| Catcher with <1500 pitches at level | KPI tile shows raw value but percentile + ranks display as `—` |
| Catcher just promoted (10 pitches at new level) | Card renders, ranks hidden, sample-size warning visible |
| Catcher with 0 games at filter year+level | Empty state with "No games found" message |
| Multi-level select includes ROK + DSL only | Pool comparison applies multi-level rollup correctly per `multi-level-rollup.md` |

---

## 6. Three-surface-parity edge cases

Per the rule's bug-history table, these specific traps have bitten
before. AC needs to NOT replicate them:

| Trap | Where | AC mitigation |
|---|---|---|
| `comp_throws` weighting at multi-level | `aggregate_org_across_levels` | AC reads pre-aggregated values from existing surfaces — never re-aggregates |
| Pop2B base filter (SBA-only) | tracker | AC reuses tracker query directly |
| `pv.pitch_id > 0` filter missing | PD-Goals + KPI weekly | AC inherits via tracker |
| Multi-level percentile pooling drift | OF/IF tracker | Catcher-side: deferred per `multi-level-rollup.md` §"Deferred" |
| FramRAA sign | All surfaces | AC reads `framing_raa` value directly — sign already handled |
| BlockRAA negation (br_rv sign) | All surfaces | AC reads pre-computed value |
| Bucket multi-level rate aggregation | tracker | AC inherits via tracker |

---

## 7. Regression suite (future)

Once all tabs ship, codify these checks as automated tests:

```python
# tests/ac_dashboard/test_parity.py
def test_catcher_cards_match_tracker(catcher_id=DIAZ_GC_ID):
    cards_data = get_catcher_card_facts(catcher_id, 2026, ("aaa",))
    tracker_data = get_catcher_leaderboard(2026, "aaa", ("R",), None, None)
    diaz_row = tracker_data[tracker_data["catcher_id"] == catcher_id].iloc[0]
    assert cards_data.fram_raa == pytest.approx(diaz_row["framing_raa"], rel=1e-6)
    assert cards_data.netk == pytest.approx(diaz_row["netk"], rel=1e-6)
    # ... per-metric assertions ...
```

Run on every PR. Catches drift if either AC or the source surface
changes. Defer the test infrastructure until v1 ships, but design
for it now.

---

## 8. Documentation discipline

When ANY of these happens, update the parity test plan:

- New metric added to AC → new row in §3 of relevant tab
- Metric definition changes in source surface → propagate to AC,
  retest, document in commit message
- New cross-tab nav flow added → new row in §4
- New edge case discovered → new row in §5 or §6

Keep this doc evergreen. It's the regression contract.

---

## 9. References

- `.claude/rules/three-surface-parity.md` — the rule this implements
- `.claude/rules/multi-level-rollup.md` — weighting iron rule
- `.claude/rules/kpi-roster-filter.md` — pool-gate display behavior
- `.claude/rules/pitfalls.md` — whiff gate, BIT cast
- `2026-05-07-ac-dashboard-master-spec.md` — three-surface parity
  callouts (§9)
- All 7 per-tab specs — verification rows
