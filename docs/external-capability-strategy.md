# Aizen External Capability Strategy

Status: REFERENCE
Last updated: 2026-05-05
Primary purpose: define the formal strategy for evaluating, adopting, productizing, and sequencing external specialist capabilities into Aizen.

Use `docs/roadmap-current.md` for active execution truth.
Use `docs/architecture-design.md` for target-state technical authority.
Use `docs/ecosystem-comparison.md` for repository-level comparison and candidate classification.
Use `docs/external-capability-task-list.md` for the execution-ready planning breakdown derived from this strategy.
Use this document for strategic decision framing.

Authority note:
- This document decides how external capabilities should be classified, sequenced, and justified at a strategy level.
- Use `external-capability-task-list.md` when translating strategy into execution-ready work items.
- When this document conflicts with `roadmap-current.md` or live kanban execution, treat those execution sources as authoritative for near-term delivery.

---

## 1. Why This Document Exists

Aizen now sits in a strong but incomplete position.
It already has substantial platform breadth, but it does not yet dominate every specialist domain that modern agent systems depend on.

The external ecosystem shows a repeated pattern:
- Aizen is stronger as a broad platform.
- specialist projects are stronger in one narrow capability.

That means the strategic question is no longer:
“Should Aizen copy competing projects?”

The correct question is:
“How should Aizen absorb external specialist advantages without losing its architectural coherence or operational focus?”

This document answers that question.

---

## 2. Strategic Thesis

Aizen should become the best Zig-native platform for combining specialist capabilities.

It should do this by following four rules:
1. keep breadth as a moat
2. close the highest-value depth gaps first
3. adopt external specialist capabilities behind Aizen-owned interfaces
4. productize only what proves valuable through benchmarks and real workflows

This avoids two common failure modes:
- trying to rebuild everything from scratch too early
- becoming a thin wrapper pile with no coherent internal architecture

---

## 3. What Counts as an External Capability Opportunity

A project is a serious external capability opportunity for Aizen when most of the following are true:
- it solves a narrow but important problem better than Aizen currently does
- the capability sits on a high-frequency agent workflow path
- the value can be benchmarked on real Aizen tasks
- the capability can be isolated behind an interface or adapter
- adoption does not require a full architectural rewrite to test usefulness
- the project teaches Aizen something structurally reusable, not just cosmetically interesting

Examples of strong opportunities:
- code intelligence
- token-efficient browser interaction
- concise and structured git workflows
- protocol interoperability

Examples of weaker opportunities:
- novelty projects with unclear leverage
- experiments with no obvious path to Aizen integration
- projects that optimize a metric Aizen does not yet need to optimize

---

## 4. Decision Classes

Every external project should be placed into one of the following classes.

### 4.1 Integrate now
Definition:
The project addresses a meaningful current gap and is worth immediate spike-level integration or evaluation.

Typical signs:
- high leverage
- low to moderate evaluation cost
- direct improvement to coding, browsing, git, or interoperability workflows

Current examples:
- codedb
- kuri
- zagi
- acp-sdk-zig

### 4.2 Benchmark only
Definition:
The project is useful mainly as a reference point for size, speed, startup, or minimal runtime shape.

Typical signs:
- strong metrics but weak product overlap
- valuable as an optimization target rather than a direct integration source

Current examples:
- KrillClaw
- some lightweight runtime agents

### 4.3 Native inspiration
Definition:
The project contains architectural ideas Aizen should likely absorb over time, but not necessarily through direct integration.

Typical signs:
- strong ideas at the subsystem level
- integration would be too invasive for an initial spike
- concepts are more valuable than code reuse

Current examples:
- Spiderweb
- some editor-native systems
- some local inference platforms

### 4.4 Component reference
Definition:
The project is not a platform-level target, but may inform one subcomponent, heuristic, or interface.

Typical signs:
- one useful trick or subsystem
- lower standalone strategic importance
- useful as supporting input to another major track

Current examples:
- zchrome
- FileScopeMCP
- zindeks
- orion-cli

### 4.5 Ignore for now
Definition:
The project may be interesting, but it does not justify current evaluation effort.

Typical signs:
- low leverage
- low maturity
- weak fit with Aizen’s roadmap
- unclear value beyond curiosity

---

## 5. Capability Prioritization Framework

External capability work should be prioritized according to the following order.

### 5.1 Priority dimension A — workflow frequency
How often would this capability improve a real Aizen workflow?

Highest value domains:
- coding
- browsing
- git operations
- interoperability with external agent tooling

### 5.2 Priority dimension B — architectural leverage
Does one integration unlock multiple future Aizen improvements?

Examples:
- code intelligence can improve planning, context retrieval, and repo navigation
- browser abstraction can support multiple backends later
- structured git can improve coding loops across many tasks

### 5.3 Priority dimension C — evaluation cost
Can Aizen learn something meaningful quickly?

