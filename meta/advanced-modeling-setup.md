---
type: meta
domain: pitching
source: personal-bsbres/examples/advanced-modeling
created: '2026-06-15'
---
# Advanced Modeling Repo Setup

`personal-bsbres/examples/advanced-modeling/` — a **README + a one-shot repo-vendoring
script** that pulls three public, state-of-the-art baseball-modeling codebases
into the repo's `external-docs/` so an AI assistant (Claude/GPT) has full file
context to analyze, debug, and build on them. It's not a model itself — it's the
"give the AI the source to read" provisioning layer.

Source files:
- `advanced-modeling/README.md` — the catalog + theory writeup
- `advanced-modeling/setup_repositories.py` — the clone-and-copy automation

---

## `setup_repositories.py` — what it does

A `subprocess`/`shutil` script that, for each target repo:

1. `git clone` into a `tempfile.mkdtemp()` temp dir.
2. Optionally `git checkout` a **pinned commit** (for reproducibility).
3. Remove any existing target dir, then `shutil.copytree(..., ignore=ignore_patterns('.git'))`
   the repo contents into `external-docs/<dir>/` — i.e. it **vendors a flat copy
   without the `.git`**, not a submodule.
4. Write a `REPOSITORY_INFO.md` into each target dir recording the source URL,
   commit, and setup date.
5. Clean up the temp dir with a Windows read-only-file handler
   (`os.chmod(path, 0o777)` in the `onerror` callback — Git objects are read-only
   on Windows and `shutil.rmtree` chokes otherwise).

It checks `git --version` as a prerequisite, resolves the project root as
`Path(__file__).parent.parent.parent`, and prints a verbose summary of what's
available for AI analysis plus next-step install/run commands.

### The three repos it pulls

| Dir | Repo | Pinned commit | Purpose |
|---|---|---|---|
| `pybaseball/` | `jldbc/pybaseball` | `aa093f9d…fcb0f89` | The Statcast/Savant data library — full source for context |
| `4S-pitching/` | `johnnynienstedt/4S_Pitching` | latest HEAD | The 4S pitch-evaluation model ([[johnny-nienstedt]]) |
| `stuff-model/` | `jack-kelly-12/Stuff-Model` | latest HEAD | Public Stuff+/Pitching+/Location+ implementation ([[jack-kelly]]) |

Only `pybaseball` is commit-pinned; the two model repos track latest. The whole
point is **full local file access** so the AI can be asked to "analyze
`external-docs/4S-pitching/4S.py`" or "explain `stuff-model/Stuff+.ipynb`."

---

## What the models are (from the README)

### 4S Pitching ([[johnny-nienstedt]])
Decomposes a pitcher into four independent `+`-scaled (100 mean, 10 SD) models:
- **Shape+** — physical characteristics (velo, movement, approach angles); XGBoost
  over 8 swing outcomes → expected run values. Weighted **65% descriptive / 71%
  predictive** of the composite.
- **Spot+** — location effectiveness via Bayesian updating per pitch; ~0.7 R² with
  future performance; release-point variance as command proxy. 15% desc / 0% pred.
- **Slot+** — deceptive release effects, inspired by **Max Bay's Dynamic Dead
  Zone**; movement relative to same release slot (rewards ride on FB, drop on
  offspeed, sweeper lift+HB). 8% desc / 10% pred.
- **Sequence+** — pitch-mixing via a pitch-type sequence matrix; three optimal
  sequences (**Match** = same angle+location, **Split** = same angle/diff location,
  **Freeze** = diff angle/same location). 12% desc / 19% pred.
- **Reported performance vs public models** (SIERA target): 4S same-season R²
  **0.44** / next-season **0.24**, vs Stuff+ 0.46/0.17 and botStf 0.43/0.25 — i.e.
  4S trades a hair of descriptive power for the best **next-season predictiveness**.

### Public Stuff+ ([[jack-kelly]])
Full open implementation of **Stuff+ / Pitching+ / Location+**:
- Trained on **Statcast 2020–2023**.
- **12 models** = 3 pitch types × 4 model types; run values built from the ground up.
- Notebooks: `Stuff+.ipynb`, `Pitching+.ipynb`, `Location+.ipynb`.
- Same-year and next-year correlation validation.

The README frames these as the **open analogs of the org's internal pitch-quality
grades** — studying them is how you reason about what GroundControl2's Stuff/Proj
grades are doing under the hood.

---

## How it ties into the rest of the repo

The README's "integration points" wire this to the other example pieces:
- **Data** → [[statcast-bulk-fetch]] (`run_pybsb.py`) feeds the models.
- **Reference** → `docs/reference/statcast_glossary.pdf` for column definitions.
- **Templates** → `templates/modeling-project/` + `templates/streamlit-app/` as
  scaffolds for new work / model-output viz.
- Quick-start clones the model repos and opens the notebooks in Jupyter.

---

## Reusable pattern

The script itself is a clean, reusable **"vendor public repos for AI context"**
recipe: temp-clone → optional commit pin → copytree-minus-`.git` → stamp an
info file → Windows-safe cleanup. Worth lifting whenever you want an assistant to
have whole-codebase context on an external project without git-submodule
machinery.

## Links
- [[MOC-baseball-analytics]]
- [[stuff-plus-4s-pitching]] — the concept note for these model families
- [[statcast-bulk-fetch]] — the data layer that feeds them
- [[statcast-pipeline]] — the broader spine
- [[johnny-nienstedt]] — 4S Pitching author
- [[jack-kelly]] — public Stuff+ author
- [[driveline]] — research-org context for the pitch-modeling lineage
- [[personal-bsbres]] — the repo this lives under
