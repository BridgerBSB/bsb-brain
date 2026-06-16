---
name: tracker-pdf-button-pickup
description: "SHIPPED May 21 2026 — Save Screen button on all 5 affiliate trackers (window.print + uncapped table heights). Only working approach after 4 failed PDF attempts. Canonical rule lives in .claude/rules/tracker-save-screen.md (synced 4 worktrees, md5 d67e93e3)."
metadata:
  node_type: memory
  type: project
  originSessionId: 6e6e8d5b-3ddf-49a1-89f1-93c41cf10ac9
---

# Tracker Save Screen — SHIPPED May 21 2026

## What shipped

**💾 Save Screen** button at bottom of sidebar on all 5 affiliate
trackers: Catcher / BR / OF / IF / Hitter / Pitcher.

Click → browser print dialog opens → coordinator picks "Save as PDF"
destination → file downloads with pre-filled filename like
`<tracker>_<seasons>_<levels>_<YYYYMMDD-HHMM>.pdf`.

**Companion change:** every `st.dataframe(...)` call across all 5
tracker pages uses `_df_height(n_rows)` — returns full natural height,
NO cap. Required so canvas-virtualized rows are in DOM at print time
(otherwise browser captures only visible viewport).

## Canonical rule

`.claude/rules/tracker-save-screen.md` — synced byte-identical to
all 4 worktrees (md5 `d67e93e3...`). Documents:

- 4 failed approaches before settling: html2canvas (garbage) →
  window.print (viewport cutoff) → server-side reportlab (wrong shape)
  → HTML popup (blocked)
- Why window.print + uncapped heights is the only working combo
- BLOCKING: never re-cap dataframe heights on tracker pages
- 5-touchpoint checklist + canonical helper + JS payload
- Honest limitations (sidebar excluded, captures current scroll only,
  page reloads after print)

## Commit chain

| Worktree | Commit | What |
|---|---|---|
| intangibles | `285be707` | Catcher rename + uncap |
| intangibles | `f560b4c2` | BR + Fielding (OF+IF) Save Screen + uncap |
| barrelsville | `3d726f8d` | Hitter Save Screen + uncap |
| bullpen | `013fe27e` | Pitcher Save Screen + uncap |
| pd-goals | `7b77d829` | Rule file shipped |
| bullpen | `93021f3e` | Rule sync |
| barrelsville | `0285d583` | Rule sync |
| intangibles | `5fa0e9f3` | Rule sync |

## Deploy needed

Pull on work laptop in all 4 worktrees + redeploy 3 Streamlit apps
(Barrelsville, Arm Farm, Intangibles).

## What NOT to revisit

Don't try html2canvas, server-side reportlab, or HTML popup again
for tracker PDF export — all documented in the rule file as failed.
If a coordinator complains about the viewport-cutoff limit, the
honest answer is "scroll the table to show what you want, then click
Save Screen." Building a "better" PDF export would require either
abandoning Streamlit's dataframe widget or pivoting to a totally
different UI architecture.
