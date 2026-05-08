# ADR-0004: Project Spec Is Hard-Coded, Not Per-Project Configurable

**Date:** 2026-05-07
**Status:** Accepted
**Supersedes:** —

## Context

`scripts/lib/project-spec.sh` defines the desired project state: Impact/Effort option names and colors, Status column order, label set. An alternative would be a per-project config file (YAML or JSON) that each repo could override.

The user's explicit requirement: the same convention must apply across all their projects. Per-project divergence is not a design goal.

## Decision

The spec is hard-coded in `scripts/lib/project-spec.sh`. Both `setup-project.sh` and `diagnose.sh` source this file as the single source of truth. Per-project overrides are not supported.

When the convention changes, the spec is edited once and all projects pick it up on the next run.

## Consequences

- Zero ambiguity about what "correct state" means: one file, no per-repo variation.
- Adding support for multiple users with different conventions would require promoting the spec to a config file. The natural split: a default spec in the skill, optionally overridden by `.github-project-spec.sh` in the repo root.
- The `Direction` field is the deliberate exception — its options are codebase-specific and UI-managed (see ADR-0005).
