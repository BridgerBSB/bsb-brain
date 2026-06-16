---
name: manifest-new-pages
description: When adding new Streamlit pages or src modules, MUST update manifest.json or Posit Connect won't deploy them
type: feedback
---

When adding a new page file to any Streamlit multi-page app (pages/*.py) or new src module (src/*.py), ALWAYS add it to manifest.json in the same commit.

**Why:** Posit Connect only deploys files listed in manifest.json. Missing files cause "Page not found" on click even though the page exists in the repo. Hit this bug twice — once on Affiliate Tracker, once on Pitching Advance.

**How to apply:** Any commit that creates a new .py file under pages/ or src/ in a Posit Connect-deployed app MUST also update the corresponding manifest.json. Check manifest.json as part of the commit, not as a follow-up.
