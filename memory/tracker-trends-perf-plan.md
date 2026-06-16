---
name: tracker-trends-perf-plan
description: Trends-tab HOIST refactor — final architecture + exact code template for porting to remaining 4 trackers. PILOT SHIPPED + VERIFIED May 22 2026 on Fielding (407842f4 on feature/astros-intangibles). Read this BEFORE porting to Barrelsville / Arm Farm / BR / Catcher.
metadata: 
  node_type: memory
  type: project
  originSessionId: 0075168d-1280-4f02-a1f6-6185d9385ac1
---

# Affiliate Tracker — Trends Tab HOIST Refactor (May 22 2026)

## TL;DR for fresh-context Claude

User wanted shared selections across MoM/WoW/YoY sub-tabs in every
affiliate tracker. After 3 failed attempts the working architecture is
the **HOIST** pattern: render mode + multiselects ONCE above the sub-tab
strip. Each sub-tab reads from shared variables and renders only the
chart. **Pilot LIVE + VERIFIED on Fielding tracker (commit `407842f4`).**

**Next: port the same pattern to 4 remaining trackers:**

| Tracker | File | Worktree | Branch | Status |
|---|---|---|---|---|
| Barrelsville (hitter) | `barrelsville/pages/2_Affiliate_Tracker.py` | `bsb-wt-hitting` | `feature/barrelsville` | ✅ `4d9c492c` |
| Arm Farm (pitcher) | `bullpen-report/pages/3_Affiliate_Tracker.py` | `bsb-wt-bullpen` | `feature/bullpen-reports` | ✅ `564f74cc` |
| Intangibles BR | `intangibles/src/br_tracker_page.py` | `bsb-wt-intangibles/astros-intangibles` | `feature/astros-intangibles` | ✅ `555de449` |
| Intangibles Catcher | `intangibles/src/catching_tracker_page.py` | same | same | ✅ `555de449` |
| Intangibles Fielding (OF+IF) | `intangibles/src/fielding_tracker_page.py` | same | same | ✅ `407842f4` |

**ROLLOUT COMPLETE May 23 2026.** All 5 trackers ship the HOIST pattern.
User needs to `git pull` + redeploy on work laptop to verify in production.

Pin work for fielding raw-obs refactor is SEPARATE — see
`fielding-raw-obs-refactor-handoff.md` (work-laptop steps for the user
at the ballpark).

---

## The 3 fixes shipped on Fielding (port these in order)

### Fix 1 — Cache composite multi-year loaders

Hoist `_load_all_monthly` / `_load_all_weekly` / `_load_all_yearly` /
`_load_monthly_org` / `_load_weekly_org` / `_load_yearly_org` to MODULE
level (if not already) + decorate with `@st.cache_data(ttl=64800,
show_spinner=False)` + add explicit args (`domain`, `ha_split`, etc.)
so the cache key is correct.

**Why:** Previously uncached; re-ran concat on every page rerun even
when each per-year fetch was a cache hit. The dropdown filter loop
isn't slow — the COMPOSITE concat being uncached was.

### Fix 2 — `_prune_multiselect_state` helper with try/except defense

Add this module-level helper:

```python
def _prune_multiselect_state(key: str, valid_options) -> None:
    """Intersect st.session_state[key] with valid_options BEFORE the widget
    renders. Streamlit silently DROPS the entire multiselect selection when
    ANY saved value isn't in the current options= list. This preserves the
    subset that's still valid.

    try/except defense: when the same key is reused across sub-tabs
    (shouldn't happen with hoist, but defensive), silent-skip if widget
    already instantiated."""
    if key in st.session_state and isinstance(st.session_state[key], list):
        try:
            valid = set(valid_options)
        except TypeError:
            return
        try:
            st.session_state[key] = [v for v in st.session_state[key] if v in valid]
        except Exception:
            pass  # widget already instantiated this run; safe to no-op
```

### Fix 3 — HOIST the Trends widgets above the sub-tab strip

