# Aizen External Capability Flat Task Breakdown

Status: PLANNING REFERENCE
Last updated: 2026-05-05
Primary purpose: flatten the highest-priority lanes from the external capability board into board-ready tasks that can be moved one-by-one into kanban.

Scope of this document:
- Lane A — Foundation and Decision Framework
- Lane B — Code Intelligence
- Lane C — Browser Efficiency and Browser Abstraction
- Lane D — Git Ergonomics for Agents
- Lane E — Protocol Interoperability

Use `docs/external-capability-task-list.md` for the lane-based board view.
Use `docs/external-capability-kanban-import.md` for field-oriented import records.
Use this file when you want individual tasks in a flat execution list.

Authority note:
- This document is a flattened planning companion to `external-capability-task-list.md`, not a live execution tracker.
- Use it when translating lane-based strategy into one-by-one task sequencing or import preparation.
- If this file conflicts with `roadmap-current.md`, active kanban state, or the lane-based board, those sources win.

---

## 1. Usage Rules

- Execute tasks strictly by priority lane order: A -> B -> C -> D -> E
- Execute tasks FIFO within each lane
- Do not skip dependencies
- Do not start implementation tasks before the prerequisite audit/design task is done
- Do not promote any spike into product work without benchmark evidence

Status vocabulary for future board import:
- TODO
- READY
- BLOCKED
- IN PROGRESS
- DONE
- DEFERRED

---

## 2. Flat Task List

### Task EC-A-1
Lane: A — Foundation and Decision Framework
Status: READY
Priority: P0
Type: docs/planning
Depends on: none
Title: Create the canonical external capability inventory
Objective:
Produce one normalized inventory of all reviewed external repositories.
Acceptance criteria:
- every repository from `ecosystem-comparison.md` is classified
- each row includes category, overlap, strategic value, difficulty, maintenance risk, license notes, and recommended action
- top-tier candidates are clearly separated from low-priority references
Promotion rule:
- required before any serious spike work begins

### Task EC-A-2
Lane: A — Foundation and Decision Framework
Status: READY
Priority: P0
Type: docs/planning
Depends on: EC-A-1
Title: Define decision labels and classification rules
Objective:
Standardize the meaning of decision labels used for external projects.
Acceptance criteria:
- `integrate now`, `benchmark only`, `native inspiration`, `component reference`, and `ignore for now` all have stable definitions
- future project reviews can reuse the definitions without reinterpretation
Promotion rule:
- required before adding new repositories to the inventory

### Task EC-A-3
Lane: A — Foundation and Decision Framework
Status: READY
Priority: P0
Type: design/planning
Depends on: EC-A-1
Title: Define benchmark scenarios for code, browser, git, and protocol evaluation
Objective:
Create repeatable scenarios tied to real Aizen workflows.
Acceptance criteria:
- code-task scenario exists
- browser-task scenario exists
- git-heavy scenario exists
- interoperability/protocol scenario exists
- each scenario has measurable outputs
Promotion rule:
- required before any benchmark task in lanes B-E

### Task EC-A-4
Lane: A — Foundation and Decision Framework
Status: READY
Priority: P0
Type: design/planning
Depends on: EC-A-2, EC-A-3
Title: Define success metrics for external capability adoption
Objective:
Require measurable evidence for adoption decisions.
Acceptance criteria:
- metrics include latency, token usage, reliability, operator clarity, architectural fit, and implementation complexity
- all later spike lanes reference the shared metrics
Promotion rule:
- required before any adopt/adapt/defer recommendation is considered valid

### Task EC-B-1
Lane: B — Code Intelligence
Status: TODO
Priority: P1
Type: research/audit
Depends on: EC-A-4
Title: Audit codedb features against Aizen coding workflow pain points
Objective:
Map codedb capabilities to actual coding-agent gaps in Aizen.
Acceptance criteria:
- must-have vs nice-to-have codedb features are separated
- overlaps and missing capabilities are documented
- Aizen pain points are explicit, not implied

