---
name: ALWAYS add new src/*.py to manifest.json
description: Connect deploys ONLY files listed in manifest.json.files — new src modules silently excluded -> ModuleNotFoundError at runtime. Add manifest entry in same commit as the new file, every time.
type: feedback
originSessionId: 44c2c027-e9d6-4099-a6c7-f4e7e13c5eed
---
When adding a NEW `src/*.py` module to any Streamlit app deployed on
Posit Connect (Barrelsville, Arm Farm, PD Engine, Intangibles), you
MUST add a corresponding entry to that app's `manifest.json` in the
same commit as the new module.

**Why:** Connect uses `manifest.json.files` as an allow-list for the
deploy bundle. New files are silently excluded otherwise. The app
deploys "successfully," but on first request the import fails with
`ModuleNotFoundError`.

**How to apply:**
1. Add the new `src/<module>.py`
2. Open the app's `manifest.json`, find the `src/` block under `files`
3. Add `"src/<module>.py": {"checksum": ""}` in alphabetical order
   alongside the other src entries
4. Commit BOTH files together — never split
5. If the same module is also imported by a script that gets bundled,
   add `scripts/<script>.py` if not already listed

**Same rule applies to:** `connect_pins/deploy.ps1` srcFiles arrays
for any Connect-scheduled jobs (see `feedback_deploy_ps1_srcfiles.md`).
Manifest covers the Streamlit deploy; deploy.ps1 covers the
scheduled-job deploy. They're independent allow-lists.

**Reference:** `.claude/rules/tracker-parquet-pins.md` §5.1 documents
this exact gotcha at length. Cross-reference when explaining to user.

**Bug history:**
- May 5 2026: shipped `barrelsville/src/advance_diagnostic.py` for the
  new Pitcher Diagnostic tab. Forgot manifest. App load broke. Fixed
  in `5fcbc52`.
- May 18 2026: shipped `barrelsville/src/gcoba_canonical.py` AND
  `pd-goals/src/gcoba_canonical.py` (sibling cross-worktree pattern).
  Forgot manifest on both. Barrelsville Postgame app threw
  ModuleNotFoundError on first user load after redeploy. Fixed in
  `005f6581`. **User had to reinforce the rule on me even though it
  was quoted back at myself earlier in the same session.** The cost
  of forgetting is the user redeploys, hits the error, has to come
  back and tell me. Two-step rollback. Internalize: when writing a new
  src/*.py, the COMMIT block has THREE artifacts, not two: the new
  module + the manifest update + the optional scripts/ entry.
- Pattern previously bit on tracker_pins.py (Apr 21 pilot, see
  tracker-parquet-pins.md commit `c03c105`).

**Cross-worktree sibling pattern:** if the new module has a sibling
copy in another worktree (like `bat_speed_clean.py`,
`gcoba_canonical.py`), update BOTH manifests in lockstep — one per
worktree. Same commit ideally, but if worktrees commit separately,
both manifest updates happen the same session.
