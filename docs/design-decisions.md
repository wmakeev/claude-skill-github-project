# Design Decisions

Why the skill is built the way it is. Read this before making structural changes — most of these decisions have non-obvious tradeoffs, and the rationale is not visible in the code.

## Storage layout

### Bot config and private key live outside the repo

`~/.config/claude-github-bot/` holds the App's private key, `config.json` (App ID, installation ID, bot login), and `get_token.py`.

**Why not in the repo:** the private key is a secret. Even if the repo is private, the convention "secrets never touch git" is worth keeping unconditionally. The skill is also designed for a public repo (open-source).

**Why not in `.github/` of the repo:** the user finds `.github/` confusing because they read it as "GitHub system / CI files". They explicitly preferred the repo root for the per-project config file.

**Why one bot for all projects (not per-repo bots):** explicit user requirement. This means the bot config is a per-machine concern, not per-repo. `~/.config/claude-github-bot/` is the right scope.

### Per-project config in repo root, not `.github/`

`claude-project.json` lives at the repo root. Holds only `owner` + `project_number`. Everything else (project node ID, field IDs, option IDs) is resolved on-the-fly via GraphQL.

**Why root and not `.github/`:** see above — user preference.

**Why not cache field IDs locally:** stale-cache is one of the most common sources of "why is this broken" friction. GraphQL resolution adds 1–2 seconds per skill invocation, which is acceptable. No cache means no possibility of cache mismatch.

**Why JSON not YAML:** `jq` is already a dependency (used heavily in scripts); adding a YAML parser would be a second dependency for almost no benefit. The file is 2 fields long.

## Versioning

### No schema version in any config file

We considered a `schemaVersion` field in `claude-project.json` to detect "this repo was set up by an older skill version, needs upgrade". Rejected.

**Why:** the user's original ask included this, but on reflection we agreed the answer is "the diagnose script is the version check". Diagnose queries the live GitHub state and compares to the spec on every run. Drift is reported regardless of which skill version originally created the project. This is more robust than a stored version number, which can lie if someone edits the project via UI.

**When to revisit:** if the spec ever needs migrations that destroy data (e.g. renaming a field that has values pinned to it on existing items), a version marker would help decide whether to run a migration. For additive changes (new field, new option, new label), the current approach handles it cleanly.

## Specification

### Hard-coded spec, not a config file

`scripts/lib/project-spec.sh` hard-codes Impact/Effort options, Status order, and label set. Not a YAML/JSON config the user can edit per-project.

**Why:** explicit user choice. The user wants the same convention across all their projects. If a per-project deviation appears, the right move is to edit the spec for everyone, not fork it.

**When to revisit:** if multiple users adopt the skill and want different conventions, the spec needs to be promoted to a config file. The split would naturally be: a default spec in the skill, optionally overridden by `.claude-project-spec.sh` in the repo root.

### Direction field has no enforced options

The `Direction` field is created but its options are managed in the GitHub UI, not in the spec.

**Why:** directions are codebase-specific (Compiler / Docs / API for one project, Backend / Mobile / Infra for another). Hard-coding them in the shared spec is wrong; making the user maintain them in a per-project config file violates the "hard-coded spec" decision above. UI-managed is the natural escape hatch.

**Tradeoff:** diagnose can only check that the field exists, not that it has the right options. Not a real loss because there is no notion of "the right options".

### Status options are checked, not auto-fixed

Status is the field GitHub creates from the Board template. We verify it has `Backlog → Todo → In Progress → In Review → Done` and report drift, but never modify it.

**Why:** Status options have items pinned to them. Renaming an option (which is what most "fixes" would entail) breaks card placement on the board. The right place to manage Status is the GitHub UI, where the user can see the consequences.

### Custom field option drift is reported, not auto-fixed

Same reason as Status. If `Impact` exists but has only 3 options instead of 4, we report it but don't modify. The user resolves manually in the UI, then re-runs the script.

**This is the single most important safety property.** Auto-rewriting options would silently destroy values on existing items.

## Script design

### Diagnose-first, not setup-first

The skill's main entry point is `diagnose.sh`, not `setup-project.sh`. Diagnose is non-destructive and produces a structured report with `[PASS]`/`[WARN]`/`[FAIL]` lines and `[INFO] suggestion:` lines pointing to specific commands.

**Why:** the skill triggers in many situations beyond first-time setup (token failure, fresh clone, spec drift after manual UI changes). Diagnose tells Claude (or the user) which subset of setup actions are actually needed. Re-running setup unconditionally is wasteful and noisy.

### Confirmation before every modification

Every state-changing action calls `confirm()`. The default is "no" — explicit `y` is required. Bypass via `NONINTERACTIVE=1` for non-interactive environments (Claude Code's Bash tool, CI, scripts) — this is the official mechanism, not a test-only escape hatch.

`confirm()` also auto-detects the absence of a controlling terminal: if no TTY is available and `NONINTERACTIVE=1` is not set, it exits with a clear error naming the variable to set. This prevents silent hangs in headless environments.

**Why:** explicit user requirement. The user wants visibility into what the skill is about to do, with the option to abort. Non-interactive callers declare their intent explicitly.

### `gh project` subcommand is the minimum requirement (≥ 2.20)

All project operations use `gh project` subcommands (`gh project view`, `gh project field-list`, `gh project field-create`). The `gh api graphql` wrapper (`gql()`) has been removed.

**Why:** `gh project` is more readable and requires no manual GraphQL query construction. The user has the latest `gh` installed, making this the natural baseline.

**Tradeoff:** `gh project field-create --single-select-options` does not support per-option colors. Fields Impact/Effort are created with the correct option names but no colors. Colors can be assigned once in the GitHub UI after initial setup; subsequent idempotent runs do not touch them.

**Minimum version:** `gh` ≥ 2.20. `diagnose.sh` checks and fails fast if the installed version is too old.

## CLAUDE.md integration

### Workflow doc is a snippet between markers, not a separate file

The workflow section is inserted into the project's `CLAUDE.md` between `<!-- BEGIN github-project skill workflow -->` and `<!-- END ... -->`, not written to a separate file like `docs/github-workflow.md`.

**Why:** Claude Code reads `CLAUDE.md` automatically at session start. Putting the workflow rules there means every Claude session in the project has the rules in context without an extra read step. A separate file would require Claude to know to fetch it.

**Tradeoff:** mixing skill-managed content with user-written content in the same file requires marker-based replacement, which is fragile. Mitigated by checking for marker presence and asking before modifying.

## What is intentionally NOT in v1

These are not bugs or oversights — they were considered and deferred. See `roadmap.md` for the full list.

- No workflow execution side (branch creation, PR opening, decision capture)
- No automated CI status surfaced on Kanban cards (GitHub limitation)
- No Priority field — derived mentally from Impact + Effort
- No Milestone management
- No batch issue creation from a spec file
- No automated decisions extraction from PR comments
