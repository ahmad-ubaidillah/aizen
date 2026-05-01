# AizenOrchestrate Documentation

This directory contains integration guides for different deployment modes.

## Choose by scenario

1. Single orchestrator with Aizen workers:
   `aizen-orchestrate + aizen`
   See: `single-aizen-integration.md`
2. Multi-agent/multi-provider orchestration:
   `aizen-orchestrate + (aizen | zeroclaw | openclaw | picoclaw bridge)`
   See: `multi-bot-integration.md`
3. Full async loop with durable task queue:
   `aizen-kanban + aizen-orchestrate + aizen`
   See: `aizen-kanban-aizen-orchestrate-aizen.md`
4. Containerized local stack with profiles:
   `docker compose + aizen-orchestrate + aizen + aizen-kanban`
   See: `docker-compose-aizen-kanban-aizen.md`

## Document map

- `single-aizen-integration.md`
  Required gateway pairing/token setup and supported response payloads.
- `multi-bot-integration.md`
  Worker protocol matrix, config examples, PicoClaw bridge, and tracker bridge entrypoint.
- `aizen-kanban-aizen-orchestrate-aizen.md`
  End-to-end native pull-mode flow, prerequisites, workflow layout, and environment variables.
- `docker-compose-aizen-kanban-aizen.md`
  Compose profiles, required config alignment, and full-stack smoke test.

## Design principle

AizenOrchestrate stays orchestration-focused. Execution logic belongs to workers (for example Aizen), and durable queue/state logic belongs to AizenKanban. You can run each component independently or combine them per workload requirements.
