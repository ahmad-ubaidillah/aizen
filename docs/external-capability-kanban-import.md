# Aizen External Capability Kanban Import Draft

Status: PLANNING REFERENCE
Last updated: 2026-05-05
Primary purpose: provide an import-ready, field-oriented task draft derived from the external capability board.

Use `docs/external-capability-task-list.md` for the lane-based planning board.
Use `docs/external-capability-flat-tasks.md` for the flat one-by-one task view.
This file is designed to be easy to copy into Aizen Kanban, GitHub issues, or another structured task system.

Authority note:
- This document is an import draft, not a source of truth for execution status.
- Use it when a board, issue tracker, or external system needs field-oriented records.
- If this file conflicts with `external-capability-task-list.md`, `roadmap-current.md`, or active kanban state, those sources win.

Recommended field set:
- id
- title
- lane
- priority
- status
- type
- dependency_ids
- benchmark_required
- owner
- summary
- acceptance_criteria
- promotion_decision

---

## Import Records

### Record 1
id: EC-A-1
title: Create the canonical external capability inventory
lane: Foundation and Decision Framework
priority: P0
status: READY
type: docs/planning
dependency_ids: []
benchmark_required: no
owner: unassigned
summary: Produce one normalized inventory of all reviewed external repositories.
acceptance_criteria:
- every repository from ecosystem-comparison.md is classified
- each row includes category, overlap, strategic value, difficulty, maintenance risk, license notes, and recommended action
- top-tier candidates are clearly separated from low-priority references
promotion_decision: required before serious spike work begins

### Record 2
id: EC-A-2
title: Define decision labels and classification rules
lane: Foundation and Decision Framework
priority: P0
status: READY
type: docs/planning
dependency_ids: [EC-A-1]
benchmark_required: no
owner: unassigned
summary: Standardize the meaning of decision labels used for external projects.
acceptance_criteria:
- integrate now, benchmark only, native inspiration, component reference, and ignore for now all have stable definitions
- future project reviews can reuse the definitions without reinterpretation
promotion_decision: required before adding new repositories to the inventory

### Record 3
id: EC-A-3
title: Define benchmark scenarios for code, browser, git, and protocol evaluation
lane: Foundation and Decision Framework
priority: P0
status: READY
type: design/planning
dependency_ids: [EC-A-1]
benchmark_required: no
owner: unassigned
summary: Create repeatable scenarios tied to real Aizen workflows.
acceptance_criteria:
- code-task scenario exists
- browser-task scenario exists
- git-heavy scenario exists
- interoperability/protocol scenario exists
- each scenario has measurable outputs
promotion_decision: required before benchmark tasks in lanes B-E

### Record 4
id: EC-A-4
title: Define success metrics for external capability adoption
lane: Foundation and Decision Framework
priority: P0
status: READY
type: design/planning
dependency_ids: [EC-A-2, EC-A-3]
benchmark_required: no
owner: unassigned
summary: Require measurable evidence for adoption decisions.
acceptance_criteria:
- metrics include latency, token usage, reliability, operator clarity, architectural fit, and implementation complexity
- later spike lanes reference the shared metrics
promotion_decision: required before adopt/adapt/defer recommendations are considered valid

### Record 5
id: EC-B-1
title: Audit codedb features against Aizen coding workflow pain points
lane: Code Intelligence
priority: P1
status: TODO
type: research/audit
dependency_ids: [EC-A-4]
benchmark_required: no
owner: unassigned
summary: Map codedb capabilities to actual coding-agent gaps in Aizen.
acceptance_criteria:
- must-have vs nice-to-have codedb features are separated
- overlaps and missing capabilities are documented
- Aizen pain points are explicit
promotion_decision: required before interface design

### Record 6
id: EC-B-2
title: Define the Aizen code-intelligence backend interface
lane: Code Intelligence
priority: P1
status: TODO
type: design
dependency_ids: [EC-B-1]
benchmark_required: no
owner: unassigned
summary: Create an Aizen-owned abstraction for external or future-native code intelligence.
acceptance_criteria:
- interface responsibilities are explicit
- interface does not overfit codedb internals
- future native implementation remains possible
promotion_decision: required before integration spike

