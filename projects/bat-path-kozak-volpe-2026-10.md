---
type: research
status: captured
created: '2026-10-13'
tags:
  - hitting
  - bat-tracking
  - swing-path
  - attack-angle
---
# Bat-path logic: Eric Kozak's Volpe threads (2025 + 2026)

**What it is.** Two X threads by Eric Kozak (@kozy_shack) diagnosing Anthony Volpe's
swing from public bat tracking (Savant + TruMedia), with a "baseline vs optimized" bat
path visual. Zac's framing: "here is some hitting logic."

- Thread 1, Sep 11 2025 (7 posts): <https://x.com/kozy_shack/status/1966275872870269306>
- Thread 2, Sep 30 2026 (5 posts): <https://x.com/kozy_shack/status/2105427183787184368>
- Fetched via `api.fxtwitter.com/2/thread/<id>` (the full author thread, not just post 1).
  All 4 images read, all 8 clips frame-sampled. Clips have no voiceover.

## Thread 1 (2025): "adjust his bat path"

- After 2023 Volpe changed his swing to cut K%: **27.8 -> 22.6**. Batted balls got worse:
  PullAir% **19.9 (2023) -> 12.9 (2025)**, Barrel% 9.0 -> 10.2, wOBACON .357 -> .343,
  xwOBACON .382 -> .384, RV/100 BIP -4.16 -> -2.78 (TruMedia spray charts).
- Savant swing card by year (2023 / 2024 / 2025): Attack Angle 12 / 10 / 11 deg (MLB 10);
  Attack Direction 2 pull / 7 oppo / 5 oppo (MLB 2 pull); Swing Path Tilt 34 / 33 / 32
  (MLB ~32-33); Intercept vs center of mass 29.3 / 26.4 / 25.1 (contact getting DEEPER);
  Swing length 7.1 / 7.1 / 7.3.
- Claim: contact deeper is consistent with whiffing less, **but it should have come with a
  much larger DECREASE in Attack Angle.** Working uphill this early in the arc hurts
  contact vs 4-seamers and LHP breaking balls (K heat map is up in the zone) and makes it
  hard to square the ball out front and pull it in the air.
- Attack direction stayed very oppo; Volpe lacks power to do damage to CF; **68% of his
  barrels went to CF**, among the least productive barrels in MLB.
- Prescription: "stay tighter": lower AA deep in the zone (more FB contact) and easier to
  contact out front and elevate pull-side. Visual: 3 orthogonal views of baseline vs
  optimized bat path (side, top, catcher's view), contact point marked on each.
- Context claim: back to even a 0 run value bat he is 1.5-2 WAR given SS defense.

## Thread 2 (2026): the step back worked, then a new problem

- Added a step back in AAA. In Sept: swing length shorter, Max EV% up. Pull% **35.4 ->
  42.1** but Pull GB% **18.9 -> 26.3** and Pull Air% **16.5 -> 15.8** (until 8/2 vs
  since 9/1): pulling more, on the ground.
- 2026 May-Aug vs Sep table (3-view path comparison, Savant):

| | Bat speed | AA | Swing length | Attack dir | Tilt | Ideal AA% | Intercept Y |
|---|---|---|---|---|---|---|---|
| May-Aug | 71.6 | 9 | 7.1 | 5 oppo | 32 | 57.8% | 25.1 |
| Sep | 68.4 | 13 | 6.8 | 5 oppo | 35 | 51.2% | 24.6 |

- Claim: now it is an Attack Angle problem. 13.1 deg is ~3 above MLB average, and with a
  deep POC that is a red flag. **By the time he reaches the pull side his AA climbs to
  17.5 deg**, so pulled contact comes out as top-spinning liners and grounders.
- Prescription: work LESS uphill throughout (lower AA everywhere) to square balls out front
  and fix pull-side ball flight: fewer barrels wasted on F8s, more pull-side XBH.

## The logic, distilled (hypotheses, not prescriptions)

1. **Read AA conditional on contact depth.** The bat is still rising as contact moves out
   front, so the same swing reads a higher AA at a pulled contact point. An AA that is
   fine deep can be too steep out front. Deep POC + high AA = the flag.
2. **Pull% is not the goal; Pull AIR% is.** More pulls on the ground is not progress.
3. **Barrel DIRECTION matters.** Average power + oppo attack direction = barrels die in CF.
4. **Swing length at a constant POC** is the "space to turn" signal (shorter = more time).
5. These are one analyst's observational reads on one player. Per
   `prescriptive-claims-from-observational-data.md`, do not ship any "should" from them
   as a coaching cue; test them.

## Takeaways for us

- **Direct input to the paused AA/VBA/HBA study** ([[optimal-swing-angles-paused]]):
  "AA conditional on PoC depth" is a concrete, testable hypothesis. We store PoC and
  PoCRelY per swing (`swing-characteristics-canon.md`), so we can plot AA vs contact depth
  per hitter and test whether steep-AA-out-front predicts pulled GB% / topspin LD.
- **Watch the canon's warnings:** HBA is bat ORIENTATION, not attack DIRECTION; every swing
  number needs its domain (BBE / whiff / all swings). Kozak's "attack direction" is a
  direction metric; check what our canon has before porting.
- **The 3-view baseline vs comparison path is a card we can build** from bat trajectory
  data (`sql-queries/bat-trajectory-discovery.sql`): one hitter, two windows (or player vs
  level average), side / top / catcher views + the 7-column table. Swing cards are PARKED
  ([[batted-ball-profile-and-swing-cards]], spec `docs/plans/2026-10-01-swing-cards-future-spec.md`);
  this is the clearest public reference for what that card should look like.
- **Window-split table** (until X vs since Y) is the shape a coach reads a mechanical
  change in. Pairs with the change-point idea ([[intervention-change-point-tool]]).

## Action steps

- [ ] Add "AA vs contact depth" as hypothesis H1 in the swing-angle study spec section 0.
- [ ] When swing cards un-park, use Kozak's 3-view comparison as the reference layout.
- [ ] Check whether Savant's "Ideal Attack Angle %" (share of swings in an ideal AA band)
      has a GC2 equivalent before inventing one (GC2 definition wins).

Related: [[MOC-hitting]] · [[optimal-swing-angles-paused]] · [[batted-ball-profile-and-swing-cards]] ·
[[agent-harness-research-2026-10-13]]