**THIS IS THE LOAD-BEARING FIX.** Without it, the user's primary
complaint ("names disappear when switching sub-tabs") doesn't resolve.

---

## EXACT HOIST RECIPE (verbatim template — adapt per tracker)

### Step 3a: Insert union-computation + hoisted widgets block

Find the `with tab_trends:` block. After all the `_*_result` data fetches
finish + `_trends_loading.empty()`, BEFORE the
`trends_wow, trends_mom, trends_yoy = st.tabs(...)` line, insert:

```python
        # =================================================================
        # HOISTED TRENDS WIDGETS (May 22 2026)
        # Mode + Players/Metrics (or Orgs/Org_Metrics) render ONCE above the
        # sub-tab strip. Each sub-tab below reads from these shared selections
        # so MoM/WoW/YoY share state by definition. Single widget per concern
        # — no DuplicateElementKey errors. Options = UNION across sub-tabs;
        # chart code silently skips players/orgs missing for a given grain.
        # =================================================================
        _player_names_all = full_df[[ID_COL, "player_name", "org"]].drop_duplicates(ID_COL) if (
            not full_df.empty and ID_COL in full_df.columns
        ) else pd.DataFrame(columns=[ID_COL, "player_name", "org"])

        def _hou_players_for(_df):
            if _df is None or _df.empty or _player_names_all.empty:
                return set()
            _merged = _df.merge(_player_names_all, on=ID_COL, how="inner")
            if "level_code" in _merged.columns:
                _merged = _merged[_merged["level_code"].isin(selected_level_codes)]
            if "org" in _merged.columns:
                _merged = _merged[_merged["org"] == "HOU"]
            return set(_merged["player_name"].dropna().unique()) if "player_name" in _merged.columns else set()

        def _orgs_for(_df):
            if _df is None or _df.empty or "org" not in _df.columns:
                return set()
            if "level_code" in _df.columns:
                _df = _df[_df["level_code"].isin(selected_level_codes)]
            return {o for o in _df["org"].dropna().unique() if o != "UNK"}

        def _metrics_for(_df):
            if _df is None or _df.empty:
                return set()
            return {lbl for lbl in _ALL_METRIC_LABELS
                    if _METRIC_LABEL_TO_KEY.get(lbl) in _df.columns}

        _trends_players_union = sorted(
            _hou_players_for(_monthly_result[0])
            | _hou_players_for(_weekly_result[0])
            | _hou_players_for(_yearly_result[0])
        )
        _trends_metrics_union = sorted(
            _metrics_for(_monthly_result[0])
            | _metrics_for(_weekly_result[0])
            | _metrics_for(_yearly_result[0])
        )
        _trends_orgs_union = sorted(
            _orgs_for(_monthly_org_result[0])
            | _orgs_for(_weekly_org_result[0])
            | _orgs_for(_yearly_org_result[0])
        )
        _trends_org_metrics_union = sorted(
            _metrics_for(_monthly_org_result[0])
            | _metrics_for(_weekly_org_result[0])
            | _metrics_for(_yearly_org_result[0])
        )

        _prune_multiselect_state(f"{KEY_PREFIX}trends_players", _trends_players_union)
        _prune_multiselect_state(f"{KEY_PREFIX}trends_metrics", _trends_metrics_union)
        _prune_multiselect_state(f"{KEY_PREFIX}trends_orgs", _trends_orgs_union)
        _prune_multiselect_state(f"{KEY_PREFIX}trends_org_metrics", _trends_org_metrics_union)

        _trends_mode = st.radio(
            "Group by", ["Player", "Org"],
            key=f"{KEY_PREFIX}trends_mode", horizontal=True,
        )

        if _trends_mode == "Player":
            _trends_sel_players = st.multiselect(
                "Players",
                _trends_players_union,
                default=_trends_players_union[:3] if len(_trends_players_union) >= 3 else _trends_players_union,
                key=f"{KEY_PREFIX}trends_players",
            )
            _trends_sel_metrics = st.multiselect(
                "Metrics",
                _trends_metrics_union,
                default=_trends_metrics_union[:3] if len(_trends_metrics_union) >= 3 else _trends_metrics_union,
                key=f"{KEY_PREFIX}trends_metrics",
            )
            _trends_sel_org_metrics = []
            _trends_sel_orgs = []
        else:
            _trends_sel_org_metrics = st.multiselect(
                "Metrics", _trends_org_metrics_union,
                default=_trends_org_metrics_union[:2] if len(_trends_org_metrics_union) >= 2 else _trends_org_metrics_union,
                key=f"{KEY_PREFIX}trends_org_metrics",
            )
            _trends_sel_orgs = st.multiselect(
                "Organizations", _trends_orgs_union,
                default=["HOU"] if "HOU" in _trends_orgs_union else _trends_orgs_union[:3],
                key=f"{KEY_PREFIX}trends_orgs",
            )
            _trends_sel_players = []
            _trends_sel_metrics = []
```

