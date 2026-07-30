# Last session state — 2026-07-30 15:38 (Range & Difficulty — pinned, LIVE)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-intangibles/astros-intangibles` · branch `feature/astros-intangibles` (plus `bsb-resources` / `feature/pd-goals` for the registry + scaffolder fixes)
- **What we were doing:** Range & Difficulty was the last live-query surface among the fielding views — first paint ran a 22-join query over every game the selected player appeared in, so cost scaled with GAMES and a three-level everyday player was the worst case (Lucas Spence). Pinned the per-play frame, kept the live query as a total fallback, and built the scheduled bundle so it refreshes.
- **Shipped this session:** `f87a8023` (per-play pin + the `_range_plays_raw_live` / `_range_plays_from_raw` seam) · `f438f86d` (harness: empty-vs-empty is INCONCLUSIVE, never a pass) · `f2fecea0` (`connect_pins_range/` bundle) · `369d6659` (`src/st_compat.py`, streamlit-optional roster import) · `fcd95a33` (pyarrow) · `ccfb8d70` (LINEAGE). bsb-resources: `41b71cc2` + `78098dac` (`docs/PARQUET_REGISTRY.md`) · `ac171cc6` + `40564188` (two scaffolder bugs fixed at the template). **Both pins LIVE on Connect, confirmed working by Zac** — `intangibles_range_plays_of_2026` (38,555 × 75, 69 fielders) and `_if_2026` (55,436 × 77, 83 fielders), ~36s to build both. OF and IF both fast.
- **EXACT next step:** Finish Connect setup for content `intangibles-pin-range-plays-2026` (GUID `eb324534-ebb9-409f-a027-a716f591688b`) — Vars tab + a **12h schedule**. Until that schedule exists the pin is a manual run and the view silently goes stale for every already-pinned fielder (the live fallback only fires for a fielder *absent* from the pin). Then run the never-executed harness: `python scripts\diff_range_pin.py --gcid 251155 --season 2026 --domain OF`, again with an IF gcid, then both with `--mode pin`.
- **Blockers / waiting on:** Nothing blocking. **The pin is live and UNVERIFIED** — `diff_range_pin.py` has never been run in either mode, so coaches are reading a frame no old-vs-new comparison has checked. Unanswered after asking twice: which domain is Lucas Spence (251155)?
- **Uncommitted work:** intangibles 14 files, bsb-resources 84 files — all pre-existing/unrelated. Nothing of this session's is uncommitted.

---

## ALSO OPEN — PD Goals org cockpit (`bsb-resources` / `feature/pd-goals`)

From the 2026-07-30 14:55 wrap. Separate live thread with an unfinished next step — the range work did not supersede it.

- **What it was:** Got the PD Goals org cockpit deployed and self-maintaining. Unblocked the work-laptop deploy chain (deploy script failed 4×, 4 different bugs), built the missing Connect-scheduled bundle for the compliance-history pin, then fixed three UI reads Zac caught on the live page.
- **Shipped:** `4d53522b` + `68ae0861` + `ab0367b3` (deploy_pd_goals.ps1) · `ce086675` + `3b5b112e` (new `connect_pins_history/` → Connect content `pd-engine-pin-compliance-history-2026`, GUID `5925205b-777d-468e-9682-e15721f3e674`) · `e4befb85` (By Domain panel height) · `542f0af0` (month trend April–July; open-player crash) · `42b2fce2` (LINEAGE). 45 tests pass. Renders at `docs/plans/mocks/pd-goals-cockpit/phase4-*.png`. Work-laptop chain ran green — history pin built, 968 rows.
- **EXACT next step:** Delete the Goal Compliance tab — but **PORT FIRST**: move the "↻ Recompute current phase (live)" button into the cockpit header and fix the caption at `src/cockpit.py:591` that tells users to click it, THEN remove the `if _view == _V_COMPLIANCE:` block in `pages/1_PD_Goals.py` (~line 1189) + its `_V_COMPLIANCE` entry in the view radio. Ask Zac whether the per-GOAL Individual Compliance table needs porting or can be dropped (the cockpit's is per-PLAYER).
- **Blockers:** Connect UI clicks on the work laptop — (1) `DB_USER`/`DB_PASS` Vars on `5925205b-...` (CONNECT_API_KEY NOT needed, Connect injects it, proven); (2) Schedule tab on BOTH pin contents, every 12h, timezone **America/Chicago** (not literal "CST"), staggered 1–2h with compliance first; (3) confirm `pd-engine-pin-compliance-2026` (`c65342b2-828c-4f6a-a9dd-916fe9caa3be`) even HAS a schedule. Also never run: the acceptance check (cockpit matrix Total vs Goal Compliance Total, same Year+Phase) — do it BEFORE deleting that tab, it's the cross-check surface.

---

## ALSO OPEN — BR 1→3 canonical rollout (`bsb-resources` / `feature/pd-goals`)

Concurrent thread on the same branch. Commits `06fcfa58` `5ee45396` `aa006003` `ff3e3bf5` belong to it (BR true 1→3 on EOY P21 + Org KPI, diff harness) — do not attribute them to the cockpit or range work.

**Correction:** the prior wrap listed `ac171cc6` under this thread. It is not — `ac171cc6` is the scaffold-pin-deploy notebook-parser fix from the 2026-07-30 evening range session, made while scaffolding `connect_pins_range`.
