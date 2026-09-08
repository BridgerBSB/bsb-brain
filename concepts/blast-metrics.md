---
{type: concept, domain: hitting, source: 'HTKCH Blast Motion quiz + biomechanics (via Ivan Quackenbush, Jun 18 2026)', created: 2026-06-18, updated: 2026-06-18}
---
# Blast / Bat-Sensor Metrics

The bat sensor is the **field-portable swing lab** — a small accelerometer/gyroscope
clipped to the knob (Blast Motion, Diamond Kinetics SwingTracker) that reconstructs the
3D path and speed of the bat through contact in seconds, in the cage, on the field, or in
a game. Where the full mocap lab ([[hitting-biomechanics]]) gives the *full-body* story
across all phases, the bat sensor gives the **business end** — what the barrel actually
did at impact — cheaply, anywhere, and every swing. It is the single most important tool
for **bat-speed training** (you cannot train an intent you cannot measure) and for
**bat-path diagnosis** (the two attack-angle [[swing-flaws-programming]] flaws are
*defined* by sensor AA paired with outcomes).

This note is the deep reference for every metric a knob sensor reports: what it is, how
it's derived, units, what good looks like, how it correlates to outcomes (EV, batted-ball
quality, in-game production), how to **train** it, and the common misreads. It is the
literal source of the deck's **`AACon% (4–16)`** metric and ties directly into the Astros
attack-angle / point-of-contact / bat-speed-canonical stack.

> **Voice rule (BLOCKING):** these are **Astros principles**. In coach- or player-facing
> material, never name or cite the sensor vendor or the source curriculum — present the
> standards as ours. Source attribution here is for our internal reference only.

---

## The sensor at a glance — what it measures and how

The knob sensor fuses an **accelerometer** (linear acceleration, 3 axes) and a
**gyroscope** (angular velocity, 3 axes) sampled at high rate. It detects the **impact
event** (the acceleration spike of ball-on-bat) and integrates the motion signal across a
short window around it to reconstruct the bat's 6-degree-of-freedom trajectory: position,
orientation, linear speed, and rotational speed through the swing. Every metric below is
either read **at the impact instant** or **across the swing window** — and *which* matters
enormously (the contact-point trap, below).

Two truths frame all sensor reading:

1. **No single swing model exists.** As in [[hitting-biomechanics]], we optimize for
   **function, not aesthetics**. Benchmarks below are *reference bands*, not cookie-cutter
   targets — anatomy, mobility, and the hitter's profile dictate his own optimum.
2. **Average, not max, separates levels.** As with [[big-3-hitting]] bat speed, MLB
   hitters don't just own a high *peak* — they sit a **higher proportion of swings near
   their peak**, across locations and pitch shapes. Read the *distribution*, not one hero
   swing.

---

## Bat Speed (at contact)

**Definition.** The linear speed of the **barrel sweet spot** (≈ 6" from the end cap — the
same barrel point used for attack angle in [[hitting-biomechanics]]) at the **impact
instant**. This is the canonical "bat speed" of the [[big-3-hitting]] model.

**How measured/derived.** The sensor reconstructs barrel position over the swing window and
differentiates it to velocity, reporting the magnitude at the detected impact time. (Mocap
labs measure it directly; markerless systems like Hawkeye/Kinatrax do too; for un-sensored
in-game swings it is *reverse-engineered* from the hardest-hit balls — see Top-8th EV in
[[big-3-hitting]].)

**Units.** mph.

**What good looks like.** In-game MLB bat speed sits around **~72 mph** (model estimate);
BP bat speed runs higher, and carrying BP speed into a game is itself a *skill*, not an
assumption. Lab "fast swing" reference band = **peak barrel velocity > 72 mph** (mostly
pros). Treat anything materially below the in-game ~72 as a development target; read the
hitter's **90th-percentile** bat speed and his **average**, not a single max.

**Correlation to outcomes.** The cornerstone relationship: **~1 mph bat speed ≈ +1.2 mph
EV** on a given batted ball, holding contact quality constant. Bat speed sets the *ceiling*
on EV and therefore on damage — average recorded bat speed rises monotonically toward the
majors (upper-MiLB > lower-MiLB, D1 > non-D1, MLB highest). **But bat speed without contact
is worthless** — a hitter who whiffs at everything has 0 EV regardless of swing speed.

