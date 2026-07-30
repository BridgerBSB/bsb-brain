---
paths:
  - "**/*tracker*.py"
  - "**/pages/*.py"
---
# Streamlit Tracker Column Pinning — Pixel-Int Width Pattern (BLOCKING)

LIVE on `feature/barrelsville` since May 8 2026 (commit `18f6303`).
Replicable across all 5 affiliate-tracker pages. This rule documents the
ONE working approach for keeping info columns pinned at the left of an
`st.dataframe` while metric columns scroll horizontally.

Pairs with `tracker-parquet-pins.md` (different concern — that's data-side
caching). This file is purely UI / Streamlit configuration.

---

## Why this rule exists

User direction May 8 2026: "Info columns should stay pinned no matter how
many metric columns are selected." Initial implementation used
`st.column_config.Column(pinned=True)` with default auto-fit widths. Pinning
worked at 5-6 selected info cols, then **silently broke at 7-8** on
standard browser windows.

Root cause turned out to be a **hardcoded 60% threshold in Streamlit's
frontend bundle** (`glide-data-grid` wrapper). It's not a bug — it's an
intentional UX guard so pinned columns can't consume the entire viewport.
But it's also undocumented and surprising.

Three iterations to land the right fix:
1. Default auto-fit widths → pinning breaks at 7-8 cols
2. `width="small"` (75px each) → pinning works but cells look padded
3. **Pixel-int widths (50px, 45px, etc.)** → narrow render + pinning holds

---

## The 60% threshold (BLOCKING fact — internalize this)

Buried in Streamlit's compiled JS bundle (`static/js/index.*.js`):

```javascript
function N1(e, t, n, r, i, o) {
    const a = useMemo(
        () => e.filter(c => c.isPinned).reduce((c, f) => c + (f.width ?? r*2), 0) > n*.6,
        [e, n, r]
    ),
    l = t || a ? 0 : e.filter(c => c.isPinned).length,
    ...
```

Decoded:
- `e` = columns array
- `n` = canvas width (px)
- `r` = `minColumnWidth` (default 50px)
- `f.width` = explicit width passed via `st.column_config.Column(width=...)`. **If unset, falls back to `r*2 = 100px`** for the threshold check.
- `a = true` when sum_of_pinned_widths > canvas_width × 0.6
- If `a` is true → effective freezeColumns set to 0 → **all pinning disabled**

**Equivalent rule**: pinned columns must collectively be ≤ 60% of table canvas width, or Streamlit silently drops pinning entirely.

The 60% is not configurable from Python. There is no API flag.

---

## The fix: pixel-int widths in column_config

`st.column_config.Column(width=<int>)` accepts pixel ints since
**Streamlit 1.49.0** (verified by extracting the 1.49.0 wheel: type alias
became `Literal["small","medium","large"] | int`). This is the smallest
required version.

### Canonical implementation (copy from `barrelsville/pages/2_Affiliate_Tracker.py`)

```python
def _column_config_for_metrics(metric_keys, display_mode, info_cols=None):
    config = {}
    if info_cols is None:
        info_cols = _INFO_COL_LABELS

    # Pin Player + info columns to the left so they stay visible while metric
    # columns scroll horizontally. Streamlit's frontend silently disables
    # pinning when sum(pinned_widths) > 0.6 * canvas_width — so we force
    # tight PIXEL widths on every short info col (Streamlit >=1.49 supports
    # int widths in column_config).
    config["Player"] = st.column_config.TextColumn("Player", pinned=True)
    if "Org" in info_cols:
        config["Org"] = st.column_config.TextColumn("Org", pinned=True, width=50)
    if "Level" in info_cols:
        config["Level"] = st.column_config.TextColumn("Lvl", pinned=True, width=45)
    if "Age" in info_cols:
        config["Age"] = st.column_config.NumberColumn("Age", format="%.1f", pinned=True, width=50)
    if "Bats" in info_cols:
        config["Bats"] = st.column_config.TextColumn("Bats", pinned=True, width=45)
    if "Pos" in info_cols:
        config["Pos"] = st.column_config.TextColumn("Pos", pinned=True, width=45)
    if "PA" in info_cols:
        config["PA"] = st.column_config.NumberColumn("PA", format="%d", pinned=True, width=55)
    if "AB" in info_cols:
        config["AB"] = st.column_config.NumberColumn("AB", format="%d", pinned=True, width=55)
    return config
```