### Record 7
id: EC-B-3
title: Build a codedb integration spike
lane: Code Intelligence
priority: P1
status: TODO
type: spike/implementation
dependency_ids: [EC-B-2]
benchmark_required: yes
owner: unassigned
summary: Create a runnable evaluation path using codedb on real repository tasks.
acceptance_criteria:
- codedb-backed evaluation path exists
- baseline vs codedb-assisted workflows can be compared
- setup is documented well enough to rerun
promotion_decision: required before benchmark and productization discussion

### Record 8
id: EC-B-4
title: Benchmark codedb on representative large-repo tasks
lane: Code Intelligence
priority: P1
status: TODO
type: benchmark
dependency_ids: [EC-B-3]
benchmark_required: yes
owner: unassigned
summary: Measure repository understanding, context retrieval quality, token cost, and latency.
acceptance_criteria:
- benchmark results are documented
- strengths and weaknesses are explicit
- recommendation is explicit: adopt, adapt, or defer
promotion_decision: required before native Code Graph proposal

### Record 9
id: EC-B-5
title: Draft the Aizen Code Graph proposal
lane: Code Intelligence
priority: P2
status: TODO
type: productization-planning
dependency_ids: [EC-B-4]
benchmark_required: no
owner: unassigned
summary: Translate evaluation findings into a native Aizen code-intelligence direction.
acceptance_criteria:
- scope, staging, and interface boundaries are documented
- proposal is resilient to backend changes
promotion_decision: only valid if EC-B-4 recommends further investment

### Record 10
id: EC-C-1
title: Audit current browser workflow limitations in Aizen
lane: Browser Efficiency and Browser Abstraction
priority: P1
status: TODO
type: audit
dependency_ids: [EC-A-4]
benchmark_required: no
owner: unassigned
summary: Document token cost, determinism, extraction quality, and workflow friction in the current browser path.
acceptance_criteria:
- baseline limitations are concrete
- current-state benchmark baseline exists
promotion_decision: required before browser abstraction design

### Record 11
id: EC-C-2
title: Define the Aizen browser backend abstraction
lane: Browser Efficiency and Browser Abstraction
priority: P1
status: TODO
type: design
dependency_ids: [EC-C-1]
benchmark_required: no
owner: unassigned
summary: Create a backend interface that can support the current browser path, kuri-backed workflows, and future native backends.
acceptance_criteria:
- snapshot, navigation, extraction, and interaction responsibilities are explicit
- multiple backend implementations are possible
promotion_decision: required before kuri spike

### Record 12
id: EC-C-3
title: Build a kuri integration spike
lane: Browser Efficiency and Browser Abstraction
priority: P1
status: TODO
type: spike/implementation
dependency_ids: [EC-C-2]
benchmark_required: yes
owner: unassigned
summary: Evaluate kuri as the first serious browser upgrade path for Aizen.
acceptance_criteria:
- kuri-backed workflows are runnable
- baseline vs kuri-assisted comparison is possible
- setup is documented for reruns
promotion_decision: required before browser benchmark recommendation

### Record 13
id: EC-C-4
title: Benchmark kuri on browsing and crawling scenarios
lane: Browser Efficiency and Browser Abstraction
priority: P1
status: TODO
type: benchmark
dependency_ids: [EC-C-3]
benchmark_required: yes
owner: unassigned
summary: Measure token savings, latency, reliability, and extraction quality.
acceptance_criteria:
- benchmark results are documented
- recommendation is explicit
promotion_decision: required before browser roadmap draft

### Record 14
id: EC-C-5
title: Draft the browser productization roadmap
lane: Browser Efficiency and Browser Abstraction
priority: P2
status: TODO
type: productization-planning
dependency_ids: [EC-C-4]
benchmark_required: no
owner: unassigned
summary: Separate short-term browser workflow improvements from long-term native backend strategy.
acceptance_criteria:
- kuri role is clear
- lightpanda role is clear
- staged browser direction is documented
promotion_decision: valid only after benchmark evidence exists

### Record 15
id: EC-D-1
title: Audit current git pain points in Aizen coding loops
lane: Git Ergonomics for Agents
priority: P1
status: TODO
type: audit
dependency_ids: [EC-A-4]
benchmark_required: no
owner: unassigned
summary: Document where standard git output creates noise, friction, or parsing problems.
acceptance_criteria:
- high-noise workflows are listed
- priority git operations are explicit
promotion_decision: required before structured git interface design

