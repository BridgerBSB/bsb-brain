# R Shiny → Posit Connect Publishing (host-a-colleague's-app playbook)

**What it is:** The repeatable workflow for taking an R/Shiny app a colleague
pushes to GitHub and publishing it to Posit Connect under Zac's account — the
"you write, I publish" pattern for teammates whose Posit publishing access was
revoked. First run: **Ryan Isler's Command Training app, shipped live 2026-07-08.**

Related: [[bsb-resources-inventory]] · [[org-training-process]] ·
[[team-training-loop]] · [[MOC-baseball-analytics]]

---

## Why this exists

IT (Catherine) removed Ryan Isler's Posit **publishing** rights. He kept coding
in R but couldn't deploy. Workaround that beats fighting IT:

- **Colleague pushes code → shared GitHub repo.**
- **Zac pulls → publishes to Posit Connect → grants the colleague viewer access.**
- Zac is publisher-of-record; colleague still "owns" the code on GitHub.

This is a general template for onboarding any non-publishing R teammate.

## The repo setup (Zac, one time per colleague)

- Enterprise GitHub account for them (Ryan = `Risler_astros`, SSO). Zac's org = `zbridger_astros`.
- Create a **fresh repo** (Ryan's = `github.com/zbridger_astros/command-training-isler`).
  Fresh repo = **no rulesets**, so direct pushes to `main` work for both — nice for a git-newcomer.
- Add them as a **collaborator (Write)**; they authorize SSO once or pushes bounce.
- **Layout:** app at repo **ROOT** (`app.R` + `www/` + any data) so Connect/RStudio
  auto-detect it; drop the reusable R kit in `r-resources/` alongside; a `README`
  explains the push-here / I-publish flow.
- Colleague works entirely inside **RStudio's Git pane** (no terminal). The
  `r-resources/` kit's RStudio git guides cover clone + commit + push.

## The reusable R kit — `r-resources-astros/` (lives in `bsb-resources`)

The Astros R starter pack, copy it into any new R teammate's repo:

- RStudio **git guides** (clone / commit / push, no CLI)
- **`R Publish To RConnect.doc`** + **`Posit Connect Tutorial.docx`** — the deploy walkthroughs
- **Major Tom functions** (`getSQLConnection` / `getCredentials`) — the Astros R↔GC2
  DB pattern: `Trusted_Connection` locally, and on Connect it decrypts creds from
  the `ON_RSTUDIO_CONNECT_SERVER_DB_<SERVER>_<DB>` env var (base64 + sodium). Only
  needed if the app hits GroundControl2 — SQLite-only apps skip it entirely.
- Trusted-connection SQL template (`server=GCSQL02`, `trusted_connection=true` — no creds)
- **R Style Guide**, and a full **deployed** reference app (`Shiny App Example/` = YakkerTech).

## ⛔ You CANNOT publish R from the personal laptop

- **No R installed** on the personal laptop (`Rscript` not found).
- **`connect2.astros.com` is internal-only** — same DNS wall that blocks reading
  Connect pins from the personal box.
- Therefore R publishing is **always work-laptop + RStudio + on the Astros network**,
  and since **Claude Code is blocked on the work laptop**, this step is *always*
  hand-guided (I direct, Zac clicks). Do not try to script it from Claude Code.

## The publish path (RStudio button — simplest, what the docs describe)

1. **File → New Project → Version Control → Git** → paste the repo URL → Create
   (browser SSO prompt is normal). *(Already cloned? Open project → ⬇ Pull first.)*
2. **Tools → Global Options → Publishing → Connect…** → **Posit Connect** (NOT
   shinyapps.io) → server `https://connect2.astros.com`. *(The old doc says
   `connect.astros.com`; **connect2** is current — the newest `.dcf` deploys there.)*
   Login = **machine username** (first-initial + lastname, no `@astros.com`) +
   Outlook/login password.
3. Open the app's `.R` file in the editor.
4. Blue **Publish** icon (top-right of editor) → **Publish Application**.
5. In the file checklist: **UNCHECK `r-resources/` and `README`**; keep the app
   `.R` + `.sqlite`/data + `www/`. Title it → **Publish**.
6. Deploy tab runs → pops the live URL. **On connect2: content → Access → add the
   colleague as viewer → send URL.**

### Console equivalent (copy-paste)

```r
install.packages(c("shiny","ggplot2","dplyr","DT","DBI","RSQLite","png","shinyWidgets"))
rsconnect::deployApp(
  appDir        = ".",
  appPrimaryDoc = "command-training-isler.R",   # needed when the file isn't app.R
  appName       = "command-training-isler",
  appTitle      = "Command Training",
  server        = "connect2.astros.com",
  appFiles      = c("command-training-isler.R","command_training.sqlite",
                    "www/astros_logo.png","www/baseball.png","www/catchers_mitt.png")
)
```

## Three gotchas (each cost a real decision on the first run)

1. **Don't bundle `r-resources/`** (~60 MB kit + example app) into the deploy —
   use `appFiles` or uncheck it in the dialog.
2. **Republishing content someone ELSE already published** requires an admin
   (**Colin on Slack**) hand-editing config files. So **publish a NEW item under
   your account** and add the colleague as viewer — never try to update their old
   revoked-account item.
3. **Bundled-SQLite writes DON'T persist on Connect.** Ryan's app writes sessions
   back to its bundled `.sqlite`; on Connect those writes reset on redeploy and
   aren't shared across users. It runs and demos fine — but **durable persistence
   (real DB or pinned dataset) is the known follow-up**, not a publish blocker.

## First-run record — Command Training (Ryan Isler)

- Self-contained Shiny app, ends in `shinyApp(ui, server)`. Deps: `shiny, ggplot2,
  dplyr, DT, DBI, RSQLite, png, grid, shinyWidgets`.
- **No GC2 dependency** — local SQLite via relative path → no DB creds / VPN / env
  Vars needed. Images referenced correctly (`img(src="astros_logo.png")` +
  `readPNG("www/baseball.png")`) → render on Connect.
- File was `command-training-isler.R` (not `app.R`) → published via `appPrimaryDoc`
  / button-with-file-open.
- **STATUS: live 2026-07-08.** Ryan = viewer on the Connect content. Follow-up =
  durable session storage (gotcha 3).


## Gotcha 4 — `repos[[1]] : subscript out of bounds` on deploy (CRAN mirror unset)

**Symptom** (hit on Ryan's 2026-07-09 republish): deploy log shows
`Warning: unable to access index for repository .../PACKAGES` during "Capturing R
dependencies", then the server fails with
`Error in repos[[1]] : subscript out of bounds ... Calls: readLockFile`.

**Cause:** RStudio's CRAN mirror wasn't set (or was the `@CRAN@` placeholder), so
the deploy manifest went up with a **blank package-repository list** — the Connect
server needs that URL to install the packages and chokes reading an empty repos.
Nothing to do with the app; the upload itself succeeds.

**Fix (RStudio Console on the work laptop):**
```r
options(repos = c(CRAN = "https://cloud.r-project.org"))
getOption("repos")   # must print the URL, NOT "@CRAN@"
```
Then republish. Make it permanent: **Tools → Global Options → Packages → Primary
CRAN repository → Global (CDN) – RStudio**. (Use `cloud.r-project.org`, not
`cran.rstudio.com` — the latter is what failed to open on the Astros network.)

**If a NEW error then appears** about *downloading/installing* a package (vs the
repos subscript), the Connect server pulls only from an internal Posit Package
Manager — point `repos` at the org's internal mirror (IT / Chris Josefy has the URL).