**How to train it.** The flagship tool is the **Speed Trainer set** (Barrel-load +20%,
Handle-load +20%, Underload −20% of game-bat weight) — the **20% over/under rule** is the
canonical bat-speed constraint; past ~20% the swing happens at a velocity that does not
transfer and bat speed stagnates or drops (DeRenne: live-arm group +10%, dry-swing +6%,
control no gain). High-**intent** swings (clearly define the problem as *speed*, not contact
quality), variability within/between sets, and **strength** work (MLB hitters put ~2× body
weight, some ~3×, into the **lead leg**; gym strength correlates strongly to bat-speed
gains). See [[training-implements]] and the root-cause tree in [[big-3-hitting]] (weak /
poor mechanics / low intent). Note: **hitters perform best at ~90–95% of max** bat speed —
raise the *training* threshold so the *game* swing rises with it.

**Common misreads / pitfalls.**
- **"Faster" that's actually slower.** Over-swinging where high torso speed isn't transferred
  through arms/hands produces a swing that *feels* faster but reads **lower bat speed** — the
  exact reason a sensor is mandatory (don't chase feel, chase the number).
- **BP speed ≠ game speed.** Reporting cage bat speed as in-game inflates the grade.
- **Ball/environment confounds** when reverse-engineering from EV: soft (heavily used) balls,
  pitch difficulty, and altitude all move EV independent of bat speed.

---

## Peak Hand Speed & the Efficiency Ratio

**Definition.** **Peak Hand Speed** = the maximum linear speed of the **hands/knob** during
the swing (not at impact — at its peak, which occurs *before* contact). The
**efficiency ratio = bat speed ÷ hand speed** — how well the hitter converts hand speed
into barrel speed via the "whip" of the kinetic chain ([[hitting-biomechanics]] hands/wrists
section).

**How measured/derived.** The sensor tracks the knob (where it's mounted) directly for hand
speed; bat speed is the barrel reconstruction. The ratio is a pure division reported per
swing and as an average.

**Units.** Hand speed in mph; efficiency is a **unitless ratio** (typically ~1.4–1.8×, i.e.
the barrel moves well faster than the hands because the bat is a lever rotating about the
hands).

**What good looks like.** A *higher* efficiency ratio means more barrel speed per unit of
hand speed — the chain is whipping the barrel rather than the hands dragging it. This is one
of the in-gym report's headline bat-sensor lines (avg bat speed · avg attack angle ·
**90th-pctile bat speed** · **efficiency = bat speed ÷ hand speed**). Read it *together with*
bat speed, never alone.

**Correlation to outcomes.** Efficiency localizes *why* bat speed is what it is. Two hitters
at the same bat speed:
- **High hand speed, low efficiency** → he's muscling the bat with the hands/arms (a
  **push pattern** / disconnection signature — distal segments outpacing proximal). Speed is
  being *spent* in the hands and lost.
- **Lower hand speed, high efficiency** → an efficient chain; there may be **more bat speed
  available** by adding hand speed (strength/intent) without re-sequencing.

**How to train it.**
- **Low efficiency (push/disconnection):** the **Bazooka bat (45–50 oz)** is built to attack
  the push pattern and bat drag — it forces the upper segments to hold isometrically and
  sequence; pair with connection cues ("swing across your shoulders," "turn behind the ball").
  The **Long bat (37"/37 oz)** patterns the full kinematic sequence and hip-shoulder
  separation upstream.
- **High efficiency, want more output:** add **hand speed** via strength + intent (Speed
  Trainers) — the conversion is already good, so raising the input raises the output.

**Common misreads / pitfalls.**
- **Chasing hand speed in isolation.** More hand speed with *falling* efficiency is the push
  pattern — you've made the swing worse. Always read the ratio alongside the raw numbers.
- **Don't equate "peak hand speed" with "bat speed."** They peak at different instants; a
  big hand-speed number with mediocre bat speed is a *transfer* problem, not a strength one.

---

## Time to Contact

**Definition.** Elapsed time from the **start of the downswing** (commit) to **impact** — how
long the swing takes once it's launched. This is the sensor analog of the biomech "the swing
takes **~0.140 s**" constraint in [[big-3-hitting]] (a blink is ~0.33 s; a 90 mph pitch reaches
the glove in < 0.4 s).

