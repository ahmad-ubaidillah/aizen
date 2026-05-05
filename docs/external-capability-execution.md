# Aizen External Capability Execution

Status: CURRENT
Last updated: 2026-05-05
Primary purpose: capture completed outputs for the first actionable external-capability planning tasks so the board has executable artifacts, not only backlog descriptions.

Use `docs/external-capability-strategy.md` for the strategic decision framework.
Use `docs/external-capability-task-list.md` for the lane-based planning board.
Use `docs/external-capability-flat-tasks.md` for the flattened task list.
Use `docs/external-capability-kanban-import.md` for structured import records.

Authority note:
- This file stores completed outputs from planning tasks that were actually executed.
- When a planning task from the external capability board is completed in-document, this file should hold the resulting artifact or point to the authoritative artifact.
- For live product delivery priorities, `roadmap-current.md` and active kanban still win.

---

## Execution Status

Completed in this pass:
- EC-A-1 — canonical external capability inventory
- EC-A-2 — decision labels and classification rules
- EC-A-3 — benchmark scenarios for code, browser, git, and protocol evaluation
- EC-A-4 — success metrics for external capability adoption

Next FIFO tasks after this file:
- EC-B-1 — Audit codedb features against Aizen coding workflow pain points
- EC-B-2 — Define the Aizen code-intelligence backend interface
- EC-B-3 — Build a codedb integration spike

---

## EC-A-1 — Canonical External Capability Inventory

### Inventory schema
Each reviewed repository should be classified using these fields:
- repository
- category
- overlap_with_aizen
- strategic_value
- integration_difficulty
- maintenance_risk
- license_notes
- recommended_action
- rationale

### Canonical inventory