**Per-tracker substitutions:**

| Token | Fielding | Barrelsville | Arm Farm | BR | Catcher |
|---|---|---|---|---|---|
| `ID_COL` | `"fielder_id"` | `"batter_id"` | `"pitcher_id"` | `"runner_id"` | `"catcher_id"` |
| `KEY_PREFIX` | `_PREFIX` (an f-string) | `""` (bare strings) | check file | check file | check file |
| `_ALL_METRIC_LABELS` | already exists | already exists | already exists | already exists | already exists |
| `_METRIC_LABEL_TO_KEY` | already exists | already exists | already exists | already exists | already exists |

**Verify Barrelsville's KEY_PREFIX**: it has NO prefix, multiselect keys
are bare strings (`"mom_players"`, etc.). So the template should be
`key="trends_players"` not `key=f"{KEY_PREFIX}trends_players"`. Same for
Arm Farm — check its existing keys to confirm.

### Step 3b: For EACH sub-tab body, replace mode radio + multiselects

Pattern PER sub-tab (find/replace each):

**REMOVE:** the local `mom_mode = st.radio(...)` (or wow_mode / yoy_mode)
**REPLACE WITH:** `mom_mode = _trends_mode` (the hoisted variable)

**Player mode body:** REMOVE the `player_options = sorted(...)` +
`_prune_multiselect_state(...)` + `sel_names = st.multiselect(...)` +
`available_metrics = [...]` + `_prune_multiselect_state(...)` +
`mom_metric_labels = st.multiselect(...)` block.

**REPLACE WITH** (mom example):
```python
sel_names = [p for p in _trends_sel_players if p in set(mom_hou_df["player_name"].unique())]
mom_metric_labels = [m for m in _trends_sel_metrics
                      if _METRIC_LABEL_TO_KEY.get(m) in mdf.columns]
```

**Org mode body:** REMOVE the `available_org_metrics = [...]` +
`_prune_multiselect_state(...)` + `mom_org_metrics = st.multiselect(...)`
+ `orgs = sorted(...)` + `_prune_multiselect_state(...)` +
`sel_orgs = st.multiselect(...)` block.

**REPLACE WITH** (mom example):
```python
mom_org_metrics = [m for m in _trends_sel_org_metrics
                    if _METRIC_LABEL_TO_KEY.get(m) in org_mom_sel.columns]
_orgs_in_mom = set(org_mom_sel["org"].unique()) if not org_mom_sel.empty else set()
sel_orgs = [o for o in _trends_sel_orgs if o in _orgs_in_mom]
```

Repeat for WoW (replace `mom_` → `wow_`, `mdf` → `wdf`, `mom_hou_df`
→ `wow_hou_df`, `org_mom_sel` → `org_wow_sel`) and for YoY (`mom_` →
`yoy_`, `mom_hou_df` → `hou_yearly`, `mdf` → `yearly_combined`,
`org_mom_sel` → `org_yoy_sel`, `mom_metric_labels` → `yoy_metric_labels`,
`mom_org_metrics` → `yoy_org_metrics`, `sel_orgs` → `sel_yo_orgs`,
`sel_names` → `sel_y_names`).

