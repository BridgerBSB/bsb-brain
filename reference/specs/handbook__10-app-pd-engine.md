# App: PD Engine (Goals + Org Board + Transition)

PD Engine is the Player Development workflow app. It hosts three
distinct surfaces under one Streamlit deployment:

1. **PD Goals** --- per-player goal tracking with percentile-based
   progress reporting
2. **Org Board** --- live HOU org roster as a kanban-style board with
   per-player drill-down and per-team views
3. **Transition Reports** --- a questionnaire app for player level
   moves, with submission → parquet pin → reportlab PDF → Slack
   delivery, all in-process on Posit Connect

Plus a dozen periodic CLIs (combined KPI stapler, drift alerts, org
KPI, mock-goal generation, one-off draft analyses).

| | |
|---|---|
| **Branch** | `feature/pd-goals` |
| **Worktree** | `C:\Users\<user>\bsb-resources` (THIS repo --- main worktree) |
| **App directory** | `pd-goals/` |
| **Posit Connect URL** | `connect2.astros.com/pd-engine/` |
| **App GUID** | `79f52369-...` |
| **Status** | LIVE |

## What it ships

| Surface | Type | Cadence |
|---|---|---|
| **PD Goals page** | Per-player goals with progress bars, rolling charts, percentile context | Live |
| **Transition page** | Form: select player → fill questionnaire → preview PDF → submit → Slack | Live (user-triggered) |
| **Transitions View page** | Browse / filter all submitted transition reports | Live |
| **WPA Plays page** | High-leverage WPA plays by player + game | Live |
| **Org Board page** | Tiered kanban (FCL → A → A+ → AA → AAA → MLB on top, DSL + IL/DFA on bottom). Cards expand inline with vitals + level history. | Live |
| **Team View page** | Per-affiliate roster with transaction timeline + age summary | Live |
| **Combined KPI PDF** (CLI) | One per-affiliate-level PDF stitching all 6 weekly KPI reports into a unified document | Sunday after the 6 weekly KPIs |
| **Org KPI report** | Combined hitting + pitching + fielding + BR + catcher org-level KPI PDF | Periodic |
| **Drift alert** (CLI) | Weekly Slack drift report --- detects when players drift on hitting/pitching metrics | Weekly |

## Key files

```
pd-goals/
├── PD_Engine.py                 # Landing page (4 cards: PD Goals, Transition, Org Board, more)
├── manifest.json
├── pages/
│   ├── 1_PD_Goals.py            # Player goals view
│   ├── 2_Transition.py          # Transition report submission form
│   ├── 3_Transitions_View.py    # Browse submitted transitions
│   ├── 4_WPA_Plays.py
│   ├── 5_Org_Board.py           # Kanban-style org roster (~1300 lines)
│   └── 6_Team_View.py           # Per-affiliate detail (~1200 lines)
├── data/
│   ├── slack_channels.csv       # *** Single source of truth for ALL channel routing across all 4 apps
│   └── goals.csv                # Goals roster source (mirrored to pin)
├── assets/
│   ├── astros_logo.png
│   ├── sugarland_logo.png
│   └── ...                      # Affiliate logos
├── src/
└── scripts/
└── connect_pins/                # Goals pin refresh (Connect-scheduled)
```

### Source modules

