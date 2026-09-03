# Last session state — 2026-09-02 17:42

- **Project / cwd:** `C:\Users\Owner\hiring` · branch `main`
  (shell cwd was `bsb-resources`, but **zero edits there** — all work was in `hiring`)
- **Supersedes** the earlier 2026-09-02 last-state (session `7269`) — same repo,
  same day, continued thread. Recall checkpoint this session: `126af22ecee274ba`,
  session id `578f`, domain `hiring/main`.

## What we were doing

Gave the **Pitching Assessment its own permission area** (it had been a scenario
in a dropdown, then a second dashboard tile — Zac asked three times), rebuilt the
8 pack as **one physical floor**, fixed the magnet-board depth chart and the
eligibility chips, reshaped the **PD Calendar** onto a single "Event" concept,
then ran `/code-review` and acted on it.

## Shipped this session

Seven commits on `hiring/main`, all pushed:

| | |
|---|---|
| `45e0fb3` | `AREA_PITCH` — own nav item, own `/admin/pitching/*` routes, own invites + submissions. Sample viewers got an exercise picker (`POST /sample/open`). |
| `0d93d12` | Sandbox link per track. 40-man players show **no R5 chip at all**. MNFA/MLFA/R5 go red + bold + ⚠ the season the year arrives. |
| `040c130` | Depth chart: pitchers in a left column. The catcher's 4th man was being **clipped away** by `overflow:hidden`; SS covered 3B because boxes are a fixed 156px and centres were 11% apart. |
| `45f5157`, `836ed7e` | Mound + plate drawn on the ground (rubber was 90° out, plate 180° out). Calendar: one typeable **Event** field, no "what kind of day", no Label. `unlimited_items`. |
| `d819437` | **The 8 pack is ONE cage**, 76 × 96, with `mounds {count 8, lane_ft 12}` as drawn furniture. Width ceiling 60 → 200 in three places. |
| `5371df9` | Nine of thirteen code-review findings. |
| `145e915` | Lineage. |

**677 passed on a clean DB.**

## EXACT next step

Zac: *"if you se these aw valid make note and then after we clear and recalll we
can see what tehs etake"* — all four deferred findings are judged **valid** and
are written up. On resume, size them and pick. Start with **#1**:

> `app/main.py:852` — `/api/scenarios` is `Depends(auth.require_access)`, so any
> candidate holding a live invite can enumerate every exercise id/title/role.
> The privacy property `whoami`'s `sample_scenarios` gating rests on is not
> enforced anywhere. Either restrict the **list** route to admin, or correct the
> claim in the comment at `app/auth.py` ~2348.

Then: (2) `_session_detail` + the invite row actions aren't track-checked, only
the lists are. (3) `/sample/open` has no rate limit and doesn't revoke the
session it says it burns. (4) The evaluator's read-only layout draws a bare
rectangle with ruler numbers and **no mound** — the coach grades on a different
picture than the candidate built on.

## Blockers / waiting on

- **Zac's call, not a bug:** `hitting-a-plus.json` now has `unlimited_items: ["*"]`
  (he said don't limit hitting equipment), but its brief still says *"Counts are
  finite"* and question 4 asks what you chose **not** to do. Reword the brief, or
  narrow the uncapping?
- Nothing was driven in a **real signed-in browser** — the Chrome extension isn't
  connected, so every render was headless Edge against local stubs.

## Two traps for the next session

- **`tests/test_magnet_api.py` fails 5–6 board-unlock tests against a used
  `data/cage.db` and passes 80/80 against a fresh one.** A red there is not
  evidence of a regression. Verify with `mv data/cage.db data/cage.db.aside`.
- **The recall ring buffer is at 10/10** — the next checkpoint evicts the oldest.

## Uncommitted work

Clean on `hiring/main` apart from pre-existing untracked `deck/`.
