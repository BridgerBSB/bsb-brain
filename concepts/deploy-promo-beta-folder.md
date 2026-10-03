---
tags:
  - reference
  - deploy
  - posit
  - promotion-models
created: '2026-06-30'
---
# Deploy gotcha: the Promotion-Model BETA = `pd-goals\promo-engine`, NOT `pd-goals`

In `bsb-wt-modeling`, **two** Streamlit apps share the repo:
- `pd-goals\` → **full PD Engine** (org-facing, entrypoint `PD_Engine.py`, pages 1–7). Its
  `manifest.json` lists all the pages.
- `pd-goals\promo-engine\` → **the private Promotion-Model BETA** (Zac+Sam, entrypoint `app.py`,
  its own `manifest.json`). This is where Promotion Readiness + the rebrand live.

**Deploy the beta with the subfolder path:**
```powershell
rsconnect deploy manifest pd-goals\promo-engine --server https://connect2.astros.com `
  --api-key <key> --title "Promotion Model (BETA)" --app-id <beta GUID>
```

**The trap (happened 2026-06-30):** running `rsconnect deploy manifest .` from *inside* `pd-goals`
deploys the **full PD Engine** (PD_Engine.py), not the beta — and with `--title "Promo Model
(BETA)"` it can RENAME the production PD Engine app. If that happens, fix the title in the Connect
UI and redeploy the real PD Engine. Use `--app-id <existing GUID>` to update an app instead of
`--new` (which creates a duplicate).

Related: [[promotion-release-models]].
