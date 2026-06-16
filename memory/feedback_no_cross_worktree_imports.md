---
name: No cross-worktree imports — inline shared helpers
description: Cross-worktree Python imports (e.g. barrelsville importing from pd-goals via sys.path) break on the work laptop because worktrees are NOT laid out as siblings the same way as the personal laptop. Inline shared helpers instead.
type: feedback
originSessionId: 47b25890-8571-4b11-bb6b-15744e1d420a
---
When a Barrelsville/Arm Farm/Intangibles script needs a helper that
lives in another worktree (most commonly `pd-goals/src/metrics.py`'s
`calculate_damage_vectorized`), **inline the helper into the consuming
worktree's `src/`. Do NOT use `sys.path.insert` to reach across
worktrees.**

**Why:** the personal laptop has all four worktrees as siblings under
`C:\Users\Owner\` (`bsb-resources`, `bsb-wt-hitting`, `bsb-wt-bullpen`,
`bsb-wt-intangibles`), so a path like
`Path(__file__).parent.parent.parent / "pd-goals"` happens to resolve.
The work laptop's layout is different — each worktree is its own
top-level dir under `C:\Users\zbridger\` and `pd-goals/` only exists
inside `bsb-resources/` (NOT inside `bsb-wt-hitting/`). Cross-worktree
sys.path inserts silently fail with `ModuleNotFoundError: No module
named 'src.metrics'` on first run.

**How to apply:**

- When you'd be tempted to write `from src.metrics import X` from a
  Barrelsville script (or any non-pd-goals worktree), STOP. Either:
  1. **Inline the helper** in the consuming worktree's `src/` (best
     for short formulas like Damage% — 5 lines).
  2. **Confirm the helper is already in this worktree's `src/`**
     (grep before writing — many helpers like `_get_woba_weights`,
     `_get_hit_specs_exponents`, `EV_MISREAD_CTE` exist in BOTH
     `barrelsville/src/tracker_data.py` AND `pd-goals/src/...` as
     intentional duplicates).
- The Sugar Land LA/EV matrix had this bug (commit `45b9151`,
  fixed `b2ea4ed` May 6 2026) — initial design doc explicitly said
  "use the Python helper for cleanliness" which was wrong direction.
- Same pattern documented in `bat-speed-canonical.md` ("Lives in TWO
  byte-identical copies — Barrelsville + PD Goals").

**Watch for:** any `sys.path.insert(...parent / "pd-goals")` or
`sys.path.insert(...parent / "intangibles")` etc. in non-target
worktrees. These should ALL be inlined or confirmed-duplicated.

**Don't apply this to:** sibling-app deploys on Connect — those have
their own worktree-root resolution patterns (see
`tracker-parquet-pins.md` §4.1 + `combined-kpi-stapler.md` §worktree-
layout-assumption). Those use `BSB_WORKTREE_ROOT` env var override.
The Connect stapler is the ONLY legitimate cross-worktree case in this
codebase, and it uses filesystem reads of pre-rendered PDFs — never
Python imports.
