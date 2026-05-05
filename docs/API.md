# Aizen API Reference

> **Status**: CURRENT — Last updated 2026-05-05
> **Scope**: aizen-core HTTP Gateway + CLI commands

---

## Table of Contents

1. [HTTP Gateway](#http-gateway)
2. [CLI Commands](#cli-commands)
3. [WebSocket](#websocket)
4. [A2A Protocol](#a2a-protocol)
5. [Agent Card](#agent-card)
6. [Error Codes](#error-codes)

---

## HTTP Gateway

Base URL: `http://localhost:<port>` (default port dari config)

### Health & Status

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/health` | No | Liveness probe — returns `200 OK` jika server running |
| `GET` | `/ready` | No | Readiness probe — checks all subsystems (memory, providers, channels) |
| `GET` | `/status` | Bearer | System status lengkap dengan metrics |
| `GET` | `/doctor` | Bearer | Diagnostic report — sama seperti `aizen doctor` CLI |

**Response `/health`:**
```json
{
  "status": "ok",
  "timestamp": "2026-05-05T07:30:00Z"
}
```

**Response `/ready`:**
```json
{
  "ready": true,
  "checks": {
    "memory": "ok",
    "providers": "ok",
    "channels": "ok"
  }
}
```

### Authentication

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/pair` | No | Pairing flow — generate pairing code untuk first-time setup |
| `POST` | `/logout` | Bearer | Revoke session token |

**Headers:**
```
Authorization: Bearer <token>
```

### Webhook — Generic

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/webhook` | Bearer | Generic webhook endpoint untuk custom integrations |

### Channel Webhooks

Semua channel webhooks menerima payload dari platform masing-masing dan merespons sesuai format platform.

| Method | Endpoint | Platform | Auth |
|--------|----------|----------|------|
| `POST` | `/telegram` | Telegram | Bot token (via query param atau header) |
| `GET/POST` | `/whatsapp` | WhatsApp | Hub verify token (GET), signature (POST) |
| `POST` | `/slack/events` | Slack | Slack signature verification |
| `POST` | `/line` | LINE | Channel signature |
| `POST` | `/lark` | Lark | Request signature |
| `GET/POST` | `/wechat` | WeChat | Message signature (GET), encrypted payload (POST) |
| `GET/POST` | `/wecom` | WeCom | Same as WeChat |
| `POST` | `/qq` | QQ | App signature |
| `POST` | `/max` | MAX (Kakao) | Secret key |
| `POST` | `/api/messages` | Microsoft Teams | HMAC signature |

**Query Parameters (WhatsApp GET):**
```
GET /whatsapp?hub.mode=subscribe&hub.challenge=abc&hub.verify_token=mytoken
```

### Cron Management

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/cron` | Bearer | List all scheduled jobs |
| `POST` | `/cron` | Bearer | Add new scheduled job |
| `DELETE` | `/cron/:id` | Bearer | Remove scheduled job |
| `POST` | `/cron/:id/pause` | Bearer | Pause scheduled job |
| `POST` | `/cron/:id/resume` | Bearer | Resume scheduled job |
| `PUT` | `/cron/:id` | Bearer | Update scheduled job |

**Request body `POST /cron`:**
```json
{
  "schedule": "0 9 * * *",
  "command": "agent -m 'Daily report'",
  "timezone": "Asia/Jakarta"
}
```

### A2A Protocol

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/a2a` | Bearer | Agent-to-Agent protocol endpoint |

**Request body:**
```json
{
  "jsonrpc": "2.0",
  "method": "tasks/send",
  "params": {
    "id": "task-123",
    "message": {
      "role": "user",
      "parts": [{"type": "text", "text": "Hello"}]
    }
  }
}
```

### Agent Card

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/.well-known/agent-card.json` | No | Agent Card (A2A spec) |
| `GET` | `/.well-known/agent.json` | No | Alias untuk agent-card.json |

**Response:**
```json
{
  "name": "Aizen Agent",
  "description": "AI agent dengan multi-channel support",
  "version": "1.0.0",
  "capabilities": {
    "streaming": true,
    "pushNotifications": false
  }
}
```

---

## CLI Commands

### Core Commands

| Command | Description |
|---------|-------------|
| `aizen agent` | Jalankan agent mode (interactive atau single prompt) |
| `aizen daemon` | Jalankan background daemon dengan HTTP gateway |
| `aizen doctor` | Jalankan diagnostic checks |
| `aizen config` | Manage configuration |
| `aizen memory` | Memory management commands |
| `aizen channels` | Channel management |
| `aizen tools` | Tool management |
| `aizen cron` | Cron job management |
| `aizen version` | Show version info |

### Agent Command Options

```bash
aizen agent \
  -m "Hello world" \              # Prompt message
  --provider "openai" \           # Provider (openai, anthropic, google, custom:URL)
  --model "gpt-4o" \              # Model name
  --system "You are a helper" \   # System prompt
  --file document.pdf \           # Attach file
  --image screenshot.png \         # Attach image
  --web \                          # Enable web search
  --no-stream                     # Non-streaming mode
```

### Daemon Command Options

```bash
aizen daemon \
  --port 8080 \                   # HTTP port (default: dari config)
  --pairing-code 123456 \         # Pre-set pairing code
  --no-pairing                    # Disable pairing (dangerous)
```

---

## WebSocket

Endpoint: `ws://localhost:<port>/ws`

**Connection:**
```javascript
const ws = new WebSocket('ws://localhost:8080/ws');
ws.send(JSON.stringify({
  type: 'subscribe',
  channel: 'events'
}));
```

**Event types:**
- `message` — Incoming message dari channel
- `tool_start` — Tool execution started
- `tool_result` — Tool execution completed
- `agent_response` — Agent response chunk (streaming)
- `error` — Error event

---

## A2A Protocol

Aizen mengimplementasikan [A2A (Agent-to-Agent) Protocol](https://github.com/google/A2A) dari Google.

### Supported Methods

| Method | Description |
|--------|-------------|
| `tasks/send` | Send task ke agent |
| `tasks/get` | Get task status |
| `tasks/cancel` | Cancel running task |
| `tasks/sendSubscribe` | Send task dengan streaming updates |

### Authentication

A2A endpoint menggunakan Bearer token yang sama dengan gateway.

---

## Error Codes

| HTTP Status | Code | Description |
|-------------|------|-------------|
| `400` | `BAD_REQUEST` | Invalid request body atau parameters |
| `401` | `UNAUTHORIZED` | Missing atau invalid Bearer token |
| `403` | `FORBIDDEN` | Valid token tapi insufficient permissions |
| `404` | `NOT_FOUND` | Endpoint atau resource tidak ditemukan |
| `429` | `RATE_LIMITED` | Too many requests (sliding window) |
| `500` | `INTERNAL_ERROR` | Server error |
| `503` | `NOT_READY` | Service belum ready (lihat `/ready`) |

**Error response format:**
```json
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Too many requests from this IP",
    "retry_after": 60
  }
}
```

---

## Rate Limits

- **Window**: 60 detik (sliding window)
- **Default limit**: 100 requests per IP per window
- **Webhook endpoints**: 1000 requests per IP per window
- **Sweep interval**: 5 menit (cleanup stale entries)

---

## Security

- **Body size limit**: 64KB default (configurable)
- **Request timeout**: 30 detik default (configurable)
- **Authentication**: Bearer token via `Authorization` header
- **Pairing**: Required untuk first-time setup (kecuali `--no-pairing`)
- **Constant-time comparison**: Untuk token verification (timing attack resistant)

---

## Related Documents

- [Architecture](architecture.md) — System architecture overview
- [Security](security.md) — Security policies dan hardening
- [Channels](channels.md) — Channel configuration guide
- [TROUBLESHOOTING](TROUBLESHOOTING.md) — Common issues dan solutions