**How measured/derived.** The sensor detects swing initiation (the rotational/linear onset
after the load) and the impact spike, and reports the interval. Often surfaced as a
**"time to impact" feedback** number for drill work.

**Units.** Seconds (e.g. **~0.140 s** target band; sensors typically read in the
0.12–0.18 s range).

**What good looks like.** Around **~0.140 s** is the working target — quick enough to let the
hitter **wait longer / decide later** and still get the barrel there. A *lower* number is
generally better **only if bat speed and path hold** — it buys decision time, the scarcest
resource against velocity. It is not a free maximize: shaving time by shortening/steepening
the path or going hand-dominant trades away path quality and bat speed.

**Correlation to outcomes.** Faster time to contact → **later commit point** → better
[[big-3-hitting]] swing decisions and bat-to-ball vs velocity and breaking balls, because the
hitter can recognize longer. Most bat-to-ball failures trace to being **consistently late**
(timing) — a quicker, more efficient delivery directly addresses that.

**How to train it.** Train it as a **byproduct of efficiency, not as a standalone "be quicker"
cue** — a hand-dominant "quick" swing is a regression. Sequence/connection work (Long bat,
Bazooka) shortens time-to-contact by removing wasted distal motion (bat-wrap, barrel
maintained vertical too long → longer path). **"Time to impact" feedback** off the sensor is a
clean external target the hitter can self-organize toward. Pair with high-velo machine reps so
the internal clock recalibrates to game timing.

**Common misreads / pitfalls.**
- **The shortcut trap:** getting "quicker" by collapsing the path or letting the hands take
  over (push pattern) — quicker *and worse*. Verify bat speed and attack angle didn't degrade.
- **Time to contact is path-coupled.** A barrel left vertical well past launch (a push-pattern
  / bat-drag marker) lengthens the path and the time; fixing the path fixes the time.

---

## Rotational Acceleration

**Definition.** How fast the bat **builds rotational speed** in the early part of the swing —
the *acceleration* of the barrel's turn out of the launch position, i.e. how explosively the
hitter gets the bat moving, not just its top speed.

**How measured/derived.** From the gyroscope's angular-velocity signal: the rate of change of
the bat's rotational speed in the initiation window (a derivative of the angular-velocity
curve early in the swing).

**Units.** Reported as a sensor index (g's of rotational acceleration / a proprietary scale).
Read it **relatively** — vs the hitter's own baseline and vs population — rather than against a
single universal number.

**What good looks like.** *Higher* rotational acceleration = the hitter gets the barrel turning
hard early — a marker of an efficient, well-sequenced launch (pelvis rotational velocity *into*
foot plant, then a powerful torso recoil; [[hitting-biomechanics]] notes pelvis velocity **at
foot plant** correlates to bat speed better than *peak* pelvis velocity). It pairs with quick
time-to-contact.

**Correlation to outcomes.** Strong early rotational acceleration supports both **bat speed**
(more runway to peak) and **time to contact** (gets there sooner) — it's an efficiency/sequence
signature. **Low** rotational acceleration often co-occurs with sequencing problems: a hitter
who can't turn the barrel hard early tends to compensate later (hands take over → push pattern,
or drags the barrel).

**How to train it.** It's primarily a **sequence + strength/power** quality. **Speed Trainers**
(intent + the 20% rule) raise explosive output; **Long bat** patterns the pelvis-leading
sequence and separation that *feeds* early rotation; strength work (the reactive/explosive
battery — Countermovement Jump, Squat Jump, Repeated Hop in [[big-3-hitting]]) raises the
power available to accelerate the bat. Lower-half power into a firm **lead-leg block** is the
engine.

