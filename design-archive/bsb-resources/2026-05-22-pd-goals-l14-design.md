# PD Goals L14 (Last 14 Days) View — Design + Implementation Plan

**Goal:** Every measurable goal should be viewable over the last 14 days,
side-by-side with the goal-period value. Boss directive (May 21 2026 via
Zac). Matches the "L2W" pattern from individual OF / IF / hitter / pitcher
KPI weekly reports — coaches already read this shape.

**Architecture:** L14 = last 14 days from today. The `recent_week` period
(misnomer — it's already 14 days) already exists in PD Goals as an opt-in
toggle that defaults OFF. This plan turns it ON by default, adds the
cumulative-SUM-specific display ("+X.X last 14d (+Y.Y% gap closed)"),
keeps the PDF and app in lockstep, and extends PD Flag Tracker to
fielding metrics with the same 14-day window.

**Tech Stack:** Streamlit, matplotlib, reportlab. SQL Server / GroundControl2
via existing `fetch_player_stats` (caching gives us free reuse).

**Out of scope:** Compliance tab L14 column ("later" per boss). Rolling
chart L14 highlight ("can already see existing one"). Custom date range
window UI (separate request).

---

## Locked decisions (from May 21 brainstorm)

| Decision | Locked answer |
|---|---|
| Which surfaces get L14 | Player view bar charts (app + PDF). PD Flag Tracker fielding extension. NOT Compliance. NOT rolling chart. |
| L14 window | Last 14 days from today |
| Cumulative SUM display in L14 column | `+3.2 last 14d (+13.8% gap closed)` — raw delta + % of remaining gap closed |
| Percentile pool for L14 values | Season pool — same as everything else. Matches individual OF / IF weekly reports. |
| Sample size policy | Always show, no minimum. Inherits existing PD Goals "no player minimum" rule. |
| Tier 1 6-term gate | Inherited automatically via `fielding_base.filter_tier1()`. No separate decision. |

---

## Architecture overview

PD Goals already supports 4 period toggles per goal card: `season`,
`goal_period`, `selected_dates`, `recent_week`. Each period:

- Fetches stats via `fetch_player_stats(player_id, type, start, end, ...)`
- Renders one square / column in the goal card with value, percentile, sample size, color, arrow

The L14 ("recent_week") period already exists end-to-end:

- App: `pages/1_PD_Goals.py:1414-1420` (fetch), `:1502` (label),
  `:1517-1523` (render block), `:241` (toggle default — currently OFF)
- PDF: `src/report.py:549` (fetch), `:818` (period iteration), `:955`
  ("Last\n14 Days" label)

**What's missing:**

1. **Default ON.** Toggle defaults OFF — boss wants every goal visible
   in L14 by default.
2. **Cumulative SUM display.** For `cumulative_sum` metrics (NetK, OAA,
   SB, IP, FramRAA, BlockRAA, etc.), the L14 column should render
   `+3.2 last 14d (+13.8% gap closed)` instead of just the raw value.
   Today it just shows the raw SUM (e.g. "32") which looks identical
   regardless of when in the goal period.
3. **PDF parity for cumulative SUM display.**
4. **PD Flag Tracker fielding extension.** Today the flag tracker has
   `drift_hitting.py`, `drift_pitching.py`, `drift_br.py`,
   `drift_catcher.py`. Fielding metrics (React, TopSpd, Arm, Exch,
   PAA/EO, OAA, etc.) are not flagged. Add `drift_fielding.py` with
   the same 14-day window + Slack delivery pattern.

---

## Cumulative SUM metric inventory

Per `rules/kpi-weekly-charts.md` and `rules/pd-goals-rolling-chart.md`,
metrics fall into three classes. Only the cumulative SUM class needs
the new L14 display logic.

| Class | Metric examples | L14 display rule |
|---|---|---|
| **Cumulative SUM** | NetK (catcher), OAA (OF/IF), PAA (cumulative form), FramRAA, BlockRAA, SB count, CS count, IP, AOL outs | **NEW** — `+X.X last 14d (+Y.Y% gap closed)` |
| **Rate** (numer / denom) | K%, BB%, Damage%, FF Velo, FPinZ%, R2K%, Whiff%, gcOBA, wRC+, **PAA/EO** | Existing — show raw L14 rate value, percentile-colored vs season pool |
| **Percentile-of-pool** (P25/P95/P99 etc.) | React P25, TopSpd P95, Arm P99, Exch P10, UseReact, AccelCU, AccelCD, ReactRad, ReactAccRad | Existing — show raw L14 percentile value, color vs season pool |

**Classifier.** Reuse `CUMULATIVE_METRICS` set from
`pd-goals/src/rolling_chart.py`. That module already enumerates which
metrics are cumulative SUM for the rolling chart, so the bar chart can
import the same classifier. No new list maintenance.

**Cumulative SUM examples to verify against during testing:**

- NetK goal `> 0.020`: a catcher with current NetK = 0.015 (75% of way
  there), L14 NetK = +0.008 should render `+0.008 last 14d (+160% gap closed)`
- OAA goal `> 10`: a fielder with current OAA = 6 (gap of 4), L14 OAA
  = +2 should render `+2 last 14d (+50% gap closed)`
- SB count goal `> 20`: a runner with current SB = 12 (gap of 8), L14
  SB = +3 should render `+3 last 14d (+37.5% gap closed)`

**Edge cases (BLOCKING — handle correctly):**

- DECREASE goal (target lower than current) — flip the sign so "gap
  closed" still means "moved toward target"
- Target = 0 goal (e.g. PAA/EO ≥ 0) — % of gap is undefined; show only
  raw delta with no parenthetical
- Already past target — show `MET +3.2 cushion last 14d` instead of % gap
- L14 delta is NEGATIVE (lost ground) — `-1.5 last 14d (-6% backward)` in red
- L14 value is None (no data) — render `— last 14d` (no parenthetical)

---

## Task 1: Default the `recent_week` toggle ON

**Files:**
- Modify: `pd-goals/pages/1_PD_Goals.py:241`

**Why first:** Smallest possible change. Lets us validate every existing
period-render path still works before adding new math. If something
breaks, easy to revert.

**Step 1: Find the toggle init line**

Read: `pd-goals/pages/1_PD_Goals.py:241`

Expected current state:
```python
st.session_state.chart_toggles = {"season": True, "goal_period": True, "recent_week": False, "selected_dates": False}
```

**Step 2: Flip the default**

```python
st.session_state.chart_toggles = {"season": True, "goal_period": True, "recent_week": True, "selected_dates": False}
```

**Step 3: Verify locally**

Open the deployed PD Engine app. Pick a player with goals. Confirm
that:
- Three squares render per goal card by default: Season, Goal Period, Last 14 Days (in that order)
- Toggle switches in the sidebar reflect the new defaults (Season + Goal Period + Last 14 Days ON)
- L14 column shows raw value + percentile + sample size like the other periods

**Step 4: Commit**

```bash
git add pd-goals/pages/1_PD_Goals.py
git commit -m "feat(pd-goals): default Last 14 Days toggle ON

Boss directive May 21 2026 — every measurable goal should be visible
in last-14-days window by default. Toggle still user-controllable.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push
```

---

## Task 2: Add the cumulative-SUM display helper

**Files:**
- Modify: `pd-goals/src/report.py` — add `format_cumulative_l14_display()` helper
- Modify: `pd-goals/pages/1_PD_Goals.py` — import + call the helper for cumulative L14 cells

Helper lives in `src/report.py` so both the PDF (which already imports
report functions) and the app (which already imports
`format_metric_value` from report) can reuse it. Single source of truth.

**Step 1: Read the existing rolling_chart cumulative classifier**

Read: `pd-goals/src/rolling_chart.py` — locate `CUMULATIVE_METRICS` constant.

Confirm the existing set covers: NetK, OAA, PAA (cumulative form),
FramRAA, BlockRAA, SB count, IP. If it's missing any, those need to
be added in a follow-up but should NOT block this task.

**Step 2: Add the cumulative L14 helper to report.py**

Add this function alongside `format_metric_value` in
`pd-goals/src/report.py`:

```python
from .rolling_chart import _normalize_metric_key, CUMULATIVE_METRICS


def is_cumulative_metric(metric_name: str) -> bool:
    """True if metric is cumulative SUM (NetK, OAA, SB, etc.).

    Used to decide whether L14 display gets the special
    `+X last 14d (+Y% gap closed)` treatment vs the standard
    raw-value-with-percentile display.
    """
    if not metric_name:
        return False
    key = _normalize_metric_key(metric_name)
    return key in CUMULATIVE_METRICS


def format_cumulative_l14_display(
    metric_name: str,
    l14_delta: float,
    current_value: float,
    target_value: float,
    direction: str,
) -> str:
    """Render the L14 cell for cumulative SUM goals.

    Returns one of:
    - "+3.2 last 14d (+13.8% gap closed)"  # standard
    - "-1.5 last 14d (-6.0% backward)"      # lost ground
    - "MET +3.2 cushion last 14d"           # already past target
    - "+3.2 last 14d"                       # target=0 (no gap math)
    - "— last 14d"                          # None / no data
    """
    if l14_delta is None:
        return "— last 14d"

    # Format the raw delta with sign
    delta_str = f"{l14_delta:+.1f}" if abs(l14_delta) >= 0.1 else f"{l14_delta:+.3f}"

    # Target=0: just show raw delta
    if target_value is None or target_value == 0:
        return f"{delta_str} last 14d"

    # Decide gap direction based on goal direction
    if direction == 'above':
        gap_remaining = target_value - current_value
        already_met = current_value >= target_value
    else:  # 'below'
        gap_remaining = current_value - target_value
        already_met = current_value <= target_value

    # Already past target
    if already_met:
        cushion_str = f"{abs(l14_delta):.1f}" if abs(l14_delta) >= 0.1 else f"{abs(l14_delta):.3f}"
        return f"MET +{cushion_str} cushion last 14d"

    # Gap math — direction-aware
    if gap_remaining <= 0:
        # Defensive: gap_remaining shouldn't be <= 0 if not already_met,
        # but handle gracefully
        return f"{delta_str} last 14d"

    # For ABOVE goals: positive delta = closing gap.
    # For BELOW goals: negative delta = closing gap.
    moved_toward = l14_delta if direction == 'above' else -l14_delta
    gap_pct = 100.0 * moved_toward / gap_remaining

    if gap_pct >= 0:
        return f"{delta_str} last 14d (+{gap_pct:.1f}% gap closed)"
    else:
        return f"{delta_str} last 14d ({gap_pct:.1f}% backward)"
```

**Step 3: Smoke test the helper in a Python REPL**

```bash
cd pd-goals
python -c "
from src.report import format_cumulative_l14_display, is_cumulative_metric

# Standard case — closing gap
print(format_cumulative_l14_display('NetK', 0.008, 0.015, 0.020, 'above'))
# Expected: '+0.008 last 14d (+160.0% gap closed)'

# Already met
print(format_cumulative_l14_display('OAA', 2, 12, 10, 'above'))
# Expected: 'MET +2.0 cushion last 14d'

# Lost ground
print(format_cumulative_l14_display('OAA', -1.5, 6, 10, 'above'))
# Expected: '-1.5 last 14d (-37.5% backward)'

# Target=0
print(format_cumulative_l14_display('PAA', 0.3, -0.2, 0, 'above'))
# Expected: '+0.3 last 14d'

# None
print(format_cumulative_l14_display('SB', None, 12, 20, 'above'))
# Expected: '— last 14d'

# Decrease goal (e.g. 'OAA below 0', rare but possible)
print(format_cumulative_l14_display('CS', -1, 5, 2, 'below'))
# Expected: '-1.0 last 14d (+33.3% gap closed)' (moved toward lower target)

# Classifier
print(is_cumulative_metric('NetK'))   # True
print(is_cumulative_metric('K%'))     # False
print(is_cumulative_metric('OAA'))    # True
print(is_cumulative_metric('FF Velo'))  # False
"
```

Expected output exactly matches the inline `# Expected:` comments. If
any line diverges, fix the helper before moving on.

**Step 4: Commit**

```bash
git add pd-goals/src/report.py
git commit -m "feat(pd-goals): add cumulative L14 display helper

format_cumulative_l14_display() renders the L14 column for cumulative
SUM goals as '+X last 14d (+Y% gap closed)'. Handles target=0, already
met, lost ground, and None edge cases.

Wired up in next commit (app + PDF render paths).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push
```

---

## Task 3: Wire cumulative L14 display into the app

**Files:**
- Modify: `pd-goals/pages/1_PD_Goals.py` — around the `active_square_periods` render loop (lines 1525-1580ish)

The current renderer treats every period identically — it renders
`sq_display` (raw value string) regardless of period or metric class.
For cumulative metrics on the L14 period only, we want the new helper's
output instead.

**Step 1: Find the renderer block**

Read: `pd-goals/pages/1_PD_Goals.py` around lines 1525-1580.

Look for the `for sq_idx, (sq_key, sq_label, sq_val, ...) in enumerate(active_square_periods):`
loop. Inside it, the value rendering happens via `sq_display` which is
computed earlier via `get_goal_display_value(...)`.

**Step 2: Add the cumulative override**

At the top of the renderer file, add the import:

```python
from src.report import (
    get_goal_status,
    format_metric_value,
    is_cumulative_metric,
    format_cumulative_l14_display,
)
```

Inside the active_square_periods render loop, BEFORE the value renders,
override `sq_display` when:
1. The current period is `recent_week` (L14)
2. The metric is in `CUMULATIVE_METRICS`
3. The goal has a valid target

```python
# Cumulative SUM override for L14 column (boss directive May 22 2026)
# For cumulative metrics on the Last 14 Days period, replace the raw
# value display with "+X last 14d (+Y% gap closed)" — same shape
# coaches see in KPI weekly L2W tables.
if sq_key == "recent_week" and is_cumulative_metric(metric_name) and target_value is not None:
    # We need current_value (e.g. season-to-date for cumulative)
    # — use season_val since cumulative goals measure "how much
    # accumulated by today"
    sq_display = format_cumulative_l14_display(
        metric_name=metric_name,
        l14_delta=sq_val,           # raw L14 SUM = the L14 contribution
        current_value=season_val,    # season-to-date accumulated
        target_value=target_value,
        direction=direction,
    )
```

**Step 3: Verify locally**

Open the deployed PD Engine. Pick a catcher with a NetK goal. Confirm:
- L14 column now reads `+0.008 last 14d (+...% gap closed)` instead of raw `0.008`
- Goal period column unchanged
- Season column unchanged
- Rate / percentile metrics (K%, React, etc.) still render with raw value + percentile (no cumulative override fires)

**Step 4: Commit**

```bash
git add pd-goals/pages/1_PD_Goals.py
git commit -m "feat(pd-goals): wire cumulative L14 display into goal cards

Cumulative SUM goals (NetK, OAA, SB, IP, FramRAA, etc.) now show
'+X last 14d (+Y% gap closed)' in the L14 column instead of the
raw value. Matches the design coaches already read in KPI weekly
L2W tables.

Rate + percentile metrics unaffected — they still show raw value +
percentile color + sample size.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push
```

---

## Task 4: Wire cumulative L14 display into the PDF

**Files:**
- Modify: `pd-goals/src/report.py` — locate the recent-period render block (around line 818, 955)

**Step 1: Find the PDF render block**

Read: `pd-goals/src/report.py:800-870` — locate the loop that iterates
over `('goal', 'recent', 'season')` periods and renders each column's
value text.

**Step 2: Apply the same override pattern**

Inside the per-period render loop, when the period key is `'recent'`
and the metric is cumulative + has a target, override the rendered
value text:

```python
if period_key == 'recent' and is_cumulative_metric(metric_name) and target_value is not None:
    value_text = format_cumulative_l14_display(
        metric_name=metric_name,
        l14_delta=val,
        current_value=goal_item.get('season_val'),
        target_value=target_value,
        direction=direction,
    )
else:
    value_text = format_metric_value(val, metric_name)
```

**Step 3: Generate a test PDF**

```bash
cd pd-goals
python scripts/generate_reports.py --player-id <test_catcher_with_netk_goal>
```

Open the generated PDF. Confirm L14 column shows the new format on
cumulative goals. Rate goals unchanged.

**Step 4: Commit**

```bash
git add pd-goals/src/report.py
git commit -m "feat(pd-goals): PDF L14 cumulative display parity

PDF report's L14 column now mirrors the app's cumulative-SUM display:
'+X last 14d (+Y% gap closed)' on cumulative goals, raw value on
rate / percentile goals. App + PDF stay in lockstep per CLAUDE.md
blocking rule #11 (App↔Report parity).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push
```

---

## Task 5: Create `drift_fielding.py` for PD Flag Tracker

**Files:**
- Create: `pd-goals/src/drift_fielding.py`
- Modify: `pd-goals/scripts/drift_alert.py` — register the new domain
- Modify: `pd-goals/src/drift_thresholds.py` — add fielding metric configs

**Architecture:** Mirror the shape of `drift_catcher.py` exactly.
Single-domain module that exposes `get_fielding_drift(season, mode,
from_year, to_year)` returning `List[FieldingFlaggedMetric]`.

**Step 1: Read the canonical patterns**

Read: `pd-goals/src/drift_catcher.py` (single-metric pattern) and
`pd-goals/src/drift_br.py` (multi-metric pattern). Read the BLOCKING
rule in `.claude/rules/pd-goals-flag-tracker.md` — domain modules MUST
mirror canonical tracker SQL (in this case `intangibles/src/fielding_tracker_data.py`).

**Step 2: Decide which metrics to flag**

Initial scope (v1):

| Metric | Source | Direction | Cumulative? | Threshold | Gate |
|---|---|---|---|---|---|
| **OAA** (OF + IF) | `Defense_Combined_By_Pos.out_made - out_prob` SUM | higher_better | yes | ±2 plays | ≥10 plays in window |
| **React P25** | `Tracking_Defensive_Metrics.reaction_4mph` percentile | lower_better | no | ±0.05s | ≥10 Tier 1 plays |
| **TopSpd P95** | `Tracking_Defensive_Metrics.top_speed` percentile | higher_better | no | ±1.0 mph | ≥10 Tier 1 plays |
| **Arm P99** | `Tracking_Defensive_Metrics.arm_strength` percentile | higher_better | no | ±2.0 mph | ≥10 throws (≥ floor) |
| **PAA/EO** | per-play ratio | higher_better | no | ±0.05 | ≥10 plays |

**Decisions to confirm with user before coding (post design-doc):**

1. Should we flag IF and OF separately or together? (Recommendation:
   separately — IF coaches review IF data, OF coaches review OF data)
2. Cumulative OAA at 14 days: how do we set the threshold? ±2 plays
   seems aggressive — but for a fielder making ~10-15 plays in 14 days,
   ±2 is meaningful signal. Confirm.
3. Should we add Exch P10 + UseReact P25 + AccelCU/CD P75? Coaches use
   them in KPI weekly but the 14-day Tier 1 gate may be too thin.

**Step 3: Write the SQL**

Mirror `intangibles/src/fielding_tracker_data.py` patterns exactly.
Same Tier 1 6-term gate. Same per-fielder PERCENTILE_CONT for the
percentile metrics. Same `DCBP.out_made - DCBP.out_prob` SUM for OAA.

Apply the Alvaro roster gate to the active-fielders CTE (per
`drift_catcher.py` line ~63 pattern):

```sql
WITH active_fielders AS (
    SELECT DISTINCT tdm.groundcontrol_id AS fielder_id
    FROM Astros.Tracking_Defensive_Metrics tdm
    JOIN Astros.Schedule_View sv ON tdm.sched_id = sv.sched_id
    JOIN MLBAM.Teams ft ON tdm.fielding_team_id = ft.team_id AND ft.season = sv.year
    JOIN Astros.Players rpl ON rpl.groundcontrol_id = tdm.groundcontrol_id
    JOIN MLB_eBis.PP_MASTER rpm ON rpm.player_id = rpl.ebis_id
    WHERE sv.sched_date BETWEEN :week_start AND :week_end
      AND sv.year = :season
      AND sv.sched_type = 'R'
      AND tdm.pos_id IN (3, 4, 5, 6, 7, 8, 9)
      AND ft.org_abbrev = 'HOU'
      AND rpm.ORG_LK = 'hou'
      AND rpm.EMPLOYEE_FLG = 0
      AND COALESCE(rpm.MNROSTERSTATUS_LK, rpm.MJROSTERSTATUS_LK)
          NOT IN ('rel','fa','vol','dis','ti','RES','REL','FA','VOL','DIS','TI','res')
)
SELECT ...
```

**Step 4: Add the metric configs to drift_thresholds.py**

Mirror the existing pattern:

```python
"oaa_inf": {
    "label": "OAA (IF)",
    "threshold": 2.0,
    "direction_lower": "off",
    "direction_higher": "good",
    "higher_better": True,
    "fmt": ".1f",
    "unit": "plays",
    "volume_gate": 10,
    "baseline_kind": "player_season",
},
"react_inf_p25": {
    "label": "React P25 (IF)",
    "threshold": 0.05,
    "direction_lower": "good",
    "direction_higher": "off",
    "higher_better": False,
    "fmt": ".3f",
    "unit": "sec",
    "volume_gate": 10,
    "baseline_kind": "player_season",
},
# ... etc per metric in the inventory above
```

**Step 5: Wire into drift_alert.py**

Read: `pd-goals/scripts/drift_alert.py`. Locate where `drift_catcher`
is imported and called. Add a parallel block for `drift_fielding`:

```python
from src.drift_fielding import get_fielding_drift

# ... in main() ...
fielding_flags = get_fielding_drift(
    season=season,
    mode=mode,
    from_year=from_year,
    to_year=to_year,
)
# Append to the master flag list for rendering / Slack delivery / CSV
```

Add a new section header to the PDF render (Fielding) following the
existing pattern. Add Good / Bad split logic.

Update the glossary in `_build_glossary` with one-liner per metric.

**Step 6: Smoke test**

```bash
cd pd-goals
python scripts/drift_alert.py --season 2026 --csv out_fielding.csv --no-deliver
```

Expected output:
- CSV contains rows from all 5 domains (hitting, pitching, BR, catcher, fielding)
- Fielding flags include realistic player names + level + metric + delta
- No SQL errors in stdout
- No empty fielding section if there are real flags

**Step 7: Commit**

```bash
git add pd-goals/src/drift_fielding.py pd-goals/src/drift_thresholds.py pd-goals/scripts/drift_alert.py
git commit -m "feat(pd-flag-tracker): add fielding drift domain

New drift_fielding.py module mirrors drift_catcher.py / drift_br.py
shape. Flags OAA, React P25, TopSpd P95, Arm P99, PAA/EO drift in
L14 window vs player_season baseline.

Six surface map in rules/pd-goals-flag-tracker.md updated separately.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push
```

**Step 8: Update the rules file**

Modify: `.claude/rules/pd-goals-flag-tracker.md` — add fielding to the
domain inventory. Sync to all 4 worktrees per `slack-channels-sync.md`
pattern.

---

## Verification checklist (manual, post all 5 tasks)

Run through this in order on the deployed app. Don't claim done before
every box is green.

- [ ] **App, default-load:** Open a player with goals. L14 column visible
  by default. Sidebar toggle shows ON for Last 14 Days.
- [ ] **App, cumulative goal:** Pick a player with a NetK or OAA goal.
  Confirm L14 column renders `+X last 14d (+Y% gap closed)`.
- [ ] **App, rate goal:** Same player. Different goal (K%, FF Velo,
  PAA/EO, React). Confirm L14 column renders raw value + percentile +
  sample size (unchanged behavior).
- [ ] **App, target=0 goal:** A PAA/EO goal with target=0. L14 shows raw
  delta only, no parenthetical.
- [ ] **App, already met:** A player who's past their target. L14 shows
  `MET +X cushion last 14d`.
- [ ] **App, no L14 data:** A player who had zero observations in last
  14 days. L14 shows `— last 14d`.
- [ ] **PDF, same battery as app:** Generate the PDF for the same player.
  L14 column in PDF matches the app for every goal class.
- [ ] **PDF, page layout intact:** No overlap, no clipping, no font
  size regressions from longer strings.
- [ ] **Flag Tracker, fielding section:** Run `drift_alert.py --no-deliver`.
  CSV has fielding rows. Slack PDF preview (`--dry-run`) shows fielding
  section with Good / Bad split.
- [ ] **No regression on other domains:** Hitting / pitching / BR /
  catcher sections still render correctly in flag tracker PDF.
- [ ] **No regression on Compliance tab:** Compliance still loads, still
  shows Met / Close / Off correctly. (Compliance is OUT of scope but
  we have to not break it.)

---

## What NOT to do (BLOCKING)

- **Don't add L14 to the Compliance tab.** Boss said "later." Do not
  preemptively scope-creep.
- **Don't add L14 highlight to the rolling chart.** Boss said "we can
  already see existing one." Rolling chart shows the daily-grain
  trajectory; L14 highlight would be redundant.
- **Don't add a custom-date-range UI.** Custom dates exist already
  (`selected_dates` toggle). L14 is fixed at last-14-days.
- **Don't pool L14 percentiles against an L14-only pool.** Use the
  season pool. Matches individual OF/IF/hitter/pitcher KPI weekly
  reports. Avoids weekly color jitter.
- **Don't add a minimum sample size for the L14 column.** PD Goals has
  no player minimum. Inherit the rule.
- **Don't divergence the cumulative SUM math between app and PDF.**
  Single helper, called from both. App ↔ Report parity is BLOCKING
  per CLAUDE.md rule #11.
- **Don't ship the fielding drift module without verifying the
  6-term Tier 1 gate matches `intangibles/src/fielding_tracker_data.py`
  exactly.** Mirror canonical per `pd-goals-flag-tracker.md` BLOCKING.
- **Don't extrapolate cumulative L14 to extrapolate season pace.** The
  helper computes `% of remaining gap closed`, NOT season pace. Season
  pace extrapolation was option C in the brainstorm; rejected (user
  picked E = raw + gap %).
- **Don't claim done before walking the verification checklist.** Per
  `superpowers:verification-before-completion` rule.
