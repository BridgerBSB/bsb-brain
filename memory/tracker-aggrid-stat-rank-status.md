---
name: tracker-aggrid-stat-rank-status
description: "Affiliate tracker \"Stat (Rank)\" AgGrid numeric-sort pilot (Barrelsville) + DSL split label fix — status, design, open items"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3ed1b21f-539a-4c4a-ab38-1ca5d3b9c935
---

# Affiliate Tracker — AgGrid "Stat (Rank)" sort pilot + DSL label fix (June 2026)

## ✅ RESOLVED Jun 4 2026 — Barrelsville USER-VERIFIED ("DSL named correctly", Jack Moss A+ ABs showing)

**The real bug (took the whole session to find): the DSL label was FROZEN in a
pin.** `get_org_rankings_dsl_split` is pin-backed (`PREFIX_ORGS_DSL_SPLIT`) and
did `if _pinned is not None: return _pinned` BEFORE ever calling
`_resolve_dsl_team_label`. The `dsl_team_label` column was computed at
pin-BUILD time (inside `_get_single_level_dsl_split_org_stats`) with the OLD
`{599,10000055}` fallback → "HOU - Team 601" baked into the pin. No code fix or
redeploy could change it — the resolver was never reached. (The old design note
"DSL split = live-DB only" was STALE; it got pinned later via
`docs/plans/2026-05-27-dsl-split-pinning-goal.md`.)

**Fix (all 5 trackers): re-derive `dsl_team_label` from the pinned `dsl_team_id`
on every read**, right after the pin returns — so a derived presentation value
is NEVER frozen; label changes take effect on deploy with ZERO re-pin.
Commits: Barrelsville `79e7ca64`, Arm Farm `4e5e14e9`, Intangibles `ba19516b`.

**LESSON (worth a rule, not yet written): never compute a derived/presentation
value INSIDE a pinned function and store it — derive it at READ time.** If you
see a stale label/category/color surviving correct code + correct deploy,
suspect a pin that froze the computed value. Same trap could exist for any
other derived column stored in a tracker pin.

**Also wrong this session (corrected):** I twice told the user "no repin needed"
without realizing the DSL split was pinned — that sent us in circles. The
re-derive fix makes "no repin needed" TRUE going forward, but the labels were
broken precisely because they were pinned.

### Still OPEN after /clear
- **Redeploy Arm Farm + Intangibles** (work laptop) to get DSL names + Stat(Rank)
  there: `cd ~/bsb-wt-bullpen && git pull` (4e5e14e9);
  `cd ~/bsb-wt-intangibles/astros-intangibles && git pull` (ba19516b).
- **Org-column first-paint flash** (renders 4th col on load, settles after) —
  cosmetic streamlit-aggrid quirk in `_render_stat_rank_aggrid`; NOT chased yet.
  User aware; offered to fix on request.
- Optionally graduate the "don't pin derived values" lesson to a `.claude/rules/` doc.

---

PILOT SHIPPED + USER-LIKED on Barrelsville hitter (`feature/barrelsville`).
**ROLLED OUT to all 4 remaining trackers June 2026** (Arm Farm, BR, Fielding
OF+IF, Catcher) — committed + pushed, all 8 files ast.parse-clean. Awaiting
work-laptop redeploy + verify (esp. Save Screen). No repins (pure display /
live-DB). Porting spec lives in `.claude/rules/tracker-aggrid-stat-rank.md`
(synced all 4 worktrees).

### Rollout commits
- Arm Farm (`feature/bullpen-reports`): **`fa19f55b`**
- BR + Fielding + Catcher (`feature/astros-intangibles`): **`ad6feafb`** (one commit, shared worktree)

### Per-tracker adaptations made during the port (NOT in Barrelsville)
- **Arm Farm**: `_render_stat_rank_aggrid` got an `ip_thirds` branch (IP/IP-S/AOL
  render baseball notation `X.Y`, where `_stat_fmt_string` returns None);
  `_AGG_INFO_NUM_FORMATTER` extended so IP uses `toFixed(1)` (fake-decimal float)
  not `Math.round`. Info cols: Player/Org/Level/Age/Pos/IP/BF/Pitches
  (numeric: Age/IP/BF/Pitches). Symbol names identical to Barrelsville.
