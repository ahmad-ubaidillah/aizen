# Multi-Agent MQTT/Redis Example

Demonstrates AizenOrchestrate orchestrating Aizen agents via MQTT and Redis Stream dispatch protocols.

## Architecture

```
AizenOrchestrate (orchestrator)
  ├─ MQTT publish ──> broker:1883 ──> planner agent
  │   └─ MQTT subscribe <── planner responses
  └─ Redis XADD ──> redis:6379 ──> builder agent
      └─ Redis XREADGROUP <── builder responses
```

## Config

- `planner` worker: dispatched via MQTT (`mqtt://broker:1883/aizen/planner/requests`)
- `builder` worker: dispatched via Redis Stream (`redis://redis:6379/aizen:builder:requests`)

Response topics/streams are auto-derived:
- MQTT: `aizen/planner/requests/responses`
- Redis: `aizen:builder:requests:responses`

## Wire Format

### Request (AizenOrchestrate -> worker)

```json
{
  "correlation_id": "run_xxx_step_yyy",
  "reply_to": "aizen/planner/requests/responses",
  "timestamp_ms": 1709578800000,
  "token": "planner-secret",
  "message": "rendered prompt text",
  "session_key": "run_xxx_step_yyy"
}
```

### Response (worker -> AizenOrchestrate)

```json
{
  "correlation_id": "run_xxx_step_yyy",
  "timestamp_ms": 1709578805000,
  "response": "agent output text"
}
```

Error:
```json
{
  "correlation_id": "run_xxx_step_yyy",
  "error": "something went wrong"
}
```

## Usage

```bash
# Start AizenOrchestrate with this config
./zig-out/bin/aizen-orchestrate --config examples/multi-agent-mqtt/config.json

# Submit a workflow (uses plan-then-build from multi-agent-slack example)
curl -X POST http://localhost:8080/runs \
  -H "Content-Type: application/json" \
  -d '{
    "strategy": "sequential",
    "steps": [
      {"id": "plan", "type": "task", "worker_tags": ["planner"],
       "prompt_template": "Plan: {{input.goal}}"},
      {"id": "build", "type": "task", "worker_tags": ["builder"],
       "prompt_template": "Build from plan: {{steps.plan.output}}"}
    ],
    "input": {"goal": "Build a REST API"}
  }'
```

## Prerequisites

- MQTT broker (e.g., Mosquitto) running on `broker:1883`
- Redis server running on `redis:6379`
- Aizen agents configured to consume from the respective topics/streams
