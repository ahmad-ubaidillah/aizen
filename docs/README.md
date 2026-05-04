# Aizen Docs Index

Last updated: 2026-05-04

This directory is now organized into one master index plus a small number of purpose-specific documents.

Recommended reading order
1. done-vs-todo.md
   Fastest snapshot of what is confirmed done vs still outstanding.
2. roadmap-current.md
   Source of truth for current status, confirmed gaps, in-flight kanban work, and next phases.
3. governance.md
   Lightweight documentation governance and source-of-truth rules.
4. architecture-design.md
   Target architecture and long-term technical design.
5. research-report.md
   Ecosystem comparison and external references.
6. gap-analysis.md
   Strategic gap inventory with updated strategic vs operational framing.
7. pm-spec.md
   Detailed original MVP/phase implementation spec from the first planning pass.
8. task-list.md
   Historical task inventory derived from older gap analysis. Kept for reference only.
9. archive-strategy.md
   Current recommendation for how to handle historical docs.
10. design/credential-pool.md
   Deep-dive design doc for a specific feature area.

Document status
- done-vs-todo.md: CURRENT / fastest human snapshot of confirmed done vs remaining work
- roadmap-current.md: CURRENT / primary source of truth for roadmap-level docs; updated with current done-vs-not-yet-done operational findings
- governance.md: CURRENT / docs operating policy
- archive-strategy.md: CURRENT / handling of historical docs
- architecture-design.md: MOSTLY CURRENT for target architecture, not execution truth
- research-report.md: REFERENCE / strategic, with some overlap against architecture-design.md
- gap-analysis.md: PARTIALLY STALE strategic reference, reframed for strategic vs operational planning; some implementation statuses were corrected but it remains non-authoritative for live execution
- pm-spec.md: HISTORICAL / original MVP spec only
- task-list.md: HISTORICAL / not an execution tracker
- live-test-findings-2026-05-04.md: CURRENT REFERENCE / verified Ranus-compatible smoke-test findings and build/runtime issues
- design/credential-pool.md: FEATURE-SPECIFIC reference

Documentation strategy
- Keep one master index: README.md
- Keep one current execution roadmap: roadmap-current.md
- Keep one lightweight governance file: governance.md
- Keep one archive policy note: archive-strategy.md
- Keep specialized docs only when they serve a distinct purpose:
  - architecture/design
  - research/comparison
  - feature deep-dives
- Do not create multiple overlapping backlog files.
- Kanban is the live execution system; roadmap-current.md is the human-readable summary.

Overlap guidance
- architecture-design.md should own target-state architecture and concrete system design
- research-report.md should own ecosystem comparison, source-system strengths, and rationale for borrowing ideas
- avoid duplicating final architecture decisions in both places; if they overlap, architecture-design.md wins for the actual target design

Source-of-truth order
1. Running product behavior and tests
2. Accepted design docs in docs/design/
3. docs/roadmap-current.md
4. Feature/task-specific notes
5. Historical, archived, or superseded docs

If a doc conflicts with roadmap-current.md and live kanban findings, treat live behavior + kanban + roadmap-current.md as the current truth.