- **BR**: string-fraction metrics `ft3_frac`/`s2h_frac` ("3/9") — numeric sort
  key = the success numerator, display = fraction string. Helper is NESTED
  inside `render()` (BR/Fielding/Catcher helpers are nested, not module-level
  like Barrelsville). `HIGHER_IS_BETTER_MAP` via `tdata.HIGHER_IS_BETTER_MAP`.
  Info cols: Runner/Org/Level/Age/Pos/Bases On/Pitches.
- **Fielding**: `render(domain)` serves both OF + IF → AgGrid keys
  domain-suffixed (`agg_f_*_{domain}`). `hib = tdata.get_higher_is_better_map(domain)`.
  Cumulative-SUM (OAA/PAA/RAA) color via the helper's `has_color` gate (they're
  in the hib map). Numeric-dtype fallback added so per-position supplementary
  info cols also get blank-on-NaN formatting.
- **Catcher**: cumulative-SUM (NetK/FramRAA/BlockRAA/SurPP) color via `has_color`.
  Info cols: Org/Level/Age/Pos/Games/Pitches.
- All 4: 4 gate sites each (HOU sub-tab, HOU-vs, Org ALL, HOU-by-level inline);
  Level Pools left on st.dataframe; other 3 display modes byte-identical;
  resilient `try/except` import + `_AGGRID_AVAILABLE` fallback; all 3 BLOCKING
  gotchas (explicit height, NaN-safe numeric formatter, HOU bold on info cols).
- Benign: BR's `_resolve_dsl_team_label` docstring still says "GBL_CLUB_LKUP";
  SQL is correct (MLBAM.Teams). Cosmetic only.

## Problem 1 — "Stat (Rank)" lex-sort ("98 > 100")

`Stat (Rank)` is the DEFAULT tracker display mode **by user request** (boss
ask). Each metric cell is a STRING `"9.8% (12)"`, and `st.dataframe` sorts
strings lexicographically → `"98" > "100"`. The other 3 modes (`Stat`,
`Rank`, `Percentile`) store numeric values and sort fine. `st.dataframe`
**cannot** numeric-sort a combined "value (rank)" cell (formatter is scalar,
sort uses the underlying scalar). Padding breaks on negatives. AgGrid is the
only clean fix (its `valueFormatter` sees the whole row, so the cell can stay
numeric for sort while displaying "value (rank)").

### Fix — surgical AgGrid, ONLY for Stat (Rank)
`barrelsville/pages/2_Affiliate_Tracker.py`:
- `_render_stat_rank_aggrid(display_df, source_df, ranked_df, metric_keys, *, highlight_hou, qualified_mask, level_width, key)` helper.
- Underlying metric cell = NUMERIC value (numeric sort). Hidden sibling fields
  per metric: `{label}__disp` (Python-formatted value string), `{label}__rank`,
  `{label}__bg` (precomputed hex via existing `_get_bg_color`/`percentile_to_color`).
- Generic JsCode (one for all metric cols, reads `params.colDef.field`):
  `_AGG_VALUE_FORMATTER` builds "disp (rank)"; `_AGG_CELL_STYLE` sets bg + bold-if-`__hou`.
- Resilient import: `try: from st_aggrid import AgGrid, JsCode, GridUpdateMode` →
  `_AGGRID_AVAILABLE`. Each of the 4 render sites gated:
  `if at_display_mode == "Stat (Rank)" and _AGGRID_AVAILABLE: <aggrid> else: <existing st.dataframe>`.
  If st_aggrid fails to import on Connect, falls back to st.dataframe (no crash).
- Other 3 modes' code paths are byte-identical (untouched).
- 4 gated sites: HOU sub-tab, HOU-vs sub-tab, Org Rankings ALL, HOU 7-row.
  Level Pools left on st.dataframe (never sorted).
- Dependency added: `streamlit-aggrid>=1.0.5,<1.2.0` in
  `barrelsville/requirements.txt` (manifest pulls deps from requirements; no
  packages block to edit; page 2 already in files allow-list).

### Follow-on fixes (all shipped, all from user testing)
1. **First-load / mode-switch height clip** — `domLayout="autoHeight"`
   mis-measures the iframe on first paint + remount (bottom rows clipped until
   an interaction). Fix: explicit `height = 30 + rows*30 + 18` passed to AgGrid;
   removed autoHeight. (`eb9d138f`)