| Repository | Category | Overlap with Aizen | Strategic value | Integration difficulty | Maintenance risk | License notes | Recommended action | Rationale |
|---|---|---|---|---|---|---|---|---|
| `justrach/codedb` | code intelligence | medium | very high | medium | medium | verify upstream repo license before shipping integration | integrate now | Highest-leverage path for structural code understanding, repo navigation, and coding-task context quality. |
| `justrach/kuri` | browser automation / token-efficient snapshots | medium | very high | medium | medium | verify upstream repo license before shipping integration | integrate now | Strong candidate for reducing browser token cost and improving deterministic extraction workflows. |
| `mattzcarey/zagi` | git ergonomics for agents | low-medium | high | low-medium | low-medium | verify upstream repo license before shipping integration | integrate now | Likely quick win for concise git output, machine-readable summaries, and coding-loop efficiency. |
| `MagnovaAI/acp-sdk-zig` | protocol interoperability | low | high | medium | medium | verify upstream repo license before shipping integration | integrate now | Valuable for future interoperability; should begin as bounded support rather than full protocol sprawl. |
| `lightpanda-io/browser` | native browser runtime | medium | high | medium-high | medium | verify upstream repo license before shipping integration | native inspiration | Important long-term browser backend input, but likely best evaluated after the first kuri-backed abstraction pass. |
| `DeanoC/Spiderweb` | distributed orchestration concepts | medium | medium-high | high | medium-high | verify upstream repo license before shipping integration | native inspiration | Architecture ideas are valuable, but direct adoption is likely invasive; harvest concepts first. |
| `zml/zml` | local model inference | low-medium | medium-high | high | high | verify upstream repo license before shipping integration | native inspiration | Long-horizon strategic importance for offline/local inference, but not a near-term delivery priority. |
| `krillclaw/KrillClaw` | lightweight runtime benchmark | medium | medium | low | low | verify upstream repo license before shipping integration | benchmark only | Useful as a comparative runtime benchmark and lite-profile reference rather than a feature donor. |
| `admica/FileScopeMCP` | file importance / dependency relevance | low-medium | medium-high | medium | medium | verify upstream repo license before shipping integration | component reference | Strong candidate for file-priority heuristics feeding coding context selection. |
| `shishtpal/zchrome` | lightweight CDP support | medium | medium | medium | medium | verify upstream repo license before shipping integration | component reference | Useful as a subcomponent reference for browser/CDP work, but not the primary strategic browser path. |
| `sutantodadang/zindeks` | lightweight code indexing | medium | medium | medium | low-medium | verify upstream repo license before shipping integration | component reference | Helpful reference for lightweight indexing heuristics if codedb proves too heavy. |
| `lupin4/wintermolt` | platform-adjacent runtime benchmark | low-medium | low-medium | medium | medium | verify upstream repo license before shipping integration | benchmark only | Mainly useful as a shape/efficiency comparison point, not a clear capability donor. |
| `satibot/satibot` | platform-adjacent runtime benchmark | low-medium | low-medium | medium | medium | verify upstream repo license before shipping integration | benchmark only | Primarily reference value for runtime composition and packaging. |
| `neolite/zaica` | platform-adjacent runtime benchmark | low-medium | low-medium | medium | medium | verify upstream repo license before shipping integration | benchmark only | Compare architecture and runtime trade-offs; no immediate specialist capability lead identified. |
| `Bare-Systems/Bear-Claw` | platform-adjacent runtime benchmark | low-medium | low-medium | medium | medium | verify upstream repo license before shipping integration | benchmark only | Reference platform only; low immediate leverage for Aizen depth gaps. |
| `nitishsancs/NanoAgent` | lightweight agent benchmark | low | low-medium | low | low | verify upstream repo license before shipping integration | benchmark only | Good for minimal-runtime comparison, not a direct subsystem donor. |
| `nitishsjsucs/NanoAgent` | lightweight agent benchmark | low | low-medium | low | low | verify upstream repo license before shipping integration | benchmark only | Same class as above; useful for comparative baselines only. |
| `benmaster82/retro-agent` | lightweight/retro runtime benchmark | low | low | low | low | verify upstream repo license before shipping integration | benchmark only | Mostly useful as a packaging/minimalism reference. |
| `Devareductionist821/retro-agent` | lightweight/retro runtime benchmark | low | low | low | low | verify upstream repo license before shipping integration | benchmark only | Same benchmark-only role as other minimal runtimes. |
| `anachary/zig-ai-platform` | platform-adjacent reference | medium | low-medium | medium | medium | verify upstream repo license before shipping integration | benchmark only | Architectural comparison value only; no top-tier gap closure identified. |
| `ZantFoundation/Z-Ant` | research input | low | medium | high | medium-high | verify upstream repo license before shipping integration | ignore for now | Interesting but not clearly connected to current high-value gaps. |
| `xreal/ffast` | research/performance input | low | medium | high | medium-high | verify upstream repo license before shipping integration | component reference | May inform performance techniques, but not a top-level initiative today. |
| `jsmestad/minga` | editor-native system | low-medium | medium | high | medium | verify upstream repo license before shipping integration | native inspiration | Valuable as editor-native inspiration, but not a near-term core-platform task. |
| `copyleftdev/zemacs` | editor-native system | low-medium | medium | high | medium | verify upstream repo license before shipping integration | native inspiration | Same class as minga: conceptually useful, not an immediate roadmap target. |
| `michalwiacek/orion-cli` | API/tool generation | low-medium | medium-high | medium | medium | verify upstream repo license before shipping integration | component reference | Useful reference for future OpenAPI-to-tool generation, but not first-wave external capability work. |
| `bkataru/powerglide` | research input | low | low-medium | high | medium | verify upstream repo license before shipping integration | ignore for now | Low proven leverage against current Aizen pain points. |
| `bkataru/zeptoclaw` | research input | low | low-medium | high | medium | verify upstream repo license before shipping integration | ignore for now | Interesting but not yet justified against current priorities. |
| `fulgidus/zignet` | research/network input | low | low-medium | high | medium | verify upstream repo license before shipping integration | ignore for now | Does not presently map to a first-wave Aizen capability gap. |
| `DeanoC/ZiggyPiAi` | research/embedded input | low | low-medium | high | medium | verify upstream repo license before shipping integration | ignore for now | Out of current strategic focus relative to code/browser/git/protocol work. |
| `mskDev0092/ZiggyClaw` | research/agent input | low | low-medium | medium-high | medium | verify upstream repo license before shipping integration | ignore for now | No clear advantage over current top targets. |
| `allisoneer/zai` | research input | low | low-medium | medium | medium | verify upstream repo license before shipping integration | ignore for now | Not yet linked to a high-frequency Aizen workflow pain point. |
| `realcow/dolse` | research input | low | low-medium | medium | medium | verify upstream repo license before shipping integration | ignore for now | No first-wave leverage established. |

