# ADR-0005: Direction Field Options Are UI-Managed, Not Spec-Enforced

**Date:** 2026-05-07
**Status:** Accepted
**Supersedes:** —

## Context

The `Direction` field is created as part of the standard project setup, but its options vary by codebase (e.g. Compiler / Docs / API for one project; Backend / Mobile / Infra for another).

Two approaches were considered:

- Hard-code Direction options in `project-spec.sh` alongside Impact/Effort — consistent, but wrong values for most repos.
- Let each repo maintain them in a per-project config — introduces per-project config, which ADR-0004 explicitly rejects.

## Decision

The `Direction` field is created by the setup script (name and type only). Its options are managed entirely through the GitHub UI by the user.

`diagnose.sh` verifies that the field exists, but does not check its options — there is no notion of "the right options" for Direction.

## Consequences

- Setup is consistent: every project gets a `Direction` field.
- Option values are always meaningful for the specific codebase.
- The tradeoff is that diagnose cannot catch option drift for this field. This is acceptable because there is no shared spec to drift from.
