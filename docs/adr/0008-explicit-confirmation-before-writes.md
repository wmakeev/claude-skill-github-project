# ADR-0008: Explicit Confirmation Before Every Write

**Date:** 2026-05-07
**Status:** Accepted
**Supersedes:** —

## Context

Scripts that modify GitHub state (create fields, add labels, update project config) could either run silently or prompt the user before each action. Silent execution is faster but removes visibility.

The skill is also called from non-interactive environments (Claude Code's Bash tool, CI pipelines) where a TTY may not be present.

## Decision

Every state-changing action calls `confirm()` before executing. The default answer is "no" — explicit `y` is required to proceed.

Non-interactive callers bypass confirmation by setting `NONINTERACTIVE=1`. This is the official mechanism, not a test-only escape hatch.

`confirm()` auto-detects the absence of a controlling terminal: if no TTY is available and `NONINTERACTIVE=1` is not set, it exits with a clear error naming the variable to set. This prevents silent hangs in headless environments.

## Consequences

- The user sees exactly what the script is about to do and can abort.
- Claude Code and CI pipelines work correctly by setting `NONINTERACTIVE=1` explicitly.
- Every new state-changing operation added to any script must go through `confirm()` — this is a non-negotiable invariant.
