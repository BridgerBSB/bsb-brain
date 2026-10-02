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
# Futuristic HUD palette (Oct 2 2026 restyle): near-black navy, neon green primary,
# cyan secondary, orange kept for the high-severity alarm only.
SURFACE, PANEL, INK, INK2, GRID = "#070b12", "#0c121c", "#d7e3ea", "#6f8293", "#16222f"
NEON, NEON_DIM, CYAN = "#22f59a", "#0f7a4f", "#3fd0ff"
YELLOW, GREEN, RED = "#f2c94c", "#22f59a", "#ff5c5c"


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


def session_streak(daily):
    """Consecutive days with >=1 session, counting back from today (today may be 0
    if the day just started - then the streak runs from yesterday)."""
    counts = [c for _, c in daily]
    if counts and counts[-1] == 0:
        counts = counts[:-1]
    n = 0
    for c in reversed(counts):
        if not c:
            break
        n += 1
    return n


def area_chart_svg(data, width=900, height=300):
    """Cumulative sessions area chart - neon line, glow, gradient fill."""
    if not data:
        return ""
    cum, run = [], 0
    for d, c in data:
        run += c
        cum.append((d, run))
    mx = max(run, 1)
    pad_l, pad_r, pad_b, pad_t = 46, 12, 28, 14
    plot_w, plot_h = width - pad_l - pad_r, height - pad_b - pad_t
    n = len(cum)

    def xy(i, v):
        return pad_l + (i / max(n - 1, 1)) * plot_w, pad_t + plot_h - (v / mx) * plot_h

    pts = [xy(i, v) for i, (_, v) in enumerate(cum)]
    line = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    base = pad_t + plot_h
    area = f"M{pts[0][0]:.1f},{base} L" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + f" L{pts[-1][0]:.1f},{base} Z"
    parts = [f'<svg viewBox="0 0 {width} {height}" role="img" aria-label="Cumulative Claude Code sessions, last {n} days">'
             '<defs><linearGradient id="ag" x1="0" y1="0" x2="0" y2="1">'
             f'<stop offset="0" stop-color="{NEON}" stop-opacity=".38"/>'
             f'<stop offset="1" stop-color="{NEON}" stop-opacity="0"/></linearGradient>'
             '<filter id="glow" x="-20%" y="-20%" width="140%" height="140%">'
             '<feGaussianBlur stdDeviation="3" result="b"/><feMerge><feMergeNode in="b"/>'
             '<feMergeNode in="SourceGraphic"/></feMerge></filter></defs>']
    for k in range(5):
        v = mx * k / 4
        y = pad_t + plot_h - (k / 4) * plot_h
        parts.append(f'<line x1="{pad_l}" y1="{y:.1f}" x2="{width-pad_r}" y2="{y:.1f}" stroke="{GRID}" stroke-dasharray="2 4"/>')
        parts.append(f'<text x="{pad_l-8}" y="{y+4:.1f}" text-anchor="end" class="tick">{v:,.0f}</text>')
    parts.append(f'<path d="{area}" fill="url(#ag)"/>')
    parts.append(f'<polyline points="{line}" fill="none" stroke="{NEON}" stroke-width="2.2" filter="url(#glow)"/>')
    step = max(1, n // 8)
    for i, (d, v) in enumerate(cum):
        x, y = pts[i]
        if (i % step == 0 and n - 1 - i >= step * .6) or i == n - 1:
            parts.append(f'<text x="{x:.1f}" y="{height-8}" text-anchor="middle" class="tick">{d.strftime("%b %d")}</text>')
        day_c = data[i][1]
        parts.append(f'<g class="bar" data-tip="{d.strftime("%b %d")}: {day_c} today, {v} total">'
                     f'<rect x="{x - plot_w/n/2:.1f}" y="{pad_t}" width="{plot_w/n:.1f}" height="{plot_h}" fill="transparent"/></g>')
    lx, ly = pts[-1]
    parts.append(f'<circle cx="{lx:.1f}" cy="{ly:.1f}" r="4" fill="{NEON}" filter="url(#glow)"/>')
    parts.append("</svg>")
    return "".join(parts)


def neon_bars(rows, unit=""):
    """HTML horizontal neon bars: rows = [(label, value)]. Width scales to max."""
    if not rows:
        return ""
    mx = max(v for _, v in rows) or 1
    out = []
    for label, v in rows:
        out.append(f'<div class="nb" data-tip="{html.escape(str(label))}: {v}{unit}">'
                   f'<span class="nb-l">{html.escape(str(label))}</span>'
                   f'<span class="nb-v">{v}</span>'
                   f'<span class="nb-track"><span class="nb-fill" style="width:{max(2, v / mx * 100):.1f}%"></span></span></div>')
    return "".join(out)


def build():
    now = datetime.datetime.now()
    today_iso = now.date().isoformat()
    notes = count_notes()
    total_notes = len(glob.glob(os.path.join(VAULT, "**", "*.md"), recursive=True))
    sess90 = sessions_by_day(90)
    # Old transcripts get rotated out, so leading zero days mean 'no data', not
    # 'no sessions'. Start the cumulative chart at the first day with data.
    first = next((i for i, (_, c) in enumerate(sess90) if c), 0)
    chart_days = sess90[min(first, len(sess90) - 21):]
    sess = sess90[-21:]
    sess_total = sum(c for _, c in sess)
    sess90_total = sum(c for _, c in sess90)
    streak = session_streak(sess90)
    n_mem = len(glob.glob(os.path.join(MEMORY, "*.md")))
    n_rules = len(glob.glob(os.path.join(RULES, "*.md")))
    inbox = notes.get("00-inbox", 0)
    has_daily_today = os.path.exists(os.path.join(VAULT, "05-daily", f"{today_iso}.md"))

    wt_infos = [(name, git_info(path, expect)) for name, path, expect in WORKTREES]
    attn, chronic_total = attention_items(wt_infos, inbox, has_daily_today)
    activity = recent_activity()
    state = parse_last_state()

    n_attn = len(attn)
    total_modified = sum(i["n_active"] for _, i in wt_infos)
    total_unpushed = sum(i["ahead"] for _, i in wt_infos)

    # ---- terminal stat strip -------------------------------------------------
    def stat(k, v, warn=False):
        return f'<span class="st"><span class="st-k">{k}:</span> <span class="st-v{" warn" if warn else ""}">[{v}]</span></span>'
    strip_html = (f'<span class="st-main">$ BSB: <b>{total_notes:,}</b></span>'
                  + stat("Attention", n_attn, n_attn > 0)
                  + stat("Unpushed", total_unpushed, total_unpushed > 0)
                  + stat("Uncommitted", total_modified, total_modified > 0)
                  + stat("Sessions", f"{sess_total} / 21d")
                  + stat("Inbox", inbox, inbox >= 25)
                  + stat("Rules", n_rules)
                  + stat("Memories", n_mem))

    # ---- TODAY ---------------------------------------------------------------
    if state:
        age = state["age_h"]
        age_txt = f"{age:.0f}h ago" if age >= 1 else f"{age*60:.0f}m ago"
        today_html = (
            f'<div class="stamp2">last wrap {html.escape(age_txt)}</div>'
            f'<div class="today-title">{html.escape(state["title"])}</div>'
            + (f'<div class="tcard"><span class="lbl2">Where you left off</span>{html.escape(state["doing"])}</div>' if state["doing"] else "")
            + (f'<div class="tcard next"><span class="lbl2">Exact next step</span>{html.escape(state["next"])}</div>' if state["next"] else "")
            + (f'<div class="tcard blk"><span class="lbl2">Blocked / waiting</span>{html.escape(state["blockers"])}</div>' if state["blockers"] else "")
        )
    else:
        today_html = '<div class="tcard">No <code>last-state.md</code> yet. Run <b>/wrap</b> at the end of a session.</div>'

    # ---- NEEDS ATTENTION -----------------------------------------------------
    sev_tag = {2: ("ALERT", "s2"), 1: ("WARN", "s1"), 0: ("INFO", "s0")}
    rows = "".join(
        f'<li class="attn {sev_tag[sev][1]}"><span class="adot"></span><span class="attn-t">{text}</span>'
        f'<span class="pill {sev_tag[sev][1]}">{sev_tag[sev][0]}</span></li>' for sev, text in attn)
    chronic_row = (f'<li class="attn s0"><span class="adot"></span><span class="attn-t">{chronic_total} chronic '
                   f'rule-sync / doc edits filtered (<b>/sync-rules</b> clears)</span><span class="pill s0">MUTED</span></li>'
                   if chronic_total else "")
    attn_html = (f'<ul class="attn-list">{rows}{chronic_row}</ul>' if attn else
                 '<p class="clear">&gt; all clear. every worktree on-branch, pushed, committed.</p>'
                 + (f'<ul class="attn-list">{chronic_row}</ul>' if chronic_row else ""))

    # ---- RECENT ACTIVITY -----------------------------------------------------
    app_color = {"PD Engine": ORANGE, "Arm Farm": CYAN, "Barrelsville": NEON, "Intangibles": YELLOW}
    act_html = '<ul class="act-list">' + "".join(
        f'<li class="act"><span class="act-app" style="color:{app_color.get(name, INK2)}">{html.escape(name)}</span>'
        f'<span class="act-date">{html.escape(date)}</span>'
        f'<span class="act-subj">{html.escape(subj)}</span></li>'
        for _, name, date, subj in activity) + "</ul>"

    # ---- vault + throughput bars ---------------------------------------------
    vault_html = neon_bars(sorted(notes.items(), key=lambda kv: -kv[1])[:10], " notes")
    thru_html = neon_bars([(d.strftime("%a %m/%d"), c) for d, c in reversed(sess[-10:])], " sessions")

    # ---- worktrees: right-rail status pills + bottom table -------------------
    wt_pills, healthy = [], 0
    for name, info in wt_infos:
        if not info["branch_ok"]:
            st, cls = "OFF-BRANCH", "s2"
        elif info["ahead"]:
            st, cls = f"UNPUSHED {info['ahead']}", "s2"
        elif info["n_active"]:
            st, cls = f"DIRTY {info['n_active']}", "s1"
        elif info["behind"]:
            st, cls = f"BEHIND {info['behind']}", "s1"
        else:
            st, cls = "CLEAN", "ok"
            healthy += 1
        wt_pills.append(f'<div class="wf {cls}"><span class="wf-ic">&#9670;</span>'
                        f'<span class="wf-n">{html.escape(name)}<span class="wf-b">{html.escape(info["branch"])}</span></span>'
                        f'<span class="pill {cls}">{st}</span></div>')
    health_pct = healthy / len(wt_infos) * 100 if wt_infos else 0

    wt_rows = []
    for name, info in wt_infos:
        dirty = []
        if info["n_active"]:
            dirty.append(f'{info["n_active"]}M')
        if info["ahead"]:
            dirty.append(f'&uarr;{info["ahead"]}')
        if info["chronic"] or info["untracked"]:
            dirty.append(f'<span class="dim">{info["chronic"]}~ {info["untracked"]}?</span>')
        wt_rows.append(f"<tr><td>{html.escape(name)}</td><td>{info['date']}</td>"
                       f"<td class='dim'>{html.escape(info['subj'])}</td><td class='mono'>{' '.join(dirty) or '-'}</td></tr>")
    wt_html = ("<table><thead><tr><th>App</th><th>Last</th><th>Subject</th><th>State</th></tr></thead><tbody>"
               + "".join(wt_rows) + "</tbody></table>")

    # ---- command deck (left rail, searchable) + quick-launch grid (right) ----
    deck_html = ""
    for group, cmds in COMMAND_DECK:
        btns = "".join(
            f'<button class="cmd" data-cmd="{html.escape(c)}" data-q="{html.escape((c + " " + d + " " + group).lower())}">'
            f'<span class="cmd-name">{html.escape(c)}</span>'
            f'<span class="cmd-desc">{html.escape(d)}</span></button>' for c, d in cmds)
        deck_html += f'<div class="deck-group"><div class="deck-h">{html.escape(group)}</div>{btns}</div>'
    n_cmds = sum(len(c) for _, c in COMMAND_DECK)
    quick = COMMAND_DECK[0][1] + COMMAND_DECK[2][1][:3] + COMMAND_DECK[3][1][:3]
    quick_html = "".join(
        f'<button class="qk cmd" data-cmd="{html.escape(c)}" title="{html.escape(c)}: {html.escape(d)}">'
        f'<span class="qk-g">{html.escape(''.join(w[0] for w in c[1:].split('-'))[:2].upper() if '-' in c else c[1:3].upper())}</span><span class="qk-n">{html.escape(c)}</span></button>'
        for c, d in quick)

    page = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>BSB Command Center</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  :root {{ --bg:{SURFACE}; --panel:{PANEL}; --ink:{INK}; --ink2:{INK2}; --grid:{GRID};
           --neon:{NEON}; --neon-dim:{NEON_DIM}; --cyan:{CYAN}; --org:{ORANGE}; --yel:{YELLOW};
           --mono:"JetBrains Mono", Consolas, monospace; }}
  * {{ box-sizing:border-box; margin:0; }}
  html, body {{ background:var(--bg); }}
  body {{ color:var(--ink); font:13px/1.5 Inter, "Segoe UI", system-ui, sans-serif; padding:14px; min-height:100vh;
          background:
            radial-gradient(1200px 600px at 70% -10%, rgba(34,245,154,.07), transparent 60%),
            radial-gradient(900px 500px at -10% 110%, rgba(63,208,255,.06), transparent 60%),
            linear-gradient(rgba(255,255,255,.018) 1px, transparent 1px) 0 0 / 100% 3px,
            var(--bg); }}
  .shell {{ display:grid; grid-template-columns:300px minmax(0,1fr) 300px; gap:12px; max-width:1800px; margin:0 auto; }}
  .rail, .main {{ display:flex; flex-direction:column; gap:12px; min-width:0; }}
  .panel {{ min-width:0; background:linear-gradient(180deg, rgba(255,255,255,.015), transparent 40%), var(--panel);
            border:1px solid var(--grid); border-radius:10px; padding:14px; position:relative; }}
  .panel.glow {{ border-color:rgba(34,245,154,.28); box-shadow:0 0 0 1px rgba(34,245,154,.06), 0 0 28px -10px rgba(34,245,154,.35); }}
  h2 {{ font:700 11px var(--mono); letter-spacing:.16em; text-transform:uppercase; color:var(--neon); margin-bottom:10px;
        display:flex; align-items:center; gap:8px; }}
  h2 .sub {{ color:var(--ink2); font-weight:400; letter-spacing:.06em; margin-left:auto; text-transform:none; }}
  .mono {{ font-family:var(--mono); font-size:11.5px; color:var(--ink2); }}
  .dim {{ color:var(--ink2); }}
  code {{ font-family:var(--mono); color:var(--neon); background:#000a; padding:1px 5px; border-radius:4px; }}

  /* brand */
  .brand {{ display:flex; align-items:center; gap:10px; }}
  .logo {{ width:34px; height:34px; border-radius:8px; display:grid; place-items:center; font:700 13px var(--mono);
           color:var(--bg); background:var(--neon); box-shadow:0 0 18px rgba(34,245,154,.55); }}
  .brand-t {{ font:700 14px var(--mono); letter-spacing:.2em; }}
  .brand-t b {{ color:var(--neon); }}
  .brand-s {{ font:11px var(--mono); color:var(--ink2); }}

  /* today */
  .stamp2 {{ font:11px var(--mono); color:var(--ink2); }}
  .today-title {{ font-weight:600; margin:2px 0 10px; }}
  .tcard {{ overflow-wrap:anywhere; background:#060a10; border:1px solid var(--grid); border-radius:8px; padding:9px 11px; margin-top:8px; font-size:12.5px; }}
  .tcard.next {{ border-color:rgba(34,245,154,.45); box-shadow:inset 3px 0 0 var(--neon); }}
  .tcard.blk {{ color:var(--ink2); box-shadow:inset 3px 0 0 var(--yel); }}
  .lbl2 {{ display:block; font:600 10px var(--mono); letter-spacing:.12em; text-transform:uppercase; color:var(--ink2); margin-bottom:3px; }}
  .tcard.next .lbl2 {{ color:var(--neon); }} .tcard.blk .lbl2 {{ color:var(--yel); }}

  /* command deck */
  .search {{ width:100%; background:#060a10; border:1px solid var(--grid); border-radius:8px; color:var(--ink);
             padding:8px 10px; font:12px var(--mono); outline:none; margin-bottom:10px; }}
  .search:focus {{ border-color:var(--neon); box-shadow:0 0 12px -4px var(--neon); }}
  .deck {{ display:flex; flex-direction:column; gap:10px; max-height:calc(100vh - 470px); min-height:260px; overflow:auto; padding-right:4px; }}
  .deck-h {{ font:600 10px var(--mono); letter-spacing:.14em; text-transform:uppercase; color:var(--cyan); margin:2px 0 5px; }}
  .cmd {{ display:flex; flex-direction:column; width:100%; text-align:left; background:#060a10; color:var(--ink);
          border:1px solid var(--grid); border-radius:8px; padding:7px 10px; margin-bottom:5px; cursor:pointer; font:inherit;
          transition:border-color .15s, box-shadow .15s; }}
  .cmd:hover {{ border-color:var(--neon); box-shadow:0 0 14px -6px var(--neon); }}
  .cmd.copied {{ border-color:var(--neon); background:rgba(34,245,154,.1); }}
  .cmd-name {{ font:600 12.5px var(--mono); color:var(--neon); }}
  .cmd-desc {{ font-size:11px; color:var(--ink2); }}

  /* chart header */
  .chart-h {{ display:flex; align-items:center; gap:10px; margin-bottom:6px; flex-wrap:wrap; }}
  .chart-h .t {{ font:700 12px var(--mono); color:var(--neon); letter-spacing:.06em; }}
  .badge {{ font:600 11px var(--mono); color:var(--yel); border:1px solid rgba(242,201,76,.5); border-radius:6px; padding:2px 8px; }}
  .chip {{ font:600 11px var(--mono); border:1px solid var(--grid); color:var(--ink2); border-radius:6px; padding:3px 9px; }}
  .chip.on {{ color:var(--bg); background:var(--neon); border-color:var(--neon); box-shadow:0 0 14px -2px rgba(34,245,154,.6); }}
  .chart-h .r {{ margin-left:auto; display:flex; gap:8px; }}
  svg {{ width:100%; height:auto; display:block; }}
  .tick {{ font:10.5px var(--mono); fill:var(--ink2); }}

  /* terminal strip */
  .strip {{ display:flex; flex-wrap:wrap; gap:8px 20px; align-items:center; padding:11px 14px; font:12px var(--mono); }}
  .st-main {{ color:var(--neon); border:1px solid rgba(34,245,154,.45); border-radius:6px; padding:3px 9px; }}
  .st-main b {{ color:var(--ink); }}
  .st-k {{ color:var(--ink2); }}
  .st-v {{ color:var(--neon); }}
  .st-v.warn {{ color:var(--org); }}

  .row3 {{ display:grid; grid-template-columns:repeat(3, minmax(0,1fr)); gap:12px; }}
  .row2 {{ display:grid; grid-template-columns:minmax(0,1fr) minmax(0,1.4fr); gap:12px; }}

  /* pills */
  .pill {{ font:700 9.5px var(--mono); letter-spacing:.08em; border-radius:4px; padding:2px 7px; white-space:nowrap;
           border:1px solid currentColor; }}
  .pill.ok {{ color:var(--neon); background:rgba(34,245,154,.08); }}
  .pill.s2 {{ color:var(--org); background:rgba(235,110,31,.1); }}
  .pill.s1 {{ color:var(--yel); background:rgba(242,201,76,.08); }}
  .pill.s0 {{ color:var(--ink2); }}

  /* attention */
  .attn-list {{ list-style:none; padding:0; display:flex; flex-direction:column; gap:7px; max-height:300px; overflow:auto; }}
  .attn {{ display:flex; align-items:flex-start; gap:8px; font-size:12px; }}
  .attn-t {{ flex:1; min-width:0; overflow-wrap:anywhere; }}
  .adot {{ width:7px; height:7px; border-radius:50%; margin-top:5px; flex:0 0 auto; }}
  .attn.s2 .adot {{ background:var(--org); box-shadow:0 0 8px var(--org); }}
  .attn.s1 .adot {{ background:var(--yel); box-shadow:0 0 8px var(--yel); }}
  .attn.s0 .adot {{ background:var(--ink2); }} .attn.s0 {{ color:var(--ink2); }}
  .clear {{ color:var(--neon); font:12px var(--mono); }}

  /* activity */
  .act-list {{ list-style:none; padding:0; display:flex; flex-direction:column; max-height:300px; overflow:auto; }}
  .act {{ display:grid; grid-template-columns:84px 1fr; column-gap:8px; font-size:12px; padding:5px 0; border-top:1px solid var(--grid); }}
  .act:first-child {{ border-top:0; }}
  .act-app {{ font:700 10.5px var(--mono); }}
  .act-date {{ font:10.5px var(--mono); color:var(--ink2); text-align:right; }}
  .act-subj {{ grid-column:1 / -1; color:var(--ink); overflow-wrap:anywhere; }}

  /* neon bars */
  .nb {{ display:grid; grid-template-columns:96px 34px 1fr; align-items:center; gap:8px; font:11px var(--mono); padding:3px 0; }}
  .nb-l {{ color:var(--ink2); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }}
  .nb-v {{ color:var(--ink); text-align:right; }}
  .nb-track {{ height:12px; background:#060a10; border-radius:3px; overflow:hidden; }}
  .nb-fill {{ display:block; height:100%; background:linear-gradient(90deg, var(--neon-dim), var(--neon));
              box-shadow:0 0 10px rgba(34,245,154,.5); border-radius:3px; }}

  /* table */
  table {{ width:100%; border-collapse:collapse; font-size:12px; }}
  th {{ text-align:left; font:600 10px var(--mono); letter-spacing:.12em; text-transform:uppercase; color:var(--ink2); padding:2px 10px 8px 0; }}
  td {{ padding:6px 10px 6px 0; border-top:1px solid var(--grid); vertical-align:top; }}

  /* right rail: worktree pills, health, quick launch */
  .wf {{ display:flex; align-items:center; gap:9px; background:#060a10; border:1px solid rgba(63,208,255,.28);
         border-radius:7px; padding:8px 10px; margin-bottom:7px; }}
  .wf.ok {{ border-color:rgba(34,245,154,.35); }} .wf.s2 {{ border-color:rgba(235,110,31,.45); }} .wf.s1 {{ border-color:rgba(242,201,76,.35); }}
  .wf-ic {{ color:var(--cyan); font-size:11px; }}
  .wf-n {{ flex:1; min-width:0; font-weight:600; font-size:12.5px; display:flex; flex-direction:column; }}
  .wf-b {{ font:10.5px var(--mono); color:var(--ink2); font-weight:400; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }}
  .health {{ height:8px; border-radius:4px; background:#060a10; overflow:hidden; margin:4px 0 6px; }}
  .health span {{ display:block; height:100%; width:{health_pct:.0f}%; background:linear-gradient(90deg, var(--yel), var(--neon));
                  box-shadow:0 0 12px rgba(34,245,154,.5); }}
  .health-l {{ display:flex; justify-content:space-between; font:10px var(--mono); color:var(--ink2); }}
  .health-s {{ font:600 12px var(--mono); color:{NEON if healthy == len(wt_infos) else YELLOW}; margin-top:8px; }}
  .qgrid {{ display:grid; grid-template-columns:repeat(4, 1fr); gap:8px; }}
  .qk {{ aspect-ratio:1; align-items:center; justify-content:center; padding:4px; margin:0; border-color:rgba(34,245,154,.5);
         box-shadow:inset 0 0 14px -6px var(--neon); }}
  .qk-g {{ font:700 15px var(--mono); color:var(--neon); text-shadow:0 0 10px rgba(34,245,154,.7); }}
  .qk-n {{ font:9px var(--mono); color:var(--ink2); margin-top:2px; }}
  footer {{ font:11px var(--mono); color:var(--ink2); padding:2px 4px; }}

  #tip {{ position:fixed; pointer-events:none; background:#000d; color:var(--ink); padding:4px 9px; font:11px var(--mono);
          border:1px solid var(--neon); border-radius:6px; display:none; z-index:9; box-shadow:0 0 14px -4px var(--neon); }}
  ::-webkit-scrollbar {{ width:6px; }} ::-webkit-scrollbar-thumb {{ background:var(--grid); border-radius:3px; }}

  @media (max-width:1400px) {{ .shell {{ grid-template-columns:270px minmax(0,1fr); }} .rail.right {{ grid-column:1 / -1; display:grid; grid-template-columns:repeat(3,1fr); }} }}
  @media (max-width:1100px) {{ .row3 {{ grid-template-columns:1fr; }} .row2 {{ grid-template-columns:1fr; }} }}
  @media (max-width:820px) {{ body {{ padding:16px; }} .shell {{ grid-template-columns:1fr; }} .rail.right {{ display:flex; }} .deck {{ max-height:none; }} }}
</style></head><body>
<div id="tip"></div>
<div class="shell">

  <aside class="rail">
    <div class="panel glow"><div class="brand"><div class="logo">BSB</div>
      <div><div class="brand-t">BSB <b>BRAIN</b></div><div class="brand-s">command center &middot; {now:%a %b %d %H:%M}</div></div></div></div>
    <div class="panel"><h2>/ Today</h2>{today_html}</div>
    <div class="panel"><h2>/ Command deck <span class="sub">{n_cmds}</span></h2>
      <input class="search" id="q" placeholder="search commands..." autocomplete="off">
      <div class="deck" id="deck">{deck_html}</div></div>
  </aside>

  <main class="main">
    <div class="panel glow">
      <div class="chart-h"><span class="t">Claude Code Sessions</span>
        <span class="badge">{streak} day streak</span>
        <span class="r"><span class="chip">Last {len(chart_days)} days</span><span class="chip on">Cumulative &middot; {sess90_total}</span></span></div>
      {area_chart_svg(chart_days)}
    </div>
    <div class="panel strip">{strip_html}</div>
    <div class="row3">
      <div class="panel"><h2>Needs attention <span class="sub">{n_attn}</span></h2>{attn_html}</div>
      <div class="panel"><h2>Recent activity <span class="sub">all worktrees</span></h2>{act_html}</div>
      <div class="panel"><h2>Vault map <span class="sub">notes / folder</span></h2>{vault_html}</div>
    </div>
    <div class="row2">
      <div class="panel"><h2>Session throughput <span class="sub">last 10 days</span></h2>{thru_html}</div>
      <div class="panel"><h2>Worktree log</h2>{wt_html}</div>
    </div>
    <footer>&gt; reads last-state.md + git across 4 worktrees at generate time. refresh: double-click Command-Center.cmd</footer>
  </main>

  <aside class="rail right">
    <div class="panel"><h2>Active worktrees</h2>{"".join(wt_pills)}</div>
    <div class="panel"><h2>Deploy chain health</h2>
      <div class="health"><span></span></div>
      <div class="health-l"><span>degraded</span><span>healthy</span></div>
      <div class="health-s">{healthy}/{len(wt_infos)} worktrees clean</div></div>
    <div class="panel"><h2>Quick launch</h2><div class="qgrid">{quick_html}</div></div>
  </aside>
</div>
<script>
  const tip = document.getElementById('tip');
  document.querySelectorAll('.bar, .nb').forEach(g => {{
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
  const q = document.getElementById('q');
  q.addEventListener('input', () => {{
    const s = q.value.trim().toLowerCase();
    document.querySelectorAll('#deck .deck-group').forEach(g => {{
      let any = false;
      g.querySelectorAll('.cmd').forEach(b => {{ const hit = !s || b.dataset.q.includes(s); b.style.display = hit ? '' : 'none'; any = any || hit; }});
      g.style.display = any ? '' : 'none';
    }});
  }});
</script></body></html>"""
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(page)
    print(f"wrote {OUT}  ({n_attn} attention items, {len(activity)} activity rows, streak {streak})")


if __name__ == "__main__":
    build()
