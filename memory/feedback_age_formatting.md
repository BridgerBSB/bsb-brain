---
name: Age formatting rule
description: Age must NEVER round up, ALWAYS display with exactly one decimal place (e.g., 23.4 not 24)
type: feedback
---

Age should NEVER round up and ALWAYS include exactly one decimal place.

**Why:** User explicitly emphasized this — rounding up age is wrong (a 23.4-year-old is NOT 24). One decimal gives precision without noise.

**How to apply:** Everywhere age is calculated or displayed — affiliate trackers, reports, PDFs, app pages. Use `math.floor` or truncation-based logic, NOT `round()`. Format as `f"{age:.1f}"` after truncating to one decimal.
