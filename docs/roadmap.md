# Roadmap

What v1 deliberately does not do, what's planned next, and known limitations. Use this as the starting point when picking up future work on the skill.

## v1 scope (current)

The v1 skill covers **setup and diagnosis only**:

- One-time bot installation on a machine
- Idempotent project configuration (custom fields, labels, issue template, CLAUDE.md snippet) for a repo
- Self-diagnostic across all layers
- Workflow rules documented in CLAUDE.md so the user (and Claude) know how to work with the project

It does **not** cover the workflow execution itself — opening branches, drafting PRs, capturing decisions. That is a separate skill (see below).

## Planned next: a separate `github-project-task` skill

The execution side of the workflow is a natural separate skill, not an extension of this one. Given an issue number, it would:

1. Move the card to **In Progress**
2. Create the branch with the convention `<type>/<num>-<short-desc>`
3. Pull the issue body and recent comments into context
4. After implementation, open a PR with `Closes #<num>` and a standard body
5. After merge, prompt the user to capture non-obvious decisions into `docs/design-decisions.md` (the project's own design-decisions file, not the skill's)
6. Move the card to **Done** and delete the branch

Why a separate skill: scope and trigger conditions are different. `github-project` triggers on configuration questions ("set up the board", "diagnose why X failed"). The execution skill triggers on per-task questions ("start working on #42", "open a PR for this branch").

Both skills should share the bot config and project pointer — that's exactly what `~/.config/claude-github-bot/config.json` and `claude-project.json` are for. They are skill-independent state.

## Known gaps in v1

### Status options drift cannot be auto-fixed

If someone renames or reorders Status columns in the GitHub UI, diagnose reports the drift but cannot repair it. Fix requires manual UI work. This is a deliberate safety choice (auto-rewrite would unpin cards) — see `design-decisions.md`.

### Custom field options drift cannot be auto-fixed

Same as above. If someone adds an `Impact` option called "Critical" via the UI, diagnose flags it as drift from the spec, but the script will not delete it. Resolution is manual.

### Direction options are unmanaged

The skill creates the field with a placeholder option (`(unset)`) and does not enforce its options afterward. The user manages directions in the UI. This is by design — directions are project-specific — but it means there's no way to replicate the same set of directions across projects automatically.

### `gh` version constraint

Scripts use `gh project` subcommands (migrated from `gh api graphql` in v1). This requires `gh` ≥ 2.20, which `diagnose.sh` checks on every run.

### No Windows support tested

Scripts are bash + Python 3. They likely work in WSL out of the box and break on native Windows (cmd/PowerShell). Not a priority because the user runs Linux.

### `setup-bot.sh` cannot create the GitHub App for the user

The App must exist on GitHub before the user runs `setup-bot.sh`. The script just collects existing App ID, installation ID, and key path. Creating an App via API requires a different auth flow (manifest flow) that's significantly more complex. Manual creation is a one-time per-machine cost — acceptable.

## Improvement ideas (not committed)

These came up during design discussion. Each has a tradeoff that prevented inclusion in v1.

### Per-project spec override

Allow `.claude-project-spec.sh` in the repo root to override the hard-coded spec. Cost: complexity in the diff/merge logic. Benefit: per-project customization. **Trigger to add:** if any single project starts wanting different fields/options than the hard-coded set.

### Priority field

Add explicit `Priority` (High/Medium/Low) instead of deriving mentally from Impact + Effort. Cost: another field, another option set. Benefit: directly actionable column-sort. **Trigger to add:** if user finds themselves manually sorting by priority and wishes the board did it.

### Milestone integration

Tie issues to release milestones via GitHub Milestones. Cost: another API surface. Benefit: native GitHub release planning. **Trigger to add:** when a project starts targeting versioned releases.

### Batch issue creation from a spec file

Define a YAML/JSON file with planned issues; one command creates them all with correct labels, fields, hierarchy. Cost: parser, idempotency for issue creation (track which issues correspond to which spec entries). Benefit: rapid bootstrap of a new project's backlog. **Trigger to add:** when starting a project with a known set of 10+ issues at once becomes a recurring pattern.

### Automated decisions extraction

Post-merge hook scans PR comments for a `[decision]` marker and drafts entries for `docs/design-decisions.md`. Cost: GitHub Action or scheduled script, parsing logic, format conventions. Benefit: closes the loop on capturing rationale that currently relies on manual discipline. **Trigger to add:** after `github-project-task` skill exists and the manual capture step proves to be skipped consistently.

### Plugin marketplace packaging

Distribute via Claude Code's `/plugin` system instead of git clone. Cost: marketplace manifest, possibly multi-skill bundling. Benefit: native install/update UX. **Trigger to add:** when there are 3+ related skills the user wants installed together. See `distribution.md` for current distribution choice.

## Open questions

These were not resolved during initial design and may need answers before substantial future work.

### How to handle skill version evolution when the spec changes

If `project-spec.sh` adds a new label (e.g. `security`), `setup-project.sh` will create it on the next run — fine. But if it renames an existing field, the diagnose will report drift forever and the user has to manually fix it. There is no migration mechanism. The current answer is "additive changes only", but at some point a non-additive change will be wanted.

### Multi-bot scenarios

The current scheme assumes one bot per machine, used by every project. If the user ever needs different bots for different projects (e.g. an org-owned bot for work projects and a personal bot for personal projects), the layout breaks. The fix would be to put `bot_login` (or a per-project bot pointer) into `claude-project.json` and let `~/.config/claude-github-bot/` hold multiple configs keyed by login.

### Project number changes

If the user deletes and recreates a project, `claude-project.json` points at the old number. Diagnose will say "project not accessible". The fix is to edit `claude-project.json` manually. Could be automated by detecting the failure and offering to re-prompt for the project number, but it's rare enough that the manual fix is fine.

## Test coverage

There is none. v1 was built and shipped without automated tests because:

- Most operations are non-idempotent at the GitHub side (creating a label twice fails); a real test environment requires a sandbox repo and a sandbox project, which adds setup overhead
- The user is the only consumer for now and provides immediate feedback
- Bash + GraphQL is awkward to test in isolation

When adding the `github-project-task` skill, this is worth revisiting — that skill will branch, commit, push, and merge, where mistakes have higher cost.