### Top-tier candidates
These are the first-wave repositories that should remain clearly separated from lower-priority references:
1. `justrach/codedb`
2. `justrach/kuri`
3. `mattzcarey/zagi`
4. `MagnovaAI/acp-sdk-zig`

### Lower-priority references
These remain useful, but should not displace the first-wave queue:
- `lightpanda-io/browser`
- `DeanoC/Spiderweb`
- `zml/zml`
- `krillclaw/KrillClaw`
- `admica/FileScopeMCP`
- `shishtpal/zchrome`
- `sutantodadang/zindeks`
- all platform-adjacent benchmark projects
- all longer-horizon research inputs

---

## EC-A-2 — Decision Labels and Classification Rules

### Decision labels

#### `integrate now`
Use when:
- the capability addresses a meaningful current Aizen gap
- the value sits on a high-frequency workflow path
- evaluation cost is acceptable now
- a bounded spike can validate usefulness without architectural chaos

Interpretation:
- create near-term audit/design/spike tasks
- require benchmark evidence before broad productization
- preferred for first-wave targets

#### `benchmark only`
Use when:
- the project is mainly valuable as a runtime or UX comparison point
- direct integration value is weak or uncertain
- the best outcome is a measurable target, not code adoption

Interpretation:
- use for baselines, lite profiles, or efficiency comparison
- do not start adoption work unless later evidence upgrades the label

#### `native inspiration`
Use when:
- the ideas are strong but direct adoption would be too invasive or premature
- architectural patterns matter more than code reuse
- Aizen should likely absorb the concept behind an Aizen-owned interface later

Interpretation:
- harvest concepts and constraints
- do not couple roadmap promises to direct upstream integration

#### `component reference`
Use when:
- one subsystem or heuristic is useful
- the overall project is not a strategic target by itself
- the value is local to one interface, heuristic, or backend feature

Interpretation:
- cite during design work
- optionally use in spikes as a secondary reference
- keep scope narrow and avoid platform-level commitment

#### `ignore for now`
Use when:
- the project does not solve a high-priority pain point
- leverage is unclear or speculative
- evaluation cost is not justified against current priorities

Interpretation:
- preserve the note in the inventory
- do not spawn near-term tasks from it
- reconsider only if priorities change or evidence improves

### Classification rules
1. Classify from Aizen’s workflow pain points, not from project novelty.
2. Prefer the smallest honest label; do not promote a project to `integrate now` without a strong workflow case.
3. If direct adoption is doubtful but the idea is strong, choose `native inspiration` rather than forcing integration.
4. If only one subcomponent matters, choose `component reference`.
5. If the main value is comparison or target-setting, choose `benchmark only`.
6. If no concrete leverage is visible today, choose `ignore for now`.
7. Every classification should include one short rationale sentence tied to code, browser, git, protocol, or another explicit Aizen need.
8. New repositories should reuse the same schema and labels before being added to any lane backlog.

### Reclassification triggers
Revisit a label when any of the following happens:
- a new Aizen pain point becomes operationally important
- benchmark evidence upgrades or weakens the case
- an abstraction layer is defined that reduces integration cost
- upstream maturity, licensing, or maintenance posture changes materially

---

## EC-A-3 — Benchmark Scenarios for Code, Browser, Git, and Protocol Evaluation

### Shared benchmark rules
Every scenario should record:
- task description
- baseline workflow
- candidate-assisted workflow
- time to usable result
- token cost or output-size proxy
- reliability / rerun stability
- operator clarity
- setup friction
- notes on architectural fit

### Scenario 1 — Code intelligence
Goal:
Measure whether an external code-intelligence backend improves repository understanding and coding-task context retrieval.

Representative task:
- Given a medium-to-large repo, identify the execution path for a feature, locate the most relevant files/symbols, and explain where a change should be made.

Baseline workflow:
- current Aizen file search, grep-style search, manual file reads, and any existing code-navigation support

Candidate-assisted workflow:
- same task using codedb or another code-intelligence backend through a bounded interface/spike path

Required outputs:
- ranked relevant files/symbols
- explanation of why those files matter
- estimate of confidence / relevance quality
- notes on misses, noise, and latency

### Scenario 2 — Browser efficiency and extraction
Goal:
Measure whether a browser candidate improves token efficiency, extraction quality, and determinism on real web workflows.

Representative tasks:
- extract key facts from a docs page
- navigate a multi-page documentation path
- capture a clean structured snapshot from a noisy site

