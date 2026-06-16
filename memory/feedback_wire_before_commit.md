---
name: Always verify functions are wired end-to-end before committing
description: Don't commit utility functions without verifying they're actually called from CLI/app/report entry points
type: feedback
originSessionId: 02135e2a-2e8a-4613-9ed2-1063cd790e2d
---
NEVER commit a utility function without verifying it's called from every entry point (CLI script, app page, report generator).

**Why:** `get_arm_angle()` was written in `advance_data.py` and the drawing code existed in `advance_report.py`, but neither CLI script ever imported or called it. The function sat unused for weeks. The app happened to call it, but the CLI-generated PDFs had no arm angle.

**How to apply:** After writing any new data function, grep for every entry point that should use it (CLI scripts in scripts/, app pages in pages/, report generators). Verify the import exists AND the function is called AND the result is passed through to rendering. Don't just check one path — check all paths.
