---
type: project
status: trial
created: '2026-06-18'
updated: '2026-06-19'
tags:
  - pd-engine
  - prp
  - goals
  - in-app-submission
  - connected-cycle
---
# PRP — Player Review Process (PD Engine)

**Status:** BUILT + LIVE on `feature/pd-goals`; **trial run AA / A+ / A in progress** (2026-06-19) · **Repo:** `bsb-resources` (OPERATE track).

## What it is
A one-page navy **Player Review Process** sheet per player: header (title / date / `Last, First` / gcid) → **department table** (each dept = Superpower + Opportunities) → **3-goal grid** (Goal 1/2/3 × What/Why/How). It is now an **app-driven, department-by-department workflow** living as a **tab inside PD Goals** (modeled on the Transition Report: Streamlit → parquet pin → reportlab PDF → Logic App → Slack).

## How it works now (the loop — "the connected cycle")
1. Open **PD Engine → PD Goals**, **pick a player in the sidebar** → **📋 PRP Report** tab loads that player's sheet.
2. Each department fills its **Superpower / Opportunities** (+ the 3-goal grid) and hits **💾 Save**, or **✓ (No Changes)** to keep the baseline as-is. Each saved section turns **green ✅** (with date; no individual name tracked).
3. When **all sections are green** (7 pitchers / 8 hitters incl. the Goals section), the **📤 Send** button unlocks → sends the PRP PDF to the player's **zzz_ coach channel** (🧪 Test mode delivers to #pd-automation-test instead).
4. **A delivered send writes the goals automatically:** the player's current open `goals.csv` row gets `end_date = send date`, and a **new row is appended** (start = send date, blank end, `goal_1/2/3` = the PRP's 3 goal "What" lines). Then the green checks clear → next cycle starts fresh (content kept). Partial/failed send = nothing written.
5. **Goal Compliance** + **Goal Glossary** tabs reflect the new goals immediately (same goals pin; date-aware selection picks the latest open row). Repeatable every cycle; everything pin-backed in Posit.

## Player universe = EBIS (no repin needed)
The PRP roster = the **EBIS/PP_MASTER active roster** (AAA→DSL), same as the sidebar. In-org players show even with **no prior PRP** (acquisitions like Bryce Collins / Garrett Apker → auto-built empty sheet, persists on first Save); released players drop off. `pin_prp_records.py` (work laptop, EBIS sync) is optional cleanup only — **never required** to make a player appear.

## Tabs in PD Goals
🎯 Goals · 📋 PRP Report · ✅ Goal Compliance · 📖 **Goal Glossary** (read-only `goals.csv` table, newest rows on top — replaced the old Upload Goals tab; Zac does back-end goal edits). Goals PDF download moved to sidebar bottom; "Connected to GC2" button removed. Goal Compliance: the All/P/H toggle drives the Org matrix + retitles it "Org Compliance (Pitching/Position Player)".

## Key files
- `pd-goals/src/prp_tab.py` — the tab's `render()` (sidebar-driven, sections, Save/No-Changes, Send, PDF preview).
- `pd-goals/src/prp_workflow_pins.py` — pin `zbridger/prp_records_<season>` (1 row/player: content + per-section status + delivery); `save_section` (upsert), `build_record_row`, `clear_section_status`, `mark_sent`.
- `pd-goals/src/prp_channels.py` — zzz_ coach-channel routing (reuses Transition lookup).
- `pd-goals/src/goals_loader.py::apply_prp_goals` — the cycle write (close old + append new to goals pin/csv).
- `pd-goals/src/prp_pdf.py` / `prp_store.py` / `data/prp_store.csv` — renderer + baseline content store (112 players: A/A+/AA/FCL/DSL).
- CLIs: `pin_prp_records.py` (EBIS sync), `clean_prp_records.py`, `add_fcl_dsl_to_store.py`, `pin_goals.py`.

## Trial-run notes (2026-06-19)
- Depts entered SP/Opp + goals in Excel for AA / A+ / A (Bridger / Camden / Sam & Cristian SharePoint sheets); team enters them into the app together.
- Send-to-zzz is the **real commit** (writes goals) — coaches QA in their channel, then forward to the athlete Z channel manually.

## Gotchas
- **Goals pin pollution:** the Goal Glossary reads the goals **pin** (`zbridger/pd_goals`), not the local CSV. If junk rows appear (blank goals + spurious end_dates, dup period buttons), re-pin the clean CSV: `python scripts/pin_goals.py` (work laptop, `CONNECT_API_KEY` set). Local `goals.csv` is the source of truth.
- `CONNECT_API_KEY` is **per PowerShell session** — pin writes fail with "board unavailable" if unset (reads via DB Windows Auth still work, which is why `--dry-run` succeeds but the real write fails).

## Deferred / open
- **Season-end auto-close** of goals never superseded by a new PRP (Zac: "maybe 9/30?") — not yet built.
- Awaiting Zac's trial-run feedback.

Related: [[pd-onboarding-curriculum]] · unified PD hub vision · dual-track OPERATE-vs-ASSEMBLE.

---

## 2026-06-25/26 — Durability incident + recovery runbook (READ THIS if PRP data looks gone)

A multi-department review session lost saved sections (everyone snapped to **0/8**) after a browser refresh. Root-caused, fixed, recovered. The data was **never actually lost** — it's versioned in the pin. Below is what happened + the runbooks.

### What broke (the wipe)
`save_section` did a whole-pin **read-modify-write**. `load_prp_records` silently **falls back to the blank Spring seed** whenever the pin read returns nothing, and `_pin_read` swallowed *any* error to `None`. So one bad/transient pin read during a save loaded the blank seed, flipped its one section, and wrote that **blank seed back over the real pin** → all 86/251 players reset toward 0/8. "0/8 for everyone" is the fingerprint of the seed getting written back.