Good candidates:
- thin wrappers
- benchmarkable tools
- modular protocol SDKs

Riskier candidates:
- full browser engines
- deep inference platforms
- distributed runtime subsystems

### 5.4 Priority dimension D — product differentiation potential
Will this capability merely close a gap, or help Aizen surpass competitors?

Gap-closing examples:
- structured git
- browser snapshots
- code indexing

Differentiation examples:
- combining all three under one coherent runtime
- distributed orchestration plus specialist tool support
- future hybrid online/offline execution

---

## 6. Immediate Strategic Priorities

The first wave of external capability work should focus on four areas.

### 6.1 Code intelligence
Why first:
- it is one of the clearest current depth gaps
- it directly improves coding-agent quality
- it affects context selection, repository understanding, and task planning

Primary candidate:
- codedb

Strategic intent:
- use external capability to define what Aizen’s future code intelligence layer should become

### 6.2 Browser efficiency and agent-oriented browsing
Why second:
- browser tasks are common and expensive in token terms
- better browser snapshots can immediately reduce cost and improve determinism

Primary candidate:
- kuri

Strategic intent:
- improve agent-facing browsing first
- decide engine/backend strategy later

### 6.3 Git ergonomics for agents
Why third:
- coding workflows repeatedly touch git
- git noise is a recurring tax on token usage and decision quality

Primary candidate:
- zagi

Strategic intent:
- make Aizen’s coding loop more concise, safer, and more structured

### 6.4 Protocol interoperability
Why fourth:
- interoperability is easier to regret later than to plan early
- ACP could become a meaningful ecosystem surface

Primary candidate:
- acp-sdk-zig

Strategic intent:
- keep Aizen extensible and standards-aware

---

## 7. Second-Wave Strategic Priorities

These matter, but should follow the first wave.

### 7.1 Native browser backend strategy
Primary candidate:
- lightpanda

Question to answer:
Should Aizen eventually own a deeper native browser backend rather than only an agent-facing browser layer?

### 7.2 Distributed execution research
Primary input:
- Spiderweb

Question to answer:
How should Aizen’s orchestration evolve when work spans multiple machines, nodes, or long-lived shared workspaces?

### 7.3 Local inference bridge
Primary input:
- zml

Question to answer:
What is the narrowest, most useful local inference entry point for Aizen without derailing the product?

### 7.4 Lite profile benchmarking
Primary input:
- KrillClaw

Question to answer:
What should Aizen optimize if it wants a smaller deployment profile without sacrificing core product identity?

---

## 8. Interface-First Adoption Rule

Aizen should adopt serious external capabilities behind Aizen-owned interfaces whenever possible.

This is essential because:
- it prevents external projects from becoming hidden architecture owners
- it reduces lock-in to the quirks of one tool
- it keeps native reimplementation possible later
- it allows fair benchmarking between external and internal approaches

Minimum interface targets:
- code intelligence backend
- browser backend
- structured git backend
- interoperability/protocol adapter layer

This rule should apply even during spike phases when practical.

---

## 9. Benchmark-First Productization Rule

No external capability should become a core Aizen commitment based on taste alone.

Before productization, Aizen should measure:
- token cost
- latency
- reliability
- operator clarity
- implementation complexity
- architectural fit
- maintenance burden

A capability should move from experiment to product plan only when benchmark evidence and design fit both look favorable.

This protects Aizen from overcommitting to exciting but low-yield technology.

---

## 10. Guardrails

External capability work must not:
- displace active operational stabilization unless explicitly prioritized
- create overlapping planning documents with equal authority
- hardwire third-party assumptions too deeply into Aizen architecture
- optimize for novelty over repeatable operator value
- collapse research, prototype, and product commitment into one phase

External capability work should:
- keep strategy, planning, and execution separated clearly
- preserve live-kanban authority for current execution
- document adoption decisions explicitly
- retire weak candidates quickly when evidence is poor

---

## 11. Desired End State

The goal is not for Aizen to become a collection of imported specialist tools.

The goal is for Aizen to become:
- broader than the specialist projects
- stronger in the most important specialist workflows
- cleaner architecturally than a loose integration pile
- more interoperable than isolated runtimes
- more strategically durable than minimalist one-purpose tools

If executed well, Aizen should be able to say:
- it has the platform breadth of a full agent ecosystem
- it has the specialist depth required for serious coding and automation work
- it can adopt, benchmark, and absorb innovation faster than narrower competitors

---

## 12. Final Strategic Recommendation

The correct sequence is:
1. classify and benchmark
2. integrate the highest-leverage specialist capabilities
3. wrap them in Aizen-owned interfaces
4. productize the proven patterns
5. use second-wave investments to create new combinations competitors do not have

In short:
Aizen should not try to beat every external project at being itself.
Aizen should become the best system for turning external specialist strengths into a coherent, superior agent platform.
