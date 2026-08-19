"""BSB Brain Command Center - static HTML dashboard generator.

Use case 03 from meta/fable5-use-cases.md: a clickable dashboard over the
vault + Claude Code sessions + worktrees. Metrics the terminal can't show.

Daily driver. Three cockpit surfaces on top (added Jul 16 2026):
  - TODAY: where you left off + the exact next step (from last-state.md).
  - NEEDS ATTENTION: computed triage (branch drift, unpushed, uncommitted,
    inbox backlog, no /log today) so nothing rots silently.
  - RECENT ACTIVITY: merged commit feed across all 4 worktrees - the
    "what the crew just did" feed (chase.h.ai's signature surface).

Run:  py C:\\Users\\Owner\\bsb-brain\\meta\\generate_command_center.py
Or double-click:  Command-Center.cmd   (regenerates + opens in browser)
Out:  C:\\Users\\Owner\\bsb-brain\\Command-Center.html

No dependencies beyond stdlib. Reads only; writes one HTML file.
"""
import os, glob, html, datetime, subprocess, collections, re

VAULT = r"C:\Users\Owner\bsb-brain"
TRANSCRIPTS = r"C:\Users\Owner\.claude\projects\C--Users-Owner-bsb-resources"
MEMORY = os.path.join(TRANSCRIPTS, "memory")
RULES = r"C:\Users\Owner\bsb-resources\.claude\rules"
OUT = os.path.join(VAULT, "Command-Center.html")
LAST_STATE = os.path.join(VAULT, "last-state.md")

WORKTREES = [
    ("PD Engine", r"C:\Users\Owner\bsb-resources", "feature/pd-goals"),
    ("Arm Farm", r"C:\Users\Owner\bsb-wt-bullpen", "feature/bullpen-reports"),
    ("Barrelsville", r"C:\Users\Owner\bsb-wt-hitting", "feature/barrelsville"),
    ("Intangibles", r"C:\Users\Owner\bsb-wt-intangibles\astros-intangibles", "feature/astros-intangibles"),
]

# Chronically-modified paths that should NOT trip the attention panel - they're
# known-intentional local drift, not fresh work. Match = substring of the git path
# (forward-slash form). Edit this list freely. The chronic count still shows, muted,
# below the real items, so nothing is ever fully hidden.
ATTENTION_IGNORE = [
    ".claude/rules/",                      # rule-sync byte-copy drift across worktrees
    "docs/ARCHIVED_REFERENCES.md",
    "docs/plans/2026-05-",                 # abandoned May planning docs
    "generate_amateur_vs_pro_slide_deck",  # delivered project, chronic tweaks
]

COMMAND_DECK = [
    ("Daily loop", [
        ("/brief", "load vault state - where you left off"),
        ("/today", "morning briefing - top 3 + the one thing"),
        ("/log", "structure today's brain-dump into a daily note"),
        ("/drift", "goal-drift check vs locked decisions"),
        ("/wrap", "close a session - write last-state, log, sync"),
        ("/sunday", "weekly review - win / friction / change"),
    ]),
    ("Capture", [
        ("/document", "save anything fed (link/file/idea) into the brain"),
        ("/ingest", "deep-ingest a source into interlinked notes"),
        ("/research", "research + capture findings into the vault"),
        ("/tidy", "vault audit - empties, strays, misfiles"),
        ("/sync", "refresh vault snapshot of rules + memory"),
    ]),
    ("Cascades", [
        ("/monday", "full Monday weekly-reports cascade, all 4 worktrees"),
        ("/dry-monday", "dry-run the cascade - PDFs only, no Slack"),
        ("/repin-goals", "re-pin goals.csv to Posit Connect"),
        ("/audit-deploys", "audit deploy.ps1 bundles vs import graphs"),
        ("/sync-rules", "byte-copy rules + scripts to all worktrees"),
    ]),
    ("Engineering", [
        ("/code-review", "review current diff for real bugs"),
        ("/verify", "exercise a change end-to-end before commit"),
        ("/metric-audit", "cross-app metric parity check"),
        ("/new-report", "pattern-enforced new report build"),
        ("/new-visual", "visual standards + render-and-look gate"),
    ]),
    ("Rules & context", [
        ("/load-rules", "PULL a domain's rules on demand (pivot / planning)"),
        ("/percentile", "percentile golden-gate table + decide/build/audit a gate"),
        ("/tracker-new-metric", "question-first: add/change a tracker metric"),
        ("/amateur", "question-first: college / draft / amateur queries"),
        ("/document-pattern", "write a reusable pattern to rules + propagate"),
    ]),
]