**Common misreads / pitfalls.**
- **Don't read it in isolation.** Low rotational accel + high VBA + high early connection is a
  *profile* with a specific prescription (below) — the single number isn't the diagnosis.
- **Sensor-scale literacy:** it's an index, not mph; compare to the hitter's own history and
  the population band, not a folk "good number."

---

## Attack Angle (AA)

**Definition.** The **vertical angle the barrel travels** at the impact instant. **+ = upward
("uppercut")**, **0° = level**, **− = downward ("chopping")**. Same definition as the bat-path
**Attack Angle** in [[hitting-biomechanics]]; the sensor reports it per swing and as an average.
**This is the literal source of the deck's `AACon% (4–16)` metric** — the share of a hitter's
contact swings whose attack angle falls in the ideal 4–16° band.

**How measured/derived.** From the reconstructed barrel trajectory: the slope of the barrel's
vertical motion at contact. **Critical:** AA is **dynamic** — negative on the downswing, it
**zeros out at the low point of the arc, then climbs progressively positive out front**. So the
reported value depends on *where in the arc contact happens* (see the contact-point trap).

**Units.** Degrees.

**The ideal 4–16° band — and WHY.** We want **average attack angle between 4° and 16°.** The
reasoning:
- **MLB average AA ≈ 7°**, which is *no coincidence* ≈ the incoming **pitch descent angle**.
  Matching the pitch plane ("on plane") delivers three things ([[hitting-biomechanics]]): a
  **large margin of error** (square it even if slightly early/late), an **efficient
  bat-ball collision** (matched planes → max bat-speed→EV transfer, the highest Smash Factor),
  and an **optimal batted-ball distribution** (hardest-hit balls at advantageous launch angles).
- **Below ~4° (toward 0°/negative):** the hardest-hit balls go on the **ground** — a massive
  waste of bat speed. **Negative AA is essentially never seen at MLB.** Backspin requires
  **LA > AA at contact**, so a too-flat path caps the air-ball ceiling.
- **Above ~16°:** the path gets **off-plane** with most pitch types → worse bat-to-ball
  ("clipping" / mishits, lower Smash Factor, more spin), and balls tend toward topspin/pull at
  high LA. High-AA hitters can slug above their bat speed but pay in contact.

**When a hitter should live at either extreme.**
- **Toward the high end (12–16°):** a **leverage / damage** hitter with the bat-to-ball to
  afford it — high bat speed, hunts a drivable pitch out front, wants to do damage in the air
  pull-side. Many **power hitters carry a higher VBA** and a more vertical, higher-AA path and
  out-slug their bat speed. Accept reduced margin for error.
- **Toward the low end (4–6°, flatter):** a **high bat-to-ball** hitter who lives on **line
  drives line-to-line** and consistency, and the **two-strike** swing for *any* hitter
  (flatter path stays on plane with more pitch types longer; "put a strike in play"). Teach a
  **lower AA with two strikes** universally.

**The AA ↔ point-of-contact relationship (and the measurement trap).** Because AA is dynamic,
**where you make contact changes the measured AA on the same swing** — deeper contact reads
*lower* (still in the downswing/near the low point), out-front contact reads *higher* (barrel
climbing). The canonical case study ([[hitting-biomechanics]]): early-program hitters "jumped"
from ~0° to 7–15° AA in 1–2 weeks **without changing their path** — they were simply **late**
off the machine (deep contact), and as **timing improved, contact moved out front** → higher
*measured* AA. **Lesson: control for contact point when reading AA**, or improved *timing*
masquerades as a path change. (Contrast bat speed, which is *not* this contact-point-sensitive
in the same way — a real speed change is a real speed change; this is why the quiz pairs the two.
**The AA↔PoC relationship is NOT the same as for bat speed.**)

**Correlation to outcomes.** AA near the pitch plane maximizes **Smash Factor** (EV transfer)
and puts the **hardest-hit balls at productive launch angles** (hard line drives + deep-backspin
fly balls = most HR flight, per the "AA ≈ pitch plane + slightly undercut" method). Too low →
hard grounders (wasted bat speed); too high → off-plane mishits + spin. This is exactly why the
**bat-path swing flaws** are *defined* by sensor AA paired with outcomes: **High AA flaw = avg
AA > 12° + poor bat-to-ball** (K%, in-zone contact, Smash Factor); **Low AA flaw = avg AA < 6° +
GB-heavy** (GB%, barrel%, xwOBACON) — see [[swing-flaws-programming]].

