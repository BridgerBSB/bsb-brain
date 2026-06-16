---
name: feedback_cli_batch_patterns
description: MUST verify CLI→module function signatures match before committing batch scripts — hitter advance had kwarg mismatch that crashed PDF generation
type: feedback
---

When writing batch CLI scripts that call report generator functions, the function call arguments MUST match the function signature exactly. Do NOT guess parameter names.

**Why:** The hitter advance batch CLI was written with `generate_hitter_advance_batch(hitter_records=...)` but the function signature was `generate_hitter_advance_batch(hitters=..., bip_dfs=...)`. This caused "got an unexpected keyword argument" at runtime — the data collection worked fine but zero PDFs were generated. Wasted a full test cycle.

**How to apply:**
1. Before committing ANY batch CLI, read the target function's signature and verify every argument name matches
2. When building data in the CLI to pass to a report function, match the exact parameter names — don't rename things in between
3. If the CLI collects data as a list of dicts (e.g., `[{"hitter": ..., "bip_df": ...}]`), verify the report function accepts that format OR unpack before calling
4. Run a basic syntax/import check before pushing: `python -c "from src.module import function; help(function)"`
5. Also verify diagnostic/utility functions exist in the module before importing them in CLI
