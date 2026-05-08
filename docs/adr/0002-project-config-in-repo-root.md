# ADR-0002: Per-Project Config File Lives in Repo Root, Not `.github/`

**Date:** 2026-05-07
**Status:** Accepted
**Supersedes:** —

## Context

The skill needs a small per-repo config file (`github-project.json`) that holds `owner` and `project_number`. Two placement candidates:

- `.github/github-project.json` — conventional location for GitHub-related tooling.
- Repo root `github-project.json` — immediately visible, flat.

The user finds `.github/` cognitively loaded as "GitHub system / CI files" and prefers the repo root for project-level tooling config.

## Decision

`github-project.json` lives at the repo root.

The file contains only `owner` and `project_number`. All other IDs (project node ID, field IDs, option IDs) are resolved on-the-fly via `gh project` and never stored locally.

JSON is used instead of YAML because `jq` is already a dependency and adding a YAML parser would be a second dependency for a two-field file.

## Consequences

- The file is immediately visible without navigating into `.github/`.
- No stale-cache problems: dynamic resolution adds ~1–2 seconds per invocation, which is acceptable.
- Any project that adopts this skill has `github-project.json` in its root — easy to detect in `diagnose.sh`.
