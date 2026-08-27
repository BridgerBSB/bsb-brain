# Last session state - 2026-08-27 15:34 (a saved note came back blank)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`.
- **Recall checkpoint (SOURCE OF TRUTH):** session `c712` - `bsb-resources/feature/pd-goals` id `ebe8348b8c4eda9a`.
- **What we were doing:** A PC&P coordinator reported that EOY notes would not
  save. They always saved. The FORM stopped reading them back, on a return visit
  to a player, because Streamlit collects the state of widgets it did not render
  and the "already hydrated" marker is a plain key that survives and blocks the
  re-read. His own workaround - refresh the whole page - is the bug's only
  recovery path, which is what confirmed it rather than cleared it.
- **Shipped this session:**
  - `568c409c` note mirror + one `_note_area` helper for all 13 position / 18
    pitcher boxes; unsaved text now survives a player switch too.
  - `dce62570` Download control back to button width (yesterday's data-URI swap
    styled it `width:100%`).
  - `0ee3fac8` SEASON into `_KP` - the key never carried it while the notes pin
    is one PER season, so reopening a closed year would have written this year's
    text onto the old row.
  - Guard `test_eoy_note_key_isolation.py` gained the return-visit lifecycle sim
    + the SEASON assertion, proven red on the pre-fix page. Two of that file's
    OWN checks were lying and were repointed.
  - `.claude/rules/streamlit-conditional-widget-state.md` Failure 1b, synced to
    all 3 sibling worktrees. LINEAGE entry pushed.
- **EXACT next step:** when the coordinators are out of the app, from
  `C:\Users\zbridger\bsb-resources\pd-goals` run the plain
  `rsconnect deploy manifest . --app-id 79f52369-8244-46da-a4d6-95df956bacad`
  (~30s). NOT `deploy_pd_goals.ps1` - UI-only change, that burns ~20 min
  re-pinning compliance for nothing. Then Zac's two tests: open a player, type,
  Save, switch players, switch back WITHOUT refreshing (note must persist); and
  download Neyens and look at page 1.
- **Blockers / waiting on:** none blocking. Page 1 geometry LOOKS RESOLVED -
  Zac loaded several decks on the current deploy and page 1 was right on all of
  them, which is what the stale-bundle theory predicts. Do not reopen it as a
  code defect. The Neyens deck from
  19:17 UTC has page 1 scaled by exactly 100/72 about the origin (fonts
  unchanged, pages 2-21 fine). HEAD renders it CORRECTLY under matplotlib 3.11.0
  and Connect's exact 3.11.1, under Agg and a bare canvas, and at `eb7851ca` -
  and that deck came from the bundle deployed BEFORE the session's `git pull`.
  If it EVER scales again, the tell is the exact 100/72 ratio with fonts
  unchanged - and the place to look is the DEPLOYED bundle on Connect, not this
  repo, which was checked five ways.
- **Uncommitted work:** clean.
