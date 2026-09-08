---
{type: concept, domain: pitching, source: personal-bsbres/statistical-models}
---
# Independent Value Family (MOC)

A 2025 **Driveline** family of intrinsic, run-value-denominated pitch/swing models built on one shared idea: **replace one big model with many small tree-based event-probability models.** Each pitch (or swing) flows through a decision tree of `p(event) × v(event)`, composed bottom-up into total run value, valued **in a vacuum** (no sequencing, no arsenal effects). The run value of an action = `outcome value − expected outcome value`. The key advantage over a monolith is **interpretability** — you can see whether a pitch's value came from a likely called strike, a high whiff chance, or weak contact.

## The members
| Model | Side | Inputs | One-line | Self-stickiness (1000 P) | Reliability |
|---|---|---|---|---|---|
| [[independent-pitch-value]] (IPV) | Pitching | Full pitch (flight + location) | All-encompassing pitch RV | r ≈ 0.67 | ~350 P |
| [[independent-stuff-value]] (ISV) | Pitching | Ball-flight only | "Stuff" — movement quality | **r ≈ 0.84** | **~30 P** (fastest) |
| [[independent-location-value]] (ILV) | Pitching | Plate location only | "Command" — zone control | r ≈ 0.65 | ~425 P |
| [[execution-run-value]] (IPV Lost) | Pitching | Intended vs actual location | RV lost missing the target | r ≈ 0.70 | ~300-325 P |
| [[independent-outcome-value]] (IOV) | Hitting | Swing decision / contact / power | Intrinsic Offensive Value | (see [[driveline-hitting-models]]) | Power ~150 BIP |

ISV + ILV ≈ the stuff/location decomposition of IPV; IPV Lost is the command-execution residual. On the hitting side, IOV mirrors the framework: `SwingDecisionRV + ContactRV + PowerRV = TotalRV`.

## Composition (shared engine)
```
Single-Pitch RV = p(Swing)·v(Swing) + p(Take)·v(Take)
  v(Swing) = v(Contact)·p(Contact) + v(Whiff)·p(Whiff)
  v(Take)  = v(Umpire Call)·p(Umpire Call) + v(HBP)·p(HBP)
  v(BIP)   = Σ v(outcome)·p(outcome) over Out/1B/2B/3B/HR
```
6 small models on the pitching side; 3 component models on the hitting side. Implemented as gradient-boosted trees ([[lightgbm-baseball-modeling]]), output in run value anchored to [[re24-run-expectancy]] and [[xwoba]].

## Public & internal analogs
All members correlate strongly to public analogs — **FanGraphs Stuff+/Pitching+/Location+** (the industry standard; also tree-based now), [[stuff-plus-4s-pitching]], [[tjstuff-plus]], [[stuff-plus-deep-learning]] — and to the Astros internal [[stuff-grade]] / [[swdec]] / [[orp-bat]]. Sibling Driveline concepts not in this family: [[mix-plus-sync]] (arsenal interaction) and [[driveline-hitting-models]] (the hitting production numbers).

## Links
- [[MOC-baseball-analytics]]
- [[independent-pitch-value]], [[independent-stuff-value]], [[independent-location-value]], [[execution-run-value]], [[independent-outcome-value]]
- [[driveline-hitting-models]], [[mix-plus-sync]], [[stuff-plus-4s-pitching]], [[tjstuff-plus]]

## From sources
- [[2026-01-19-the-evolution-of-pitch-design-saberseminar-2025-r-d-podcast]] - The Evolution of Pitch Design | Saberseminar 2025 | R&D Podcast EP 111