NAVY, ORANGE = "#002D62", "#EB6E1F"
SURFACE, PANEL, INK, INK2, GRID = "#101418", "#171d24", "#e8eaed", "#9aa4af", "#242c35"
YELLOW, GREEN, RED = "#e0b341", "#57a86b", "#e05a4a"


def run_git(path, *args, strip=True):
    try:
        out = subprocess.run(["git", "-C", path] + list(args),
                             capture_output=True, text=True, timeout=15).stdout
        return out.strip() if strip else out
    except Exception:
        return ""


def count_notes():
    counts = {}
    for entry in sorted(os.listdir(VAULT)):
        p = os.path.join(VAULT, entry)
        if os.path.isdir(p) and not entry.startswith("."):
            n = len(glob.glob(os.path.join(p, "**", "*.md"), recursive=True))
            if n:
                counts[entry] = n
    counts["(root)"] = len(glob.glob(os.path.join(VAULT, "*.md")))
    return counts


def sessions_by_day(days=21):
    today = datetime.date.today()
    cutoff = today - datetime.timedelta(days=days - 1)
    per_day = collections.Counter()
    for f in glob.glob(os.path.join(TRANSCRIPTS, "*.jsonl")):
        d = datetime.date.fromtimestamp(os.path.getmtime(f))
        if d >= cutoff:
            per_day[d] += 1
    return [(cutoff + datetime.timedelta(days=i),
             per_day.get(cutoff + datetime.timedelta(days=i), 0))
            for i in range(days)]


def git_info(path, expect):
    """Rich per-worktree state: branch, last commit, split dirty, ahead/behind.
    Modified tracked files are split into `active` (real, alarms) vs `chronic`
    (matches ATTENTION_IGNORE, muted)."""
    branch = run_git(path, "branch", "--show-current")
    last = run_git(path, "log", "-1", "--format=%ad|%s", "--date=format:%b %d")
    porc = run_git(path, "status", "--porcelain", strip=False).splitlines()
    modified_files, untracked = [], 0
    for l in porc:
        if l.startswith("??"):
            untracked += 1
            continue
        p = l[3:].strip()
        if " -> " in p:  # rename: take the new path
            p = p.split(" -> ")[-1]
        modified_files.append(p)
    active = [p for p in modified_files
              if not any(ig in p.replace("\\", "/") for ig in ATTENTION_IGNORE)]
    ahead = behind = 0
    if branch:
        ab = run_git(path, "rev-list", "--left-right", "--count", f"origin/{branch}...HEAD")
        parts = ab.split()
        if len(parts) == 2:
            behind, ahead = int(parts[0]), int(parts[1])
    date, _, subj = last.partition("|")
    return {"branch": branch, "date": date, "subj": subj[:72],
            "modified": len(modified_files), "active": active, "n_active": len(active),
            "chronic": len(modified_files) - len(active), "untracked": untracked,
            "ahead": ahead, "behind": behind,
            "branch_ok": branch == expect, "expect": expect}


def recent_activity(n_each=8, total=14):
    """Merged commit feed across all worktrees, newest first."""
    acts = []
    for name, path, _ in WORKTREES:
        out = run_git(path, "log", f"-n{n_each}", "--format=%at|%ad|%s",
                      "--date=format:%m/%d %H:%M")
        for line in out.splitlines():
            epoch, _, rest = line.partition("|")
            date, _, subj = rest.partition("|")
            if epoch.isdigit():
                acts.append((int(epoch), name, date, subj))
    acts.sort(reverse=True)
    return acts[:total]


