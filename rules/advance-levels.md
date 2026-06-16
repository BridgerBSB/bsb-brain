---
paths:
  - "**/advance_*.py"
  - "**/generate_advance*.py"
  - "**/*pitcher_advance*.py"
  - "**/*fielding_advance*.py"
---

# Advance Reports — Permissive Level Policy (BLOCKING)

Advance reports (hitter advance, future pitcher advance, future fielding
advance) deliberately override the global "always exclude ind/bbc/win"
rules in `level-codes.md`. They answer a different question than KPI /
postgame / tracker reports, and the level-filtering policy follows from
that.

## The core principle

**Advance = "what is this player doing RIGHT NOW?"**

Standard analytics (KPI, postgame, tracker, Org Rankings) filter junk
levels because those queries need apples-to-apples pools for percentile
coloring. Mixing winter-league pitches into an AAA distribution pool
**contaminates the pool**.

Advance windows on **recency** (last X pitches / last 30 days / last 100
BF / whatever the threshold is). Its output is not a percentile vs a
pool — it's a description of the **opposing player's current form**.

When regular-season R-game data is thin (early season, midseason pickup,
rehab stint, indy-ball callup, BBC promotion), recent data from **any**
source is the best signal we have. As R-game data accumulates through
the season, the recency window naturally shifts toward R games because
R games are what's newest. We **stack recency**; we **do not filter by
league purity**.

## ALLOWED for advance (but excluded from standard analytics)

| Level | What it is | Why we keep it for advance |
|---|---|---|
| `bbc` | Big league camp (spring) | Real opposing pitchers we'll see in the regular season — earliest in-season form data |
| `ind` | Independent ball | Mid-season acquisitions come from Atlantic League etc.; indy venues have TrackMan — clean pitch data |
| `int` | International / internal | Rehab bullpens, international leagues, intrasquads with tracked data |
| `sum` | Summer leagues | Real pitches from summer collegiate / prospect leagues |
| `win` | Winter leagues | Off-season work — often the only data for a recent acquisition |
| `min` | MiLB minor/exhibition | Real minor-league opposition |

## STILL EXCLUDED — true junk

| Level | Why excluded |
|---|---|
| `nae` | "Unknown" — metadata junk, no usable signal |
| `hsb` | Showcase / high-school — different player population, different venues |
| `jcb` | Junior camp — youth programs |
| `NULL` | No level assigned — malformed row |

## Canonical implementation

Barrelsville hitter advance: `barrelsville/src/advance_data.py`

```python
# NARROW and WIDE intentionally share the same junk list now —
# they differ only on sched_type (NARROW=R, WIDE=R+S+E+I).
_JUNK_NARROW = "'nae','hsb','jcb'"
_JUNK_WIDE = "'nae','hsb','jcb'"

# Sched types
_SCHED_NARROW = "('R')"
_SCHED_WIDE = "('R','S','E','I')"
```

Any other hardcoded `NOT IN (...)` in advance-module queries must match
this list. Grep before committing:

```bash
grep -n "NOT IN.*'bbc'\|NOT IN.*'ind'\|NOT IN.*'win'" barrelsville/src/advance_data.py
```

All results should either use `{level_exclude}` substitution from
`_JUNK_NARROW` / `_JUNK_WIDE`, or hardcode only `('nae','hsb','jcb')`.

## Scope mode mechanic (unchanged by level policy)

The NARROW-vs-WIDE decision is still based on "does this pitcher have
enough recent R-game IP to anchor NARROW scope?" The level policy change
**only loosens which levels count** toward that scope. The mode switch
behavior, the IP threshold, and the sched_id gating all stay the same.

## Forward-looking: future advance reports inherit this policy

When we build these, they MUST use the same permissive level policy:

### Pitcher advance (what an opposing hitter does vs pitchers)

- Needs batted-ball events, swings, zone coverage, decisions, attack angle
- Same `_JUNK_NARROW` / `_JUNK_WIDE` = `'nae','hsb','jcb'`
- Same `_SCHED_NARROW = 'R'` / `_SCHED_WIDE = 'R','S','E','I'`
- Recent swing data from indy/BBC/winter is signal, not noise

### Fielding advance (what an opposing fielder does)

- Needs defensive opportunities, arm throws, route efficiency
- Same permissive level policy
- Will almost certainly need `E` (exhibition) to capture ST tracking
  data when the season is young

### Shared expectation for all three domains

- ~30 IP / ~100 PA / ~X plays is the typical recency threshold
- Below threshold: WIDE mode, all sched_types, all (non-junk) levels
- Above threshold: NARROW mode, R-games, same allowed level list
- **Level purity is never the goal** — recency + real player is the goal

## What NOT to do

- **Don't propagate the global `level-codes.md` "always exclude" list**
  into advance queries. It's correct for KPI / postgame / tracker, wrong
  for advance.
- **Don't add new junk codes to advance filters without discussing.** If
  a level has real pitches from real opposing players, it's signal.
- **Don't quietly split NARROW and WIDE junk lists** (revert them to
  differ by level) — they share the same list on purpose now.
- **Don't add level filters to per-pitch display tables** that render the
  opposing player's recent outings. If a pitch is in the data, we want
  the user to see it (with level labeled).

## Cross-reference

- Global level code meanings: `.claude/rules/level-codes.md`
- Global sched_type meanings: `.claude/rules/sched-types.md`
- **Non-EBIZ pitcher one-offs:** `.claude/rules/advance-non-ebiz-pitchers.md`
  — when an opposing pitcher isn't in PP_MASTER (indy callup, mid-season
  acquisition, multi-GC-id) the standard advance flow breaks. Use the
  diagnostic SQL + `generate_advance_oneoff.py` companion documented there.
- The global `level-codes.md` rules still apply to **KPI / postgame /
  tracker / Org Rankings / percentile pools**. Advance is the only
  documented exception.
