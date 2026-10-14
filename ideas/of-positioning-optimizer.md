---
type: idea
status: backlog
tier: unranked
domain: fielding
effort: L
lens: data-scientist
source: research
owner: zac
link: https://medium.com/@colinhofmeister/where-should-the-defense-stand-4ea568dda964
created: '2026-10-13'
tags:
  - idea
  - backlog
  - positioning
  - mazzo
---
# OF positioning optimizer, validated on real starting spots

Copy Colin Hofmeister's public architecture (pre-pitch batted-ball mix, park BIP reweighting,
out model + physical coverage race, wall reach, rule-constrained optimizer, held-out
discount) and add the step public data cannot do: score model spots against our ACTUAL
`Play_Starting_Positions` play by play, which also lets us GRADE where our OFs stood. Answers
Mazzo item 1 ("take a stance"). Hard rule from the source: no feature may use where a ball
was fielded. Gate on HawkEye coverage per level first.

Detail: [[defensive-positioning-hofmeister-2026-10]] · [[mazzo-of-br-wishlist-2026-10]].