### Width recommendations per column kind

| Content | Recommended width | Rationale |
|---|---|---|
| 3-char text (Bats="L"/"R", Pos="OF") | **45px** | Just enough for 3-char content + small padding |
| Org abbreviations ("HOU", "AAA") | **50px** | Slightly wider for readability |
| Level abbreviation ("AAA", "AA") | **45px** | Header renamed to "Lvl" to fit |
| Age (decimal "23.4") | **50px** | 4 chars + decimal |
| Integer counters (PA, AB, "237") | **55px** | Up to 4-digit numbers |
| Long names (Player) | **NO width set** (auto-fit) | Auto-grows for "Christopher Whittington" etc. |
| Heavily-content-typed cols | **NO width** | Let auto-fit handle them; budget against 100px fallback |

### Total pinned width budget

For 8 info cols on Barrelsville:
- Player auto-fit ≈ 150-200px (depends on longest name in HOU)
- Org(50) + Lvl(45) + Age(50) + Bats(45) + Pos(45) + PA(55) + AB(55) = **345px**
- **Total pinned ≈ 500-545px**
- Threshold needs canvas ≥ 545/0.6 = **910px**
- Works on every reasonable browser window (laptop screens included)

**Compare to width="small" approach:**
- Player auto + 7 × 75 = 525px + auto = ~675-725px
- Threshold needs canvas ≥ 1208px
- Breaks on narrow windows

**Compare to no-explicit-widths default:**
- Threshold uses `f.width ?? 100px` fallback → 8 × 100 = 800px (regardless of actual rendered widths)
- Threshold needs canvas ≥ 1334px
- Breaks on most browser windows

---

## requirements.txt — BLOCKING constraints

```text
# Core
streamlit>=1.49.0,<1.50.0  # 1.49 for pixel-int widths in column_config; <1.50 to avoid the pandas-3/numpy-2 cascade
pandas>=2.0.0,<3.0.0       # pandas 3.0 dropped df.append(), pd.np
numpy>=1.24.0,<2.0.0       # NumPy 2 dropped np.float_, np.int_, np.bool8
```

### Why both upper bounds matter

May 8 2026 deployment cascade: bumping streamlit to `>=1.36.0` without
upper bounds caused pip to pull `streamlit==1.57.0`, which dragged in
`pandas==3.0.2` and `numpy==2.4.4` as transitive deps. Both have breaking
API changes that crash existing tracker code at import time. App deploy
"succeeded" but Streamlit failed to launch. Diagnostic was costly because
Connect's deploy log doesn't immediately reveal the launch error.

**Always cap streamlit, pandas, AND numpy** when bumping any of them.

### Cache-busting Connect's environment

Connect aggressively caches the Python env when the requirements.txt hash
hasn't changed. Edits to comments INSIDE the existing comment block may
not invalidate the cache. To force a clean rebuild:

```diff
-# Barrelsville Dashboard Dependencies
+# Barrelsville Dashboard Dependencies (env rebuild trigger: YYYY-MM-DD)
```

Editing the **first line** is the most reliable cache-bust.

---

## Replication checklist for the other 5 trackers

| # | Tracker | File path | Status |
|---|---|---|---|
| 1 | Barrelsville (hitter) | `barrelsville/pages/2_Affiliate_Tracker.py` | ✅ Done May 8 2026 |
| 2 | Arm Farm (pitcher) | `bullpen-report/pages/3_Affiliate_Tracker.py` | TODO |
| 3 | Intangibles BR | `intangibles/pages/X_BR_Tracker.py` (verify name) | TODO |
| 4 | Intangibles Fielding (OF + IF) | `intangibles/src/fielding_tracker_page.py` | TODO |
| 5 | Intangibles Catcher | `intangibles/src/catching_tracker_page.py` | TODO |

### Per-tracker steps (copy this checklist when porting)

1. **Update `requirements.txt`** for that worktree:
   - `streamlit>=1.49.0,<1.50.0`
   - `pandas>=2.0.0,<3.0.0`
   - `numpy>=1.24.0,<2.0.0`
   - Bust cache via first-line comment edit
