# ADR-0007: Diagnose-First Entry Point

**Date:** 2026-05-07
**Status:** Accepted
**Supersedes:** —

## Context

The skill is invoked in multiple situations beyond first-time setup: token failure, fresh clone on a new machine, spec drift after manual UI changes, periodic health checks. A setup-first design would run all setup steps unconditionally on every invocation — wasteful and potentially noisy.

## Decision

The skill's primary entry point is `scripts/diagnose.sh`, not `scripts/setup-project.sh`.

`diagnose.sh` is read-only. It produces structured output with `[PASS]`/`[WARN]`/`[FAIL]` lines and `[INFO] suggestion:` hints pointing to the specific commands needed. Exit codes: 0 = clean, 1 = warnings, 2 = failures.

Setup scripts are invoked only when diagnose identifies a specific gap and the user confirms.

## Consequences

- Diagnose is safe to run at any time without side effects.
- Claude (or the user) receives a precise list of what is actually wrong, not a full setup replay.
- Every other script in the skill must stay consistent with what diagnose reports — if diagnose says something is broken, the corresponding setup command must fix exactly that.