Baseline workflow:
- current browser path in Aizen

Candidate-assisted workflow:
- kuri-backed or future-native backend path through a browser abstraction

Required outputs:
- extracted facts / snapshot quality
- number of retries or corrective steps
- token/output-size comparison
- latency and determinism notes

### Scenario 3 — Git ergonomics
Goal:
Measure whether concise and structured git workflows reduce noise and improve downstream agent reasoning.

Representative tasks:
- summarize working tree changes
- explain diff impact
- compare branches / worktrees
- prepare a compact commit/PR review context package

Baseline workflow:
- standard git CLI output used in current Aizen loops

Candidate-assisted workflow:
- zagi-backed or structured-wrapper workflow producing concise + machine-friendly output

Required outputs:
- compact human-readable summary
- structured machine-readable summary
- output-size reduction vs baseline
- evidence of improved downstream usability

### Scenario 4 — Protocol interoperability
Goal:
Measure whether ACP-style interoperability brings practical value without creating protocol sprawl.

Representative tasks:
- establish minimal ACP-capable connection path
- exchange a small representative request/response flow
- assess fit relative to Aizen’s current transport/protocol model

Baseline workflow:
- current Aizen protocol/transport handling without ACP support

Candidate-assisted workflow:
- bounded ACP spike using acp-sdk-zig or an equivalent minimal implementation

Required outputs:
- minimal supported surface documented
- blockers and incompatibilities listed
- protocol layering implications explained
- recommendation on staged adoption or deferral

---

## EC-A-4 — Success Metrics for External Capability Adoption

### Required metric dimensions
Every adoption or defer recommendation should be evaluated against the same shared dimensions.

#### 1. Latency
Questions:
- does the candidate reduce time to usable result?
- does it introduce expensive startup or coordination overhead?

Minimum expectation:
- report relative improvement or regression against baseline

#### 2. Token usage / output size
Questions:
- does the candidate reduce prompt payload or output verbosity?
- does it improve signal density for downstream reasoning?

Minimum expectation:
- report either token comparison or a stable proxy such as serialized output size

#### 3. Reliability
Questions:
- is the result stable across reruns?
- how often do retries, manual corrections, or fallback paths occur?

Minimum expectation:
- report rerun stability and notable failure modes

#### 4. Operator clarity
Questions:
- does the candidate make workflows easier to debug, inspect, and explain?
- does it improve the quality of intermediate artifacts?

Minimum expectation:
- record whether outputs are easier for operators and downstream agents to interpret

#### 5. Architectural fit
Questions:
- can the capability sit behind an Aizen-owned interface?
- does adoption preserve future backend flexibility?
- does it align with Aizen’s breadth-first platform strategy?

Minimum expectation:
- explain whether the integration strengthens or weakens Aizen’s internal coherence

#### 6. Implementation complexity
Questions:
- how invasive is the spike or integration?
- how much custom glue, maintenance burden, or operational risk is introduced?

Minimum expectation:
- classify effort and risk at least as low / medium / high and justify briefly

### Scoring guidance
A recommendation should not be treated as valid unless it includes:
- at least one concrete baseline comparison
- explicit strengths
- explicit weaknesses
- a final call: adopt, adapt, defer, or ignore

### Promotion rule
For lanes B-E:
- no productization proposal should be accepted without benchmark evidence tied to these shared metrics
- no integration spike should be treated as roadmap justification by itself
- benchmark outcomes must reference at least latency, token usage/output size, reliability, operator clarity, architectural fit, and implementation complexity

---

## EC-B-1 — Audit codedb Features Against Aizen Coding Workflow Pain Points

### Current Aizen coding workflow pain points

#### Pain point 1 — File discovery is broad, but structural understanding is shallow
Observed issue:
- Aizen can search files and content effectively, but deeper structural questions still require multiple manual hops.
- Operators often need to discover not only *where text appears*, but which files, symbols, routes, and dependency edges actually matter.

Why this matters:
- coding tasks slow down when the agent must reconstruct execution flow from repeated search + read loops
- token cost rises because more files must be opened to infer structure indirectly

#### Pain point 2 — Relevance ranking for large repos is not yet code-structure-aware enough
Observed issue:
- current workflows can surface candidate files, but prioritization is still weaker than a purpose-built code-intelligence layer
- large or multi-service repositories create noise when many files mention the same concept

