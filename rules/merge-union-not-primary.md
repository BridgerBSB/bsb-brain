# Merge Union Pattern — Never `df = primary.copy()` then Left-Join (BLOCKING)

When aggregating Python DataFrames from multiple parallel SQL queries
into one displayed table (org rollups, per-runner leaderboards,
per-catcher leaderboards, etc.), **NEVER build the result starting from
one "primary" frame and left-joining the rest.** Build the row universe
from the UNION of every non-empty frame, then left-join each in.

The anti-pattern silently drops rows whenever the chosen primary frame
is sparse (HawkEye-dependent / PBL-coverage-dependent / Tier-1-gate-
dependent), even though the dropped row has real data in the other
frames.

---

## The anti-pattern

```python
# WRONG — drops orgs/runners/catchers without primary-frame data
leads_df = results["leads"]
if leads_df.empty:                       # bail-out symptom of the bug
    return pd.DataFrame()
df = leads_df.copy()                     # primary frame becomes the universe
df = df.merge(esb_df, on="org", how="left")     # SB data lost for orgs
df = df.merge(tracking_df, on="org", how="left")# not in leads_df
```

If `leads_df` is missing 6 orgs (their home parks have no HawkEye, no
PBL row), those orgs vanish from the display even when `esb_df` has
their SB/CS data — because the union universe = leads_df's orgs only.

---

## The canonical fix

```python
# RIGHT — union universe, every frame left-joined into it
leads_df = _clean_org_names(results["leads"])
esb_df = _clean_org_names(results["esb"])
tracking_df = _clean_org_names(results["tracking"])

# 1. Build row universe from UNION of every non-empty frame
all_orgs: set = set()
for fr in (leads_df, esb_df, tracking_df):
    if not fr.empty and "org" in fr.columns:
        all_orgs.update(fr["org"].dropna().unique())
if not all_orgs:
    return pd.DataFrame()
df = pd.DataFrame({"org": sorted(all_orgs)})

# 2. Left-join each non-empty frame
if not leads_df.empty:
    df = df.merge(leads_df, on="org", how="left")
else:
    for col in ("pl_1b", "sl_1b", "pl_2b", "sl_2b"):  # NaN-fill expected cols
        if col not in df.columns:
            df[col] = np.nan
if not esb_df.empty:
    df = df.merge(esb_df, on="org", how="left")
else:
    for col in ("sb", "cs"):
        if col not in df.columns:
            df[col] = np.nan
# ... same for tracking_df
```

---

## Where the bug appears in practice

HawkEye / PBL / TDM tracking is **venue-dependent**. Coverage map:

| Source | Coverage |
|---|---|
| `Astros.Pitches_View` (most pitch-level) | **Universal** — every game, every pitch |
| `Astros.Events_View` (PA, SB, CS, advancement) | **Universal** — every PA, every event |
| `MLBAM.SplitsBat` / `MLBAM.Gamelog_*` | **Universal** — MLBAM-recorded |
| `Astros.Pitches_Baserunner_Leads` (PBL) | **HawkEye-only** — sparse at FCL, DSL, many MiLB opponents, some AAA/AA/A+ samples |
| `Astros.Tracking_Defensive_Metrics` (TDM) | **HawkEye-only** — same coverage gaps |
| `Astros.Defense_Combined_By_Pos` (DCBP) | **HawkEye-derived but broader** — has rows for many plays where TDM is empty |
| `groundcontroltracking.Tracking.*` | **HawkEye-only** — same coverage gaps |
| `Astros.Hits` | **Mixed** — Hawkeye for tracking; Stringer-fed positions can be present where Hawkeye isn't |

Any function that left-joins HawkEye-dependent data onto another
HawkEye-dependent frame is at risk. Any function that joins
Events_View data onto a HawkEye-dependent primary IS BUGGED.

---

## Why bail-out + primary-copy = bug

The pattern has two parts and BOTH must be removed:

1. **`if primary.empty: return pd.DataFrame()`** — bails when primary
   has zero rows. But other frames may have data. Returning empty
   throws everything away.

