# Orchestration Gaps Design — Phase 2

**Date:** 2026-03-13
**Status:** Draft
**Scope:** AizenOrchestrate, AizenKanban, AizenDashboard
**Branch:** feat/orchestration (extends Phase 1)

---

## Overview

Phase 2 closes remaining gaps vs LangGraph and Symphony. No backward compatibility needed.

---

## 1. Command Primitive

Nodes can return `goto` alongside `state_updates` to control routing:

```json
{
    "state_updates": {"review_grade": "approve"},
    "goto": "merge_step"
}
```

Engine behavior: if response contains `goto`, skip normal edge evaluation and jump directly to the named node. The node must exist in the workflow. `goto` can be a string (single node) or array (fan-out to multiple nodes).

Worker response JSON:
```json
{"response": "Approved", "goto": "merge_step"}
```

Engine parses `goto` from worker response alongside the text response. For `task` and `agent` nodes only. `route`, `transform`, `interrupt` nodes don't use `goto`.

---

## 2. Subgraphs

New node type `subgraph`:

```json
{
    "review_flow": {
        "type": "subgraph",
        "workflow_id": "code-review-workflow",
        "input_mapping": {
            "code": "state.fix_result",
            "description": "state.task_description"
        },
        "output_key": "review_result"
    }
}
```

Engine behavior:
1. Load workflow definition from `workflows` table by `workflow_id`
2. Build subgraph input from parent state via `input_mapping` (key = subgraph input key, value = parent state path)
3. Create a child run with `createRunWithState()`, linking to parent via a new `parent_run_id` column
4. Execute child run to completion (inline, not spawning a separate engine tick loop — just call `processRun` recursively)
5. On completion, extract child's final state and write to parent's `output_key`
6. On failure, propagate failure to parent run

### Schema changes

```sql
ALTER TABLE runs ADD COLUMN parent_run_id TEXT REFERENCES runs(id);
```

### StepType update

Add `subgraph` to StepType enum in types.zig.

---

## 3. Breakpoints on Any Node

Workflow-level config:

```json
{
    "interrupt_before": ["review", "merge"],
    "interrupt_after": ["generate"],
    ...
}
```

Engine behavior: before executing a node, check if it's in `interrupt_before`. If so, save checkpoint and set run to `interrupted`. After executing a node, check `interrupt_after`. Same behavior.

Resume works exactly like interrupt node resume — `POST /runs/{id}/resume` with optional `state_updates`.

This is purely engine logic — no schema changes, no new API endpoints.

---

## 4. Store API in AizenKanban

New table:

```sql
CREATE TABLE store (
    namespace TEXT NOT NULL,
    key TEXT NOT NULL,
    value_json TEXT NOT NULL,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL,
    PRIMARY KEY (namespace, key)
);
CREATE INDEX idx_store_namespace ON store(namespace);
```

### API endpoints

```
PUT    /store/{namespace}/{key}     — put (upsert)
GET    /store/{namespace}/{key}     — get single
GET    /store/{namespace}           — list all in namespace
DELETE /store/{namespace}/{key}     — delete
DELETE /store/{namespace}           — delete namespace
```

Request body for PUT:
```json
{"value": {"any": "json"}}
```

Response for GET:
```json
{
    "namespace": "user_123",
    "key": "preferences",
    "value": {"theme": "dark"},
    "created_at_ms": 1710300000000,
    "updated_at_ms": 1710300005000
}
```

### Usage from AizenOrchestrate workflows

New template syntax: `{{store.namespace.key}}` — engine fetches from aizen-kanban Store API during prompt rendering.

Runtime resolution:

- AizenKanban base URL comes from workflow-level `tracker_url` / `aizen-kanban_url`, or from run config (`config.tracker_url`, surfaced as `state.__config.tracker_url`).
- Optional auth token comes from `tracker_api_token` / `aizen-kanban_api_token` on the workflow or run config.
- Missing store keys render as empty strings in templates.

New node type isn't needed — `task` nodes can read via template, and `transform` nodes can write via a `store_updates` field (single object or array of objects):

```json
{
    "save_context": {
        "type": "transform",
        "updates": {},
        "store_updates": {
            "namespace": "project_context",
            "key": "latest_review",
            "value": "state.review_result"
        }
    }
}
```

`store_updates.value` can point at a state path such as `state.review_result`, or it can be inline JSON that will be written as-is.

Engine calls aizen-kanban `PUT /store/{namespace}/{key}` after `updates` are applied, so writes can reference the node's freshly updated state.

---

## 5. Multi-Turn Continuation

Extend `agent` node with multi-turn support:

