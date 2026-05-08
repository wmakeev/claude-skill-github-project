# Architecture Decision Records

This directory contains all ADRs for the project.
Read `0000-use-architecture-decision-records.md` for the process.

## Index

| # | Title | Status | Date |
|---|-------|--------|------|
| [0000](0000-use-architecture-decision-records.md) | Use Architecture Decision Records | Accepted | 2026-05-07 |
| [0001](0001-bot-config-outside-repo.md) | Bot Config and Private Key Stored Per-Machine Outside the Repo | Accepted | 2026-05-07 |
| [0002](0002-project-config-in-repo-root.md) | Per-Project Config File Lives in Repo Root, Not `.github/` | Accepted | 2026-05-07 |
| [0003](0003-no-schema-version-in-config.md) | No Schema Version in Config Files | Accepted | 2026-05-07 |
| [0004](0004-hardcoded-project-spec.md) | Project Spec Is Hard-Coded, Not Per-Project Configurable | Accepted | 2026-05-07 |
| [0005](0005-direction-field-ui-managed.md) | Direction Field Options Are UI-Managed, Not Spec-Enforced | Accepted | 2026-05-07 |
| [0006](0006-no-auto-fix-option-drift.md) | Field Option Drift Is Reported, Never Auto-Fixed | Accepted | 2026-05-07 |
| [0007](0007-diagnose-first-architecture.md) | Diagnose-First Entry Point | Accepted | 2026-05-07 |
| [0008](0008-explicit-confirmation-before-writes.md) | Explicit Confirmation Before Every Write | Accepted | 2026-05-07 |
| [0009](0009-gh-project-subcommands.md) | Use `gh project` Subcommands, Not Raw GraphQL | Accepted | 2026-05-07 |
| [0010](0010-workflow-doc-as-claude-md-snippet.md) | Workflow Doc Inserted as a Snippet into CLAUDE.md | Accepted | 2026-05-07 |

---

> **For coding agents:** Before planning any significant change, scan this index
> and read ADRs relevant to the affected area. Treat `Accepted` ADRs as
> constraints, not suggestions.
