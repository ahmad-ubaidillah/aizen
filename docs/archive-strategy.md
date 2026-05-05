# Aizen Documentation Archive Strategy

Last updated: 2026-05-05
Status: CURRENT

## Purpose

This document defines when and how Aizen documentation is archived. Without a clear strategy, the `docs/` folder accumulates stale planning documents that contradict each other and confuse contributors.

---

## Archive Criteria

A document SHOULD be archived when ANY of the following is true:

1. **Superseded** — another document now serves the same purpose better (e.g., `roadmap-current.md` replaces `task-list.md` as the execution tracker)
2. **Stale for 60+ days** — `Last updated:` header is more than 60 days old AND the content no longer reflects reality
3. **Historical only** — the document captures a one-time analysis or decision that will not change (e.g., initial ecosystem comparison)
4. **Contradicts current source of truth** — the document conflicts with `roadmap-current.md` or live kanban findings, and updating it is not worth the effort

A document SHOULD NOT be archived if:

- It is still referenced from `README.md` or `roadmap-current.md`
- It describes a long-term target architecture that has not changed (e.g., `architecture-design.md`)
- It is a feature-specific design doc for an in-flight feature

---

## Archive Process

### Step 1: Mark as stale (immediate)

Change the document's `Status:` to `STALE` or `HISTORICAL` and add a note at the top:

```markdown
> **Note:** This document is preserved for historical context. For current execution priorities, see [roadmap-current.md](./roadmap-current.md).
```

### Step 2: Update index (immediate)

In `README.md`, move the doc to a "Historical / Archived" section and strikethrough or remove its entry from the recommended reading order.

### Step 3: Move to `docs/archive/` (after 30 days)

```bash
mkdir -p docs/archive
git mv docs/<stale-doc>.md docs/archive/
```

Update any remaining internal links that pointed to the old location.

### Step 4: Delete (after 90 days in archive)

If the archived document has not been referenced or consulted in 90 days, it can be permanently deleted. This is a manual decision — do not auto-delete.

---

## Current Archive Candidates

| Document | Current status | Reason | Proposed action | Timeline |
|----------|----------------|--------|-----------------|----------|
| `task-list.md` | HISTORICAL | Superseded by `roadmap-current.md` and live kanban | Keep linked as historical reference; archive later if no longer useful | Earliest 2026-06-05 |
| `pm-spec.md` | HISTORICAL | Phase 1 MVP spec is complete; current work is in later phases | Keep linked as historical reference; archive later if no longer useful | Earliest 2026-06-05 |

---

## Archive Directory Structure

```
docs/
├── README.md
├── roadmap-current.md
├── governance.md
├── archive/
│   ├── 2026-05-task-list.md
│   ├── 2026-05-pm-spec.md
│   └── ...
├── design/
│   └── credential-pool.md
└── ...
```

When moving a file to `archive/`, prefix it with the archive date: `YYYY-MM-<original-name>.md`. This makes sorting obvious.

---

## Recovery

If an archived document is needed again:

1. Check `docs/archive/` for the file
2. If it was deleted, check git history: `git log --all -- docs/archive/<file>.md`
3. Restore with `git show <commit>:docs/archive/<file>.md > docs/<file>.md`
4. Update `Status:` to `CURRENT` or `MOSTLY CURRENT`
5. Update `README.md` index

---

## Changelog

- **2026-05-05**: Created this archive strategy document. Identified `task-list.md` and `pm-spec.md` as first archive candidates.
