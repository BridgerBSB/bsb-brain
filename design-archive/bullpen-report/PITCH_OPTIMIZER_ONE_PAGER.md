# Matchup Pitch Optimizer — One Pager

> *For full reference, see [`PITCH_OPTIMIZER.md`](PITCH_OPTIMIZER.md).*

## What it is

A pre-series scouting tool that recommends the **best pitch + location**
for an Astros pitcher to throw against each opposing batter, broken
out by count situation.

Output: one PDF per pitcher per series, showing every opposing batter
on a single page.

## The question it answers

> Of the pitches **this pitcher actually throws**, which one — in which
> location — gives him the biggest run-value edge against **this
> specific hitter**, in **this specific count**?

Grounded in real data: the pitcher's actual season pitches, the
hitter's actual season pitches, count-state run expectancy (RE288).

## Why it matters

| User | What they get |
|---|---|
| Pitching coordinator | Ready-made attack plan per pitcher per opponent — replaces hand-built notes |
| Pitcher | Targeted plan grounded in his own arsenal, not generic "throw strikes" advice |
| Pitching coach | Reference for high-leverage at-bat calls |
| Player development | Consistent league-wide framework for scouting + evaluation |

## How to read it

Each cell of the table shows three lines:

```
CH              ← pitch type (changeup)
Mid (Horz)      ← location (middle third, horizontal band)
-0.096          ← expected run-value gain (in pitcher's favor)
```

| Cell color | Meaning |
|---|---|
| 🟦 Blue (faint → deep) | Pitcher wins. Deeper = stronger edge. |
| 🟥 Red (faint → deep) | Hitter wins. Deeper = bigger hitter edge. Avoid. |
| — (em dash) | No recommendation — pitcher hasn't thrown enough of that pitch type in that count, or no zone passed targeting rules. |

## The three count buckets

| Bucket | Counts | What the recommendation is for |
|---|---|---|
| **Early** | 0-0, 1-0, 1-1 | Get ahead without giving in |
| **Ahead** | 0-1, 0-2, 1-2, 2-2 | Putaway pitch (split: best in-zone + best chase pitch) |
| **Behind** | 2-0, 2-1, 3-0, 3-1, 3-2 | Throw a strike but limit damage |

## What it is NOT

- Not real-time — pre-series prep only
- Not a sequencing tool — top picks ranked independently
- Not a recommendation for a pitch he doesn't throw
- Not a substitute for the coach — the math points; the coach calls it

## How to get a report

```powershell
py -3.11 -m streamlit run bullpen-report\Arm_Farm.py
```

Inside the app: **Pitching Advance → pick level/series/pitcher → Optimizer tab**.

For bulk PDFs covering every pitcher: sidebar **"Download Pitch
Optimizer Summaries"** button. ZIP lands in `Downloads\`.

---

*Astros Player Development — Pitching Analytics*
