---
name: contact-map-postgame-merged
description: "Camden's Contact Map (Swing Lab) merged into Barrelsville Postgame as a 3rd view (PR"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5e839857-f554-4166-a88d-9c360ed4ccae
---

Camden Quick's **Contact Map** (Swing Lab) shipped into the **Barrelsville Postgame**
app as a third `segmented_control` view alongside Postgame Report / Visuals. PR #9
(`cq/contact-map-prod` → `feature/barrelsville`), **MERGED 2026-06-24** at `b0df535`.
New files: `barrelsville/src/contact_map_data.py` + `contact_map_render.py` +
`click3d.py` (+ `click3d_frontend/index.html`). Pure Plotly + a self-contained
clickable-3D component. Heavy whole-level pools are `@st.cache_data(ttl=3600)` under
`@st.fragment`.

Review (this session) verified clean: DB columns/joins canonical, integration wiring
(all page vars in scope above the keyed selector, signature match, view-persistence),
caching, coordinate conventions. Two first-round fixes landed: 3-tier video chain +
miss-dist double-round.

**OPEN CAVEAT (now live in merged code, untested):** Contact Map's `_GCOBA_INPUTS_SQL`
diverges from our canonical gcOBA path (`tracker_data.py` / [[gcoba-canonical]] /
`postgame_percentiles.py`) on 3 inputs — (1) **IBB dropped** (`pa=pa_flags`, `ibb=0`,
`pa=1` gate) vs canonical `pa+ibb`; (2) **no EV-misread p95 filter** vs canonical
`NOT(ev>=100 AND la<-35 AND ev>ISNULL(bp95.p95_ev,105))`; (3) **swing-dist off the
`ev.pitches` S/W/T string** vs canonical `pitch_result_id IN (10,22,23)`. So the same
hitter's gcOBA **TOTAL** can show a different value + percentile color in Contact Map
than in the Postgame Report on the same page. Camden's comments call it deliberate
GC2-exact; Zac chose to TRUST that for now (he didn't know GC2's true definition).
Verified from code that all 3 canonical surfaces DO apply the p95 filter — so "match
canonical" = WITH filter, and Camden's is the divergent one. Note the p95 filter is
the same `batter_ev_p95` PERCENTILE_CONT CTE that [[db-strain-ev-precompute-status]]
is precomputing.

Concerns raised to Camden: PR comment
(github.com/zbridger_astros/bsb-resources/pull/9#issuecomment-4794504057) + memo
`barrelsville/docs/2026-06-26-contact-map-review-notes-for-camden.md` (untracked local
file unless committed). 7 items; only #1 (gcOBA parity) is "verify before coaches."

**Why:** the divergent gcOBA gate shipped to production unverified; if a coach sees two
different gcOBA colors for one hitter on the Postgame page, this is the cause.

**How to apply:** if the mismatch surfaces (or before heavy coach use), run a parity
row — Contact Map TOTAL gcOBA vs Postgame Report vs GC2 — on one real hitter. If they
match GC2, the *report* may be the off one (separate audit). If GC2 has no p95 filter,
that's a finding about our whole gcOBA canonical, NOT this PR — don't bolt the fix onto
Contact Map. Other future items in the memo: TOTAL should color vs the already-loaded
`percentiles["gcoba"]`; render-and-look (#18) smoke cases; switch-hitter frame-level
bat mirroring.
