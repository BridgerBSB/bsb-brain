---
name: feedback_deploy_ps1_srcfiles
description: When adding a new src/*.py module, update connect_pins/deploy.ps1 srcFiles AND bundleFiles arrays alongside manifest.json. SAME allow-list class as manifest.
type: feedback
originSessionId: ce49675e-d469-44ff-abf4-611a92dd6a5b
---
When adding ANY new `src/*.py` module to a worktree that has Connect-scheduled pin jobs, BOTH allow-lists must be updated:

1. **`manifest.json` `files` block** — for the Streamlit app deploy
2. **`connect_pins/deploy.ps1` `$srcFiles` AND `$bundleFiles`** — for the Connect-scheduled pin job deploy

**Why:** Both are independent allow-lists. Files not listed are silently excluded from the deploy bundle, causing `ModuleNotFoundError` at runtime. The Streamlit app and the scheduled pin job each have their own bundle.

**How to apply:** When you write a new `src/foo.py` and any code in `src/tracker_data.py` (or any module that ends up in the pin bundle) imports it:
- Edit `barrelsville/manifest.json` → add `"src/foo.py": {"checksum": ""}`
- Edit `barrelsville/connect_pins/deploy.ps1` → add `"foo.py"` to `$srcFiles` AND `"src/foo.py"` to `$bundleFiles`
- Other worktrees with Connect-scheduled pins (`bsb-wt-bullpen/connect_pins`, `bsb-wt-intangibles/connect_pins_*`): same pattern if you touched their modules

**The bug:** May 3 2026 — bat_speed_clean.py was added to barrelsville/src/ and referenced by tracker_data.py. Manifest.json was updated (commit `5a27879`) but deploy.ps1 was forgotten. The Streamlit app deployed fine, but the Connect-scheduled `barrelsville-pin-tracker-2026` job failed at execution with `ModuleNotFoundError: No module named 'src.bat_speed_clean'`. Fixed in commit `3ba6287`.

The `tracker-parquet-pins.md` rule §12.4 documents this for the Streamlit deploy. The deploy.ps1 srcFiles update is the equivalent for the scheduled-pin deploy — same lesson, different file.
