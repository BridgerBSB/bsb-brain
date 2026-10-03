---
name: feedback_lead_with_connect_db_vars
description: "When giving Posit Connect deploy steps for DB-backed content, LEAD with the required Vars (DB_USER/DB_PASS/CONNECT_API_KEY) — don't bury them"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e4e180a0-5ce3-4def-a271-8fc45ff80905
---

When handing Zac deploy/run steps for any Posit Connect content that touches the database (apps, scheduled pin/notebook jobs), **lead with the required env Vars as the first, prominent step**: `DB_USER`, `DB_PASS` (FreeTDS connection on the Linux Connect box) and `CONNECT_API_KEY` (pins board). Without `DB_USER`/`DB_PASS` the content falls back to Windows auth, which doesn't exist on the Linux container → `SSPI Provider / No Kerberos credentials available` → render/launch failure.

**Why:** Jun 22 2026, the arm-angle pin job's Connect deploy failed its first auto-render with the Kerberos/SSPI error purely because the Vars weren't set yet. I *had* listed the Vars but buried them in step 4 of a checklist; Zac: "the issue was that I just needed to set these — but you didn't inform me here: DB_USER, DB_PASS." Setting them connected it.

**How to apply:**
- First line of any Connect deploy instruction = "set these Vars in the content's Vars tab or it can't connect: DB_USER, DB_PASS, CONNECT_API_KEY."
- Connect auto-renders a jupyter-static notebook ONCE at deploy time, before Vars exist — so a DB-dependent notebook will fail that first render unless it skips cleanly when creds are absent (guard pattern now in `connect_pins_arm_angle/pin_arm_angle_2026.ipynb`).
- The SSPI/Kerberos error on Connect is almost always "DB_USER/DB_PASS not set," not a real auth problem.

Related: [[pitch-similarity-app-status]], [[connect-offload-migration]].
