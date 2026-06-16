---
type: concept
domain: hitting
source: Driveline HTKCH — The Big 3 PDF
created: '2026-06-15'
updated: '2026-06-15'
---
# The Big 3 (Hitting)

Driveline's assessment-to-development engine. When a hitter shows up, two questions
drive everything: **(1) how does he compare to MLB hitters? (2) how does he develop
to get there?** Driveline pairs publicly available in-game MLB data with large
in-gym MLB training samples to answer "what *is* an MLB hitter?" — and the answer
collapsed into the **Big 3**. The model is deliberately brutally honest: becoming an
MLB hitter = becoming a statistical **outlier** (best in the world), and a
data-driven assessment lets the coach tell a player *exactly why* he isn't there yet
plus a roadmap. Players consistently leave these meetings *more* motivated, not less.

> Hitting is complex, but the best hitters do three things better than the rest:
> **hit it hard · square it up often · swing at good pitches** → **Bat Speed ·
> Bat-to-Ball · Swing Decisions**. Each is measured as independently as possible;
> together they snapshot a hitter and pave the development plan.

---

## 1. Bat Speed

**What/why:** barrel velocity at impact. Moving the bat fast is non-negotiable at a
high level — swinging faster → harder contact (higher EV) holding contact quality
constant. **~1 mph bat speed ≈ +1.2 mph EV** on a given batted ball, all else equal.
Average recorded bat speed rises monotonically toward the majors (upper-MiLB > lower-MiLB,
D1 > non-D1, MLB highest of all). The pitching analog (velo = objectively better
stuff) became common knowledge in the 2010s via radar guns; the hitting world is now
catching up as EV is broadcast and amateurs hit on launch monitors.