**How to train it.**
- **Lower a too-high AA:** "flatter bat path" / "swing across your shoulders" / "top-down"
  (hunt the top of the zone, hit a low line drive); "hit the top of the ball." Implement: **Smash
  bat + Hitting PlyoCare / Smash Factor balls** for plane-matching feedback (mishit reads:
  *hook/topspin* → flatten or back up contact).
- **Raise a too-low AA:** "vertical / ferris-wheel bat path," "expect a pitch at the bottom,"
  "hit it out in front in the air," "pull it in the air with backspin." Implement: the
  **offset-closed plyo drill**; verify it's a *path* change, not just later/deeper contact.
- **Train the distribution, not one number:** `AACon% (4–16)` is the share *in band* — move the
  whole distribution into the band, don't chase a single hero-swing AA.

**Common misreads / pitfalls.**
- **The contact-point trap (the big one):** never grade a path change on AA alone without
  controlling contact point — late→on-time timing fakes a path change. On training bats this
  shows up as "cheating the overload" by contacting too far out front (the Long-bat tee-location
  enforcement exists for this reason).
- **Treating 4–16° as a target for everyone always.** It's the *pre-2K leverage* band; the same
  hitter should flatten with two strikes. And the band is a *reference*, not a mandate — VBA,
  posture, and profile move the individual optimum.
- **Average can hide a bimodal distribution** — a hitter averaging 10° might be splitting between
  chops and lifts; read the spread.

---

## Vertical Bat Angle (VBA)

**Definition.** The angle of the **bat itself** (the barrel-to-handle line) **relative to the
ground at impact** — **"flat" ≈ 0°** vs **"steep/vertical" toward −90°.** Distinct from attack
angle: AA is where the barrel is *traveling*; VBA is how the bat is *tilted*. (In
[[hitting-biomechanics]] terms this is the bat-position VBA, sibling to HBA.)

**How measured/derived.** From the bat's reconstructed orientation (gyro-derived) at the impact
instant — the inclination of the bat shaft to horizontal.

**Units.** Degrees (toward −90° = more vertical/steep; near 0° = flatter).

**The pitch-height relationship.** VBA is **driven by pitch location**: **up in the zone →
flatter (near 0°)**, **down in the zone → more vertical (toward −90°)**. A hitter must *vary*
VBA with side bend and posture to cover the zone — failure to adjust VBA mirrors a failure to
adjust to **pitch height** ([[hitting-biomechanics]] torso side-bend story). So read **avg VBA
in the context of where the pitches were** — a steep avg VBA on a diet of low pitches is normal;
a steep avg VBA on pitches up is a posture/adjustability flag.

**What good looks like.** There is **no single ideal VBA** — it's posture-driven and individual
(less side/forward bend → flatter; more → steeper), analogous to pitchers' release-point variance.
What matters is an **appropriate, adjustable** VBA for the hitter's posture and the pitch.

**Correlation to outcomes (power implications).** **Many power hitters carry a high (steep) VBA**
and slug *above* what their bat speed predicts — a steeper bat tends to a more vertical, dynamic,
higher-AA path that puts a high share of hard contact at high LA (gap-to-gap/middle damage).
**Flat-VBA hitters** hold AA longer → flush contact across a **wider range of contact points** →
hard line drives **line-to-line**, generally higher bat-to-ball but a higher bat-speed bar to
clear for HR flight (a flat swing meeting a 35° HR ball is a big plane gap → low Smash Factor).
Steep paths struggle on the lines (hook-to-pull / slice-to-oppo) and need more perfect out-front
timing.

**How to train it.** VBA is a **posture output**, so train posture, not the angle directly:
- **Short bat (~28")** patterns **postural adjustments** to pitch height (knee flexion, hip
  flexion, forward + side bend) — the direct lever on VBA-by-location. "Maintain posture" =
  at least as much **side bend at contact** as **forward bend at launch.**