def attention_items(wt_infos, inbox, has_daily_today):
    """Compute the daily triage list: (severity, text) + chronic count.
    Empty items = all clear. severity: 2=high(orange) 1=med(yellow) 0=low(dim)."""
    items = []
    for name, info in wt_infos:
        if info["branch"] and not info["branch_ok"]:
            items.append((2, f"{name}: on <b>{html.escape(info['branch'])}</b>, expected {html.escape(info['expect'])}"))
        if info["ahead"]:
            items.append((2, f"{name}: <b>{info['ahead']} commit(s) unpushed</b> - git push"))
        if info["behind"]:
            items.append((1, f"{name}: {info['behind']} commit(s) behind origin - git pull"))
        if info["n_active"]:
            names = ", ".join(os.path.basename(p) for p in info["active"][:3])
            more = f" +{info['n_active']-3}" if info["n_active"] > 3 else ""
            items.append((1, f"{name}: {info['n_active']} uncommitted - <span class='mono'>{html.escape(names)}{more}</span>"))
    if not has_daily_today:
        items.append((1, "No daily note today - run <b>/log</b> to capture the day"))
    if inbox >= 25:
        items.append((0, f"{inbox} notes in 00-inbox awaiting filing - run <b>/tidy</b>"))
    items.sort(key=lambda x: -x[0])
    chronic_total = sum(i["chronic"] for _, i in wt_infos)
    return items, chronic_total


def parse_last_state():
    """Pull the 'what we were doing' + 'exact next step' from last-state.md."""
    if not os.path.exists(LAST_STATE):
        return None
    txt = open(LAST_STATE, encoding="utf-8").read()
    age_h = (datetime.datetime.now() - datetime.datetime.fromtimestamp(os.path.getmtime(LAST_STATE))).total_seconds() / 3600

    def grab(label):
        m = re.search(rf"\*\*{label}[:\*]*\*\*[:\s]*(.+?)(?=\n\s*-\s*\*\*|\n#|\Z)", txt, re.S | re.I)
        return re.sub(r"\s+", " ", m.group(1)).strip() if m else ""

    head = re.search(r"^#\s*(.+)", txt)
    return {
        "title": head.group(1).strip() if head else "Last session",
        "doing": grab("What we were doing"),
        "next": grab("EXACT next step"),
        "blockers": grab("Blockers / waiting on"),
        "age_h": age_h,
    }


