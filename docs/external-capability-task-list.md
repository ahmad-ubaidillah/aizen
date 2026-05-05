# Aizen External Capability Upgrade Task Board

Status: PLANNING REFERENCE
Last updated: 2026-05-05
Primary purpose: provide a kanban-closer planning board for translating external capability strategy into future execution.

Use `docs/roadmap-current.md` for live execution truth.
Use `docs/external-capability-strategy.md` for the formal strategic decision framework.
Use `docs/ecosystem-comparison.md` for the repository comparison that feeds this board.
Use this document to create future kanban epics, ordered tasks, dependencies, and exit criteria.

Authority note:
- This document is execution-ready planning, not the live kanban itself.
- Use it to import, stage, or decompose future work after strategy is already agreed.
- When this document conflicts with `roadmap-current.md`, active kanban state, or explicit operational P0s, those live execution sources win.

---

## 1. How to Use This Board

This document is intentionally closer to a real kanban board than a general planning note.

Rules:
- execute by lane priority from top to bottom
- execute FIFO within each lane unless a dependency blocks it
- do not start a later lane while an earlier lane has unblocked work still pending
- do not promote a spike into product work without benchmark evidence
- keep operational stabilization separate from this board unless there is an explicit dependency

Status labels used here:
- TODO
- READY
- BLOCKED
- IN PROGRESS
- DONE
- DEFERRED

Recommended real-kanban mapping:
- TODO = backlog
- READY = ready for sprint / next-up
- BLOCKED = blocked
- IN PROGRESS = active work
- DONE = completed
- DEFERRED = intentionally postponed

---

## 2. Board Summary

Goal:
Strengthen Aizen by integrating or productizing the most valuable specialist capabilities from the external Zig ecosystem without losing architectural coherence.

Top immediate targets:
1. codedb
2. kuri
3. zagi
4. acp-sdk-zig

Second-wave targets:
5. lightpanda
6. Spiderweb concepts
7. zml concepts
8. Lite-profile benchmarking inspired by KrillClaw

Execution rule:
This board is strategic-follow-up work. It must not displace current operational P0s tracked elsewhere unless explicitly approved.

---

## 3. Lane A — Foundation and Decision Framework

Purpose:
Create the evaluation framework that all later lanes depend on.

Exit criteria for Lane A:
- all reviewed repositories are classified consistently
- benchmark scenarios are documented
- adoption metrics are defined
- later lanes can reference shared standards instead of inventing their own

### A-1
Title: Create the canonical external capability inventory
Status: READY
Priority: P0
Depends on: none
Type: docs / planning
Objective:
Produce one normalized inventory of all reviewed external repositories.
Deliverables:
- repository name
- category
- overlap with Aizen
- strategic value
- integration difficulty
- maintenance risk
- license notes
- recommended action
Done when:
- every repository from `ecosystem-comparison.md` is classified
- categories are consistent
- top-tier candidates are clearly separated from low-priority references

### A-2
Title: Define decision labels and classification rules
Status: READY
Priority: P0
Depends on: A-1
Type: docs / planning
Objective:
Standardize the meaning of the project decision labels.
Done when:
- `integrate now`, `benchmark only`, `native inspiration`, `component reference`, and `ignore for now` all have stable definitions
- a future reviewer can classify a new project without guessing

### A-3
Title: Define benchmark scenarios for code, browser, git, and protocol work
Status: READY
Priority: P0
Depends on: A-1
Type: design / planning
Objective:
Create repeatable evaluation scenarios tied to real Aizen workflows.
Done when:
- code task scenario exists
- browser task scenario exists
- git-heavy task scenario exists
- interoperability/protocol scenario exists
- each scenario has measurable outputs

### A-4
Title: Define success metrics for external capability adoption
Status: READY
Priority: P0
Depends on: A-2, A-3
Type: design / planning
Objective:
Prevent taste-driven adoption by requiring measurable evidence.
Done when:
- metrics include latency, token usage, reliability, operator clarity, architectural fit, and implementation complexity
- every later spike lane references the shared metrics

FIFO order for Lane A:
A-1 -> A-2 -> A-3 -> A-4

---

## 4. Lane B — Code Intelligence (codedb-first)