2. **"Invalid Number" in PA/AB/Pitches/Age** — numericColumn + NaN (partial/
   initial-load frame OR DSL sub-team rows) renders literal "Invalid Number".
   Fix: coerce numeric-info cols + `_AGG_INFO_NUM_FORMATTER` valueFormatter
   (blank on null/NaN/non-finite; integer except Age 1dp). GENERAL, not
   DSL-only. (`9f145dbf`)
3. **HOU rows not bold** — metric cells bolded HOU rows but info cols didn't,
   so rows looked un-bold vs Stat mode. Fix: `_AGG_INFO_BOLD_STYLE` cellStyle
   on info cols (bold if `__hou`; `startswith("HOU")` catches both DSL sub-team
   rows). (in `0f728992` range)

### Commits (feature/barrelsville)
`ee64426b` (AgGrid pilot) → `eb9d138f` (height) → `9f145dbf` (Invalid Number)
→ HOU-bold + DSL-labels (HEAD `0f728992`).

## Problem 2 — DSL split labels showed "ORG - Team <id>" not club names

Screenshot proved every org's DSL split row rendered `"HOU - Team 601"` /
`"Team 5005"` etc. — the "DSHOUB/DSASOR" I'd claimed was NOT live.

Root cause: the split GROUPS by MLBAM `team_id` (601 Blue / 5005 Orange), but
`_load_dsl_team_labels` + the hardcoded fallback were keyed on
`GBL_CLUB_LKUP.CLUB_LK` (599 / 10000055) — a different id space, no bridge
column → never matched → "Team N".

### Resolved data (from `sql-queries/dsl-team-label-mismatch.sql`, committed `15275d9a`)
- `MLBAM.Teams`: team_id **601 = "DSL Astros Blue"**, **5005 = "DSL Astros Orange"**
  (`name`/`name_short`/`name_display_full` all = full club name; `league='DSL'`).
- `GBL_CLUB_LKUP`: CLUB_LK 599 = Blue (CLUBSHORTNAME DSHOUB), 10000055 = Orange
  (DSASOR). No MLBAM-team_id column to bridge.

### Fix (Barrelsville `src/tracker_data.py`, in `0f728992`)
`_load_dsl_team_labels()` rewritten to source from `MLBAM.Teams`
(`SELECT team_id, name, season WHERE league='DSL'`), keyed on **team_id** (the
grouping key), latest-season name wins → resolves for all 30 orgs.
`_DSL_TEAM_LABELS_HOU_FALLBACK` re-keyed to `{601:"DSL Astros Blue",
5005:"DSL Astros Orange"}`. Renders "HOU - DSL Astros Blue/Orange". Live-DB,
no repin.

## OPEN / NEXT
1. **User redeploys all 4 apps** (work laptop): `cd ~/bsb-wt-bullpen && git pull`
   → redeploy Arm Farm; `cd ~/bsb-wt-intangibles/astros-intangibles && git pull`
   → redeploy Intangibles (covers BR + Fielding + Catcher). Barrelsville already
   shipped (pull `feature/barrelsville` if not yet redeployed). Then verify per
   tracker: numeric sort (100 > 98), no height clip, no "Invalid Number", HOU
   bold, DSL rows render "DSL Astros Blue/Orange", and **Save Screen**.
2. **Save Screen with AgGrid is the one open risk** (`tracker-aggrid-stat-rank.md`
   "OPEN" section + `tracker-save-screen.md`). AgGrid renders in an iframe and
   virtualizes rows; `window.print` may clip/capture poorly. UNSOLVED — tackle
   AFTER the rollout verifies. Candidate fixes: AgGrid print `domLayout`, native
   CSV/Excel export instead of print, or force all rows into DOM before print.
3. Done: rule doc already exists (`tracker-aggrid-stat-rank.md`, synced 4
   worktrees) — it's the porting spec. After redeploy verifies, optionally add an
   AgGrid addendum to `tracker-stat-rank-display.md`.

## Cross-refs
- [[dsl-org-split-design]] — the DSL split feature this corrects.
- `.claude/rules/tracker-stat-rank-display.md` — the Stat (Rank) mode (st.dataframe
  era); will need an AgGrid addendum after rollout.
- `.claude/rules/streamlit-tracker-column-pinning.md` — st.dataframe pinning
  (AgGrid uses native `pinned:'left'`, no 60% threshold problem).
- `.claude/rules/tracker-save-screen.md` — Save Screen (window.print); the
  AgGrid-iframe interaction is the open risk.