def bar_chart_svg(data, width=860, height=180):
    if not data:
        return ""
    mx = max(c for _, c in data) or 1
    pad_l, pad_b, pad_t = 30, 26, 12
    plot_w, plot_h = width - pad_l - 8, height - pad_b - pad_t
    n = len(data)
    slot = plot_w / n
    bw = max(6, slot - 2)
    parts = [f'<svg viewBox="0 0 {width} {height}" role="img" aria-label="Claude Code sessions per day, last {n} days">']
    for gy in range(0, mx + 1, max(1, mx // 3)):
        y = pad_t + plot_h - (gy / mx) * plot_h
        parts.append(f'<line x1="{pad_l}" y1="{y:.1f}" x2="{width-8}" y2="{y:.1f}" stroke="{GRID}" stroke-width="1"/>')
        parts.append(f'<text x="{pad_l-6}" y="{y+4:.1f}" text-anchor="end" class="tick">{gy}</text>')
    for i, (d, c) in enumerate(data):
        x = pad_l + i * slot + (slot - bw) / 2
        h = (c / mx) * plot_h
        y = pad_t + plot_h - h
        label = d.strftime("%b %d")
        parts.append(
            f'<g class="bar" data-tip="{label}: {c} session{"s" if c != 1 else ""}">'
            f'<rect x="{x:.1f}" y="{pad_t}" width="{bw:.1f}" height="{plot_h}" fill="transparent"/>'
            + (f'<rect x="{x:.1f}" y="{y:.1f}" width="{bw:.1f}" height="{max(h,1):.1f}" rx="4" fill="{ORANGE}"/>'
               if c else "") + "</g>")
        if d.weekday() == 0 or i in (0, n - 1):
            parts.append(f'<text x="{x+bw/2:.1f}" y="{height-8}" text-anchor="middle" class="tick">{d.strftime("%m/%d")}</text>')
    parts.append("</svg>")
    return "".join(parts)


def hbar_chart_svg(counts, width=400):
    items = sorted(counts.items(), key=lambda kv: -kv[1])[:10]
    mx = max(c for _, c in items) or 1
    row_h, pad_l = 26, 118
    height = len(items) * row_h + 8
    plot_w = width - pad_l - 44
    parts = [f'<svg viewBox="0 0 {width} {height}" role="img" aria-label="Vault notes by folder">']
    for i, (name, c) in enumerate(items):
        y = 4 + i * row_h
        w = max(3, (c / mx) * plot_w)
        parts.append(
            f'<g class="bar" data-tip="{html.escape(name)}: {c} notes">'
            f'<text x="{pad_l-8}" y="{y+15}" text-anchor="end" class="lbl">{html.escape(name)}</text>'
            f'<rect x="{pad_l}" y="{y+3}" width="{w:.1f}" height="{row_h-9}" rx="4" fill="{ORANGE}"/>'
            f'<text x="{pad_l+w+7:.1f}" y="{y+15}" class="val">{c}</text></g>')
    parts.append("</svg>")
    return "".join(parts)


def build():
    now = datetime.datetime.now()
    today_iso = now.date().isoformat()
    notes = count_notes()
    total_notes = len(glob.glob(os.path.join(VAULT, "**", "*.md"), recursive=True))
    sess = sessions_by_day()
    sess_total = sum(c for _, c in sess)
    n_mem = len(glob.glob(os.path.join(MEMORY, "*.md")))
    n_rules = len(glob.glob(os.path.join(RULES, "*.md")))
    inbox = notes.get("00-inbox", 0)
    has_daily_today = os.path.exists(os.path.join(VAULT, "05-daily", f"{today_iso}.md"))

    wt_infos = [(name, git_info(path, expect)) for name, path, expect in WORKTREES]
    attn, chronic_total = attention_items(wt_infos, inbox, has_daily_today)
    activity = recent_activity()
    state = parse_last_state()

    # ---- tiles (ops-forward) -------------------------------------------------
    n_attn = len(attn)
    total_modified = sum(i["n_active"] for _, i in wt_infos)
    total_unpushed = sum(i["ahead"] for _, i in wt_infos)
    tiles = [
        ("Needs attention", n_attn, "items to triage below", ORANGE if n_attn else GREEN),
        ("Unpushed", total_unpushed, "commits not on origin", ORANGE if total_unpushed else INK),
        ("Uncommitted", total_modified, f"active · {chronic_total} chronic ignored", YELLOW if total_modified else INK),
        ("Sessions / 21d", sess_total, "Claude Code, bsb-resources", INK),
        ("Inbox", inbox, "00-inbox awaiting filing", YELLOW if inbox >= 25 else INK),
        ("Vault notes", total_notes, f"{n_rules} rules · {n_mem} memories", INK),
    ]
    tile_html = "".join(
        f'<div class="tile"><div class="tile-v" style="color:{col}">{v}</div>'
        f'<div class="tile-k">{k}</div><div class="tile-s">{s}</div></div>'
        for k, v, s, col in tiles)

    # ---- TODAY panel ---------------------------------------------------------
    if state:
        age = state["age_h"]
        age_txt = f"{age:.0f}h ago" if age >= 1 else f"{age*60:.0f}m ago"
        daily_link = f'05-daily/{today_iso}.md' if has_daily_today else None
        today_html = (
            f'<div class="stamp2">last wrap {html.escape(age_txt)} · {html.escape(state["title"])}</div>'
            + (f'<p class="lead"><span class="lbl2">Where you left off</span>{html.escape(state["doing"])}</p>' if state["doing"] else "")
            + (f'<p class="lead next"><span class="lbl2">Exact next step</span>{html.escape(state["next"])}</p>' if state["next"] else "")
            + (f'<p class="lead blk"><span class="lbl2">Blocked / waiting</span>{html.escape(state["blockers"])}</p>' if state["blockers"] else "")
        )
    else:
        today_html = '<p class="lead">No <code>last-state.md</code> yet. Run <b>/wrap</b> at the end of a session to capture where you left off.</p>'

    # ---- NEEDS ATTENTION panel ----------------------------------------------
    chronic_row = (f'<li class="attn s0"><span class="adot"></span>{chronic_total} chronic '
                   f'rule-sync / doc edits filtered out (run <b>/sync-rules</b> to clear)</li>'
                   if chronic_total else "")
    if attn:
        rows = "".join(
            f'<li class="attn s{sev}"><span class="adot"></span>{text}</li>' for sev, text in attn)
        attn_html = f'<ul class="attn-list">{rows}{chronic_row}</ul>'
    else:
        attn_html = ('<p class="clear">All clear - every worktree on-branch, pushed, and committed.</p>'
                     + (f'<ul class="attn-list">{chronic_row}</ul>' if chronic_row else ""))

    # ---- RECENT ACTIVITY feed ------------------------------------------------
    app_color = {"PD Engine": ORANGE, "Arm Farm": "#7aa2d6", "Barrelsville": GREEN, "Intangibles": YELLOW}
    act_rows = "".join(
        f'<li class="act"><span class="act-app" style="color:{app_color.get(name, INK2)}">{html.escape(name)}</span>'
        f'<span class="act-date">{html.escape(date)}</span>'
        f'<span class="act-subj">{html.escape(subj)}</span></li>'
        for _, name, date, subj in activity)
    act_html = f'<ul class="act-list">{act_rows}</ul>'

    # ---- worktrees table -----------------------------------------------------
    wt_rows = []
    for name, info in wt_infos:
        flag = "" if info["branch_ok"] else " ⚠"
        sev = "warn" if (info["ahead"] or info["n_active"] or not info["branch_ok"]) else "ok"
        dot = f'<span class="dot {sev}"></span>'
        dirty = []
        if info["n_active"]:
            dirty.append(f'{info["n_active"]}M')
        if info["ahead"]:
            dirty.append(f'↑{info["ahead"]}')
        if info["chronic"] or info["untracked"]:
            dirty.append(f'<span class="dim">{info["chronic"]}~ {info["untracked"]}?</span>')
        wt_rows.append(f"<tr><td>{dot}{name}{flag}</td><td class='mono'>{html.escape(info['branch'])}</td>"
                       f"<td>{info['date']}</td><td class='dim'>{html.escape(info['subj'])}</td>"
                       f"<td>{' '.join(dirty) or '—'}</td></tr>")
    wt_html = ("<table><thead><tr><th>App</th><th>Branch</th><th>Last commit</th>"
               "<th>Subject</th><th>State</th></tr></thead><tbody>"
               + "".join(wt_rows) + "</tbody></table>")

    # ---- command deck --------------------------------------------------------
    deck_html = ""
    for group, cmds in COMMAND_DECK:
        btns = "".join(
            f'<button class="cmd" data-cmd="{html.escape(c)}" title="{html.escape(d)}">'
            f'<span class="cmd-name">{html.escape(c)}</span>'
            f'<span class="cmd-desc">{html.escape(d)}</span></button>' for c, d in cmds)
        deck_html += f'<div class="deck-group"><h3>{group}</h3><div class="deck-btns">{btns}</div></div>'

    page = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>BSB Brain - Command Center</title>
<style>
  * {{ box-sizing: border-box; margin: 0; }}
  body {{ background:{SURFACE}; color:{INK}; font: 14px/1.5 "Segoe UI", system-ui, sans-serif; padding: 24px; }}
  header {{ display:flex; align-items:baseline; gap:14px; border-bottom: 2px solid {ORANGE}; padding-bottom: 12px; margin-bottom: 18px; }}
  h1 {{ font-size: 19px; letter-spacing: .18em; text-transform: uppercase; }}
  h1 b {{ color:{ORANGE}; }}
  header .stamp {{ color:{INK2}; font-size: 12px; margin-left:auto; text-align:right; }}
  h2 {{ font-size: 12px; letter-spacing:.14em; text-transform: uppercase; color:{INK2}; margin-bottom: 10px; }}
  h3 {{ font-size: 11px; letter-spacing:.1em; text-transform: uppercase; color:{ORANGE}; margin: 0 0 6px; }}
  .grid {{ display:grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom:16px; }}
  .panel {{ background:{PANEL}; border:1px solid {GRID}; border-radius:10px; padding:16px; }}
  .span2 {{ grid-column: 1 / -1; }}
  .tiles {{ display:grid; grid-template-columns: repeat(6, 1fr); gap: 12px; margin-bottom: 16px; }}
  .tile {{ background:{PANEL}; border:1px solid {GRID}; border-radius:10px; padding:14px 16px; }}
  .tile-v {{ font-size: 30px; font-weight: 650; }}
  .tile-k {{ font-size: 11.5px; letter-spacing:.08em; text-transform: uppercase; color:{ORANGE}; margin-top:2px; }}
  .tile-s {{ font-size: 11px; color:{INK2}; }}
  /* today */
  #today {{ border-left: 3px solid {ORANGE}; }}
  .stamp2 {{ color:{INK2}; font-size:11.5px; margin-bottom:8px; }}
  .lead {{ font-size:13.5px; margin:7px 0; }}
  .lbl2 {{ display:block; font-size:10.5px; letter-spacing:.1em; text-transform:uppercase; color:{INK2}; margin-bottom:1px; }}
  .lead.next {{ color:{INK}; }} .lead.next .lbl2 {{ color:{ORANGE}; }}
  .lead.next {{ background:#1d242c; border-radius:7px; padding:8px 11px; }}
  .lead.blk .lbl2 {{ color:{YELLOW}; }} .lead.blk {{ color:{INK2}; }}
  /* attention */
  .attn-list {{ list-style:none; display:flex; flex-direction:column; gap:7px; }}
  .attn {{ display:flex; align-items:flex-start; gap:9px; font-size:13px; }}
  .attn .adot {{ width:8px; height:8px; border-radius:50%; margin-top:5px; flex:0 0 auto; }}
  .attn.s2 .adot {{ background:{ORANGE}; }} .attn.s1 .adot {{ background:{YELLOW}; }} .attn.s0 .adot {{ background:{INK2}; }}
  .attn.s0 {{ color:{INK2}; }}
  .clear {{ color:{GREEN}; font-size:13px; }}
  /* activity */
  .act-list {{ list-style:none; display:flex; flex-direction:column; gap:5px; max-height:340px; overflow:auto; }}
  .act {{ display:grid; grid-template-columns: 92px 74px 1fr; gap:8px; align-items:baseline; font-size:12.5px; padding:2px 0; border-top:1px solid {GRID}; }}
  .act:first-child {{ border-top:0; }}
  .act-app {{ font-size:11px; font-weight:600; }}
  .act-date {{ color:{INK2}; font-family:Consolas,monospace; font-size:11px; }}
  .act-subj {{ color:{INK}; }}
  svg {{ width:100%; height:auto; display:block; }}
  .tick, .val, .lbl {{ font: 11px "Segoe UI", sans-serif; fill:{INK2}; }}
  .val {{ fill:{INK}; }}
  .bar rect {{ transition: opacity .12s; }}
  .bar:hover rect {{ opacity:.75; }}
  #tip {{ position:fixed; pointer-events:none; background:#000c; color:{INK}; padding:4px 9px;
         border:1px solid {GRID}; border-radius:6px; font-size:12px; display:none; z-index:9; }}
  table {{ width:100%; border-collapse: collapse; font-size: 13px; }}
  th {{ text-align:left; color:{INK2}; font-weight:500; font-size:11px; text-transform:uppercase;
       letter-spacing:.08em; padding: 4px 10px 8px 0; }}
  td {{ padding: 6px 10px 6px 0; border-top: 1px solid {GRID}; }}
  .mono {{ font-family: Consolas, monospace; font-size: 12px; color:{INK2}; }}
  .dim {{ color:{INK2}; }}
  .dot {{ display:inline-block; width:8px; height:8px; border-radius:50%; margin-right:8px; }}
  .dot.ok {{ background:{GREEN}; }} .dot.warn {{ background:{ORANGE}; }}
  .deck {{ display:grid; grid-template-columns: repeat(4, 1fr); gap:16px; }}
  .deck-btns {{ display:flex; flex-direction:column; gap:6px; }}
  .cmd {{ display:flex; flex-direction:column; text-align:left; background:{SURFACE}; color:{INK};
         border:1px solid {GRID}; border-radius:8px; padding:8px 11px; cursor:pointer; font:inherit; }}
  .cmd:hover {{ border-color:{ORANGE}; }}
  .cmd.copied {{ border-color:{GREEN}; }}
  .cmd-name {{ font-family: Consolas, monospace; font-size:13px; color:{ORANGE}; }}
  .cmd-desc {{ font-size:11.5px; color:{INK2}; }}
  footer {{ color:{INK2}; font-size:11.5px; margin-top:18px; }}
  code {{ font-family:Consolas,monospace; color:{INK}; background:#000a; padding:1px 5px; border-radius:4px; }}
  @media (max-width: 1100px) {{ .tiles {{ grid-template-columns:repeat(3,1fr); }} }}
  @media (max-width: 980px) {{ .grid, .deck {{ grid-template-columns:1fr; }} }}
</style></head><body>
<div id="tip"></div>
<header><h1>B.S.B. <b>BRAIN</b> - Command Center</h1>
<span class="stamp">generated {now:%a %b %d · %H:%M}<br>double-click <code>Command-Center.cmd</code> to refresh</span></header>

<div class="tiles">{tile_html}</div>

<div class="grid">
  <div class="panel span2" id="today"><h2>Today - where you left off</h2>{today_html}</div>
  <div class="panel"><h2>Needs attention{f' ({n_attn})' if n_attn else ''}</h2>{attn_html}</div>
  <div class="panel"><h2>Recent activity - all worktrees</h2>{act_html}</div>
</div>

<div class="grid">
  <div class="panel span2"><h2>Claude Code sessions - last 21 days (bsb-resources)</h2>{bar_chart_svg(sess)}</div>
  <div class="panel"><h2>Vault notes by folder - top 10</h2>{hbar_chart_svg(notes)}</div>
  <div class="panel"><h2>Worktrees - live deploy chain</h2>{wt_html}</div>
  <div class="panel span2"><h2>Command deck - click to copy, paste into Claude Code</h2>
    <div class="deck">{deck_html}</div></div>
</div>

<footer>Today reads <code>last-state.md</code> (run /wrap to update). Attention + activity read git across all 4 worktrees live.
Command deck copies the slash command to your clipboard. Data refreshes only on regenerate - double-click <code>Command-Center.cmd</code>.</footer>
<script>
  const tip = document.getElementById('tip');
  document.querySelectorAll('.bar').forEach(g => {{
    g.addEventListener('mousemove', e => {{
      tip.textContent = g.dataset.tip; tip.style.display = 'block';
      tip.style.left = (e.clientX + 14) + 'px'; tip.style.top = (e.clientY - 10) + 'px';
    }});
    g.addEventListener('mouseleave', () => tip.style.display = 'none');
  }});
  document.querySelectorAll('.cmd').forEach(b => b.addEventListener('click', async () => {{
    try {{ await navigator.clipboard.writeText(b.dataset.cmd); }} catch (e) {{
      const t = document.createElement('textarea'); t.value = b.dataset.cmd;
      document.body.appendChild(t); t.select(); document.execCommand('copy'); t.remove(); }}
    b.classList.add('copied'); setTimeout(() => b.classList.remove('copied'), 900);
  }}));
</script></body></html>"""
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(page)
    print(f"wrote {OUT}  ({n_attn} attention items, {len(activity)} activity rows)")


if __name__ == "__main__":
    build()