### Step 3c: Verify + commit + push

1. Grep for stragglers: `grep -n "key=f\"\{_PREFIX\}\(mom_\|wow_\|yoy_\)\(players\|metrics\|orgs\|org_metrics\|mode\)\""`  — should return zero
   (replace `_PREFIX` and bare-string pattern per tracker)
2. `python -c "import ast; ast.parse(open(<path>).read()); print('OK')"`
3. Single commit per worktree, descriptive message referencing
   `407842f4` as the pilot
4. `git push`

---

## Failed approaches (DO NOT REPEAT)

| Attempt | Commit | Why it failed |
|---|---|---|
| Per-sub-tab unique keys (`mom_players`, `wow_players`, `yoy_players`) | initial state | Each sub-tab has independent state. Selections don't share. (User's original complaint.) |
| Unified key + prune-in-each-sub-tab | `dda766be` | `StreamlitAPIException`: can't write to `session_state[X]` after widget with `key=X` is instantiated. Second sub-tab's prune call crashes. Reverted `bb993d7f`. |
| Unified key + prune-at-top + same options | (intermediate, mental model only) | Different sub-tabs pass different `options=` → Streamlit silently drops invalid values. Doesn't actually fix the bug. |
| Unified key + UNION options + prune-at-top | `b19933c8` | `StreamlitDuplicateElementKey`: Streamlit forbids duplicate keys across widgets regardless of config match. Reverted `6d03d733`. |
| **HOIST (single widget above sub-tabs)** | `407842f4` | **WORKS.** One widget = no duplicate. State shared by definition. Sub-tabs read shared variables. |

**Lesson:** Streamlit's widget-key invariants are strict. Cross-tab
state sharing requires ONE widget instance, period. The hoist is the
only architecturally correct fix.

---

## What's IN scope (the 3 fixes)

1. **Composite cache** (Fix 1) — `@st.cache_data` on the multi-year loaders
2. **Prune helper** (Fix 2) — `_prune_multiselect_state` with try/except
3. **HOIST** (Fix 3) — mode + multiselects above sub-tabs, sub-tabs read shared

## What's NOT in scope (deferred)

- `st.fragment` wrap around Trends body. Would scope reruns to inner
  widget interactions only. Bigger refactor (~900-line reindent across
  3 sub-tabs). Skip for now; sub-tab content updates feel acceptable
  with cache + hoist already in place.
- Per-sub-tab independent mode (Player on MoM, Org on WoW
  simultaneously). User accepted that mode is now SHARED across all 3
  sub-tabs as a tradeoff for shared selections.
- Static `MONTHLY_METRIC_KEYS` constant — turns out dynamic filter is
  defensive against missing-monthly-query case. Don't bother.

---

## Pin re-run instructions (SEPARATE — at the ballpark)

For Intangibles fielding multi-level slowness, see
**`fielding-raw-obs-refactor-handoff.md`** in this memory dir.

TL;DR for the user at the ballpark:
- Code already shipped on `feature/astros-intangibles` (~`388f9c0e`)
- Replaces 12+ hr per (domain, year) POOLED_LEVEL_COMBOS pin with
  raw-obs pin (~6 min)
- Steps: pull → run `scripts/diag_pooled_parity.py` → if pass, re-pin
  2026 + backfill historical years → redeploy `connect_pins_fielding/`

This is INDEPENDENT of the Trends-tab hoist work. Both can ship in
parallel — the hoist is pure UI code, the pin work is the data layer.

---

## Cross-references

- `tracker-parquet-pins.md` — pin architecture
- `tracker-new-metric-checklist.md` — 5-place metric checklist
- `fielding-raw-obs-refactor-handoff.md` — pin work for IF/OF multi-level
- Fielding hoist commit: `407842f4` on `feature/astros-intangibles`
  (the verbatim reference impl — read it before porting)
