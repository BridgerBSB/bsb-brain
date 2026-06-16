---
name: SZ Tango — Future Migrations Parked for Later
description: Out-of-scope files/apps that still use old ball-radius-inset or hardcoded 1.5-3.5 SZ bounds after the Apr 21 Barrelsville Tango refactor. Deliberately deferred. Migrate when the moment is right. Status as of May 10 2026 — Intangibles catcher SHIPPED; Barrelsville hitter_analysis 13/17-zone + 3 Arm Farm surfaces still parked.
type: project
originSessionId: 967e8752-cb38-4540-b3a2-cb69fee5e15c
---
## Context
Apr 21, 2026 — Barrelsville fully migrated to Tango SZ framework (see `sz-framework-savant-zones.md`). Other apps were deliberately parked to respect team cadence. May 10 2026 — Intangibles catcher migrated (item #2 below). 4 surfaces still parked.

## Parked Migrations (in order of blast radius)

### 1. Barrelsville `hitter_analysis.py` 13/17-zone grid
**Why:** This is the Savant-style grid that expands axis limits to ±20" x / ±200% z to show Chase + Waste as grid cells (variant F). Was always scoped as a later "Updated Tango Zone" effort.
**Why:** Grid widths + coloring rules need a dedicated discussion with user.
**How to apply:** Plan a separate refactor — the 13-zone cells themselves need to be defined using Tango x/z bands rather than the current fixed ±0.83 / 1.665-3.335 literals. Also: decide between 13 vs 17 zones for the grid.
**Also affects:** `scripts/generate_team_hitter_analysis.py` (duplicates the 13-zone logic).

### ~~2. Intangibles catcher 4-panel~~ — **SHIPPED May 10 2026**
- `intangibles/src/catcher_report.py:74-75` — `SZ_BOTTOM` / `SZ_TOP` now
  computed inline as `0.27 * 6.0212` (~1.626 ft) and `0.535 * 6.0212`
  (~3.221 ft). Inlined per `feedback_no_cross_worktree_imports.md` (no
  cross-worktree import to barrelsville's `abs_zone_bounds`).
- `intangibles/pages/4_Catching.py:778-781` — Plotly rect now imports
  `SZ_BOTTOM` / `SZ_TOP` from `catcher_report` so PDF + Plotly cannot
  drift apart. Single source of truth.
- SZ rectangle shrank from 24" (1.5-3.5) to ~19.1" tall — the user-
  reported "way too tall" issue. X bounds (±0.708) unchanged (were
  already correct). No data-side change (CSC drives framing
  classification, not geometric SZ bounds).

### 3. Arm Farm postgame PDF `±0.83` bug
**File:** `bullpen-report/src/postgame_report.py:271-272`
**Problem:** SZ x hardcoded at `±0.83` (≈20" called zone) instead of ABS `±0.708` (17" plate). Arm Farm app uses correct `±0.708`.
**Reason parked:** Pitchers/coaches used to the 20" called zone rendering. Mixing this with the Tango Heart/Shadow overlay would require a bigger conversation.
**What to change:** Switch to `HP_HALF_W = 0.708` in postgame PDF to match app + ABS spec. Consider adding dotted Tango Heart/Shadow overlays as part of the same change (but scope this discussion first).

### 4. Arm Farm advance pitching matchup
**File:** `bullpen-report/src/advance_pitching_report.py`
**Problem:** Uses fallback `_DEFAULT_ZONE` with `sz_z_min=1.665, sz_z_max=3.335` (retired ball-radius values) — only when hitter zone not in DB. Per-hitter `get_hitter_zone_bounds()` still uses ball-radius inset formula too.
**Reason parked:** Advance pitching matchup is pitcher vs. hitter scoped — lots of inter-dependent logic. Separate plan needed.
**What to change:** Migrate fallback to `abs_zone_bounds(None)` and per-hitter logic to `abs_zone_bounds(height_ft)`.

### 5. Arm Farm LVA cells + location scatter
**Files:** `bullpen-report/src/plots.py` (LVA), `bullpen-report/src/postgame_report.py` (LVA PDF)
**Problem:** Hardcoded 1.5-3.5 for SZ z-bounds.
**Reason parked:** Variant D (pitcher-view generic) doesn't have Heart/Shadow layers, so the visual impact is small. But consistency would be nice.

## How to apply when the moment is right

When the user gives the green light for any of the above:
1. Read `sz-framework-savant-zones.md` + `.claude/rules/visual-standards.md` for the authoritative framework
2. Import `abs_zone_bounds()` from the relevant `plots.py` in that app (Arm Farm/Intangibles each have their own `plots.py` — bootstrap a Tango framework clone, OR add a shared util)
3. Follow the same pattern as Barrelsville: classify data + draw visuals through the same `abs_zone_bounds()` call
4. Commit per-app with a clear BREAKING data warning in the message
5. Three-surface-parity check: if the change affects an org-level metric displayed in Arm Farm tracker / PD-Goals / KPI weekly, audit all 3 before shipping

## Reference Commits (Barrelsville, Apr 21)
- `fe0c745` plots.py framework
- `45627eb` postgame classification
- `f21e9c9` weekly hitter constants
- `11a2472` postgame PDF visual
- `e54d404` postgame app Plotly visual
- `a2366a6` weekly hitter report + line 1037 filter fix
- `58ec668` heart_zone_report SQL X fix
- `8d5e34e` weekly hitter visual parity
- `ab5622d` weekly + heart_zone SQL Z formula
- `3bd4d21` Wave 4 docs
- `7726f01` doc cleanup (stop perpetuating retired 1.5-3.5)

Tag: `pre-tango-sz-refactor` (rollback anchor).
