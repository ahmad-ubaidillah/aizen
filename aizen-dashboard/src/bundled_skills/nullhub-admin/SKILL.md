---
name: aizen-dashboard-admin
version: 0.1.0
description: Teach managed aizen agents to discover AizenDashboard routes first and then use aizen-dashboard api for instance, provider, component, and orchestration tasks.
always: true
requires_bins:
  - aizen-dashboard
---

# AizenDashboard Admin

Use this skill whenever the task involves `aizen-dashboard`, AizenDashboard-managed instances, providers, components, or orchestration routes.

Workflow:

1. Do not ask the user for the exact `aizen-dashboard` command or endpoint if `aizen-dashboard` can discover it.
2. Start with `aizen-dashboard routes --json` to discover the current route contract.
3. Use `aizen-dashboard api <METHOD> <PATH>` for the actual operation.
4. Prefer a read operation first unless the user already gave a precise destructive intent.
5. After a mutation, verify with a follow-up `GET`.

Rules:

- Prefer `aizen-dashboard api` over deleting files directly when AizenDashboard owns the cleanup.
- If a route or payload is unclear, inspect `aizen-dashboard routes --json` again instead of guessing or asking the user for syntax.
- Use `--pretty` for user-facing inspection output.
- Use `--body` or `--body-file` for JSON request bodies.
- If path segments come from arbitrary ids or names, percent-encode them before building the request path.
- Do not claim a route exists until it is confirmed by `aizen-dashboard routes --json` or a successful request.

Common patterns:

```bash
aizen-dashboard routes --json
aizen-dashboard api GET /api/meta/routes --pretty
aizen-dashboard api GET /api/components --pretty
aizen-dashboard api GET /api/instances --pretty
aizen-dashboard api GET /api/instances/aizen/instance-1 --pretty
aizen-dashboard api GET /api/instances/aizen/instance-1/skills --pretty
aizen-dashboard api DELETE /api/instances/aizen/instance-2
aizen-dashboard api POST /api/providers/2/validate
```

Shorthand paths are allowed:

```bash
aizen-dashboard api GET instances
aizen-dashboard api POST providers/2/validate
```