2. **`df = primary.copy()`** — uses primary as the row universe. Orgs/
   runners/catchers in OTHER frames but not in primary are silently
   dropped at the next merge step (left-join restricts to the left
   side's keys).

The union pattern removes BOTH. If ALL frames are empty, we return
empty (`if not all_orgs: return pd.DataFrame()`). If ANY frame has
data, that row appears.

---

## Multi-key merges (game_month, level, etc.)

When merging on a composite key like `(org, game_month)` or
`(runner_id, game_month)`, union tuples:

```python
_pairs: set = set()
for fr in frames:
    if not fr.empty and all(c in fr.columns for c in merge_keys):
        for o, m in zip(fr["org"].dropna(), fr["game_month"].dropna()):
            _pairs.add((o, m))
if not _pairs:
    return pd.DataFrame()
df = pd.DataFrame(sorted(_pairs), columns=merge_keys)
```

---

## Gates that complicate the fix

Some functions have a qualifying gate (`min_pitches`, `min_plays_per_month`,
`min_on_base`) applied to the primary frame. Naïvely applying union
would let unqualified rows through.

**Two ways to handle:**

1. **Move the gate to a universal-coverage source.** For BR runner
   leaderboard, `times_on_df` (Events_View) is universal. Filter the
   union against `times_on_df.n_times_on >= min_on_base` instead of
   against `leads_df` row presence.

2. **Apply gate AFTER union but skip rows without primary data.**
   `mask = df["n_pitches"].isna() | (df["n_pitches"] >= min_pitches)`
   — keeps rows with sufficient primary volume OR rows with no primary
   data at all. Use this when the gate is for "noisy primary signal"
   not "qualifying volume."

**Skipped sites pending review (May 11 2026):**

| File | Site | Reason |
|---|---|---|
| `intangibles/src/catching_tracker_data.py:2308` | per-catcher season | `min_pitches` gate on framing_df; partial union handling exists for empty framing |
| `intangibles/src/fielding_tracker_data.py:2850` | per-fielder monthly | `min_plays_per_month` gate on tracking_agg |

Revisit if FCL/DSL catcher/fielder leaderboards show missing players.

---

## Audit checklist when writing a new merge

For any new function that aggregates multiple frames into one display:

1. **Identify every input frame.** What SQL/table powers each?
2. **Classify each by coverage:** universal vs venue/HawkEye-dependent.
3. **If 2+ frames are mixed-coverage, apply union pattern.** Don't
   pick one as primary even if it's "expected to have the most rows."
4. **NaN-fill expected columns** when a frame is empty so downstream
   code doesn't crash on missing column.
5. **Document any gate** — what's being filtered and why. If the gate
   uses primary-frame row presence, switch to a universal-coverage
   source.

---

## Bug history (May 11 2026)

User reported FCL org KPI BR section missing orgs — SBs visible in
Events_View but the BR section dropped them entirely. Investigation
revealed the bug class above. Six fix commits across two worktrees:

| Commit | Worktree | What |
|---|---|---|
| `d226faf` | bsb-resources | PD Goals BR org rollup |
| `dd63cb4` | bsb-wt-intangibles | BR tracker × 4 sites |
| `f257f4f` | bsb-resources | PD Goals OF/IF/Catcher org rollups |
| `238ed98` | bsb-wt-intangibles | Catching tracker × 2 sites (org monthly + per-catcher monthly) |
| `96f588f` | bsb-wt-intangibles | Fielding tracker × 3 sites (OF/IF org season + pooled + monthly) |

**Total: 12 sites fixed across 3 files in 2 worktrees.** Two sites
intentionally skipped pending gate-handling review (catching 2308,
fielding 2850).

---

## What NOT to do

- **Don't** start the merge with `df = primary.copy()`. Use the union.
- **Don't** bail-out with `if primary.empty: return pd.DataFrame()`.
  Bail only when ALL frames are empty (the union is empty).
- **Don't** assume a frame is universal because it usually is. Pitches_View
  IS universal; TDM / PBL / DCBP are not.
- **Don't** treat the qualifying gate (`min_pitches`, etc.) as a
  display gate. Move it to a universal source or apply after union
  with a sentinel for "no primary data."
- **Don't** rely on left-join semantics to "auto-include" missing rows.
  Left-join restricts to the LEFT side's keys. If left is sparse,
  right's extras get dropped.

---

## Cross-references

- `db-columns.md` — table coverage notes (HawkEye vs universal)
- `multi-level-rollup.md` — multi-level weighting iron rule (separate concern)
- `three-surface-parity.md` — tracker/KPI/PD-Goals parity (separate concern)
- `tracking-schema.md` §HawkEye coverage caveat — explicit warning
  that tracking tables are venue-dependent
