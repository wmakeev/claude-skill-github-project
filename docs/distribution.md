# Distribution

How the skill is distributed and installed. v1 uses the simplest mechanism that works; later options are documented for when the situation changes.

## Current choice: git clone, optionally via symlink

Claude Code discovers skills in two locations:

- `~/.claude/skills/<name>/SKILL.md` — personal, available across all projects
- `<project>/.claude/skills/<name>/SKILL.md` — project-scoped, committed to the repo

This skill is intended for personal scope (the user's own machines), so the install target is `~/.claude/skills/github-project/`.

### Repo layout

`SKILL.md` lives at the repo root, not inside a subdirectory. This means `git clone <url> ~/.claude/skills/github-project` produces a directly usable structure with no manual reorganisation.

```
claude-skill-github-project/   ← repo root
├── SKILL.md                    ← discovered by Claude Code
├── scripts/
├── templates/
├── docs/                       ← these files
├── README.md                   ← for human visitors on GitHub
├── LICENSE                     ← MIT
└── .gitignore
```

### Install on the development machine (symlink)

```bash
# clone wherever the user keeps their projects
cd ~/Documents/_MVV/
git clone https://github.com/<user>/claude-skill-github-project
ln -s ~/Documents/_MVV/claude-skill-github-project ~/.claude/skills/github-project
```

The symlink means edits to the skill source are immediately visible to Claude Code — no separate "deploy" step. `git push` from the working copy is the publication step.

### Install on a consumer machine (direct clone)

```bash
git clone https://github.com/<user>/claude-skill-github-project ~/.claude/skills/github-project
```

Update later: `cd ~/.claude/skills/github-project && git pull`.

### Live detection

Claude Code watches for changes in skill directories. New files and edits are picked up within the current session. Creating the top-level `~/.claude/skills/` directory for the very first time requires restarting Claude Code so it can start watching that path.

## Why not npm

We considered shipping the skill as an npm package with a `postinstall` script that copies/symlinks files into `~/.claude/skills/`. Rejected for v1.

**Reasons:**

- The skill is bash + Python with no JavaScript runtime. npm is the wrong package manager for that content.
- The user would need a `package.json`, `version` bumps, publish flow, and a `postinstall` script that handles cross-platform paths. All of that infrastructure exists to replace `git clone`, which already works.
- Updates via `npm update -g` are not meaningfully better than `git pull` for a single user on their own machines.

**When to revisit:** if the skill becomes part of a multi-skill toolkit that already uses npm for other reasons. Standalone, npm is overhead.

## Why not a Claude Code plugin marketplace (yet)

Claude Code has a `/plugin` system with marketplaces. A custom marketplace is a git repo with a specific manifest structure, registered via `/plugin marketplace add <url>`. After that, `/plugin` lists the skills inside it for one-click install.

This is the most polished distribution mechanism, but it adds a layer (the marketplace manifest) that's only worth it when there are multiple skills to bundle together.

**When to revisit:** when the user has 3+ related skills (e.g. `github-project`, `github-project-task`, plus one more) and wants a single install path for all of them.

## Repo metadata

Three files belong in the repo alongside the skill but are not part of the skill content itself:

### `README.md`

Audience: a human landing on the GitHub repo page. Should answer:

- What this is (a Claude Code skill for setting up a GitHub Project workflow)
- What it does (one-paragraph summary of components)
- Prerequisites (gh, jq, python3, git, optional pip packages)
- Install (`git clone <url> ~/.claude/skills/github-project`)
- First use (in Claude Code, ask "diagnose the github project setup" or similar)
- Link to `docs/design-decisions.md` for the curious

The skill's own `SKILL.md` is for Claude — it doesn't need to be a great human onboarding doc. The README is the human onboarding doc.

### `LICENSE`

MIT. The simplest permissive license, the most expected default for personal open-source. Without a license file, the repo is technically not open-source — by default all rights are reserved.

### `.gitignore`

Modest:

```
*.tmp
*.log
.DS_Store
```

The skill itself produces no build artifacts. Only protect against editor noise and OS clutter.

## Public vs private

The repo is public (open-source). This means:

- The bot config and private key MUST stay outside the repo (already enforced by storing them in `~/.config/claude-github-bot/`).
- `claude-project.json` in the user's own project repos contains only `owner` + `project_number`, which are public information anyway. Safe to commit.
- The skill scripts assume the user runs them. They do not exfiltrate data, but a future contributor could add something that does. Standard open-source caveat — mention in README that the user should review skill code before installing.

## Cross-machine workflow

The expected steady state:

```
Machine A (development)
├── ~/Documents/_MVV/claude-skill-github-project/  ← git working copy
└── ~/.claude/skills/github-project                ← symlink to above

Machine B (laptop, etc.)
└── ~/.claude/skills/github-project                ← direct git clone
```

When the skill is updated:

1. Edit on Machine A, commit, push.
2. On Machine B, `git pull` inside `~/.claude/skills/github-project`.
3. Bot config (`~/.config/claude-github-bot/`) is per-machine and not synced. If it doesn't exist on Machine B, the user runs `scripts/setup-bot.sh` once.
4. Project pointer (`claude-project.json`) is in each user-project repo and travels with `git clone` of that project.

## Update discipline

- `SKILL.md` and `scripts/` are loaded on every relevant Claude session, so updates take effect immediately after `git pull`.
- The `templates/CLAUDE.md.snippet` is copied into project repos by `setup-project.sh`. After updating it in the skill, individual projects need `setup-project.sh` re-run to pick up the new snippet (the script will diff and ask). There is no auto-propagation.
- `scripts/lib/project-spec.sh` is read by `diagnose.sh` and `setup-project.sh` on each run. Spec changes are picked up automatically.
