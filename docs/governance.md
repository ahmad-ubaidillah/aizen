# Aizen Documentation Governance

Last updated: 2026-05-05
Status: CURRENT

## Purpose

This document defines how Aizen documentation is maintained, updated, and deprecated. It exists to prevent the docs folder from becoming a graveyard of stale planning documents that contradict each other.

---

## Source of Truth Hierarchy

When two documents conflict, the higher-ranking source wins:

1. **Running product behavior and tests** — code is the ultimate truth
2. **Accepted design docs in `docs/design/`** — feature-specific deep dives
3. **`docs/roadmap-current.md`** — current execution priorities and status
4. **Feature/task-specific notes** — kanban tasks, PR descriptions, commit messages
5. **Historical, archived, or superseded docs** — kept for reference only

---

## Document Lifecycle

### Creating a new doc

- Ask: "Does this deserve its own file, or can it live in `roadmap-current.md`?"
- If it's a feature deep-dive → `docs/design/<feature>.md`
- If it's a quick operational note → `roadmap-current.md` (append to relevant section)
- If it's a one-time analysis → consider a kanban task attachment instead

### Updating an existing doc

- Update the `Last updated:` header
- If the change is material, add a brief changelog entry at the bottom
- If the doc becomes stale, change its `Status:` to `PARTIALLY STALE` or `STALE`

### Deprecating a doc

1. Change `Status:` to `ARCHIVED` or `HISTORICAL`
2. Add a deprecation note at the top explaining why and what replaces it
3. Do NOT delete the file immediately — keep it for 30+ days so links don't break
4. After 30 days, move it to `docs/archive/` (create the directory if needed)

---

## Status Labels

Every doc MUST have a `Status:` field near the top:

| Label | Meaning |
|-------|---------|
| `CURRENT` | Actively maintained, reflects current reality |
| `MOSTLY CURRENT` | Core content is valid, some details may be stale |
| `PARTIALLY STALE` | Significant portions are outdated; use with caution |
| `STALE` | Do not use for execution decisions; kept for reference only |
| `HISTORICAL` | Preserved for context; not a source of truth |
| `ARCHIVED` | Moved to `docs/archive/`; no longer linked from index |

---

## Cross-Referencing Rules

- When mentioning another doc, use a relative Markdown link: `[roadmap-current.md](./roadmap-current.md)`
- When a doc is superseded, link forward: "Superseded by [roadmap-current.md](./roadmap-current.md)"
- When a doc supersedes another, link backward: "Supersedes [task-list.md](./task-list.md)"

---

## Commit Message Convention for Docs

Use the `docs:` prefix for documentation-only changes:

```
docs: update roadmap-current.md with provider-smoke findings
docs: mark gap-analysis.md as partially stale
docs: add credential-pool design document
```

For code changes that require doc updates, update the doc in the same PR/commit if possible.

---

## Review Checklist

Before merging a PR that changes docs:

- [ ] All `Last updated:` headers are current
- [ ] No broken internal links (`grep -r "\[.*\](.*)" docs/` and verify)
- [ ] Status labels are accurate
- [ ] `README.md` index is updated if files were added/removed/renamed
- [ ] No contradictions with `roadmap-current.md`

---

## Changelog

- **2026-05-05**: Created this governance document.
