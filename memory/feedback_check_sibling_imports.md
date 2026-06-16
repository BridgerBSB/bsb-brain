---
name: Check sibling imports before writing scripts
description: ALWAYS check existing scripts in the same directory for import patterns before writing new ones
type: feedback
originSessionId: c55a776a-300f-45c5-9975-13b1e64ad5b9
---
When creating new scripts, ALWAYS read an existing script in the same directory first to match the import pattern. Don't guess `sys.path` or module paths — copy the working pattern from a sibling file.

**Why:** Wrote `from intangibles.src.` when every other script in `intangibles/scripts/` uses `from src.` with a `sys.path.insert` to the parent dir. Caused ModuleNotFoundError on work laptop. Basic mistake that wasted time.

**How to apply:** Before writing any new `.py` file, `head -10` an existing file in the same directory to see how imports work.