Purpose:
Close Aizen’s biggest specialist gap for coding workflows.

Exit criteria for Lane B:
- codedb value is measured against baseline Aizen coding workflows
- Aizen-owned code-intelligence interface is defined
- a clear adopt/adapt/defer decision exists
- a native productization direction is drafted if justified

### B-1
Title: Audit codedb features against Aizen coding workflow pain points
Status: TODO
Priority: P1
Depends on: A-4
Type: research / audit
Objective:
Map codedb capabilities to actual Aizen coding-agent gaps.
Done when:
- must-have vs nice-to-have features are separated
- overlaps and missing capabilities are explicit

### B-2
Title: Define the Aizen code-intelligence backend interface
Status: TODO
Priority: P1
Depends on: B-1
Type: design
Objective:
Create an Aizen-owned abstraction for external or future-native code intelligence.
Done when:
- interface responsibilities are explicit
- interface does not overfit codedb internals
- future native implementation remains possible

### B-3
Title: Build a codedb integration spike
Status: TODO
Priority: P1
Depends on: B-2
Type: spike / implementation
Objective:
Wire codedb into an evaluation path that can be used on real repository tasks.
Done when:
- codedb-backed path is runnable
- baseline vs codedb-assisted workflows can be compared

### B-4
Title: Benchmark codedb on representative large-repo tasks
Status: TODO
Priority: P1
Depends on: B-3
Type: benchmark
Objective:
Measure repository understanding, context retrieval quality, token cost, and latency.
Done when:
- benchmark results are documented
- recommendation is explicit: adopt, adapt, or defer

### B-5
Title: Draft the Aizen Code Graph proposal
Status: TODO
Priority: P2
Depends on: B-4
Type: productization planning
Objective:
Translate evaluation findings into a native Aizen code-intelligence direction.
Done when:
- scope, staging, and interface boundaries are documented
- proposal is implementation-neutral enough to survive future backend changes

FIFO order for Lane B:
B-1 -> B-2 -> B-3 -> B-4 -> B-5

---

## 5. Lane C — Browser Efficiency and Browser Abstraction (kuri-first)

Purpose:
Improve web-task efficiency and browser ergonomics for agent loops.

Exit criteria for Lane C:
- current browser pain points are documented
- browser abstraction is defined
- kuri is benchmarked against baseline behavior
- short-term and long-term browser direction are both clear

### C-1
Title: Audit current browser workflow limitations in Aizen
Status: TODO
Priority: P1
Depends on: A-4
Type: audit
Objective:
Document token cost, determinism, extraction quality, and workflow friction in the current browser path.
Done when:
- baseline limitations are concrete
- current-state benchmark baseline exists

### C-2
Title: Define the Aizen browser backend abstraction
Status: TODO
Priority: P1
Depends on: C-1
Type: design
Objective:
Create a backend interface that can support the current browser path, kuri-backed workflows, and future native backends.
Done when:
- snapshot, navigation, extraction, and interaction responsibilities are explicit
- multiple backend implementations are possible

### C-3
Title: Build a kuri integration spike
Status: TODO
Priority: P1
Depends on: C-2
Type: spike / implementation
Objective:
Evaluate kuri as the first serious browser upgrade path for Aizen.
Done when:
- kuri-backed workflows can be run in controlled evaluation scenarios
- baseline vs kuri-assisted comparison is possible

### C-4
Title: Benchmark kuri on browsing and crawling scenarios
Status: TODO
Priority: P1
Depends on: C-3
Type: benchmark
Objective:
Measure token savings, latency, reliability, and extraction quality.
Done when:
- results are documented
- recommendation is explicit

### C-5
Title: Draft the browser productization roadmap
Status: TODO
Priority: P2
Depends on: C-4
Type: productization planning
Objective:
Separate short-term browser improvements from long-term native backend strategy.
Done when:
- kuri role is clear
- lightpanda role is clear
- future browser direction is staged

FIFO order for Lane C:
C-1 -> C-2 -> C-3 -> C-4 -> C-5

---

## 6. Lane D — Git Ergonomics for Agents (zagi-first)

Purpose:
Reduce token waste and improve git-heavy coding workflows.