| File | Purpose |
|---|---|
| `src/database.py` | DB connection (dual-mode FreeTDS / ODBC 17) |
| `src/roster.py` | Active HOU roster query (Alvaro pattern) |
| `src/goals_loader.py` | Read goals from pin → CSV fallback |
| `src/goal_parser.py` | Parse natural-language goal strings into typed metric goals |
| `src/goals_template.py` | Goal template / formatting |
| `src/metrics.py` | Per-metric value computation (Damage formula, fielding metrics, hit specs) |
| `src/percentiles.py` | Percentile distributions per metric per level |
| `src/stats.py` | PD Goals bar chart query (current-window value per player) |
| `src/rolling_stats.py` | Rolling chart data (past N games for trend display) |
| `src/rolling_chart.py` | Rolling chart helpers (cumulative-at-tick) |
| `src/drift_hitting.py` | Hitting drift detection |
| `src/drift_pitching.py` | Pitching drift detection |
| `src/drift_thresholds.py` | Drift threshold constants |
| `src/bat_speed_clean.py` | Canonical bat speed cleaning helper (mirrors Barrelsville copy) |
| `src/org_kpi_data.py` | Org-level KPI report data (hitting + pitching + fielding) |
| `src/org_kpi_report.py` | Org KPI PDF generator |
| `src/transition_pins.py` | Pin read/write for transition_reports + transition_drafts |
| `src/transition_pdf.py` | Transition PDF generator (one-page card with header bar + 6 O/D/BR boxes) |
| `src/transition_channels.py` | Channel resolver for transition delivery |
| `src/transition_slack.py` | Logic App POST wrapper |
| `src/transition_view_data.py` | View-page query helpers (3-tab browse) |
| `src/transactions_data.py` | TR_HISTORY query helpers (org board + team view) |
| `src/wpa_plays_data.py` | WPA query data |
| `src/wpa_plays_report.py` | WPA report generator |
| `src/pins_config.py` | Pin board connection (`allow_pickle_read=True` for joblib pins) |

### CLI scripts

| Script | Purpose |
|---|---|
| `scripts/generate_combined_kpi.py` | **The KPI stapler** --- combines the 6 weekly KPI PDFs into ONE per-affiliate-level PDF and delivers to affiliate channels |
| `scripts/generate_org_kpi.py` | Org-level KPI report (hitting + pitching + fielding + BR + catcher) |
| `scripts/pin_goals.py` | Refresh `zbridger/pd_goals_data` pin from CSV (Connect-scheduled or manual) |
| `scripts/clean_transition_submissions.py` | Maintain the transition_reports pin (--list / --delete <uuid> / --clear-all --confirm) |
| `scripts/drift_alert.py` | Weekly drift report (Slack delivery) |
| `scripts/generate_goals_batch.py` | Batch generate per-player goal cards |
| `scripts/test_goal_parsing.py` | Goal parser test harness |
| `scripts/ss_draft_analysis.py` | HS first-round SS progression analysis (one-off) |
| `scripts/hs_firstround_2025_placement.py` | 2025 HS first-rounder placement (one-off) |
| `scripts/splitter_analysis.py` | Splitter analysis (one-off) |
| `scripts/diagnose_of_data.py`, `generate_of_percentile_report.py`, `generate_of_bar_report.py` | OF metric diagnostics + reports |
| `scripts/generate_org_2b_3b_sb.py` | Org-level 2B/3B/SB analysis |
| `scripts/generate_wpa_plays.py` | WPA plays CLI |
| `scripts/compare_tracker_vs_org_kpi.py` | Three-surface parity diagnostic |

## PD Goals

### What it does

For each HOU active-roster player, parse their goal strings (free-form
text like "Increase FF Velo to 93mph" or "Decrease Whiff% to 25%"),
compute the player's current value for that metric over the current
season window, and display:

- A progress bar (current value vs target)
- A rolling chart (last N games of the metric)
- A percentile context (what percentile this value sits at within the
  level pool)
- The goal text itself

Goals are stored in `pd-goals/data/goals.csv`, mirrored to the
`zbridger/pd_goals_data` pin (refreshed every 6 hours by
Connect-scheduled `pin_goals.py`).

### Goal types

Three categories --- detailed in `.claude/rules/pd-goals-unmeasurable.md`:

1. **MEASURABLE** --- metric exists in DB, wired in `stats.py`
   (e.g. `ff_velo`, `whiff_pct`, `arm_strength`, `top_speed`)
2. **OBJECTIVE but UNMEASURABLE** --- real metric but no DB source
   yet (e.g. lean mass, force-deck CI100, body weight). Tagged
   `direction=DESCRIPTIVE` for now.
