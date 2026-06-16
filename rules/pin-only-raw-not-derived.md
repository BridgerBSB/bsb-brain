# Pin Only Raw/Source Columns — Re-derive Presentation at Read Time (BLOCKING)

**Never store a DERIVED / presentation value inside a pinned dataset.** Pins
freeze whatever was in the DataFrame at *pin-build time*. If a derived column
(a display label, category, color, formatted string, bucket, rank label, etc.)
is computed *inside* the pinned function, that value gets frozen — and no later
code change or redeploy can fix it, because the read path returns the pin and
**short-circuits the code that would recompute it**.

Store only the RAW inputs the derivation needs (ids, counts, raw metric values).
**Compute the derived value at READ time**, right after the pin returns.

---

## The bug class (June 2026 — DSL sub-team label, cost ~a full session)

`get_org_rankings_dsl_split` is pin-backed (`PREFIX_ORGS_DSL_SPLIT`):

```python
_pinned = _try_pin_bundle(season, PREFIX_ORGS_DSL_SPLIT, ...)
if _pinned is not None:
    return _pinned          # <-- returns BEFORE the label resolver ever runs
```

The display label `dsl_team_label` was computed *inside* the pinned builder
(`_get_single_level_dsl_split_org_stats`: `df["dsl_team_label"] =
df["dsl_team_id"].apply(_resolve_dsl_team_label)`), so the string got baked into
the pin. The pin had been built with the OLD label map (`{599,10000055}`
GBL_CLUB_LKUP keys), producing `"HOU - Team 601"`. When the fix shipped
(re-key to `{601,5005}` MLBAM.Teams), the live resolver was **never reached** —
the pin returned the frozen string. Correct code + correct on-disk file + three
clean redeploys all still showed "Team 601". Hours lost chasing "stale deploy".

### Symptom signature (memorize this)
**A stale label / category / color survives correct code AND a confirmed-clean
redeploy → suspect a pin froze the computed value.** Grep the read path for
`if _pinned is not None: return _pinned` and check whether the stale column is
computed before the pin is written.

---

## The fix pattern — re-derive after the pin returns

```python
_pinned = _try_pin_bundle(season, PREFIX_ORGS_DSL_SPLIT, ...)
if _pinned is not None:
    # derived label is PRESENTATION — recompute from the pinned RAW id so a
    # mapping change takes effect on deploy with ZERO re-pin.
    if "dsl_team_id" in _pinned.columns:
        _pinned = _pinned.copy()
        _pinned["dsl_team_label"] = _pinned["dsl_team_id"].apply(_resolve_dsl_team_label)
    return _pinned
```

The pin keeps the RAW `dsl_team_id`; the label is recomputed on every read. A
future label-map change is a code change only — no re-pin, ever. Shipped across
all 5 trackers: Barrelsville `79e7ca64`, Arm Farm `4e5e14e9`, Intangibles
`ba19516b` (BR + Fielding + Catcher).

---

## DSL split — the canonical state (do NOT "simplify" it)

`dsl_team_label` deliberately appears TWICE in each tracker's `tracker_data.py`,
and that is CORRECT — do not "fix the rule violation" by deleting the wrong one:

1. **Build-time stamp** — `_get_single_level_dsl_split_org_stats`:
   `df["dsl_team_label"] = df["dsl_team_id"].apply(_resolve_dsl_team_label)`.
   Still writes a label into the pin. A harmless leftover (it gets overridden).
2. **Read-time re-derive** — `get_org_rankings_dsl_split`, immediately after
   `if _pinned is not None:`. Recomputes from `dsl_team_id`, OVERRIDING the
   frozen value. **This line is load-bearing — it is what keeps the label fresh.**

**Future agents:**
- Do **NOT** delete the read-time re-derive (line 2) because "the rule says
  don't pin derived values." Existing pins already contain stale labels;
  removing the read-time override re-freezes them → the "HOU - Team 601" bug
  returns. The read-time derivation is the FIX, not a violation.
- Do **NOT** be confused that a derived column is still stamped at build time
  (line 1). The read-time override makes it harmless. The accepted state is
  **"both present, read-time wins."**
- The only safe simplification is to drop the **build-time stamp** (line 1) so
  the pin is purely raw — **never** the read-time re-derive (line 2). Not
  required; cosmetic.

## Rule

| Pin THIS (raw/source) | NOT this (derive at read) |
|---|---|
| ids (`dsl_team_id`, `org` code), raw counts, raw metric values | display labels (`dsl_team_label`), human names |
| numerator / denominator components | formatted strings, rank-label strings |
| the inputs a helper needs | category / bucket / color from a lookup |

If a value comes from a **lookup table or a mapping helper** (`_resolve_*`,
`_label_for`, a dict, a CASE), it is DERIVED — recompute it at read time, do not
freeze it in the pin.

---

## What NOT to do

- **Don't** call a label/category/color resolver *inside* the function that
  builds the pin. Apply it after the pin read in the public accessor.
- **Don't** "fix" a frozen-label bug by re-pinning. It works once, then
  re-breaks on the next mapping change. Re-derive at read time instead.
- **Don't** trust a doc note that a pinned feature is "live-DB only." The DSL
  split note said exactly that and was stale — it got pinned later via
  `PREFIX_ORGS_DSL_SPLIT` (`docs/plans/2026-05-27-dsl-split-pinning-goal.md`).
  Grep the read path for `_try_pin_bundle` to confirm what is actually pinned.
- **Don't** assume "correct code + clean redeploy" means a stale display value
  is impossible. A pin is a third state between code and deploy.

---

## Cross-references

- `tracker-parquet-pins.md` — pin architecture, schema, stale-pin shim, what to pin.
- `tracker-aggrid-stat-rank.md` — DSL label fix + AgGrid Stat (Rank); the read-time
  re-derive is the companion to that label fix.
- `never-round-until-display.md` — sibling principle (don't freeze a transformed
  value mid-pipeline; do it at the display boundary).
