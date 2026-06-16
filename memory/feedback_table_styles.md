---
name: Table Style Preference
description: Use postgame report table style (Rectangle patches + text), ask user which style before starting. Document both plottable and matplotlib Rectangle approaches.
type: feedback
originSessionId: 3735d6ae-711a-4c43-8405-7283c0ef038e
---
Use the postgame report table style (matplotlib Rectangle patches + ax.text) for new reports — NOT the bullpen/KPI report style.

**Why:** User prefers the postgame report rendering style for new table-heavy reports. Both packages (plottable vs raw matplotlib Rectangle) exist in the codebase but user wants consistency with the more recent postgame pattern.

**How to apply:** When creating any new report with tables, ask the user upfront which table rendering approach they want. Document both approaches somewhere accessible so the choice is explicit. Default to the postgame Rectangle pattern unless told otherwise.