3. **SUBJECTIVE** --- no numeric metric possible
   (e.g. "Improve soft skills", "Maintain weight", "Improve
   eccentrics on Force Decks"). Always `direction=DESCRIPTIVE`.

### Goal parser keywords (subjective)

The parser recognizes specific keywords as inherently subjective and
ALWAYS routes them to `DESCRIPTIVE` regardless of any numeric value
in the goal text. Full list in `pd-goals-unmeasurable.md`. Examples:
"twitch", "eccentric", "Force Deck"/"Force Plate", "explosiveness",
"shoulder scores", "Maintain Velocity throughout", "internal clock".

### Recently promoted to measurable (Apr 7 2026)

Some goals that used to be subjective got concrete metric backing:

| Old form | New form | Metric |
|---|---|---|
| "Baseline Organizational Goals" | "Increase FPinZ% to 57%" | `fpinz_pct` |
| "Maintain Velocity throughout outings" | "Increase FF Velo to 93mph" | `ff_velo` |
| "Continue defensive progress" | "Increase Arm to 85mph in IF" | `arm_strength` (P99) |
| "Develop FT 10 IVB x 15 HB" | "Avg FT IVB above 10 and HB above 15" | `ft_ivb` + `ft_hb` |

## Transition Reports

### What it does

A coordinator submits a transition report when a player moves between
levels (call-up, send-down, release). The form has 20+ fields covering
hitting/pitching/fielding/baserunning observations. On submit:

1. Append a row to the `zbridger/transition_reports` pin
2. Render a one-page reportlab PDF (header bar + 6 O/D/BR boxes)
3. POST to the Logic App → Slack delivery to:
   - The player's `zzz_<name>` coach channel
   - The promoted-to affiliate's general channel (e.g. `z1_sugar_land`)
4. Cleanup: delete the draft pin entry, delete the temp PDF
5. Show success status to the user

All in-process on Posit Connect. No CLI step.

### Architecture --- the in-app submission pattern

```
┌────────────────────────────────────────────┐
│ Streamlit app on Posit Connect              │
│                                             │
│ pages/2_Transition.py                       │
│   ├── form widgets                          │
│   ├── Save Draft button   ──┐              │
│   |__ Submit button       ----+--> handlers │
│                              |               │
│ src/transition_pins.py    <--+  pin RW       │
│ src/transition_channels.py <-+  routing      │
│ src/transition_pdf.py     <--+  reportlab    │
│ src/transition_slack.py   <--/  Logic App    │
│                                             │
└─────────┬───────────────────────────────────┘
          │
          ▼  parquet pin + Logic App
   Pins: zbridger/transition_reports
          zbridger/transition_drafts
   Slack: zzz_<name> + affiliate channel
```

This is the canonical reusable architecture for any future internal
form app (incident reports, weekly coach notes, scout reports). Full
spec: `.claude/rules/in-app-submission.md`.

### Pitcher variant (May 3 2026)

`report_type` field detects pitchers automatically from
`POSITION_LK` (TWP also routes to pitcher) and switches to a
pitcher-specific PDF layout with conditional question blocks. Browse
view branches per `report_type`. PDFs include role badge.

### Key invariants

- Two parquet pins: `zbridger/transition_reports` (final submissions)
  + `zbridger/transition_drafts` (work-in-progress drafts).
- Joblib bundles for both --- `allow_pickle_read=True` required on
  the pin board.
- Both pins use a canonical column list. `_conform(df, cols)` helper
  adds missing columns as NaN, drops extras --- prevents schema drift
  from breaking old rows.
- Logic App payload: `{"channel": cid, "filename": fn, "pdf": b64}`.
  Field names BLOCKING.
- Test mode toggle: a "Test mode" checkbox routes ALL deliveries to
  `pd-automation-test` only. Default off.
- Cleanup CLI ships from day one: `scripts/clean_transition_submissions.py`
  with `--list`, `--delete <uuid>`, `--clear-all --confirm`.

## Org Board (`5_Org_Board.py`)

Live HOU org roster as a tiered kanban. May 2026 ship.

### Layout (locked May 7 2026)

```
Top row (6 columns, ascending toward MLB):
┌──────┬──────┬──────┬──────┬──────┬──────┐
│ FCL  │  A   │  A+  │  AA  │  AAA │ MLB  │
└──────┴──────┴──────┴──────┴──────┴──────┘

Bottom row (3+3 split, aligned with top via repeat(6, 1fr)):
┌──────────────────────┬────────────────────┐
│  DSL                 │  IL / DFA          │
│  3-cards-per-row     │  3-cards-per-row   │
└──────────────────────┴────────────────────┘

Above the grid: Recent Moves horizontal timeline (7-day window)
Right rail (>1280px): Total Roster · Showing · By Level · footer
```

### Two roster sources, EBIS canonical

| Need | Source | Notes |
|---|---|---|
| Active HOU players | `src.roster.get_roster()` (Alvaro pattern) | Returns 230+ ACT/OPT/OUTRT players. EXCLUDES IL statuses. |
| IL/DFA players | `_load_il_sus_roster()` (local SQL in 5_Org_Board.py) | Mirrors get_roster shape but INCLUDES IL/REHAB/DFA |

::: blocking
**IL DEDUPE INVARIANT:** After loading both, build
`il_gc_ids = set(il_roster_full["groundcontrol_id"])` and EXCLUDE
those gc_ids from `roster_full`. IL players appear ONLY in the IL
column, never duplicated in their nominal level column.
:::

::: blocking
**DRAWER LOOKUP MUST CHECK BOTH ROSTERS.** When `?drawer=GC_ID` is
set, the lookup falls through both rosters --- otherwise every
IL/REHAB/DFA card opens an empty drawer.
:::

### IL/DFA detection

PP_MASTER `MNROSTERSTATUS_LK` / `MJROSTERSTATUS_LK` codes:

| Bucket | Codes | Label |
|---|---|---|
| Injury — short-term | `7DL`, `DL`, `10D`, `15D` | `IL` (yellow) |
| Injury — long-term | `60D`, `FSIL` | `IL-60` (red) |
| Rehab | `7RH`, `15R`, `60R` | `REHAB` (navy) |
| Designated for assignment | `DFA` | `DFA` (orange) |

Excluded: `RES` (paternity/bereavement), `VOL` (historical), `DIS`
(suspended).

### Card expansion (Option B, May 8 2026)

Cards in both Org Board and Team View are native HTML
`<details>`/`<summary>` elements. Click summary → expands inline
below the card. No URL change, no Streamlit rerun, no white flash.

JSON blob + JS lazy-render: pre-rendered HTML history strings ship
as JSON; capture-phase `toggle` event listener targets
`window.parent.document` and replaces the placeholder when a
`<details>` opens.

::: blocking
**Script injection MUST use `st.components.v1.html`, NEVER
`st.markdown(unsafe_allow_html=True)`.** Streamlit strips
`<script>` tags from `st.markdown` as a security default; the
listener never reaches the DOM and every card opens to "Loading…"
forever. `st.components.v1.html(html, height=0)` runs JS in an
iframe, so reach the parent-frame DOM via `window.parent.document`.
Fixed May 8 2026 commit `12e6194`.
:::

### TR_HISTORY data

Source: `MLB_eBis.TR_HISTORY` joined to `MLB_eBis.TR_NAME_LKUP` for
human-readable transaction name + category.

CLUB_LK → level_code mapping has TWO sources:

1. `LEVEL_CLUB_MAP` (HOU canonical, 9 hardcoded entries) for the 9
   HOU clubs.
2. `load_global_club_map()` (queries `MLB_eBis.GBL_CLUB_LKUP WHERE
   ACTIVE_FLG = 1`) for cross-org transactions (trades, waiver
   claims, amateur signings reference clubs from other orgs).

Resolution order: LEVEL_CLUB_MAP first (faster, HOU-canonical), global
map fills the gaps.

## Team View (`6_Team_View.py`)

Per-affiliate detail page. Lists the roster + transaction timeline +
average age (computed from `team_roster["age"].mean()`, truncated to
one decimal --- per the never-round-up rule).

## Cross-app integration: the goals pin

`pd-goals/scripts/pin_goals.py` writes `zbridger/pd_goals_data` (a
parquet pin). Every other app reads from it:

- **Arm Farm** postgame report displays the player's pitcher goals on
  page 1.
- **Barrelsville** postgame may eventually do the same for hitter goals.
- **PD Goals page** (this app) reads its own pin.

::: blocking
**Three-app integration via pin --- not via cross-worktree imports.**
NEVER use `sys.path.insert` to reach across worktrees. The personal
laptop has worktrees as siblings; the work laptop doesn't. The pin
is the canonical cross-app data exchange layer.
:::

## Channel routing

`pd-goals/data/slack_channels.csv` is the **single source of truth**
for channel routing across ALL FOUR apps. It's mirrored across all
four worktrees AND inside `intangibles/data/slack_channels.csv` (a
fallback path that never fires at runtime but stays in sync just in
case).

Per CSV schema:

```
groundcontrol_id, player_name, channel_name, channel_email,
channel_id, channel_type, z_channel_id
```

- `channel_id` = coach channel (`zzz_<name>`)
- `z_channel_id` = athlete channel (`z_<name>`)

::: blocking
**FIVE COPIES MUST STAY IN SYNC.** When adding/editing/removing rows,
update ALL FIVE copies in the same operation:

1. `bsb-resources/pd-goals/data/slack_channels.csv`
2. `bsb-wt-bullpen/pd-goals/data/slack_channels.csv`
3. `bsb-wt-hitting/pd-goals/data/slack_channels.csv`
4. `bsb-wt-intangibles/astros-intangibles/pd-goals/data/slack_channels.csv`
5. `bsb-wt-intangibles/astros-intangibles/intangibles/data/slack_channels.csv`

Verify with `wc -l` --- all 5 line counts MUST match. CRLF line
endings preserved. See `.claude/rules/slack-channels-sync.md` for the
full procedure.
:::

## The Combined KPI Stapler

`scripts/generate_combined_kpi.py` is the cross-worktree PDF stapler
that owns affiliate-channel delivery for the WHOLE KPI weekly family.

After the 6 weekly KPI runs finish, the stapler:

1. Walks the four worktree output directories to find the per-level
   PDFs (Hitter, Pitcher, OF, IF, BR, Catcher).
2. Trims each PDF's individual title page (the per-domain cover).
3. Prepends ONE combined cover page (affiliate logo + "Astros Weekly
   KPI Reports" branded title).
4. Staples the trimmed PDFs together with `pypdf`.
5. Delivers the combined PDF to the affiliate channel.

| Level | Combined PDF goes to | Channel name |
|---|---|---|
| `mlb` | `C0ABHSF6SCA` | pd-automation-test (overflow) |
| `aaa` | `GFYF1JQR1` | z1_sugar_land |
| `aax` | `CFXS0BMLG` | z2_corpus_christi |
| `afa` | `GFYF4K3GB` | z3_asheville |
| `afx` | `GFYJ94D2N` | z4_fayetteville |
| `rok` | `C0516HKL6KX` | wpb_complex (FCL) |
| `dsl` | `CFZLA3W2K` | z8_dominican_academy |

::: blocking
**This is the ONLY place the affiliate channel map exists.** Never
re-add `AFFILIATE_CHANNEL_IDS` to any of the 6 individual KPI scripts
--- that's how the spam comes back. Each individual script has a
tripwire comment in place of the deleted block; if a future agent
removes the comment AND re-adds delivery, this rule's been violated.
:::

## Where to look next

- **Chapter 11** for the cross-app patterns (three-surface parity, in-app submission, dual query path).
- **Chapter 13** for delivery + the combined KPI stapler.
- `.claude/rules/pd-goals.md` --- the canonical app rule file (large).
- `.claude/rules/in-app-submission.md` --- the form pattern.
- `.claude/rules/org-board.md` --- the kanban architecture spec.
- `.claude/rules/combined-kpi-stapler.md` --- the stapler architecture.
- `pd-goals/PD_Engine.py` --- start here when reading code.
