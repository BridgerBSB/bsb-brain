# IL Advance Coverage — Design (REVISED 2026-05-26 evening)

**Date:** 2026-05-26 (revised same day after earlier cube proposal)
**Branch:** feature/pd-goals (design lives here); implementation spans 3 worktrees
**Status:** Design approved, ready for implementation

---

## Revision note

**Previous design (this same file, earlier commit `15d80ac1`):** added
opposing-IL coverage by restructuring `--level rok` ZIPs into a
4-quadrant cube (Arm Farm) + named subfolders (Barrelsville/Intangibles).

**Revised design (this version):** introduce IL as a **brand new level**
(`--level IL`) that emits its own dedicated ZIP. Each script's
`--level rok` code path is left untouched. Less invasive, purely
additive. Today's HOU-side IL augmentation in `--level rok` (commit
`27a654f0`) gets reverted — that functionality moves to `--level IL`.

---

## The new architecture

Add `'IL'` as a valid level in `BATCH_LEVELS` for all 3 advance batch
scripts. When invoked with `--level IL`:

1. **Schedule layer:** query upcoming FCL series (`LEVELOFPLAY_LK='r'`) —
   same as `--level rok`. IL rehab assignments physically happen at FCL.
2. **Roster pool:** swap the standard FCL roster for the IL/REHAB roster
   on whichever side each script iterates.
3. **PDF generation:** unchanged — same template, same content shape.
   Just driven by a different roster pool.
4. **ZIP packaging:** unchanged — same per-series structure as
   `--level rok`. Filename has `_IL_` instead of `_FCL_`.
5. **Slack delivery:** routes to the FCL-equivalent channel per script
   (since IL guys rehab at FCL physically).

### Per-script interpretation of `--level IL`

| Script | "IL" applies to | Roster pool when level == 'IL' |
|---|---|---|
| Arm Farm pitching | "our pitchers" (HOU side) | HOU IL/REHAB pitchers from any level (MLB/AAA/AA/A+/A) |
| Barrelsville hitter | "opposing pitchers" | Opposing org's IL/REHAB pitchers from any of THEIR levels |
| Intangibles hitter | "opposing hitters" | Opposing org's IL/REHAB hitters from any of THEIR levels |

Each script handles "IL" on whichever side it iterates today. No
restructuring of existing folder layouts.

### Channel routing

Add `"IL"` key to each script's CHANNEL_IDS dict, pointing to the
existing FCL channel for that script:

| Script | CHANNEL_IDS["IL"] |
|---|---|
| Arm Farm | `C0AMUQVTDUG` (fcl_armfarm) |
| Barrelsville | `C0ALSF1GMTQ` (fcl_barrelsville) |
| Intangibles | `C0AKG8WA267` (fcl_intangibles) |

---

## Implementation per worktree

### Arm Farm (`bsb-wt-bullpen/bullpen-report`)

**1. Revert commit `27a654f0`** — restore `--level rok` to pre-session
state. Roll back the HOU IL augmentation in `get_astros_pitchers`
caller. Keep `_IL_REHAB_STATUSES` constant + `get_astros_il_pitchers_for_fcl()`
helper around — they get reused by `--level IL` (just stop calling them
from the rok path).

**2. Add to `src/advance_pitching_data.py`:**
- `BATCH_LEVELS` already exists; add `'IL'` to it.
- `PP_TO_SPORT` mapping: add a sentinel entry for IL routing (or handle
  IL specially in the level-loop without mapping).
- Modify `get_astros_pitchers` (or wrap it) so when called with
  `levels=['IL']`, it returns HOU IL/REHAB pitchers from any level (reuse
  `get_astros_il_pitchers_for_fcl()`).
- Make sure schedule fetch for IL maps to FCL (`'r'`) under the hood.

**3. Modify `scripts/generate_advance_pitching_batch.py`:**
- Add `'IL': 'C0AMUQVTDUG'` to `PITCHING_ADVANCE_CHANNEL_IDS`.
- When `level == 'IL'`: get_upcoming_series('rok', ...) for schedule;
  use get_astros_il_pitchers_for_fcl() for "our_pitchers"; everything
  else identical. ZIP filename uses `IL` token.

