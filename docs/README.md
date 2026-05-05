# Aizen Docs Index

Last updated: 2026-05-05

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
   Ecosystem comparison and external references across broader AI agent systems.
6. ecosystem-comparison.md
   Zig ecosystem comparison focused on external capability borrowing, integration candidates, and phased strategy for Aizen.
7. gap-analysis.md
   Strategic gap inventory with updated strategic vs operational framing.
8. pm-spec.md
   Detailed original MVP/phase implementation spec from the first planning pass.
9. task-list.md
   Historical task inventory derived from older gap analysis. Kept for reference only.
10. archive-strategy.md
   Current recommendation for how to handle historical docs.
11. design/credential-pool.md
   Deep-dive design doc for a specific feature area.
12. external-capability-strategy.md
   Formal strategy document for evaluating, integrating, productizing, and sequencing external specialist capabilities.
13. external-capability-task-list.md
   Kanban-ready task list derived from the ecosystem comparison and external capability strategy.
14. external-capability-execution.md
   Completed outputs for executed planning tasks from the external capability board.

Document status
- done-vs-todo.md: CURRENT / fastest human snapshot of confirmed done vs remaining work
- roadmap-current.md: CURRENT / primary source of truth for roadmap-level docs; updated with current done-vs-not-yet-done operational findings
- governance.md: CURRENT / docs operating policy
- archive-strategy.md: CURRENT / handling of historical docs
- architecture-design.md: MOSTLY CURRENT for target architecture, not execution truth
- research-report.md: REFERENCE / broader strategic comparison across AI agent systems, with some overlap against architecture-design.md
- ecosystem-comparison.md: REFERENCE / Zig ecosystem comparison, integration candidates, and capability-borrowing rationale for Aizen
- external-capability-strategy.md: REFERENCE / formal strategic framing for adopting external specialist capabilities into Aizen
- external-capability-task-list.md: PLANNING REFERENCE / execution-ready task breakdown derived from the external capability analysis; not the live kanban itself
- external-capability-execution.md: CURRENT / completed outputs for executed external-capability planning tasks
- gap-analysis.md: PARTIALLY STALE strategic reference, reframed for strategic vs operational planning; some implementation statuses were corrected but it remains non-authoritative for live execution
- pm-spec.md: HISTORICAL / original MVP spec only
- task-list.md: HISTORICAL / not an execution tracker
- live-test-findings-2026-05-04.md: CURRENT REFERENCE / verified Ranus-compatible smoke-test findings and build/runtime issues
- design/credential-pool.md: FEATURE-SPECIFIC reference
- external-capability-flat-tasks.md: PLANNING REFERENCE / flattened one-by-one breakdown derived from the lane-based external capability board
- external-capability-kanban-import.md: PLANNING REFERENCE / field-oriented import draft for kanban or issue tracker ingestion

Documentation strategy
- Keep one master index: README.md
- Keep one current execution roadmap: roadmap-current.md
- Keep one lightweight governance file: governance.md
- Keep one archive policy note: archive-strategy.md
- Keep specialized docs only when they serve a distinct purpose:
  - architecture/design
  - research/comparison
  - feature deep-dives
  - external capability strategy
  - kanban-ready planning breakdowns
- Do not create multiple overlapping backlog files.
- Kanban is the live execution system; roadmap-current.md is the human-readable summary.

Overlap guidance
- architecture-design.md should own target-state architecture and concrete system design
- research-report.md should own broader ecosystem comparison, source-system strengths, and rationale for borrowing ideas across AI agent systems
- ecosystem-comparison.md should own Zig-focused external ecosystem scanning, capability classification, and repository-by-repository comparison for Aizen
- external-capability-strategy.md should own the formal decision framing for what Aizen should integrate, benchmark, emulate, or ignore from external specialist projects
- external-capability-task-list.md should own the execution-ready planning breakdown for future kanban translation
- avoid duplicating final architecture decisions in multiple places; if they overlap, architecture-design.md wins for the actual target design
- avoid treating reference planning docs as live execution truth; roadmap-current.md and live kanban remain authoritative for current work

Source-of-truth order
1. Running product behavior and tests
2. Accepted design docs in docs/design/
3. docs/roadmap-current.md
4. Feature/task-specific notes and active planning docs tied to current work
5. Reference strategy and ecosystem comparison docs
6. Historical, archived, or superseded docs

If a doc conflicts with roadmap-current.md and live kanban findings, treat live behavior + kanban + roadmap-current.md as the current truth.
