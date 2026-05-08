# ADR-0000: Use Architecture Decision Records

**Date:** 2026-05-07
**Status:** Accepted

## Context

Architectural and significant design decisions made in isolation tend to get
forgotten. Without a record of *why* a choice was made, future sessions (human
or agent) either repeat the debate or silently reverse the decision.

This project uses Architecture Decision Records (ADR) to capture decisions that
are worth remembering across time and context windows.

## Decision

We adopt the ADR practice introduced by Michael Nygard. Each significant
decision gets its own Markdown file in `docs/adr/`.

**Rules for this project:**

- One file = one decision.
- File name: `NNNN-short-hyphenated-title.md` (zero-padded, autoincrement).
- Statuses: `Draft` → `Accepted` | `Deprecated` | `Superseded by ADR-NNNN`.
- **Architecturally significant decisions** (stack, domain invariants, module
  boundaries) are **append-only** — create a new ADR with `Superseded by`.
- **Tactical decisions** (library swap, minor config) may receive a dated
  `## Update YYYY-MM-DD` section instead of a new file. Use this **only for
  non-reversals** (clarifications, scope extensions). If the direction changes,
  write a new ADR.
- Do not delete ADRs. Mark them `Deprecated` or `Superseded`.
- The index lives in `docs/adr/README.md` — update it with every new ADR.

**Superseding an existing ADR:**

1. Create a new ADR with `Supersedes: ADR-NNNN` in the header.
2. In the old ADR, change `Status:` to `Superseded by ADR-MMMM` (link both ways).
3. Do not delete or rewrite the body of the old ADR — its history is the point.

**Write an ADR when:**
- You would argue about this decision 6 months from now.
- The decision is non-obvious or involves a real trade-off.
- A coding agent needs to know this constraint to avoid undoing it.

**Do NOT write an ADR for:**
- Library version bumps — use CHANGELOG.
- Obvious conventions already standard in the language/framework.
- Every PR — ADR inflation makes the log useless.

## Consequences

- Every significant decision is findable and linkable.
- Coding agents receive stable context that survives context-window compaction.
- New ADRs require updating `docs/adr/README.md`.