- Cues: **top-down** (look top-of-zone, add side bend to reach lower pitches) to keep VBA
  flatter on high pitches and let it steepen appropriately down.
- Don't prescribe a VBA number; prescribe the **adjustability** and let the functional VBA emerge.

**Common misreads / pitfalls.**
- **Reading avg VBA without pitch-height context** — the single biggest VBA error. Steep on low
  pitches is correct; flat on high pitches is correct.
- **Conflating VBA with AA.** A steep bat (VBA) is not automatically a high attack angle, and vice
  versa — they're different quantities; report both.
- **Chasing a "power" steep VBA** at the cost of zone coverage — steepening to slug can wreck
  line-to-line contact and high-pitch coverage.

---

## Early Connection & Connection at Impact

**Definition.** **Connection** = the relationship between the **bat's tilt and the body/torso
plane**, expressed at two checkpoints:
- **Early Connection** — the bat-to-body relationship at **the start of the downswing** (load /
  launch).
- **Connection at Impact** — that relationship **at contact**.

These are the sensor's read on the biomech "**connection**" checkpoint ([[hitting-biomechanics]]):
torso, lead arm, and hands traveling at the same rotational speed early, then releasing as the
torso decelerates — i.e. **on-plane, connected** vs **disconnected** (push or drag).

**How measured/derived.** From the bat's orientation relative to the reconstructed body/swing
plane at each instant (the "P-positions" the sensor scores). Reported as **scores/angles** at
the two checkpoints.

