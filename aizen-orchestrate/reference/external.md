# External Requirements for End-to-End Flow

This file lists what **must exist** in external projects (`aizen`, `aizen-kanban`) for the current AizenOrchestrate flow to work.

## 1) aizen must-have contract (for AizenOrchestrate worker dispatch)

1. Expose an HTTP webhook endpoint with an explicit path, normally `/webhook`.
2. Accept `POST` requests with `Content-Type: application/json`.
3. Accept Bearer auth when worker `token` is configured in AizenOrchestrate (`Authorization: Bearer <token>`).
4. Accept request body fields produced by AizenOrchestrate webhook protocol:
   - `message` (string)
   - `text` (string)
   - `session_key` (string)
   - `session_id` (string)
5. Return HTTP `2xx` for successful execution.
6. Return a JSON object with a synchronous result in `response` (string).
   - Canonical working shape: `{"status":"ok","response":"..."}`
7. Do not return async-only ack without output for sync orchestration.
   - `{"status":"received"}` without `response` is treated by AizenOrchestrate as an error.

## 2) aizen-kanban must-have contract (for native tracker runtime)

1. `POST /leases/claim`
   - Request JSON: `{"agent_id":"...","agent_role":"...","lease_ttl_ms":<int>}`
   - Responses:
     - `204` when no task is available.
     - `200` with JSON containing: `task`, `run`, `lease_id`, `lease_token`, `expires_at_ms`.
2. `POST /leases/{lease_id}/heartbeat`
   - Must accept header `Authorization: Bearer <lease_token>`.
   - Must return `200` with refreshed `expires_at_ms` while lease is valid.
3. `POST /runs/{run_id}/events`
   - Must accept header `Authorization: Bearer <lease_token>`.
   - Request JSON: `{"kind":"...","data":{...}}`
   - Expected status: `200` or `201`.
4. `POST /runs/{run_id}/transition`
   - Must accept header `Authorization: Bearer <lease_token>`.
   - Request JSON: `{"trigger":"...","expected_stage":"...","expected_task_version":<int>,"usage":{...}}`
   - Expected status: `200`.
5. `POST /runs/{run_id}/fail`
   - Must accept header `Authorization: Bearer <lease_token>`.
   - Request JSON: `{"error":"...","usage":{...}}` (`usage` optional)
   - Expected status: `200`.
6. `GET /tasks/{task_id}`
   - Must return `200` with full task payload including `task_version` and `available_transitions`.
   - Each transition object must contain string `trigger`.
7. Pipeline/task role alignment must exist:
   - task current stage must be claimable by the workflow `claim_role`.
   - otherwise `POST /leases/claim` will never provide relevant work.

## 3) Optional but required for full observability

1. `POST /artifacts` in aizen-kanban for attaching execution reports.
   - The native tracker runtime uses payload: `task_id`, `run_id`, `kind`, `uri`, `meta`.
   - If unsupported, orchestration still works, but report artifact persistence is lost.

## 4) Compose profile requirements (if using this repo's docker-compose)

1. aizen must provide `GET /health` (used by compose healthcheck).
2. aizen-kanban must provide `GET /health` (used by compose healthcheck).
3. aizen pairing token must match AizenOrchestrate worker token.
4. AizenOrchestrate worker URL for aizen must include explicit path, e.g. `http://aizen:3000/webhook`.