Exit criteria for Lane D:
- current git pain points are documented
- a structured git interface is defined
- zagi-backed workflows are benchmarked
- there is a clear long-term git direction for Aizen

### D-1
Title: Audit current git pain points in Aizen coding loops
Status: TODO
Priority: P1
Depends on: A-4
Type: audit
Objective:
Document where standard git output creates noise, friction, or parsing problems.
Done when:
- high-noise workflows are listed
- priority git operations are explicit

### D-2
Title: Define the Aizen structured git interface
Status: TODO
Priority: P1
Depends on: D-1
Type: design
Objective:
Create an Aizen-owned abstraction for concise and machine-friendly git output.
Done when:
- both concise human-readable and structured output needs are covered
- the interface is not tightly coupled to zagi internals

### D-3
Title: Build a zagi evaluation wrapper
Status: TODO
Priority: P1
Depends on: D-2
Type: spike / implementation
Objective:
Enable direct evaluation of zagi-assisted git workflows.
Done when:
- comparison path is runnable
- baseline vs zagi-assisted output can be compared fairly

### D-4
Title: Benchmark structured git workflows on real coding tasks
Status: TODO
Priority: P1
Depends on: D-3
Type: benchmark
Objective:
Measure token savings and downstream coding workflow quality.
Done when:
- results are documented for status, diff, branch, and worktree-heavy scenarios
- recommendation is explicit

### D-5
Title: Draft the Aizen Git Engine proposal
Status: TODO
Priority: P2
Depends on: D-4
Type: productization planning
Objective:
Define how Aizen should own concise, structured, and guardrailed git behavior long-term.
Done when:
- scope, output modes, and safety posture are documented

FIFO order for Lane D:
D-1 -> D-2 -> D-3 -> D-4 -> D-5

---

## 7. Lane E — Protocol Interoperability (ACP-first)

Purpose:
Improve Aizen’s interoperability posture without destabilizing its current protocol model.

Exit criteria for Lane E:
- ACP scope is understood
- Aizen protocol/interface implications are clear
- a minimal ACP adoption path is defined
- adoption can be staged instead of overcommitted

### E-1
Title: Audit ACP scope and maturity relative to Aizen needs
Status: TODO
Priority: P1
Depends on: A-4
Type: protocol audit
Objective:
Determine what level of ACP support makes sense for Aizen first.
Done when:
- expected transport surface is clear
- likely interoperability targets are documented

### E-2
Title: Define Aizen protocol/interoperability interface requirements
Status: TODO
Priority: P1
Depends on: E-1
Type: design
Objective:
Clarify how ACP would fit relative to Aizen’s existing transport and protocol concepts.
Done when:
- scope boundaries are explicit
- protocol layering is documented

### E-3
Title: Build an ACP design spike using acp-sdk-zig
Status: TODO
Priority: P1
Depends on: E-2
Type: spike / implementation
Objective:
Validate the feasibility of minimal ACP support.
Done when:
- spike outcome is concrete
- risks and blockers are documented

### E-4
Title: Write a staged ACP adoption plan
Status: TODO
Priority: P2
Depends on: E-3
Type: planning
Objective:
Sequence ACP adoption from minimal interoperability to fuller support if justified.
Done when:
- rollout stages are documented
- scope creep is controlled

FIFO order for Lane E:
E-1 -> E-2 -> E-3 -> E-4

---

## 8. Lane F — Native Browser Backend Strategy (lightpanda track)

Purpose:
Evaluate long-term native browser backend direction after agent-facing browser improvements are clearer.

Exit criteria for Lane F:
- backend-level browser needs are separated from workflow-level needs
- lightpanda’s role is evaluated with clear recommendations

### F-1
Title: Define browser backend questions not solved by kuri alone
Status: TODO
Priority: P2
Depends on: C-5
Type: design / analysis
Objective:
Identify which browser concerns belong to the engine/backend layer rather than the agent workflow layer.
Done when:
- backend concerns are explicit
- lightpanda evaluation scope is justified

### F-2
Title: Evaluate lightpanda as a strategic backend candidate
Status: TODO
Priority: P2
Depends on: F-1
Type: research / architecture assessment
Objective:
Determine whether lightpanda-like capabilities should shape Aizen’s long-term browser backend plan.
Done when:
- complexity, dependency, and fit analysis is documented
- recommendation is explicit