Why this matters:
- the agent spends cycles reading nearby-but-not-central files
- downstream edits and reviews become less confident

#### Pain point 3 — Change-impact reasoning is not yet first-class in the external capability lane
Observed issue:
- code-change planning benefits from explicit caller/callee, symbol, route, or dependency context
- Aizen has planning/docs strength, but this lane still needs stronger graph-backed change reasoning for repository-scale coding work

Why this matters:
- implementation plans and refactors are safer when blast radius can be estimated directly
- review quality improves when likely affected areas are surfaced early

#### Pain point 4 — Multi-file code navigation still needs better bounded abstractions
Observed issue:
- without a dedicated code-intelligence backend abstraction, repo navigation logic risks being spread across ad hoc search patterns
- this makes later benchmarking and backend swapping harder

Why this matters:
- a clean interface is required before Aizen can compare codedb, zindeks-style approaches, or future native graph/index layers fairly

#### Pain point 5 — Large-repo context preparation is still expensive
Observed issue:
- coding tasks frequently require building a compact “working set” of relevant files, symbols, and context notes
- today this often depends on repeated search/read/manual synthesis loops

Why this matters:
- slower time to usable implementation context
- more prompt payload spent on discovery instead of reasoning or execution

### codedb capability mapping

| codedb capability area | Aizen pain point addressed | Importance | Notes |
|---|---|---|---|
| Structural symbol/file indexing | Pain points 1, 2, 5 | must-have | Directly improves repo understanding and relevance ranking for coding tasks. |
| Relationship-aware navigation (references/callers/callees/routes/flows) | Pain points 1, 3 | must-have | High leverage for impact analysis, execution-path tracing, and safer edits. |
| Queryable repository graph / semantic search hybrid | Pain points 2, 5 | must-have | Needed for large-repo retrieval quality and compact working-set construction. |
| Focused context extraction for a coding task | Pain points 2, 5 | must-have | Strong candidate for reducing context noise before implementation/review. |
| Rename/refactor assistance | Pain point 3 | nice-to-have | Valuable after trust is established; not required for the first spike. |
| API/route impact awareness | Pain point 3 | must-have | Especially important for service-oriented repos and dashboard/backend coupling. |
| Cross-file dependency ranking | Pain points 2, 5 | must-have | Needed to prioritize what files matter first. |
| Rich graph querying for advanced analysis | Pain points 1, 3 | nice-to-have | Useful for deeper investigation, but not necessary for the first minimal integration. |
| Bulk codebase exploration ergonomics | Pain points 1, 5 | nice-to-have | Helpful, but should follow the core retrieval/impact path. |

### Must-have codedb features for the first serious evaluation
- structural indexing of files and symbols
- relevance-ranked retrieval for large repositories
- relationship/context views that explain why a file or symbol matters
- change-impact / dependency-aware exploration
- task-bounded context extraction suitable for coding and review workflows
- support for repository-scale queries without forcing full manual graph traversal

### Nice-to-have codedb features
- rename/refactor helpers
- advanced graph querying for expert analysis
- broader developer ergonomics beyond the first bounded coding workflows
- secondary exploration modes that are useful but not essential to benchmark the core value

### Overlaps with current Aizen direction
- overlaps with existing search/read/code-navigation ambitions
- overlaps with future Code Graph / code-intelligence planning already implied by EC-B tasks
- overlaps with file-priority and context-selection goals from the broader external capability strategy

### Gaps that codedb could close well
- structural relevance ranking in large repositories
- direct explanation of symbol/file importance
- change-impact reasoning for edits and reviews
- better compact context packages for implementation planning

### Gaps that codedb alone does not solve
- final Aizen-owned interface design
- productized UX decisions for how code intelligence appears in CLI/dashboard flows
- long-term native fallback strategy if an external backend becomes too heavy or restrictive
- broader git/browser/protocol pain points outside code-intelligence scope

### Audit conclusion
Recommendation:
- codedb remains the strongest first-wave candidate for the code-intelligence lane
- the first integration should be explicitly bounded around repository understanding, relevance ranking, impact/context exploration, and compact working-set generation
- do not over-scope the first spike into full refactoring automation or advanced graph power-user features

This satisfies EC-B-1 by making Aizen pain points explicit, separating must-have from nice-to-have capabilities, and documenting overlaps plus missing areas.

