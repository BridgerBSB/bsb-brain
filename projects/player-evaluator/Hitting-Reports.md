---
type: reference
created: '2026-06-29'
tags:
  - player-evaluation
  - hitting
  - core-4
  - scouting
---
# Hitting Reports

Part of [[Player-Evaluator-Agent]]. Evaluate every hitter through the Core 4.

## The Core 4
1. **Bat speed**. Sets the ceiling for impact. Use bat speed mph, 90th-pct bat speed, EV
   ceiling, P80 EV, and xwOBA/SLG signals.
2. **Bat-to-ball skills**. Contact%, zone contact%, whiff%, miss%, IZ miss%, and the ability
   to handle better competition. Great bat-to-ball gives a player more room to grow into power.
3. **Swing decisions**. IZ-Swing%, OZ-Swing%, chase%, BB/K, K%, and whether the hitter is
   making bad decisions or good decisions with execution misses. Swing-decision quality needs
   context, because binary strike/ball decisions can miss nuance around competitive pitches and
   called-strike probability.
4. **Ball flight / contact quality**. EV, Barrel%, hard-hit%, Well-hit%, launch angle, pulled
   air%, and whether the hardest contact is in the air to the pull side.

## Hitter metric list
K%, BB%, Chase%, Whiff%, Miss%, IZ-Swing%, OZ-Swing%, IZ-Contact%, OZ-Contact%, P80 or top-8th
EV, Max EV, Hard-hit%, Well-hit%, GB/LD/FB/PU%, Pull/Mid/Oppo%, performance vs velocity
(especially 90+).

## Hitter report logic (traits that scale win)
- Elite bat-to-ball plus similar OPS is a strong projection base.
- Chase rate matters, but separate chase from swing intent and in-zone aggression.
- 105 mph P80 EV is enough power foundation if the hit tool and approach are strong.
- A hitter with present power but major swing-and-miss risk is more volatile.
- Prefer "path to more damage" language when the hitter already controls the zone.
- Bet on the hit foundation and project power before betting on current power holding vs better arms.

## Hitter language (use these)
- "He already controls the zone at a high level."
- "There is a clear path to more damage if he shifts more swing volume in-zone."
- "The bat-to-ball foundation gives me more confidence projecting added impact."
- "The power foundation is present, but the swing decisions and ball flight need to improve."
- "He is not overmatched in the zone."
- "I would rather bet on the hit foundation and project power than bet on current power holding against better arms."

## Hitter Comparison Format
Player X. With (metric comparison), he pairs (strength) with (supporting metric). That tells me
(interpretation). His (risk metric) is (context), so there is a clear path to (development
outcome) through (specific adjustment). His (EV or contact metric) suggests (power or hit
foundation). I am more confident projecting (future skill) from this foundation than betting on
(other player's riskier trait) holding as competition improves.

See [[Report-Formats-and-Examples]] for the Quick Report template and [[Vocabulary-Bank]] for
the full phrase set. Mechanics in [[Biomechanics]].
