---
title: Manager / dev-coach situational assessment - external research
date: 2026-09-09
tags: [hiring, assessment, baseball-iq, game-management, research]
status: capture
---

# Manager / dev-coach situational assessment - what exists

**What it is:** research capture for the video-first situational questionnaire
idea (managers + development coaches), started 2026-09-09 in the hiring repo.
Catalog and open questions live in
`hiring/assessments/situational/README.md`. Query for the first item:
`bsb-resources/sql-queries/afx-3-2-two-outs-runners-on-last7-video.sql`.

## Existing products (player-facing situational quizzes)

| Product | What it does | Link | Read? |
|---|---|---|---|
| 6Tool | Coaches upload own questions or use a pool, many with game footage; quizzes by position/category; results tracked per player. Built by former pro players. Closest to our idea. | https://6-tool.com/ and https://6-tool.com/faq | Site blocked fetch (content empty); from search excerpts |
| Baseball IQ Pro | 8,200+ written situational questions (rules, strategy, positioning, baserunning, batting), ages 8-14, AI weak-spot plans | https://baseballiqpro.com/ | excerpt only |
| Baseball IQ Trainer | Hundreds of scenarios with explanations, Rookie/Veteran/All-Star tiers | https://apps.apple.com/us/app/baseball-iq-trainer/id6762203227 | excerpt only |
| Mind and Muscle | Cutoffs, bunt defense, first-and-third, OF reads; youth 8-18; "freeze and quiz" method | https://mindandmuscle.ai/baseball-situations-app , https://mindandmuscle.ai/blog/parent-guides/teaching-situational-awareness | excerpt only |
| BASIQs | 7,000+ animated defensive/baserunning situations | https://basiqs.com/ | excerpt only |
| ThinkingBaseball | situational app | https://apps.apple.com/us/app/thinkingbaseball/id1221028028 | excerpt only |
| Dugout Edge | Baseball IQ quiz + "situations every player should know" printable | https://www.dugoutedge.com/baseball-iq-quiz , https://www.dugoutedge.com/articles/baseball-situations-every-player-should-know | excerpt only |
| Sciency baseball quiz | strategy quiz with scenarios inspired by real MLB moments | https://sciency.blog/baseball-quiz | excerpt only |

Gap: none use the organisation's own video, none ask a manager-level decision
with the lever defended, none ask the teaching question ("what do you tell the
player").

## Manager evaluation frameworks (sitting managers, from outcomes)

- FanGraphs, How Should We Evaluate a Manager: four measurable categories -
  reliever usage (BMAR, wRM), bullpen role flexibility (Reliever Role
  Rigidity), lineup construction (projected wOBA by slot vs optimal), bunting
  with non-pitchers (fewer is better). Clubhouse unmeasured.
  https://blogs.fangraphs.com/how-should-we-evaluate-a-manager/ (read)
- Baseball Prospectus: BMAR introduction and the Bullpen (Mis)management tool.
  https://www.baseballprospectus.com/news/article/19753/baseball-prospectus-news-introducing-the-bp-bullpen-mismanagement-tool/ ,
  https://www.baseballprospectus.com/news/article/25011/pitching-backward-perfect-hindsight-and-bullpen-mismanagement/ ,
  https://www.baseballprospectus.com/news/article/21557/baseball-therapy-saving-the-save/ (excerpts)
- FiveThirtyEight, savviest and crappiest bullpen managers:
  https://fivethirtyeight.com/features/baseballs-savviest-and-crappiest-bullpen-managers (excerpt)
- Beyond the Box Score, Manager Scorecard (2009):
  https://www.beyondtheboxscore.com/2009/2/24/769947/manager-scorecard (excerpt)
- FanGraphs, Managing Decisions and an MLB Team:
  https://blogs.fangraphs.com/managing-decisions-and-an-mlb-team/ (excerpt)
- MLB video, Bo Knows: Game situations (Bo Porter + Mark DeRosa break down
  managerial mindsets): https://www.mlb.com/video/bo-knows-game-situations

## The levers, with the numbers we can cite

- **Infield in** (SIS 2019, read): .366 BA on grounders/short liners vs .296
  back; batting team scored at least one run 49% vs 63%. 2018 usage: Padres 98,
  Phillies 93, White Sox 82; Angels 32, Brewers 32, Mariners 34.
  https://www.sportsinfosolutions.com/2019/05/03/the-effectiveness-of-infield-in-defense/
- **Infield in with 2B+3B, <2 outs** (Paraball Notes, read): MLB brings it in
  29% with 0 outs, 43% with 1 out; author argues teams should do it more for
  win probability despite worse run expectancy.
  https://www.paraballnotes.com/blog/should-you-bring-the-infield-in-with-runners-on-2nd-and-3rd-and-less-than-2-outs
- **Send or hold** (Crawfish Boxes 2012, fetch 403, excerpt): break-even
  p = (H - O)/(S - O); nobody out send only if certain, one out hold unless the
  next two cannot drive him in, two outs send. Also Robert Frey
  https://rfrey22.medium.com/baserunning-should-you-send-the-runner-ead23c6229df ,
  BP "Why all third-base coaches should be fired"
  https://www.baseballprospectus.com/news/article/10073/hot-stove-u-why-all-third-base-coaches-should-be-fired/ ,
  DRaysBay break-evens https://www.draysbay.com/2020/8/9/21359078/calculating-baserunning-break-even-points ,
  arXiv 1505.00456 https://arxiv.org/pdf/1505.00456 , process-vs-outcome piece
  https://jrod20033.substack.com/p/the-third-base-coachs-dilemma-navigating
- **Run expectancy tables**: FanGraphs RE matrix reloaded for the 2020s
  https://blogs.fangraphs.com/the-run-expectancy-matrix-reloaded-for-the-2020s/ ;
  Retrosheet-built 2023-25 matrix with SB/bunt analysis
  https://github.com/RyanArpin/mlb-run-expectancy ; Baseball-Reference WE/RE
  https://www.baseball-reference.com/about/wpa.shtml
- **Bunting / IBB**: Dan Blewett run-expectancy bunting
  https://danblewett.com/run-expectancy-bunting-bad/ ; Data Jocks IBB
  https://thedatajocks.com/using-run-expectancy-to-value-intentional-walks/ ;
  bunting + ghost runner causal paper https://arxiv.org/pdf/2404.06587
- **3-2 two outs, runners go**: applies only when every runner is forced
  (Quora + Baseball Fever threads, excerpts):
  https://www.baseball-fever.com/forum/general-baseball/baseball-101-coaching-fundamentals/79730-running-on-a-full-count-two-outs

## Takeaways for the build

1. Format gap is real: org video + decision + teaching question.
2. Score process, not outcome (the third-base-coach dilemma piece is the framing).
3. Our own RE / break-even numbers should come from GC2 by level, not from MLB
   tables; A-ball break-evens differ (arm strength, error rates).
4. Astro World already has a server-graded quiz engine with gating; the hiring
   cage app already has scenarios + invites. Either can host it; decide first.

Related: [[director-searches-2026]], [[hitting-coach-question-bank]],
[[coordinator-notes-questionnaire]], [[astro-world-astrosedu-media-and-quizzes-2026-08-03]].
