# ADR-0003: No Schema Version in Config Files

**Date:** 2026-05-07
**Status:** Accepted
**Supersedes:** —

## Context

A `schemaVersion` field in `github-project.json` was considered to detect "this repo was set up by an older skill version and may need migration". The idea was that on each run the skill could compare the stored version against the current spec and prompt for upgrades.

The counter-argument: `diagnose.sh` already queries the live GitHub state and compares it against the spec on every run. It reports drift regardless of which skill version originally created the project.

## Decision

No schema version is stored in any config file.

`diagnose.sh` is the version check. It compares live GitHub project state to the current spec and surfaces all drift unconditionally.

## Consequences

- No possibility of a stored version number lying (e.g. after manual UI edits that `schemaVersion` would not reflect).
- Diagnose is more robust than a version marker for the common case (additive spec changes, option additions, label additions).
- **Revisit if** the spec ever needs a destructive migration — e.g. renaming a field that has values pinned to existing items. In that case a version marker would help decide whether to run the migration. For all additive changes the current approach is sufficient.