### Barrelsville (`bsb-wt-hitting/barrelsville`)

**1. Add to `src/advance_data.py`:**
- `_IL_REHAB_STATUSES` constant.
- `BATCH_LEVELS`: add `'IL'`.
- New helper `get_opposing_il_pitchers(opp_org_pp)` — queries
  `MLB_eBis.PP_MASTER` for `ORG_LK = opp_org_pp`, IL/REHAB status,
  any LEVELOFPLAY_LK.
- `ADVANCE_CHANNEL_IDS["IL"] = "C0ALSF1GMTQ"` (fcl_barrelsville).
- `AFFILIATE_NAMES["IL"] = "IL"`.

**2. Modify `scripts/generate_advance_batch.py`:**
- When `level == 'IL'`: get_upcoming_series('rok', ...) for FCL schedule;
  use `get_opposing_il_pitchers(opp_org)` instead of standard opposing
  pitcher roster query; everything else identical (same PDF template,
  same per-series ZIP).

### Intangibles (`bsb-wt-intangibles/astros-intangibles/intangibles`)

**1. Add to `src/hitter_advance_data.py`:**
- `_IL_REHAB_STATUSES` constant.
- `BATCH_LEVELS`: add `'IL'`.
- New helper `get_opposing_il_hitters(opp_org_pp)` — queries
  `MLB_eBis.PP_MASTER` for `ORG_LK = opp_org_pp`, IL/REHAB status,
  any LEVELOFPLAY_LK, position not in pitcher codes.
- `ADVANCE_CHANNEL_IDS["IL"] = "C0AKG8WA267"` (fcl_intangibles).
- `AFFILIATE_NAMES["IL"] = "IL"`.

**2. Modify `scripts/generate_hitter_advance.py`:**
- When `level == 'IL'`: get_upcoming_series('rok', ...) for FCL schedule;
  use `get_opposing_il_hitters(opp_org)` instead of standard opposing
  hitter roster; everything else identical (same combined-PDF template).

---

## What gets reverted vs preserved

### Reverted (Arm Farm only)
- The HOU IL augmentation block in `generate_advance_pitching_batch.py`
  (~21 lines added in commit `27a654f0`).
- The import of `get_astros_il_pitchers_for_fcl` in the CLI (keep it in
  `advance_pitching_data.py` for reuse by the new `--level IL` path).

### Preserved
- `_IL_REHAB_STATUSES` constant in `advance_pitching_data.py`
- `get_astros_il_pitchers_for_fcl()` helper in `advance_pitching_data.py`
- Channel ID fix in `PITCHING_ADVANCE_CHANNEL_IDS["rok"]` →
  `C0AMUQVTDUG` (fcl_armfarm). Still applies; rok runs deliver there
  regardless. PLUS add `"IL"` key pointing to same channel.

---

## Backwards compatibility (key win)

- `--level rok` (and every other level) behaves IDENTICALLY to today's
  state on each script. Zero changes to existing flow.
- New `--level IL` is purely additive. Run when you want IL coverage,
  skip otherwise.
- Coaches see the new IL ZIP arrive in the same channel they're already
  monitoring (fcl_*). Filename token (`_IL_`) tells them what it is.
- Monday cascade unaffected — none of the 3 advance batches need to add
  `IL` to their cascade scope. User runs `--level IL` manually when an
  IL/rehab cycle is active.

---

## Manual usage after ship

```powershell
# All HOU IL/REHAB pitchers vs opposing FCL hitters
python bullpen-report/scripts/generate_advance_pitching_batch.py --level IL --deliver

# All opposing org's IL/REHAB pitchers (for HOU FCL hitters to scout)
python barrelsville/scripts/generate_advance_batch.py --level IL --deliver

# All opposing org's IL/REHAB hitters (BR/OF/IF context)
python intangibles/scripts/generate_hitter_advance.py --level IL --deliver
```

3 IL ZIPs land in 3 FCL channels. Done.

---

## Implementation order

1. Arm Farm: revert `27a654f0` + add `--level IL`.
2. Barrelsville: add `--level IL`.
3. Intangibles: add `--level IL`.
4. Commit + push per worktree.

Each script is independent, no shared infra. Could be parallelized but
sequential is safer for verification.