**Measurement:** bat sensors (Blast Motion, Diamond Kinetics) read mph at contact;
markerless mocap (Hawkeye, Kinatrax) or markered systems (Driveline's Optitrack lab)
measure directly. It can also be *reverse-engineered from batted balls*: bats have a
regulated batted-ball coefficient of restitution (ratio of bat speed → EV at a given
moment-of-inertia), so a hitter's hardest-hit balls (flush barrels) imply bat speed.
Driveline's in-game KPI for un-sensored swings is **Top-8th EV** = average EV of the
hardest **12.5%** (top 1/8th) of BIP, converted to estimated in-game bat speed via a
proprietary model trained on **200,000+ paired Blast/HitTrax swings** (continually refined).

**Benchmarks (2022, "what good looks like"):**
| Metric | MLB mark | Note |
|---|---|---|
| In-game bat speed | **~72.6 mph** (model est.) | "in-game" underlined — BP bat speed runs higher; taking BP speed into a game is a *skill* not an assumption |
| Max EV (batting-title qualified) | **~110–112 mph** | "Have you hit a ball 111 w/ wood?" — if no, likely below-avg bat speed |
| Top-8th EV (qualified) | **~105.5 mph** | compare your own top-8th avg to 105.5 |

**The "average not max" insight:** MLB hitters have a *higher proportion of swings
near their peak* bat speed — they get a better swing off **more often**, across
locations and pitch shapes. Lesser hitters may own MLB top-end bat speed but rarely
reach it consistently. Caveats on EV data: pitch difficulty, environment, and **ball
quality** (heavily-used balls go soft → lower EV) all matter. DIY: a standard radar
gun has cosine error; BP max distance is a rough proxy.

**Just how important?** Critical, but not everything — a big leaguer and little
leaguer who whiff at everything both have 0 mph EV. Bat speed without contact is
worthless. → Big 3 #2.

---

## 2. Bat-to-Ball Skills

**What/why:** the ability to make **consistent quality contact** ("the hit tool").
As pitching improves (harder, nastier), this matters *more*. Inputs: vision, pitch
recognition, timing, adjustability, bat path, coordination. Simple framing: when you
swing, do you square it up / hit the sweet spot?

**KPI = Smash Factor** (borrowed from golf). Golf: `EV / club speed` (1.5 = perfect
driver collision). Baseball must factor incoming pitch speed:

> **Smash Factor = 1 + (Exit Velocity − Bat Speed) / (Pitch Speed + Bat Speed)**

It answers "how close was this collision to perfectly efficient?" — and crucially
**controls for bat speed** (you know the *highest possible* EV given bat speed +
pitch speed; actual EV ÷ that = smash factor). It registers **0 for a whiff** and
weights fouls by their contact quality.

**What good looks like:** most BIP fall **0.9–1.2 Smash Factor**, higher = better.

**Why it beats the alternatives** (each flawed):
- **Line Drive% (10–25°):** only counts BIP (ignores whiffs/fouls); rewards mishit
  20° clips off the end / jam shots; punishes barrels outside the LD band.
- **Avg EV / Hard-Hit% (≥95):** ignore whiffs; confound bat speed (90 EV = perfect
  for a 13yo, a mishit for a good college hitter) — exactly what the Big 3 wants to *isolate*.
- **Whiff% (misses ÷ swings):** all whiffs weighted equal (middle-middle FB ≠ BB in
  the dirt). **zMiss%** (in-zone only) improves it, but in-zone pitches aren't equal
  either (97 top-of-zone FB whiffs far more than a CH down the middle). It also values
  all BIP equally (barrel = slow roller).
- **Smash Factor+** (Driveline's robust model) layers in pitch **location** + pitch
  quality (**Stuff+**) to grade contact **above expectation** — the cleanest read.

DIY: LD%, Whiff%, zWhiff%, avg EV are usable proxies if you lack an analytics team —
just respect the flaws above.

---

## 3. Swing Decisions ("approach")

**What/why:** the skill of swinging AND not-swinging at the right pitches. Bat speed
and bat-to-ball set the **floor and ceiling** of production; swing decisions
determine where on that spectrum a hitter lands. Poor decisions also *break* the
other two (force/decelerate the bat, lower intent).

**Measurement.** Traditional proxies + their flaws:
- **Chase%:** good signal but lacks count state (2-0 chase ≠ 0-2 chase), distance
  off the plate (1 inch vs "waste" zone), and ignores **bad takes** (taking
  middle-middle).
- **K/BB & OBP:** confounded — better hitters get pitched around (more balls → more
  walks, easier OBP) and get on base more on contact; high bat-to-ball hitters post
  good K/BB simply by rarely K'ing while *actually* deploying poor decisions (e.g.
  putting a 1-0 slider out of the zone in play for a weak grounder = "low run value" BIP).

**Driveline's model.** A complex **ML run-value model** predicts the run value of
each swing/take decision from game context, pitch nastiness, and batter tendencies.
A simpler bucketed version (pitch labeled by **count, zone, type** using MLBAM
Gameday + Attack Zones) computes the swing decision as:
1. expected run value for swing vs take in that bucket;
2. subtract take-RV from swing-RV → net runs of swinging;
3. label pitch swung (1) / taken (0), subtract the expected swing **probability**;
4. multiply (2)×(3) → net swing-decision value, **weighted by swing probability**.

Effect: a swing at MM FB in a 2-0 → big positive; a chase of an 0-2 down-away slider
→ negative. The swing-probability weighting **punishes rare mistakes harder** and
**rewards challenging-yet-correct** decisions (because few MLB hitters make them).

**What good looks like — Pre-2K (non-two-strike):**
- Hunt pitches you can do **damage** on (hard + in the air), generally **heart /
  sub-heart**. ~25% of 2022 MLB pitches were heart/sub-heart.
- Bigger problem than passing drivables is **swinging at low-run-value locations**
  (incl. *strikes*: a well-located down-away slider strike in 0-0 is a *bad* swing).
- *"Better 0-1 than 0-for-1."* Taking a strike has a small penalty; a weak grounder
  has a huge out-probability. You can **take a strike and still "win" the pitch.**
- "Controlling your at-bat" → two benefits: (1) **more damage** on heart/sub-heart
  (smaller swing-zone keeps "A swing" intact — Soto: "if you swing at balls you're
  not taking your A swing"; Bregman: "I only swing at something I can homer on"); (2)
  **better counts + more walks** (lower chase). "I can get a bad hitter out in one
  pitch; it takes three for a great one" — bad hitters throw away ABs on soft contact.

**What good looks like — 2K:** dynamic changes (whiff/take = out). Two jobs: **cover
the zone** (expand to the *edges*, no further) and **minimize chase increase**. 2022
MLB chase: **~23% pre-2K → ~40%+ with two strikes** (nearly double). Much of the
spike is mindset/fear-of-K, not just better pitches. Fix: teach the zone, stay in it;
accept occasional K-looking. (Highly debated; player/situation dependent.)

DIY: track chase + heart/sub-heart takes; post-AB notebook ("Did you win this
pitch?"); train with **2K and pre-2K rounds** + balls-and-strikes dispersion so the
hitter actually practices decisions instead of auto-swing mode.

---

## Putting it together — interdependence

Measured independently, but coupled at a base level: low bat speed → must start
sooner → worse bat-to-ball + decisions vs velo/breaking; poor decisions → "break
posture" / decelerate to force contact on shadow/chase pitches → slower bat speed;
"be ready to hit everything" lowers intent + bat speed on all swings. Still, relative
independence makes the model a powerful diagnostic.

## The Big 3 Profile (20–80 scouting scale)

Each skill graded on the **20–80 scale** (50 = MLB average; each 10 pts = 1 SD in a
normal distribution). Standardizing across metrics lets you compare any hitter to MLB
or to his population (age/level).

| Grade | Percentile meaning |
|---|---|
| 20 | 99.9% of MLB hitters better |
| 30 | 97.7% better (batter > 2.3%) |
| 40 | 84% better (batter > 16%) |
| 50 | **MLB average** (better than 50%) |
| 60 | better than 84% (+1 SD) |
| 70 | better than ~97% |
| 80 | better than 99.9% (+3 SD) |

A profile reads **BatSpeed/Bat-to-Ball/SwingDec**, e.g. **55/45/60**. Used to guide
deeper investigation, allocate training economy, and set game strategy.

## Root-cause decision trees (when a grade is low)

**Low Bat Speed:**
1. **Weak.** Swinging fast needs strength/power. Lab: MLB hitters put **~2× body
   weight** (some near **3×**) of force into the **lead leg** during the swing (~400 lb
   for a 200-lb hitter, one leg, while extending knee/hips + rapidly rotating pelvis/torso).
   "Too weak to deadlift 300" → won't match MLB lead-leg force. Strength gains
   **correlate strongly** to bat-speed gains at Driveline.
2. **Poor mechanics / rotational coordination.** Strong in the gym but slow bat = inefficient
   sequencing. Lab measures pelvis/torso/arms/hands/bat segment speeds to localize the
   shortfall (NFL players/bodybuilders who can't drive a BP ball out of the infield).
3. **Low intent.** Deliberately slow swings their whole career (precision culture, wild
   youth pitchers, big youth zones, fear of K). Removing the artificial limiter often
   "pops" bat speed fast. "Have you tried swinging faster?" → "Can't control it in a
   game" → "Do you *practice* it?" → "No." **Hitters perform best at 90–95% of max bat
   speed**; raise training thresholds so the game swing rises with it.

**Low Bat-to-Ball:**
1. **Poor bat path.** 90 mph reaches the glove in <0.4 s; the swing takes ~0.140 s
   (a blink ~0.33 s). The best widen their **margin of error** by swinging **on
   plane** with the pitch — square it up even if timing is imperfect. A 20° or −10°
   attack angle demands perfect timing. Off-plane also hurts contact *quality*
   ("clip"/mishit) — highest-smash-factor BIP = attack angle matches pitch descent angle.
2. **Vision / pitch-recognition.** Dynamic visual acuity; can be trained, but transfer
   of visual-acuity scores → batting is academically debated.
3. **Timing.** Rhythmic skill; most common issue is **consistently late**. Should be
   subconscious — internal clock syncs to the pitcher, recalibrates pitch-by-pitch.
   Most training is slow velo → train more high-velo reps for game timing.
   *Diagnostic split:* are the eyes/brain telling them the wrong place, or is recognition
   fine but the barrel doesn't get to the spot? (vision vs mechanical/timing).

**Low Swing Decisions** — two profiles:
1. **Over-aggressive.** Throw away ABs pre-2K; don't grasp swing-decision value /
   fear 2K. Many pro/college hitters "got away with it" on youth talent advantage;
   doesn't scale up (a FB 3" above the zone is much harder at 93 than 80).
2. **Too passive** (rarer). Take too many drivables early, over-optimize for walks,
   lack confidence. Especially **taking drivable offspeed early** — with rising early
   breaking-ball usage, hitters must pull the trigger on hangers in all counts.
   *Also consider* **gaze strategy** (deliberate, not innate like acuity — shift to
   release point, track early ball flight, saccade to predicted contact) and
   **head movement** (some horizontal head movement early likely needed; coil amount,
   downward head/eye move, head tilt all interact — "more questions than answers").

## Which is most important / easiest to train?

**Importance (for predicting overall production):** **Bat Speed > Bat-to-Ball >
Swing Decisions** (hence the Big-3 order). Margins are small but real.

**Trainability matrix:**
| Big 3 skill | How reliably can we improve? | How much can a hitter improve? | How fast? |
|---|---|---|---|
| **Bat Speed** | **Highest** | Lowest | Middle |
| **Bat-to-Ball** | Lowest | Middle | Lowest |
| **Swing Decisions** | Middle | **Highest** | **Highest** |

- **Bat speed:** most reliable (natural gains until ~27–28, well-researched);
  incremental, takes deliberate work; big early jumps only for previously low-intent hitters.
- **Bat-to-ball:** the "Holy Grail" — *believed* innate/undevelopable because
  high-whiff lower-MiLB hitters rarely become MLB hitters (poor bat-to-ball scales up
  badly). NOT impossible — Driveline sees real gains (mostly bat-path/attack-angle +
  timing), but with *less certainty* than bat speed and a wider, more varied range.
- **Swing decisions:** "low-hanging fruit" — rarely deliberately trained, so it's the
  most **malleable** (a half-grade 50→55 in a window is notable) and **fastest** to move
  (approach/strategy shift, not physical adaptation).

**Program-design considerations:** time horizon (youth/amateur underclassmen/recently
drafted = long-term; MLB needing a season / MiLB near FA-or-release / amateur senior
year = short-term); season timing (offseason → heavy bat-speed; ramp bat-to-ball +
swing decisions toward opening day; in-season bat-speed is high-intensity/high-rep,
manage workload); and the most realistic path given the profile (a 60/40/40 ≠ a
40/60/60 program).

---

## In-gym assessment process (5-day template)

- **Day 1 — Intake / "snapshot":** 40–50 swings off a standardized machine; HitTrax or
  Rapsodo batted-ball data; **Blast** bat sensor; **K-Vest** biomech; **Edgertronic**
  at 600 fps.
- **Day 2 — PT + Strength + group hitting:** PT screen; strength assessment (re-run
  every 6 wks); group hits (2–4) for more batted-ball + sensor data.
- **Day 3 — Mocap + bat-speed training + group:** Optitrack lab kinematics/kinetics;
  **Axe Bat Speed Trainers** bat-speed workout.
- **Day 4 — Bat-to-ball + group:** Hitting **PlyoCare** + **Smash Factor** balls,
  batted-ball physics lesson, bat-to-ball techniques.
- **Day 5 — Athlete meeting + swing design:** walk through batted-ball, Blast, K-Vest,
  mocap reports; build an individualized, objective, data-driven plan; 1-on-1 swing-design
  drill session.
(Condensed for pros with rich in-game data.)

**Report contents (TRAQ):** *Batted-ball* — avg EV, top-8th EV, avg LA, avg LA of
hard-hit, contact-in-zone, LA-range distribution, spray (-45 LF pole → +45 RF pole).
*Bat sensor* — avg bat speed, avg attack angle, **90th-pctile bat speed**, **efficiency
(bat speed ÷ hand speed)**, est. top-8th EV + LA at top-8th.

**Strength assessment (every 6 wks), 4 tests** — maps to a "physical Big 3":
1. **Isometric Mid-Thigh Pull** — lower-body **maximal** strength (total force).
2. **Countermovement Jump** — lower-body **explosive** strength (w/ countermovement).
3. **Squat Jump** — explosive strength from a static start.
4. **Repeated Hop Test** — **reactive** ability (eccentric→concentric speed).

**PT assessment** — global movement screen + per-segment; key swing positions: seated
thoracic combined motions (posterior rotation 45°+ with lateral flexion 20–30°;
lateral flexion + anterior rotation 45°+; thoracic flexion — some flexion is needed to
rotate); **hip IR/ER** (supine 90° flex + prone 0° flex; target **IR 30–40°, ER
50–60°**); **tibial IR/ER** (~5–10° each direction, symmetric).

---

## Game-Planning & "Approach" types

Define the approach *before* the AB so you can review it after ("without a clear
approach we can't define success"). Three archetypes:
- **Zone hitter:** hunts a swing-zone (middle-in/up/down); before 2K the rulebook zone
  is irrelevant — only "is it in my zone, can I drive it?" Simple, aggressive within
  the zone. Wants **heatmaps**.
- **Target hitter:** more external — commits to a ball flight / field target ("drive it
  right-center"). Intention organizes mechanics + decisions (committing to pull-air-backspin
  → you'll take the outer-third/shadow pitch). Wants a **combination**.
- **Guess hitter:** sits on pitch types — exact pitch or **hard vs soft** (esp. vs a
  reliever's 2 nasty pitches). **Easier to adjust hard→soft than soft→hard**, so most
  hitters look fastball (controlled stride lets them adjust to a hittable offspeed);
  sitting soft is "all in." Wants **usage-rate charts**.

Every approach is a "give-and-take / long game" — be okay with how you're willing to lose.

**Building the game plan** — three opponent inputs:
- **Arsenal:** types, velos, movement profiles. Conceptualize shapes vs *average*
  ("dead-zone" FB underperforms at its velo; unique shapes outperform). Vertical:
  ride/carry & sink (FB), depth (offspeed). Horizontal: run & cut (FB), sweep & fade
  (offspeed). MLB example report: *93–95 dead-zone heater · 83–86 SL avg depth /
  above-avg sweep · 82–84 CH above-avg run.* Analytical hitters may want raw IVB/HB inches.
- **Usage rates:** how often each pitch, in which situations (vs RHH/LHH, counts, RISP).
  Pitchers throw more early breaking balls w/ RISP (guess hitter sits soft); 80% FB in
  0-1 → prep for it.
- **Locations:** heatmaps (red = dense). Carry FBs up, sinkers down, ability to pitch
  inside is rare.

**Distill, don't dump.** Hitters aren't computers — match the visual to the hitter
type, avoid information overload. The flip side (opposing-pitcher view) of an advance
report answers three heatmap questions: **where does he swing / do damage / whiff?**
Optimized approach = swing where you do damage, take where you whiff. Low-hanging
fruit: many hitters are *wrong* about where they actually do damage (say "middle away,"
data says "middle-in").

**Big 3 profile → approach prototypes:**
- **High bat-to-ball:** often over-aggressive/chase too much (lean on contact). Should
  do the *opposite* — earn selectivity, shrink the zone (3–4 baseballs) or a specific
  target (pull-gap air), raise pre-2K contact quality.
- **Low bat-to-ball:** likely benefits from **guessing** (can't make late adjustments;
  maximize when right).
- **High bat speed / low bat-to-ball:** production via high-wOBAcon; be **more
  aggressive / swing more** (high whiff + low swing rate = trouble — "if you whiff a
  lot, why only give yourself one pass?"). Note: many of the game's most productive
  hitters profile **60+ bat speed / sub-50 bat-to-ball / 50+ swing decisions.**

Keep game-time external (task/movement-problem focused); leave swing tinkering for the
cage. "A perfect plan with an imperfect swing beats a perfect swing with no plan."

## How used (Astros analyst lens)

This is the assessment → development roadmap engine the whole HTKCH system hangs off.
Org analogs in the BSB stack: **gcOBA / SwDec / Damage%** percentile pools, the
bat-speed-canonical cleaning, and attack-angle/PoC tracking — see links.

## Links
- [[MOC-baseball-analytics]] · [[driveline]]
- [[hitting-biomechanics]] · [[swing-flaws-programming]] · [[training-implements]]
- [[anatomy-physiology-kinesiology]] · [[meta/skill-dev-principles]] · [[meta/org-training-process]]
- [[swing-path-bat-tracking]] · [[swdec]] · [[xwoba]] · [[barrel-pct]] · [[wrc-plus]]
- Pitching analogs: [[stuff-plus-4s-pitching]] · [[stuff-grade]] (Stuff+ feeds Smash Factor+)