```json
{
    "fix_bug": {
        "type": "agent",
        "prompt": "Fix this: {{state.task_description}}",
        "continuation_prompt": "Task is still active. Continue from current state.",
        "max_turns": 10,
        "tags": ["coder"],
        "output_key": "fix_result"
    }
}
```

Engine behavior:
1. Turn 1: A2A `tasks/send` with rendered `prompt`, `contextId = "run_{id}_step_{name}"`
2. Parse response — check if agent indicated completion (response contains final answer, no pending tool calls)
3. If not complete and turn < `max_turns`: send `continuation_prompt` via A2A with same `contextId` (session persistence)
4. Repeat until complete or `max_turns` exhausted
5. Final response text → state_updates via `output_key`

Between turns, engine can:
- Check if aizen-kanban task state changed (reconciliation)
- Apply pending state injections
- Broadcast SSE `agent_turn` events

No schema changes needed — this is engine logic using existing A2A infrastructure.

---

## 6. Configurable Runs

Workflow JSON gets optional `defaults` section:

```json
{
    "defaults": {
        "model": "claude-sonnet-4-6",
        "temperature": 0.7,
        "max_agent_turns": 10
    },
    ...
}
```

Run creation accepts `config` overrides:

```
POST /workflows/{id}/run
{
    "input": {"task": "fix bug"},
    "config": {"model": "claude-opus-4-6", "temperature": 0.3}
}
```

Merged config (run overrides > workflow defaults) stored in `run.config_json`.

Template access: `{{config.model}}`, `{{config.temperature}}`.

### Schema changes

```sql
ALTER TABLE runs ADD COLUMN config_json TEXT;
```

---

## 7. Per-State Concurrency in AizenKanban

Extend aizen-kanban claim endpoint to support per-state limits.

Claim request gets optional `concurrency` parameter:

```
POST /leases/claim
{
    "agent_id": "boiler-01",
    "agent_role": "coder",
    "concurrency": {
        "per_state": {"in_progress": 5, "rework": 2}
    }
}
```

Claim logic: before returning a task, count currently-leased tasks in the same state. If at limit, skip to next eligible task.

This is a aizen-kanban store.zig change in the claim query.

---

## 8. Reconciliation

Engine tick adds a reconciliation step for runs linked to aizen-kanban tasks:

After each step completes, if `run.task_id` is set (pull-mode run):
1. Fetch current task state from aizen-kanban: `GET /tasks/{task_id}`
2. If task state changed to a terminal state → cancel the run
3. If task state changed to a different active state → update run metadata, continue

This prevents wasted agent execution on tasks that humans already resolved.

Engine logic only — no schema changes.

---

## 9. Workspace Reuse Per Issue

In AizenOrchestrate's tracker/workspace system, workspaces should be reused for the same aizen-kanban task:

- Workspace directory name based on `task_id` (not `run_id`)
- On new run for same task: reuse existing workspace (skip `after_create` hook, still run `before_run`)
- On task completion: run `after_run` hook, keep workspace
- On task terminal state + configurable cleanup: run `before_remove`, delete workspace

This is a tracker.zig + workspace.zig change.

---

## 10. Message-Native State (add_messages reducer)

New reducer type `add_messages`:

```json
{
    "state_schema": {
        "messages": {"type": "array", "reducer": "add_messages"}
    }
}
```

Behavior:
- Each message has an `id` field
- On update: if message with same `id` exists, replace it. Otherwise append.
- Special: if update contains `{"remove": true, "id": "msg_123"}`, remove that message.
- If message has no `id`, auto-generate one and append.

This enables chat-history-aware workflows where messages can be updated or removed by ID.

Implementation: new case in `state.zig` `applyReducer()`.

### ReducerType update

Add `add_messages` to ReducerType enum in types.zig.

---

## Summary of Changes

| Repo | Changes |
|------|---------|
| AizenOrchestrate types.zig | Add `subgraph` to StepType, `add_messages` to ReducerType |
| AizenOrchestrate engine.zig | Command goto, subgraph execution, breakpoints, multi-turn, reconciliation, store_updates |
| AizenOrchestrate state.zig | add_messages reducer |
| AizenOrchestrate store.zig | `parent_run_id` + `config_json` columns |
| AizenOrchestrate api.zig | config in run creation, template store access |
| AizenOrchestrate templates.zig | `{{store.X.Y}}`, `{{config.X}}` access |
| AizenOrchestrate tracker.zig | Workspace reuse, reconciliation |
| aizen-kanban store.zig | Store KV CRUD, per-state concurrency in claim |
| aizen-kanban api.zig | Store endpoints, claim concurrency param |
| aizen-kanban migrations | Store table |
| aizen-dashboard UI | Store viewer page (optional) |