2. **Find the `_column_config_for_metrics` function** in the page (or its equivalent — name may differ per tracker).
3. **Identify the info column labels** the tracker exposes (Player, Org, Level, etc.). Note: each tracker has its own info col list — Catcher has different ones than BR.
4. **Set `pinned=True, width=<px>`** on each info col. Use the table above for px choices.
5. **Rename long headers** ("Level" → "Lvl", "Position" → "Pos") so they fit the narrow widths.
6. **Player column stays auto-fit** (no explicit width).
7. **Verify** total pinned width is < 60% of typical browser canvas (~900px target).
8. **Test redeploy** — no pin re-run needed; this is purely Streamlit-side.

### Per-tracker info column variations (research before applying)

| Tracker | Likely info cols | Notes |
|---|---|---|
| Barrelsville | Player, Org, Lvl, Age, Bats, Pos, PA, AB | Reference impl |
| Arm Farm | Player, Org, Lvl, Age, Throws, Pos (RHP/LHP), IP, BF | "Throws" instead of "Bats" |
| Intangibles BR | Runner, Org, Lvl, Age, Bats, Pos, PA, SB | "SB" replaces AB |
| Intangibles OF/IF | Fielder, Org, Lvl, Age, Bats, Pos, Inn, Plays | "Inn"/"Plays" replace PA/AB |
| Intangibles Catcher | Catcher, Org, Lvl, Age, Bats, Pos, Inn, Pitches | Different volume cols |

Use `width=55` for any 3-4 digit integer counter regardless of label.

---

## What NOT to do

- **Don't use `width="small"`** (75px) on the narrow info cols. Cells look bloated with whitespace. Pixel ints are the canonical fix.
- **Don't bump streamlit cap to `<1.50` without also capping pandas and numpy.** The May 8 2026 cascade will return — `streamlit==1.57.0 + pandas==3.0.2 + numpy==2.4.4` boots but breaks at runtime.
- **Don't pass int widths in apps targeting pre-1.49 Streamlit.** They'll be silently ignored or cause type errors. Always cap floor at `>=1.49.0` when using ints.
- **Don't try to write CSS overrides to control column widths.** `st.dataframe` uses canvas-based rendering (glide-data-grid). CSS doesn't affect cell rendering. The only API surface is `column_config`.
- **Don't pin Player with an explicit narrow width.** Long names get truncated with `...`. Player must stay auto-fit. The threshold math accommodates this.
- **Don't drop the comment in `_column_config_for_metrics` explaining the threshold.** Future agents need to understand why these specific px values were chosen, or they'll "simplify" by removing widths and break pinning.
- **Don't skip the cache-bust** when changing version constraints. Connect's lockfile cache will keep using stale package combinations and the new constraints won't apply.
- **Don't claim "pinning works"** without testing on a narrow browser window (≤ 1100px wide). The threshold engages most aggressively on narrow viewports — that's where the regression appears first.

---

## Bug history (Barrelsville reference, May 8 2026)

1. **Initial implementation** (`6e6dc30`): default auto-fit widths, `pinned=True` on each info col. Tested on wide window — appeared to work.
2. **User reported pinning fails at 7-8 info cols** on regular browser window. Investigated Streamlit source, found 60% threshold logic in compiled JS.
3. **First fix** (`5446091`): `width="small"` (75px) on 7 narrow info cols. Pinning worked but cells looked padded with empty space.
4. **User asked for narrow look + pinning together** (the "have your cake" version). Discovered `width=int` support in 1.49+. Bumped requirements floor to 1.49.0.
5. **Final fix** (`18f6303`): pixel-int widths (Org=50, Lvl=45, Age=50, Bats=45, Pos=45, PA=55, AB=55). Total ≈ 540px. Threshold engages only below 900px viewport. User signed off.

### Streamlit cascade (parallel concern, same day)

- `bb440a4` → `87d069a`: bumped streamlit floor to >=1.36.0. Pip pulled streamlit 1.57.0 + pandas 3.0.2 + numpy 2.4.4. Deploy "succeeded" but app failed to launch.
- `87d069a` → `bdc9625`: capped pandas <3.0 and numpy <2.0. First-line comment edit forced Connect cache rebuild.
- After rebuild, app started clean.

Lesson encoded in this rule: **always cap all three (streamlit, pandas, numpy) when changing any of them.**

---

## Cross-references

- `tracker-parquet-pins.md` — separate concern (data caching). New columns added via this rule don't require pin re-runs unless the underlying SQL also changed.
- `delivery.md` — unrelated to UI but referenced by tracker pages.
- The bundled Streamlit JS (`streamlit/static/js/index.*.js`) — not editable but useful for verifying the 60% threshold logic. Search for `freezeColumns:` in any release.
