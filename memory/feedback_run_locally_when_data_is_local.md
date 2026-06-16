---
name: feedback-run-locally-when-data-is-local
description: "When a script is CSV/parquet-driven and the inputs exist on the personal laptop, RUN IT HERE — do not default to \"do this on the work laptop.\" The personal/work split is specifically about DB access (and rsconnect for some deploys), not about all script execution."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 38cd7bfe-8736-487b-83ef-c3b83a379c01
---

When the user asks me to render/regenerate/run a script and the script is CSV-driven (or parquet-driven, pin-read, or otherwise reads from local files), **run it on the personal laptop directly**. Do not punt to "do this on the work laptop."

**Why:** The user spent 30+ minutes opening a STALE PPTX during the v5.4 review because I kept telling them "run on the work laptop" for a script that only reads `C:\Users\Owner\Downloads\*.csv`. They didn't catch that they had an old file open because I never showed them a fresh artifact. They got rightfully pissed: "i hope we made all the correct changes... fuck u have sero inituitauion." This was the amateur-vs-pro slide deck on `feature/pd-goals`, May 24 2026.

**How to apply:**
- Personal laptop = NO DB access, NO rsconnect deploy capability. That's the rule.
- Personal laptop CAN run anything that's pure Python + reads from local files (CSVs, parquet, pins-via-CONNECT_API_KEY, etc.).
- Before saying "run this on the work laptop", check: does the script touch the DB (`pyodbc`, `database.py::run_query`, `from src.database import`)? If no DB call in the import graph, RUN IT HERE.
- Script families that are safe to run locally:
  - Slide deck generators (`pd-goals/scripts/generate_amateur_vs_pro_slide_deck*.py`) — CSV-driven
  - PDF/PPTX rendering from pre-computed CSVs
  - Pure analysis scripts that read from `~/Downloads/*.csv` or `~/bsb-resources/sql-queries/*.sql` output
  - Any matplotlib / reportlab / pypdf rendering pass over already-fetched data
- Script families that MUST run on the work laptop:
  - Anything that calls `run_query()` against `GCSQL02`
  - Pin builds (`pin_*.py`) — need DB to refresh
  - `connect_pins*/deploy.ps1` — rsconnect deploys
  - Any script that imports `src/database.py` and actually hits it (not just imports)
- If unsure, just try running it on personal. If it crashes with a DB error, THEN tell the user it needs the work laptop.
- After running, USE `SendUserFile` to surface the artifact. Don't make the user navigate to find it — they will open an old one by mistake.

**Don't repeat the "I thought you ran it here in the past" moment.** They have run this exact script locally before (the v4.4 / v5 PPTXs already on disk are proof). I should have remembered the rendering pipeline is local-capable.

---

## Slide deck has TWO build functions — keep them in sync (May 25 2026)

`pd-goals/scripts/generate_amateur_vs_pro_slide_deck.py` has `build_deck()` (PDF). `pd-goals/scripts/generate_amateur_vs_pro_slide_deck_pptx.py` has `build_pptx()` — a *duplicate* slide-order list + its own `from generate_amateur_vs_pro_slide_deck import (...)` block listing every `slide_*` function it calls.

**Whenever the PDF's `build_deck()` slide order changes, `build_pptx()` MUST mirror it AND its import list MUST add any new `slide_*` functions / drop removed ones.** I shipped v5.5 (8 focus slides → 2 consolidated pages) by editing only the PDF build, ran the PPTX script, told the user "v5.5 delivered" — and the file still had 22 slides because the PPTX script's own order list called the 8 individual slides. User caught it ("This is interesting.").

Audit checklist before sending a regenerated PPTX:
1. After editing `build_deck()`, ALSO edit `build_pptx()` to match.
2. Update the `from generate_amateur_vs_pro_slide_deck import (...)` block — add new functions, drop removed ones (orphaned imports raise ImportError on cold-run).
3. Update `total_pages` in BOTH files.
4. **Verify slide count after running**: `python -c "from pptx import Presentation; print(len(Presentation('output/...pptx').slides))"` — should equal `total_pages`.
5. Only THEN `SendUserFile`.