FIFO order for Lane F:
F-1 -> F-2

---

## 9. Lane G — Distributed Execution Research (Spiderweb track)

Purpose:
Preserve and evaluate useful distributed-system ideas without prematurely committing to implementation.

Exit criteria for Lane G:
- Spiderweb concepts are mapped to real Aizen orchestration needs
- speculative ideas are clearly separated from near-term value

### G-1
Title: Map Spiderweb concepts to Aizen orchestration goals
Status: TODO
Priority: P3
Depends on: none
Type: research
Objective:
Determine which distributed concepts actually matter for Aizen.
Done when:
- alignment map exists
- useful vs speculative concepts are separated

### G-2
Title: Draft distributed execution research notes for Aizen
Status: TODO
Priority: P3
Depends on: G-1
Type: architecture research
Objective:
Capture the concepts worth preserving for future planning.
Done when:
- notes are durable enough for later roadmap work
- no premature implementation assumptions are baked in

FIFO order for Lane G:
G-1 -> G-2

---

## 10. Lane H — Local Inference Bridge Research (zml track)

Purpose:
Explore the narrowest useful local-inference entry point for Aizen.

Exit criteria for Lane H:
- first-step use cases are defined
- future options are documented without overcommitting

### H-1
Title: Define the narrowest useful local inference entry points
Status: TODO
Priority: P3
Depends on: none
Type: research / scoping
Objective:
Start with realistic local-inference use cases rather than full local-chat ambition.
Done when:
- embeddings, reranking, or similar narrow use cases are evaluated first
- unnecessary scope is excluded

### H-2
Title: Draft local inference bridge options for Aizen
Status: TODO
Priority: P3
Depends on: H-1
Type: research / planning
Objective:
Document plausible future local-inference paths and tradeoffs.
Done when:
- options and tradeoffs are written down clearly

FIFO order for Lane H:
H-1 -> H-2

---

## 11. Lane I — Lite Profile Benchmarking (KrillClaw track)

Purpose:
Use ultra-light runtimes as benchmark references for a possible Aizen Lite profile.

Exit criteria for Lane I:
- Aizen Lite goals are explicitly defined
- current vs target footprint discussion is grounded in evidence

### I-1
Title: Define what Aizen Lite should mean
Status: TODO
Priority: P3
Depends on: none
Type: scoping
Objective:
Clarify whether the target is binary size, startup speed, memory footprint, deployment simplicity, or some subset.
Done when:
- Lite profile goals are documented clearly
- unnecessary scope is excluded

### I-2
Title: Benchmark Aizen footprint against lightweight references
Status: TODO
Priority: P3
Depends on: I-1
Type: benchmark
Objective:
Use KrillClaw and similar runtimes as external reference points.
Done when:
- benchmark notes exist
- realistic optimization targets are proposed

FIFO order for Lane I:
I-1 -> I-2

---

## 12. Global Dependency Summary

Top-level order:
- Lane A must complete before Lanes B, C, D, and E should start
- Lane C should finish before Lane F begins
- Lanes G, H, and I can run later and independently, but should not jump ahead of higher-priority unblocked lanes

Recommended macro order:
1. Lane A
2. Lane B
3. Lane C
4. Lane D
5. Lane E
6. Lane F
7. Lane G
8. Lane H
9. Lane I

---

## 13. Promotion Rules

A task or lane may move from spike/research into implementation planning only when:
- benchmark evidence exists
- the recommendation is explicit
- an Aizen-owned interface exists or is clearly defined
- the maintenance burden is considered acceptable
- the work does not conflict with more urgent operational priorities

---

## 14. Suggested Kanban Conversion Fields

When moving these items into the real board, use fields like:
- ID
- title
- lane
- status
- priority
- type
- dependency_ids
- owner
- acceptance_criteria
- benchmark_required (yes/no)
- promotion_decision

---

## 15. Final Note

This document is intentionally closer to the board style you use:
- ordered by priority
- lane-based
- FIFO-aware
- dependency-aware
- explicit about exit criteria

Intended flow:
`ecosystem-comparison.md` -> `external-capability-strategy.md` -> `external-capability-task-list.md` -> this board -> live kanban