### Record 16
id: EC-D-2
title: Define the Aizen structured git interface
lane: Git Ergonomics for Agents
priority: P1
status: TODO
type: design
dependency_ids: [EC-D-1]
benchmark_required: no
owner: unassigned
summary: Create an Aizen-owned abstraction for concise and machine-friendly git output.
acceptance_criteria:
- concise human-readable mode is covered
- structured machine-readable mode is covered
- interface is not tightly coupled to zagi internals
promotion_decision: required before zagi spike

### Record 17
id: EC-D-3
title: Build a zagi evaluation wrapper
lane: Git Ergonomics for Agents
priority: P1
status: TODO
type: spike/implementation
dependency_ids: [EC-D-2]
benchmark_required: yes
owner: unassigned
summary: Enable direct evaluation of zagi-assisted git workflows.
acceptance_criteria:
- comparison path is runnable
- baseline vs zagi-assisted output can be compared fairly
promotion_decision: required before git benchmark recommendation

### Record 18
id: EC-D-4
title: Benchmark structured git workflows on real coding tasks
lane: Git Ergonomics for Agents
priority: P1
status: TODO
type: benchmark
dependency_ids: [EC-D-3]
benchmark_required: yes
owner: unassigned
summary: Measure token savings and downstream workflow quality.
acceptance_criteria:
- results are documented for status, diff, branch, and worktree-heavy scenarios
- recommendation is explicit
promotion_decision: required before Git Engine proposal

### Record 19
id: EC-D-5
title: Draft the Aizen Git Engine proposal
lane: Git Ergonomics for Agents
priority: P2
status: TODO
type: productization-planning
dependency_ids: [EC-D-4]
benchmark_required: no
owner: unassigned
summary: Define how Aizen should own concise, structured, and guardrailed git behavior long-term.
acceptance_criteria:
- scope, output modes, and safety posture are documented
promotion_decision: valid only if benchmark evidence supports continued investment

### Record 20
id: EC-E-1
title: Audit ACP scope and maturity relative to Aizen needs
lane: Protocol Interoperability
priority: P1
status: TODO
type: protocol-audit
dependency_ids: [EC-A-4]
benchmark_required: no
owner: unassigned
summary: Determine what level of ACP support makes sense for Aizen first.
acceptance_criteria:
- expected transport surface is clear
- likely interoperability targets are documented
promotion_decision: required before interface design

### Record 21
id: EC-E-2
title: Define Aizen protocol/interoperability interface requirements
lane: Protocol Interoperability
priority: P1
status: TODO
type: design
dependency_ids: [EC-E-1]
benchmark_required: no
owner: unassigned
summary: Clarify how ACP fits relative to Aizen’s current transport and protocol concepts.
acceptance_criteria:
- scope boundaries are explicit
- protocol layering is documented
promotion_decision: required before ACP spike

### Record 22
id: EC-E-3
title: Build an ACP design spike using acp-sdk-zig
lane: Protocol Interoperability
priority: P1
status: TODO
type: spike/implementation
dependency_ids: [EC-E-2]
benchmark_required: yes
owner: unassigned
summary: Validate the feasibility of minimal ACP support.
acceptance_criteria:
- spike outcome is concrete
- risks and blockers are documented
promotion_decision: required before staged ACP adoption planning

### Record 23
id: EC-E-4
title: Write a staged ACP adoption plan
lane: Protocol Interoperability
priority: P2
status: TODO
type: planning
dependency_ids: [EC-E-3]
benchmark_required: no
owner: unassigned
summary: Sequence ACP adoption from minimal interoperability to fuller support if justified.
acceptance_criteria:
- rollout stages are documented
- scope creep is controlled
promotion_decision: valid only if ACP spike results justify follow-up

---

## Import Notes

Recommended import order:
EC-A-1 -> EC-A-2 -> EC-A-3 -> EC-A-4 -> EC-B-1 -> EC-B-2 -> EC-B-3 -> EC-B-4 -> EC-B-5 -> EC-C-1 -> EC-C-2 -> EC-C-3 -> EC-C-4 -> EC-C-5 -> EC-D-1 -> EC-D-2 -> EC-D-3 -> EC-D-4 -> EC-D-5 -> EC-E-1 -> EC-E-2 -> EC-E-3 -> EC-E-4

This file is intentionally verbose enough to preserve meaning during manual import.
