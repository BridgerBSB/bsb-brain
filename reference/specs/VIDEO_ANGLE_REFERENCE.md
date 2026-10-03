# Video Angle Reference — BR Postgame

## Overview

The BR Postgame system provides **three video columns per pitch**:
**V** (personal-device safe), **Main** (behind/center-field view),
and **Side** (side-angle view). The angle fallback chains differ based on:

1. **Level** — MLB venues (HawkEye) have many camera angles; MiLB fewer
2. **Runner's base** — 1B vs 2B runners need different perspectives (Main + Side only)

Each fallback list is tried left-to-right. The **first non-NULL angle wins**.

> **V column — IT-blocker workaround (Apr 22 2026):** IT blocks most
> Video_Network angles on personal devices. Only **V** (and sometimes A)
> plays on player phones / coach personal laptops / Sporty Clips. The
> **V** column is a dedicated `ISNULL('V', 'A')` fallback that always
> resolves to a personal-device-safe URL. Rendered as the FIRST video
> column. Main + Side chains preserved unchanged for team-device
> (affiliate iPad / dugout TV) use. Same pattern applied to OF weekly,
> IF weekly, and hitting postgame (see Barrelsville `src/video.py`).

---

## MLB Video Angles (level_code = 'mlb')

MLB venues use the HawkEye camera system with 30+ angles available.

### Runner on 1B (MLB)

| Column | Fallback Order | Notes |
|--------|---------------|-------|
| **Main** | M → V → B → X → A → I | M = high home behind HP, best view of 1B lead |
| **Side** | C → X → B → A → M → V → I | C = side view ideal for lead distance measurement |

### Runner on 2B (MLB)

| Column | Fallback Order | Notes |
|--------|---------------|-------|
| **Main** | B → M → X → V → A → I | B = high behind HP, best view of 2B lead from behind |
| **Side** | V → K → M → B → A → I | V = center field camera, shows lead from side perspective |

---

## MiLB Video Angles (all levels below MLB)

MiLB venues typically have fewer camera angles available (often just A, J, M, V, W, C).

### Runner on 1B (MiLB)

| Column | Fallback Order | Notes |
|--------|---------------|-------|
| **Main** | M → V → A → J | M = field level, V = center field, A = broadcast |
| **Side** | W → V → M → A → J | W = side angle specific to MiLB setups |

### Runner on 2B (MiLB)

| Column | Fallback Order | Notes |
|--------|---------------|-------|
| **Main** | M → J → V → A | J = behind home alternate available at some MiLB venues |
| **Side** | C → J → V → A | C = side view, J = behind home alternate |

---

## Angle Code Reference

| Code | Description | Typical Availability |
|------|-------------|---------------------|
| A | Broadcast / main TV camera | MLB + MiLB |
| B | High behind home plate | MLB (HawkEye) |
| C | Side angle | MLB + some MiLB |
| I | Center field camera | MLB (HawkEye) |
| J | Behind home alternate | MiLB |
| K | Behind home by hand (RHH) | MLB (HawkEye) |
| M | High home / field level | MLB + MiLB |
| V | Center field | MLB + MiLB |
| W | Side angle (MiLB-specific) | MiLB |
| X | High home alternate | MLB (HawkEye) |

### Angles NOT used for BR (and why)

| Code | Description | Why Excluded |
|------|-------------|-------------|
| E | Open LHP side angle | Points toward 3B — bad perspective for 1B/2B leads |
| 6 | LHP side alternate | Same issue — 3B-facing angle |
| F | Open RHH side | Good for hitting, not ideal for lead measurement |
| H | Open LHH side | Good for hitting, not ideal for lead measurement |
| D | Dugout camera | Low angle, obstructed view |
| L | Behind home by hand (LHH) | Rarely useful for BR context |

---

## Implementation Details

### Source Code

The angle chains are defined as constants in `src/br_data.py`:

```python
_MLB_VIDEO = {
    'main_1b': ['M', 'V', 'B', 'X', 'A', 'I'],
    'side_1b': ['C', 'X', 'B', 'A', 'M', 'V', 'I'],
    'main_2b': ['B', 'M', 'X', 'V', 'A', 'I'],
    'side_2b': ['V', 'K', 'M', 'B', 'A', 'I'],
}

_MILB_VIDEO = {
    'main_1b': ['M', 'V', 'A', 'J'],
    'side_1b': ['W', 'V', 'M', 'A', 'J'],
    'main_2b': ['M', 'J', 'V', 'A'],
    'side_2b': ['C', 'J', 'V', 'A'],
}
```

### Helper Functions

- `_build_isnull(angles)` — Builds nested `ISNULL(vn_X.video_url, ...)` chain
- `_video_columns_sql(level_code, base_expr)` — Generates `CASE WHEN` SQL for both columns
- `_video_joins_sql(level_code, sched_col, pitch_col)` — Generates LEFT JOINs for needed angles only

### SQL Pattern

The `get_br_pitch_by_pitch()` function now accepts `level_code` and generates SQL like:

```sql
-- Two video columns with base-aware, level-aware fallback
CASE bl.occupied_base
    WHEN 1 THEN ISNULL(vn_M.video_url, ISNULL(vn_V.video_url, ...))
    WHEN 2 THEN ISNULL(vn_B.video_url, ISNULL(vn_M.video_url, ...))
END AS main_video_url,
CASE bl.occupied_base
    WHEN 1 THEN ISNULL(vn_C.video_url, ISNULL(vn_M.video_url, ...))
    WHEN 2 THEN ISNULL(vn_V.video_url, ISNULL(vn_K.video_url, ...))
END AS side_video_url
```

Only the angles needed for the given level are LEFT JOINed (MLB joins ~8 angles, MiLB joins ~5).

### Data Flow

```
User selects game → level_code from Schedule_View
  → get_br_pitch_by_pitch(gc_id, sched_id, level_code)
    → _video_columns_sql(level_code) → CASE WHEN per base
    → _video_joins_sql(level_code) → only needed angle JOINs
  → DataFrame with main_video_url + side_video_url columns
    → App: two link columns (Main, Side)
    → PDF: two clickable ▶ markers per row
```

### Database Table

All video URLs come from `Astros.Video_Network`:
- `sched_id` (int) — game ID
- `pitch_id` (int) — pitch ID within game
- `angle` (char) — single-letter angle code
- `video_url` (varchar) — full URL to video clip

---

## Key Discoveries (Feb 26, 2026)

1. **MLB and MiLB camera systems are fundamentally different** — MLB uses HawkEye with 30+ angles, MiLB has fewer fixed cameras
2. **Away/spring training games** typically only have A, V, B, F, H, I angles (no M, K, L)
3. **Home games** (HawkEye venues) have the full angle set including M, K, L, X, B, C
4. **Angles E and 6 are excluded** — they are LHP-side angles that point toward 3B, giving a poor view of 1B/2B leads
5. **The fallback order matters** — e.g., for 2B runners at MLB, B (high behind HP) is preferred over M because it gives a better straight-on view of the runner's lead from second base
