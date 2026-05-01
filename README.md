# Aizen Agent

**Execute with Zen.**

Aizen is a Zig-first autonomous AI agent runtime that combines:
- **NullClaw's** extreme minimalism and vtable plugin architecture (678KB binary, 1MB RAM, <2ms boot)
- **Zeph's** intelligence features (SYNAPSE graph memory, 8-layer security, self-learning skills)
- **Hermes's** skill breadth (25+ categories, 20+ platforms, autonomous skill creation)

## Ecosystem

| Service | Port | Description |
|---------|------|-------------|
| aizen-core | 8080 | Agent runtime, providers, channels, tools, memory |
| aizen-dashboard | 3000 | Management hub + chat UI |
| aizen-watch | 7710 | Observability, traces, evals |
| aizen-kanban | 7720 | Task tracking, pipeline FSM |
| aizen-orchestrate | 7730 | Workflow engine, checkpoints, SSE |
| aizen-skill-bridge | — | Python skill loader (SKILL.md compatible) |

## Quick Start

```bash
# Build all services
make build

# Run smoke tests
make test

# Start aizen-core
./aizen-core

# Start dashboard
./aizen-dashboard
```

## Architecture

See [Architecture Design](docs/architecture-design.md) and [PM Spec](docs/pm-spec.md).

## License

MIT