### Task EC-B-2
Lane: B — Code Intelligence
Status: TODO
Priority: P1
Type: design
Depends on: EC-B-1
Title: Define the Aizen code-intelligence backend interface
Objective:
Create an Aizen-owned abstraction for external or future-native code intelligence.
Acceptance criteria:
- interface responsibilities are explicit
- interface does not overfit codedb internals
- future native implementation remains possible

### Task EC-B-3
Lane: B — Code Intelligence
Status: TODO
Priority: P1
Type: spike/implementation
Depends on: EC-B-2
Title: Build a codedb integration spike
Objective:
Create a runnable evaluation path using codedb on real repository tasks.
Acceptance criteria:
- codedb-backed evaluation path exists
- baseline vs codedb-assisted workflows can be compared
- setup is documented well enough to rerun
Benchmark required: yes

### Task EC-B-4
Lane: B — Code Intelligence
Status: TODO
Priority: P1
Type: benchmark
Depends on: EC-B-3
Title: Benchmark codedb on representative large-repo tasks
Objective:
Measure repository understanding, context retrieval quality, token cost, and latency.
Acceptance criteria:
- benchmark results are documented
- strengths and weaknesses are explicit
- recommendation is explicit: adopt, adapt, or defer
Benchmark required: yes

### Task EC-B-5
Lane: B — Code Intelligence
Status: TODO
Priority: P2
Type: productization-planning
Depends on: EC-B-4
Title: Draft the Aizen Code Graph proposal
Objective:
Translate evaluation findings into a native Aizen code-intelligence direction.
Acceptance criteria:
- scope, staging, and interface boundaries are documented
- proposal is resilient to backend changes
Promotion rule:
- only valid if EC-B-4 recommends further investment

### Task EC-C-1
Lane: C — Browser Efficiency and Browser Abstraction
Status: TODO
Priority: P1
Type: audit
Depends on: EC-A-4
Title: Audit current browser workflow limitations in Aizen
Objective:
Document token cost, determinism, extraction quality, and workflow friction in the current browser path.
Acceptance criteria:
- baseline limitations are concrete
- current-state benchmark baseline exists

### Task EC-C-2
Lane: C — Browser Efficiency and Browser Abstraction
Status: TODO
Priority: P1
Type: design
Depends on: EC-C-1
Title: Define the Aizen browser backend abstraction
Objective:
Create a backend interface that can support the current browser path, kuri-backed workflows, and future native backends.
Acceptance criteria:
- snapshot, navigation, extraction, and interaction responsibilities are explicit
- multiple backend implementations are possible

### Task EC-C-3
Lane: C — Browser Efficiency and Browser Abstraction
Status: TODO
Priority: P1
Type: spike/implementation
Depends on: EC-C-2
Title: Build a kuri integration spike
Objective:
Evaluate kuri as the first serious browser upgrade path for Aizen.
Acceptance criteria:
- kuri-backed workflows are runnable
- baseline vs kuri-assisted comparison is possible
- setup is documented for reruns
Benchmark required: yes

### Task EC-C-4
Lane: C — Browser Efficiency and Browser Abstraction
Status: TODO
Priority: P1
Type: benchmark
Depends on: EC-C-3
Title: Benchmark kuri on browsing and crawling scenarios
Objective:
Measure token savings, latency, reliability, and extraction quality.
Acceptance criteria:
- benchmark results are documented
- recommendation is explicit
Benchmark required: yes

### Task EC-C-5
Lane: C — Browser Efficiency and Browser Abstraction
Status: TODO
Priority: P2
Type: productization-planning
Depends on: EC-C-4
Title: Draft the browser productization roadmap
Objective:
Separate short-term browser workflow improvements from long-term native backend strategy.
Acceptance criteria:
- kuri role is clear
- lightpanda role is clear
- staged browser direction is documented

### Task EC-D-1
Lane: D — Git Ergonomics for Agents
Status: TODO
Priority: P1
Type: audit
Depends on: EC-A-4
Title: Audit current git pain points in Aizen coding loops
Objective:
Document where standard git output creates noise, friction, or parsing problems.
Acceptance criteria:
- high-noise workflows are listed
- priority git operations are explicit