**Units.** Degrees / a connection score per checkpoint (read vs band and vs the hitter's baseline).

**What good looks like.** A **connected, on-plane** relationship — the barrel in the same plane as
the lead arm and swing plane ([[hitting-biomechanics]] "aligned"), maintained early and re-achieved
near impact. The two together describe whether the hitter **holds the bat in plane through the
turn** or lets it drift early.

**Correlation to outcomes.** Connection is the **efficiency/sequence** read in bat-position terms:
- **Poor early connection** (bat too vertical / out of plane at launch) → the **push pattern**
  (hands/arms outpace torso) or **bat drag** (barrel dumped below plane) — lost bat speed, lost
  efficiency ratio, narrower margin for error.
- **Connection that collapses by impact** → the barrel left the plane mid-swing — off-plane
  contact, lower Smash Factor.
On-plane connection underpins the **margin of error** + **collision efficiency** benefits of being
on plane.

**How to train it.** Connection problems are **upper-body sequence** problems — the **Bazooka bat**
(holds the upper segments isometric, attacks push pattern + bat drag) and the **Long bat**
(separation/sequence) are the primary tools; **Smash bat + plyo/Smash Factor balls** train the
flush, on-plane feel. Cues: "swing across your shoulders / across your face," "turn behind the ball,"
"flatter bat path / top-down," and **overload** ("pretend the bat weighs 100 lbs, use your whole
body"). See [[swing-flaws-programming]] (Push Pattern, Torso Overcoil).

**Common misreads / pitfalls.**
- **Reading connection scores without the body context** — connection is *relative to the body
  plane*; the sensor infers it, so corroborate with side-view / CF video when it disagrees with the
  eye.
- **"Early connection" is not load style.** Pre-swing bat waggle, barrel tips, and wrist flicks are
  **mostly style** ([[hitting-biomechanics]] arms) — judge connection at launch/impact, not the
  pre-load fidget.

---

## On-Plane Efficiency & the Biomech Bat-Path Story

The sensor's path metrics — **attack angle, VBA, connection (early + impact), horizontal
direction** — are the *measurable shadow* of the biomech **bat-path** narrative. "On-plane" means
the **vertical AA matches the pitch descent** and the **horizontal direction matches the horizontal
pitch plane** ("through the baseball," not "out-to-in / down and across"). On-plane buys the three
benefits restated throughout this note: **margin of error**, **collision efficiency (Smash Factor)**,
and an **optimal batted-ball distribution**.

The sensor is how we **operationalize** that story in the field without the mocap lab:
- **Connection (early/impact)** ↔ the biomech *connected → release* relationship and the "aligned"
  bat-in-plane checkpoint.
- **VBA** ↔ posture (forward + side bend) and the *plane-matching across pitch heights*.
- **AA + horizontal direction** ↔ the *plane match* itself and the *leverage vs two-strike* swing.
- **Bat speed / hand speed / efficiency / rotational accel / time to contact** ↔ the *kinetic-chain
  whip* (segment sequencing pelvis → torso → arms → hands → bat) that the lab measures segment by
  segment.

When sensor and biomech disagree, remember the lab measures the **whole body across all phases**
while the sensor measures the **barrel at/around impact** — both true, different vantage points.

---

## How We Train Each — Mini-Matrix

| Metric | Primary train tool | Key cue(s) | Underlying driver |
|---|---|---|---|
| **Bat Speed** | Speed Trainers (±20%), strength | "Swing faster" (high intent); 90–95% in practice | Strength + intent + sequence |
| **Peak Hand Speed** | Speed Trainers; check vs efficiency | (don't isolate — read with efficiency) | Strength + intent |
| **Efficiency (BS÷HS)** | Bazooka, Long bat | "Across your shoulders," "turn behind the ball" | Connection / sequence |
| **Time to Contact** | Long bat, Bazooka; "time-to-impact" feedback | (byproduct of efficiency, not "be quick") | Sequence (remove wasted path) |
| **Rotational Accel** | Speed Trainers, Long bat, jump/hop strength | High-intent explosive launch | Lower-half power + sequence |
| **Attack Angle** | Smash bat + Plyo/Smash Factor balls; offset-closed plyo | High→"flatter/top-down"; Low→"ferris wheel/in front" | Path + posture (control PoC!) |
| **VBA** | Short bat | "Top-down," "maintain posture" (side bend ≥ forward bend) | Posture / adjustability |
| **Connection (early+impact)** | Bazooka, Long bat, Smash bat | "Across your face," "turn behind the ball," overload | Upper-body sequence / on-plane |

All implement work obeys the **20% over/under rule** for anything claiming bat-speed transfer, and
all path/connection work leans on **plyo/Smash Factor ball flush-vs-glancing feedback**. Detailed
implement → flaw mapping: [[training-implements]] and [[swing-flaws-programming]]. Train with
**external cues** and **blocked → random** progression per [[meta/skill-dev-principles]] and
[[drills-programming]].

---

## Common Blast Profiles and What to Do

Read profiles, not single numbers. A few recurring patterns and their prescriptions:

- **High early connection + low rotational accel + high avg VBA** *(the quiz profile).*
  Reading: the hitter is **connected/on-plane early and steep** (good plane setup, power-leaning
  VBA), but **isn't accelerating the barrel hard out of the launch** — a **power/sequence**
  shortfall, not a path/connection one. **Prescription:** train **rotational explosiveness** —
  Speed Trainers (high intent, ±20%) and the **Long bat** to pattern pelvis-leading sequence into
  a firm lead-leg block; lower-half **explosive/reactive strength** (CMJ, Squat Jump, Repeated
  Hop). **Protect** the already-good connection (don't add a push-pattern cue) and the VBA (it's
  a power asset — just confirm he can flatten it for high pitches via Short-bat posture work). Net:
  *add early barrel acceleration and bat speed without disturbing his on-plane, leverage-friendly
  bat position.*

- **High hand speed + low efficiency ratio + bat still vertical past launch.** Classic **push
  pattern** — hands muscling the bat. **Bazooka + Long bat**, connection cues, "flatter/top-down."

- **Avg AA > 12° + poor bat-to-ball (high K%/low in-zone contact).** The **High AA flaw**. Flatten:
  Smash bat + plyo, "top-down," teach the two-strike flatter swing. *First* rule out the
  contact-point/timing artifact.

- **Avg AA < 6° + GB-heavy (high GB%, low xwOBACON).** The **Low AA flaw**. Steepen: offset-closed
  plyo, "ferris wheel," "in front in the air." *First* confirm it's path, not late/deep contact.

- **High bat speed + low bat-to-ball (high AA, lots of whiff).** Approach prescription
  ([[big-3-hitting]]): be **more aggressive / swing more** (production via high wOBAcon) — many of
  the game's most productive hitters profile 60+ bat speed / sub-50 bat-to-ball / 50+ swing
  decisions.

- **Good AA + good bat speed but slow time to contact / late.** Likely **timing**, not path —
  high-velo machine reps to recalibrate the internal clock; verify the path metrics are actually
  fine before touching mechanics.

---

## Astros Stack Tie-In

The bat-sensor metrics are the field/in-gym layer; the BSB analytics stack carries their **in-game
analogs and the data hygiene** that makes them trustworthy:

- **`AACon% (4–16)`** (the deck metric) is *literally* this note's Attack Angle in the **4–16°
  ideal band**, scored as the share of contact swings in band — read it as the in-band *rate*,
  and always against **point-of-contact** context (the dynamic-AA trap is the #1 misread).
- **Attack-angle / point-of-contact tracking** in the hitter tracker mirrors the AA↔PoC story:
  AA must be read *controlling for contact point*, exactly the biomech case study.
- **Bat-speed cleaning** — `rules/bat-speed-canonical` (3-step per-player: top-90% / 57 mph floor /
  2.5σ) is the production discipline behind "read the distribution, 90th-percentile + average, not
  one hero swing." The in-gym report's **90th-pctile bat speed + efficiency (BS÷HS)** lines are the
  same two reads.
- **gcOBA / SwDec / Damage%** percentile pools ([[big-3-hitting]], [[xwoba]], [[swdec]]) are the
  *outcome* side that bat-path metrics must be **paired** with — AA alone is never the diagnosis;
  AA + K%/in-zone contact (high) or AA + GB%/xwOBACON (low) is.
- **Statcast bat tracking** (2023+) and the [[swing-path-bat-tracking]] arc reconstruction give a
  swing-plane coaching overlay that is the *in-game* cousin of the knob sensor's path output.
- **`never-round-until-display`** applies: carry sensor metrics at full precision; round once at the
  display layer (the `AACon% (4–16)` rate especially).

---

## How Used

The bat sensor is the **portable, every-swing** bridge between the mocap lab
([[hitting-biomechanics]]) and the development plan ([[big-3-hitting]] → [[swing-flaws-programming]]
→ [[training-implements]]). Its metrics define the two **bat-path flaws**, drive **bat-speed
training** (the one intent you can't train blind), and feed the org's **attack-angle / PoC /
bat-speed-canonical** work and the **`AACon% (4–16)`** snapshot metric. It is also the comprehension
gate's hardest module — see the Blast/bat-sensor quiz in [[hitting-quiz-bank]] (define each metric;
why 1 mph of bat speed matters; *why 4–16° and when to live at an extreme*; AA↔PoC vs bat speed; and
the high-early-connection / low-rotational-accel / high-VBA training prescription).

## Links
- [[MOC-baseball-analytics]]
- [[hitting-biomechanics]] (bat path, AA/VBA/HBA, connection, kinetic chain) · [[big-3-hitting]]
  (bat speed, Smash Factor, EV link) · [[swing-path-bat-tracking]] (Statcast bat tracking / arc)
- [[training-implements]] (which implement trains which metric) · [[swing-flaws-programming]]
  (the two AA flaws are sensor-defined) · [[drills-programming]]
- [[meta/skill-dev-principles]] (external cues, blocked→random, constraints, specificity)
- [[hitting-quiz-bank]] (Blast quiz section) · [[pd-onboarding-curriculum]] (module home)
- [[xwoba]] · [[swdec]] · [[barrel-pct]] (outcome pairings)
- Astros tie-in: `rules/bat-speed-canonical` (90th-pctile + 3-step cleaning), hitter-tracker
  attack-angle / point-of-contact tracking, the deck's `AACon% (4–16)` metric, `never-round-until-display`.

## From sources
- [[2026-09-04-how-a-struggling-juco-player-worked-with-driveline-to-reach]] - How a struggling JUCO player worked with Driveline to reach his dream
- [[2026-03-28-his-bat-path-is-costing-him]] - His bat path is costing him
