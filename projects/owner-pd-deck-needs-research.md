---
status: research captured 2026-10-10; Needs + Staff slides published to the deck
  (version 14)
tags:
  - owner-deck
  - player-development
  - trajekt
  - kinatrax
  - player-app
  - biomechanics
created: 2026-10-10
---
# Owner PD deck: "Needs" slide research (Trajekt, Player Application, KinaTrax)

**What it is:** Research and image sourcing for the "Needs" slide that Sam asked to add to the owner-facing deck "What Player Development Means to the Astros Organization" (artifact https://claude.ai/artifact/UVm5wbrjeuh7nbwArw2Lyd). Sam's three needs, as Zac relayed them on 2026-10-10: **Trajekt** (a more difficult offensive training environment), a **Player Application** (phone-accessible, with data, reports and video available with ease) and **KinaTrax** (an easier, reliable way to gather biomechanics that drive actionable plans for player improvement). In the same request Sam sent a "what we look for in staff" slide (Engine / Figure / Coachable / Obsessed) to be redesigned. Both slides are now built.

Related: [[owner-pd-deck-mlb-value-research]] (the value and acquisition-cost research behind the same deck) · [[promotion-models-STATUS]]

## Slide as built (deck version 14, 2026-10-10)

- `needs` (last slide, after `value`): eyebrow "Looking Ahead", title "Needs", three cards, each with an image, a name and one line:
  - **Trajekt:** "Replicates any pitcher's velocity, spin and release, synced to video, for a more difficult offensive training environment."
  - **Player Application:** "A phone-accessible app that puts data, reports and video in every player's hands, available with ease."
  - **KinaTrax:** "Markerless 3D motion capture: a reliable way to gather biomechanics that drive actionable plans for player improvement."
- `staff` (after `scope`): eyebrow "Our Staff", title "What We Look For", a 2x2 grid of checkbox tiles for Engine, Figure, Coachable and Obsessed. Sam's original slide was titled "How do I have a good year? What does success look like?". It was retitled from Zac's framing ("this is what we look for in staff"). No definitions were added; the words are Sam's.
- Image assets in the deck: Trajekt `/_blob/d6bf921553d09c5e0b3c1566f8f0cc3e`, phone `/_blob/f41a27f71716e73a765b716de186e10e`, KinaTrax `/_blob/520ee8df985934a117d48444588dbc77`.

## Sources

### Trajekt Sports: homepage (company)
- URL: https://trajektsports.com/
- Fetched via: WebFetch direct (200). `/arc` returns 404.
- Substance: the product is **Trajekt Arc**. It controls speed, 3D spin and seam orientation for "any pitch imaginable", and lets the user choose a pitcher's release slot to replicate the trajectory. Pitcher video plays on the screen ("Visualization") so hitters can time at-bats at game speed. Company claims: **6M+ pitches, 120+ systems deployed, 50+ organizations**. There is a waitlist for a publicly available model. No customer teams are named.
- Image: `Arc 2026.png` (1500x1161 RGBA, transparent background): https://images.squarespace-cdn.com/content/v1/6424811cd766c5252c99b78c/2da46ef3-8537-4291-886d-acfd934d65ef/Arc+2026.png. It shows the full Arc enclosure with pitcher video and the on-screen hit and pitch readout (EV, LA, pitch type, speed, breaks). It was composited onto Astros navy for the slide.
- Takeaways for us: "Replicates a specific pitcher, synced to video" is the honest owner-level pitch. The product page is the source for the speed / spin / seam / release-slot claims. The adoption counts are company-reported.

### Trajekt press coverage (ESPN, AP, MLB.com, Inquirer)
- URLs: https://www.espn.com/mlb/story/_/id/40401564 · https://www.click2houston.com/sports/2024/03/26/robots-replicate-reality-high-tech-pitching-machine-mimics-every-pitcher/ · https://www.mlb.com/marlins/news/miami-marlins-use-revolutionary-trajekt-arc-hitting-machine · https://inquirer.com/phillies/bryce-harper-return-trajekt-arc-pitching-machine-phillies-20230421.html · https://www.wlrn.org/light/sports/2025-08-18/miami-marlins-robot-pitcher-baseball-technology
- Fetched via: WebSearch excerpts (articles not fetched in full).
- Substance: teams upload a pitcher's metrics (public Statcast plus Trackman, Rapsodo, Hawk-Eye) and video into a playlist-style menu. A model maps the pitch characteristics to a machine configuration. The machine sits on a gantry so its release point can move, and a two-piece screen on a sliding track shows the pitcher's video with the ball exiting through a hole in the middle. MLB approved in-game use in the batting cage (2024 coverage). **Cost: $15,000 to $20,000 per month per machine on a three-year lease** (AP, March 2024). This is the only cost figure found, and it is 2024 coverage.
- Takeaways for us: the cost figure is useful if ownership asks "what does it cost". It is NOT on the slide. Confirm current pricing with Trajekt before quoting it.

### KinaTrax: company site, now under Hawk-Eye / Sony
- URL: https://www.kinatrax.com/ (301 redirect) -> https://www.hawkeyeinnovations.com/biomechanics
- Fetched via: WebFetch on the redirect target.
- Substance: "Industry Leaders of In-Stadium and In-Lab Markerless Motion Capture". It uses a high-speed multi-camera setup and deep learning for "precise 3D joint location and bone segment orientation". Listed uses: scouting and valuation (historical data plus a college sharing network), performance optimization (game vs training data), injury prevention (custom biomechanics reports for prevention and rehab). It also integrates with force plates and ball trajectory and has a web portal for fast review. Case study: Auburn Baseball, in-stadium 3D pitching and hitting data. Branded "a Sony Company". The page has no photos, only logos.
- Takeaways for us: Zac's description ("precise 3D joint location and bone segment orientation for both indoor and outdoor environments") matches the company's own wording. On the site, "outdoor" appears as "in-stadium" and "indoor" as "in-lab".

### Sony press release: Sony acquires KinaTrax (Oct 16 2024)
- URLs: https://www.sony.co.jp/en/news-release/202410/24-1016E/ · https://refreshmiami.com/news/sony-acquires-boca-based-sportstech-kinatrax-a-leader-in-biomechanics-and-player-performance/
- Fetched via: WebFetch direct (both 200). The newscaststudio.com copy returned 403.
- Substance: Sony (not Hawk-Eye) acquired KinaTrax, a "research-grade markerless motion capture" company. Its camera systems are in **over 75 stadiums and labs** (Sony), or **over 100** (Refresh Miami, Oct 2024), across MLB, MiLB and NCAA, and it is expanding to the NBA and NHL. Founded 2016 in Boca Raton by Steven Cadavid (now Head of Biomechanics at Sony's sports businesses). About 50 employees. Terms undisclosed. It works alongside Hawk-Eye, the tracking provider behind Statcast.
- Takeaways for us: the speaker notes say "now part of Sony's sports business, alongside Hawk-Eye". The stadium count differs by source (75 vs 100), so neither number is on the slide.

### FanGraphs TechGraphs: "KinaTrax Gives Rays In-Game Markerless Motion Capture Data"
- URL: https://techgraphs.fangraphs.com/kinatrax-gives-rays-in-game-markerless-motion-capture-data/
- Fetched via: WebFetch direct.
- Substance: the Rays were the first MLB partner. Multiple ballpark cameras capture 275-300 fps from about 350 ft and are combined into a 3D view. The founder claimed positional accuracy within **1.5 cm**, and a game produces up to **1.4 TB**. **Teams own the data** (it identifies the pitcher, so it is treated as medical information). KinaTrax can produce reports, or teams with qualified staff can use the raw data directly. Other excerpts (edge-ai-vision 2017 presentation, https://www.edge-ai-vision.com/2017/10/using-markerless-motion-capture-to-win-baseball-games-a-presentation-from-kinatrax/): **20 joint centers per frame, 300+ fps**, export to C3D, BVH and CSV.
- Takeaways for us: "teams own the data" and "raw data available" matter for whether we build our own reports (the BSB pattern) or rely on vendor reports. The accuracy figure dates from the founder's 2013 SABR talk, so do not quote it to ownership as current.

### iMerit blog: KinaTrax annotation case (source of the slide image)
- URL: https://imerit.ai/resources/blog/computer-vision-revolutionizes-baseball-game-motion-capture-technology/
- Fetched via: WebFetch direct.
- Substance: iMerit annotates KinaTrax video. The 3D reconstruction is frame by frame, with 20 joint centers per frame.
- Image used: https://imerit.ai/wp-content/uploads/2021/01/kinatrax-pitcher-model.png (600x400). A youth pitcher with a skeleton overlay showing joint angle, arm speed and stride length callouts. **Low resolution, and the pitcher is a youth player.** Swap it if Sam wants a pro or lab image. A KinaTrax or Hawk-Eye press kit request is the clean source.

### Unsplash: hand holding an iPhone (stock photo for Player Application)
- URL: https://unsplash.com/photos/hand-holding-smartphone-with-app-icons-A6JxK37IlPo (image https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5)
- Fetched via: WebFetch on the Unsplash search page, then curl of the image.
- Substance: free Unsplash License (not Unsplash+). An iPhone X home screen, held in one hand on a grey background.
- Takeaways for us: if a mock of our own player app exists later, put its screenshot on this card in place of the stock photo.

## Open items
1. Pro or lab image for KinaTrax (current: a 600px youth image from the iMerit blog).
2. Whether to show cost on the slide (Trajekt $15-20K/month lease, 2024 AP). Currently only in this note.
3. Definitions for Engine / Figure / Coachable / Obsessed, if Sam wants a line under each.