### The fix (shipped + live)
- `_read_existing_pin()` — a **strict** mutation-path reader. Returns `None` on board-down / transient error / empty pin. All 5 mutations (`save_section`, `reopen_section`, `mark_sent`, `clear_section_status`, `reset_player`) now **abort (return False) instead of seeding** when the pin can't be read. Seeding stays the job of `pin_prp_records.py` / the read-only display loader only. Commit `7892abbe` on `feature/pd-goals`.
- Net effect: a failed read now surfaces as **"Save failed — pin unavailable"** instead of silently wiping. The catastrophic class is dead.

### Recovery runbook — restore from pin version history
Pins are **versioned** on Connect, so a bad overwrite is just a new version on top of the good ones. Tool: `pd-goals/scripts/recover_prp_pin.py` (commit `6341a43b`). Run from the `pd-goals` dir on the **work laptop** (`$env:CONNECT_API_KEY` set in that session):
```powershell
python scripts/recover_prp_pin.py                 # list every version + sections_done count
python scripts/recover_prp_pin.py --inspect 49620 # per-player detail for one version
python scripts/recover_prp_pin.py --restore 49620 # write that version back as newest (asks to type RESTORE)
```
- `--list` is also the **default** (bare command). NOTE: pin versions sort **oldest→newest by ascending id** — the wipe versions are the *newest* (highest ids) with `sections_done ≈ 1`; the good one is the **last high-count version before the wipe**.
- **This incident: version `49620`** = 251 players / 27 with progress / **156 sections** = the high-water mark. Restored successfully (showed up as `PRP restore from 49620` content in Connect).
- The recover script reuses the app's `get_board()` so the internal-cert SSL patch + key are applied — **don't** hand-run raw `pins.board_connect(...)` in a bare terminal (and never paste Python into PowerShell — it's not Python).

### "Save failed — pin unavailable" runbook (the scary-but-not-loss one)
After a **redeploy**, saves failed with this banner AND a previously-saved player showed **blank/0**. That is **NOT data loss** — when the app can't reach the pin, the display quietly falls back to the **blank starter sheet**, so every player *looks* empty, and the wipe-guard refuses to write.
- **Cause:** the app lost pin access — almost always `CONNECT_API_KEY` missing/blank in the **PD Engine → Vars tab** after a fresh deploy (without it `get_board()` returns `None` → reads blank, writes refuse).
- **Confirm data safe:** `python scripts/recover_prp_pin.py` — if versions still show real `sections_done`, the data is intact; it's purely an access problem.
- **Fix:** Connect → Content → PD Engine → **Vars** → set `CONNECT_API_KEY` = `H9MB6feNB2ccKfmoX9Q3DS7AykVhvNNb` → **restart the content** (Vars only re-read on restart) → reload app → saved players reappear.
- The deploy log showing `pins==0.9.1` + `pyarrow` present means packages are fine — it's the Var, not the env.

### Per-player pins — BUILT then REVERTED (do NOT reintroduce)
To kill the residual "two coaches save different players at the same second" clobber, I refactored to **one pin per player** (`zbridger/prp_p<season>_<gcid>`). **Reverted** (`fc2353d8` → revert `209ab5b9`) because on Posit Connect **every pin is its own Content item** → ~250 players = ~250 dashboard rows = admin/IT problem, and it directly conflicts with IT/Catherine's push to move state **off** Connect. The architecture stays **one pin** (`zbridger/prp_records_<season>`, 1 row/player).
- **Residual on the single pin:** two saves to *different* players within the same ~1s can drop **one section** (re-saveable) — never a wipe, never a whole sheet. Wipe class is fully fixed regardless.
- **Proper "never-again" fix (future, needs IT):** move PRP state to a **DB table** (one row/player, `UPDATE … WHERE gcid=…` → row-level locking, transactional, single object, zero Connect sprawl). This *aligns* with the offload direction instead of fighting it — blocked only by the Connect app being read-only (`rs_connect_ro`); needs IT to grant a writable PRP table/proc. Code can be built ready-to-go for a one-table ask.

### Durability facts to remember
- PRP pin is **app-write-only** — there is **no nightly/scheduled job** that touches it (unlike the trackers). Nothing silently overwrites it overnight.
- You do **not** need `pin_prp_records.py` to keep data — only to **sync the roster** to EBIS (drops retired/released players, keeps every existing edit). A retired name lingering in the list is **cosmetic**, not corruption.
- Sanity-check after any deploy: (1) `recover_prp_pin.py` list shows real counts, (2) open a known-saved player and confirm sections render, (3) save one section → hard-refresh → still there.

### Same session, different worktree — Arm Farm FIP always red (fixed)
`bullpen-report` `scripts/pitcher_analysis.py`: FIP cells colored **red for every pitcher**. Not a color bug — a **scale mismatch**: `get_level_percentiles` builds the FIP pool as **FIP "core"** (no `fip_const`, ~0.9), but the looked-up value is the **displayed FIP** which *adds* `fip_const` (~4.0) → every pitcher ranks above the whole pool → 100th pct → lower-is-better → always red. Fix: in `get_level_percentiles` shift the `"fip"` pool up by the level's `_get_fip_constant_for_level` so both sides share a scale (uniform shift → ranks unchanged). `"fip"` is consumed *only* by `pitcher_analysis` (postgame doesn't touch it) → zero parity risk. On `feature/bullpen-reports`. Re-run the script to see it (it's a batch PDF, no app redeploy).

Related: [[pd-onboarding-curriculum]] · `in-app-submission.md` (live rule) · `tracker-parquet-pins.md` §5.10 (CONNECT_API_KEY).