---

## EC-B-2 — Define the Aizen Code-Intelligence Backend Interface

### Interface design goals
- give Aizen one owned abstraction for external or future-native code intelligence
- avoid coupling product behavior directly to codedb-specific concepts
- support future backend substitution without rewriting calling workflows
- optimize first for repository understanding, task-bounded retrieval, and impact-aware coding assistance

### Core design principles
1. Aizen owns the task semantics; the backend supplies structured code intelligence.
2. The interface must answer workflow questions, not expose raw backend internals first.
3. Every result should explain *why it is relevant* whenever possible.
4. The interface should support both lightweight and graph-rich backends.
5. Advanced backend features may exist behind optional capabilities, but the base contract must stay small.

### Proposed base interface surface

#### 1. `find_relevant_context`
Purpose:
- Given a task description, repo scope, and optional hints, return the most relevant files/symbols/context packages for coding work.

Inputs:
- task_query
- repo_scope
- optional file/symbol/path hints
- max_results

Outputs:
- ranked files and/or symbols
- short rationale per result
- optional grouped context package

#### 2. `explain_symbol_or_file`
Purpose:
- Explain why a file or symbol matters in the repository and what nearby relationships are most important.

Inputs:
- symbol or file target
- optional scope or depth

Outputs:
- summary
- incoming/outgoing relationships if available
- notable usage/ownership context

#### 3. `trace_change_impact`
Purpose:
- Estimate what is likely affected by changing a file, symbol, route, or interface.

Inputs:
- target
- direction (`upstream`, `downstream`, or equivalent)
- optional depth

Outputs:
- affected files/symbols/processes/routes
- confidence or strength notes
- grouped impact levels if available

#### 4. `trace_execution_or_usage`
Purpose:
- Follow likely execution or usage paths related to a concept, symbol, route, or subsystem.

Inputs:
- concept or target
- optional scope hints

Outputs:
- execution/usage path summary
- ranked participating symbols/files
- optional process or route context

#### 5. `build_task_context_package`
Purpose:
- Produce a compact, coding-ready context package for implementation, debugging, or review work.

Inputs:
- task_query
- optional target files/symbols
- optional limits

Outputs:
- prioritized files/symbols
- rationale for inclusion
- optional risk notes / dependency notes
- compact summary designed for prompt injection or handoff

### Optional capability extensions
These should not be required for the first backend implementation.

#### `query_graph`
- for advanced graph-native analysis
- optional because not every backend should expose raw graph querying to callers

#### `rename_symbol_preview`
- preview coordinated rename impact
- optional until trust and product scope justify refactor support

#### `route_api_impact`
- specialized API/route impact reporting
- optional but highly valuable for service-heavy repos

### Backend capability model
Each backend should declare capabilities such as:
- `relevance_retrieval`
- `symbol_context`
- `impact_analysis`
- `execution_trace`
- `context_packaging`
- `graph_query`
- `rename_preview`
- `api_route_impact`

Calling layers should degrade gracefully if a backend lacks an optional capability.

### What the interface must not do
- it must not expose codedb-specific storage or schema concepts as the primary user-facing contract
- it must not require graph-query literacy for normal coding workflows
- it must not assume one repository model or one language strategy forever
- it must not bake first-wave benchmark assumptions into permanent product semantics

### Minimum viable backend contract for EC-B-3
A first codedb-backed spike should be considered valid if it can support:
- `find_relevant_context`
- `explain_symbol_or_file`
- `trace_change_impact`
- `build_task_context_package`

That is enough to benchmark the core value of code intelligence for Aizen without overcommitting to advanced features.

### Future native compatibility
This interface leaves room for:
- codedb as the first serious backend
- lighter-weight indexing fallback inspired by zindeks or simple structural search
- a future native Aizen Code Graph direction if benchmark results justify it

### EC-B-2 conclusion
The Aizen code-intelligence interface should stay workflow-first, backend-agnostic, and small at the base layer. codedb may be the first backend, but the interface should be owned by Aizen and remain compatible with future native or lighter-weight alternatives.

---

## Changelog
- **2026-05-05**: Executed EC-A-1 through EC-A-4 in-document and created the first authoritative execution artifact for the external capability board.
- **2026-05-05**: Executed EC-B-1 and EC-B-2, adding the codedb pain-point audit and the first Aizen code-intelligence backend interface draft.
