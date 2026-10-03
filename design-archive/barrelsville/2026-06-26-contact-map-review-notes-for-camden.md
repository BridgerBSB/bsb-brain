# Contact Map (PR #9) — Areas of Skepticism & Future Considerations

**To:** Camden
**Re:** `cq/contact-map-prod` — Contact Map as a third Postgame view
**From:** review pass on `b0df535`

Hey Camden — really nice work on this. The wiring is clean (every page var is in
scope above the keyed selector, `render_contact_map`'s signature matches the call,
the keyed `segmented_control` keeps the active view, and the heavy whole-level pools
are all `@st.cache_data(ttl=3600)` under an `@st.fragment`), the column usage is
canonical, and the coordinate conventions (catcher's view, plate point-down, ABS 17"
zone) are all on point. The two items from the first round — the 3-tier video chain
and the miss-dist double-round — are verified fixed.

None of the below blocks the integration. These are the spots I wasn't 100% sure
about and that are worth a look before it goes in front of coaches, roughly in
priority order.

---

## 1. gcOBA input gate vs. our canonical (the one to verify)

This is the main one. `_GCOBA_INPUTS_SQL` feeds the canonical `compute_gcoba()`
helper — good — but the **inputs** it builds differ from our blessed gcOBA path
(`tracker_data.py` / `gcoba_canonical.py` / `postgame_percentiles.py`) in three
places:

| Input | Our canonical | Contact Map |
|---|---|---|
| **IBB in PA** | `pa = SUM(pa) + SUM(ibb)` (includes IBB) | `pa = pa_flags`, `ibb_flags` hardcoded `0`, `pa=1` gate → IBB dropped |
| **EV-misread p95 filter** | `NOT (ev>=100 AND la<-35 AND ev>ISNULL(bp95.p95_ev,105))` on `n_bip_tracked` / `n_barrel` / `avg_useful_ev` | none (your comment says deliberate) |
| **Swing distribution** | `pitch_result_id IN (10,22,23)` per PA | S/W/T counted off the `ev.pitches` string |

**Why I'm flagging it:** with these gates, the *same hitter's* gcOBA **TOTAL** can
come out with a different value — and a different percentile color — in the Contact
Map than in the Postgame Report sitting right above it on the same page. Your
comments say the inputs are intentionally GC2-exact, so this may be correct on
purpose.

**Suggested check:** pick one real hitter and compare three numbers —
Contact Map TOTAL gcOBA vs. Postgame Report gcOBA vs. GC2's own gcOBA. If they
match GC2, great, and the *report* may be the one that's slightly off (separate
issue). If GC2 itself has no p95 filter, that's actually a finding about our
canonical helper, not your PR — flag it and we'll audit `gcoba_canonical.py`
across all surfaces rather than fix it here. Either way, a single Sacco-style
parity row settles it.

---

## 2. TOTAL gcOBA colors against a rebuilt pool

The TOTAL row is percentile-colored against a fresh `_gcoba_pool` (min 10 PA,
ttl 1h) rather than the `percentiles["gcoba"]` distribution the page already has
loaded for the Postgame Report (min 25 PA, ttl 16h).

**Future consideration:** coloring the TOTAL against the *existing* pool would
guarantee one color per hitter per page (and skip a redundant whole-level load).
The per-pitch-type rows genuinely need their own pool — no existing counterpart —
so this only applies to the TOTAL.

---

## 3. Render-and-look (rule #18)

I didn't see evidence the five figures were rendered and eyeballed; the PR notes
defer testing to after merge.

**Suggested check before coach release:** smoke-render the worst cases — longest
player name in the subheader, a switch-hitter game, an all-Miss selection, and a
zero-`est` frame — and look at the long `figA` y-axis title plus the side-by-side
colorbar spacing (`x=1.02` on two `st.columns(2)` charts can crowd the neighbor).

---

## 4. Switch-hitter bat mirroring

The bat-frame maps mirror by the frame's *majority* hand (one decision per frame),
so for a switch hitter the minority-hand swings get mirrored to the wrong side on
the bat-frame views. The strike-zone and pitch-frame maps are per-row correct, so
this is contained to the bat silhouette.

**Future consideration:** per-row mirroring (or splitting switch hitters into
vs-RHP / vs-LHP, the way the advance fielder pages now do) would resolve it.

---

## 5. `bf_*` column invariant (hardening, not a bug)

The 3D / miss views rely on `bf_along_in` / `bf_depth_in` / `bf_height_in` always
being present, which holds today because `get_swings` adds them on any non-empty
frame. A defensive `.get()` (or a one-line column-presence guard) at the customdata
build would make that explicit if the data layer ever returns a frame built another
way.

---

## 6. OAK→ATH org label (cosmetic)

`_PLAYER_LIST_SQL` (the standalone Swing-Lab dropdown, not the postgame path) selects
`UPPER(mt.org_abbrev)` without the OAK→ATH canon. The JOIN is on `team_id` so nothing
drops — Athletics just shows as `OAK` instead of `ATH` in that one dropdown. Trivial,
only matters if the standalone app ships.

---

## 7. Heads-up: EV-p95 CTE load

Adding the canonical p95 filter (item 1, if we go that way) pulls in the
`batter_ev_p95` `PERCENTILE_CONT` CTE — the same compute R&D/Navisite flagged in the
Jun-24 DB-strain note. It's cached hourly here, so it's bounded, but worth knowing
it stacks onto the thing we're actively trying to lighten. Not a reason to skip the
filter — just context for how to schedule/precompute it.

---

Again — solid, careful PR. #1 is the only thing I'd genuinely want eyes on before it
reaches coaches; the rest are polish and future-proofing. Happy to pair on the gcOBA
parity row if useful.
