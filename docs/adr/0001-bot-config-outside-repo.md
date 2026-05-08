# ADR-0001: Bot Config and Private Key Stored Per-Machine Outside the Repo

**Date:** 2026-05-07
**Status:** Accepted
**Supersedes:** —

## Context

The GitHub App requires a private key and a `config.json` (App ID, installation ID, bot login).
These files must be accessible to the `get_token.py` helper at runtime.

Two placement options were considered:

- Inside the repo (e.g. `.github/` or repo root) — easy to find, versioned.
- Outside the repo in a per-machine location (`~/.config/claude-github-bot/`) — standard secret-handling practice.

The skill is designed for use in public, open-source repositories.

## Decision

Bot config and the private key live in `~/.config/claude-github-bot/`, never inside any repository.

One bot is shared across all projects on a machine. Bot configuration is therefore a per-machine concern, not a per-repo one.

## Consequences

- The private key can never accidentally be committed, regardless of whether the repo is public or private.
- Setting up the bot on a new machine requires running `scripts/setup-bot.sh` (or manually placing the files) — it is not cloned automatically.
- `diagnose.sh` checks for the presence of these files and fails fast with a clear message when they are missing.