### Task EC-D-2
Lane: D — Git Ergonomics for Agents
Status: TODO
Priority: P1
Type: design
Depends on: EC-D-1
Title: Define the Aizen structured git interface
Objective:
Create an Aizen-owned abstraction for concise and machine-friendly git output.
Acceptance criteria:
- concise human-readable mode is covered
- structured machine-readable mode is covered
- interface is not tightly coupled to zagi internals

### Task EC-D-3
Lane: D — Git Ergonomics for Agents
Status: TODO
Priority: P1
Type: spike/implementation
Depends on: EC-D-2
Title: Build a zagi evaluation wrapper
Objective:
Enable direct evaluation of zagi-assisted git workflows.
Acceptance criteria:
- comparison path is runnable
- baseline vs zagi-assisted output can be compared fairly
Benchmark required: yes

### Task EC-D-4
Lane: D — Git Ergonomics for Agents
Status: TODO
Priority: P1
Type: benchmark
Depends on: EC-D-3
Title: Benchmark structured git workflows on real coding tasks
Objective:
Measure token savings and downstream workflow quality.
Acceptance criteria:
- results are documented for status, diff, branch, and worktree-heavy scenarios
- recommendation is explicit
Benchmark required: yes

### Task EC-D-5
Lane: D — Git Ergonomics for Agents
Status: TODO
Priority: P2
Type: productization-planning
Depends on: EC-D-4
Title: Draft the Aizen Git Engine proposal
Objective:
Define how Aizen should own concise, structured, and guardrailed git behavior long-term.
Acceptance criteria:
- scope, output modes, and safety posture are documented

### Task EC-E-1
Lane: E — Protocol Interoperability
Status: TODO
Priority: P1
Type: protocol-audit
Depends on: EC-A-4
Title: Audit ACP scope and maturity relative to Aizen needs
Objective:
Determine what level of ACP support makes sense for Aizen first.
Acceptance criteria:
- expected transport surface is clear
- likely interoperability targets are documented

### Task EC-E-2
Lane: E — Protocol Interoperability
Status: TODO
Priority: P1
Type: design
Depends on: EC-E-1
Title: Define Aizen protocol/interoperability interface requirements
Objective:
Clarify how ACP fits relative to Aizen’s current transport and protocol concepts.
Acceptance criteria:
- scope boundaries are explicit
- protocol layering is documented

### Task EC-E-3
Lane: E — Protocol Interoperability
Status: TODO
Priority: P1
Type: spike/implementation
Depends on: EC-E-2
Title: Build an ACP design spike using acp-sdk-zig
Objective:
Validate the feasibility of minimal ACP support.
Acceptance criteria:
- spike outcome is concrete
- risks and blockers are documented
Benchmark required: yes

### Task EC-E-4
Lane: E — Protocol Interoperability
Status: TODO
Priority: P2
Type: planning
Depends on: EC-E-3
Title: Write a staged ACP adoption plan
Objective:
Sequence ACP adoption from minimal interoperability to fuller support if justified.
Acceptance criteria:
- rollout stages are documented
- scope creep is controlled

---

## 3. Ordering Summary

Global order:
- EC-A-1
- EC-A-2
- EC-A-3
- EC-A-4
- EC-B-1
- EC-B-2
- EC-B-3
- EC-B-4
- EC-B-5
- EC-C-1
- EC-C-2
- EC-C-3
- EC-C-4
- EC-C-5
- EC-D-1
- EC-D-2
- EC-D-3
- EC-D-4
- EC-D-5
- EC-E-1
- EC-E-2
- EC-E-3
- EC-E-4

---

## 4. Intended Next Step

This file is meant to be the bridge between the lane-based board and the real kanban system.

Intended flow:
`external-capability-task-list.md` -> `external-capability-flat-tasks.md` -> import-ready kanban format
