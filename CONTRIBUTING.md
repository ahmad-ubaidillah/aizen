# Contributing to Aizen

> **Status**: CURRENT — Last updated 2026-05-05

Terima kasih atas minat Anda untuk berkontribusi pada Aizen. Dokumen ini adalah panduan kontribusi untuk seluruh monorepo Aizen.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Monorepo Structure](#monorepo-structure)
3. [Development Workflow](#development-workflow)
4. [Code Standards](#code-standards)
5. [Testing](#testing)
6. [Documentation](#documentation)
7. [Commit Guidelines](#commit-guidelines)
8. [Security](#security)
9. [Review Process](#review-process)

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Zig | **0.16.0** | Primary language (aizen-core) |
| Node.js | 20.x+ | Dashboard dan tooling |
| pnpm | 9.x+ | Package manager (monorepo) |
| Docker | Latest | Containerization dan deployment |
| Git | 2.40+ | Version control |

Verify toolchain:

```bash
zig version          # Expected: 0.16.0
node --version       # Expected: v20.x.x
pnpm --version       # Expected: 9.x.x
docker --version     # Any recent version
git --version        # 2.40+
```

### Recommended

- **VS Code** dengan extensions:
  - Zig Language (ziglang.vscode-zig)
  - Error Lens
  - GitLens

---

## Monorepo Structure

```
aizen/
├── aizen-core/          # Zig — Agent engine, gateway, providers
├── aizen-dashboard/     # Zig — Web dashboard (Zig + WebAssembly)
├── aizen-kanban/        # TypeScript — Kanban board UI
├── aizen-orchestrate/   # TypeScript — Workflow orchestration
├── aizen-skill-bridge/  # TypeScript — Skill marketplace
├── aizen-watch/         # TypeScript — Monitoring dan alerting
├── docs/                # Dokumentasi (Markdown)
├── docker/              # Docker configurations
└── scripts/             # Build dan utility scripts
```

**Rule of thumb:**
- Performance-critical code (agent engine, gateway) → `aizen-core` (Zig)
- UI dan business logic → TypeScript packages
- Shared types → `packages/shared-types`

---

## Development Workflow

### 1. Clone dan Setup

```bash
git clone https://github.com/aizen/aizen.git
cd aizen

# Install dependencies
pnpm install

# Build core
zig build
```

### 2. Branch Naming

```
feature/<name>      # New feature
fix/<name>          # Bug fix
docs/<name>         # Documentation update
refactor/<name>     # Code refactoring
test/<name>         # Test improvements
security/<name>     # Security fix
```

### 3. Commit Message Format

Gunakan [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat` — New feature
- `fix` — Bug fix
- `docs` — Documentation only
- `style` — Formatting (no logic change)
- `refactor` — Code refactoring
- `test` — Adding or updating tests
- `build` — Build system changes
- `ci` — CI/CD changes
- `perf` — Performance improvement
- `security` — Security fix

**Scopes:**
- `core` — aizen-core
- `dashboard` — aizen-dashboard
- `kanban` — aizen-kanban
- `orchestrate` — aizen-orchestrate
- `skill-bridge` — aizen-skill-bridge
- `watch` — aizen-watch
- `docs` — Documentation
- `deps` — Dependencies

**Examples:**

```bash
feat(core): add Credential Pool untuk multi-key rotation
fix(gateway): handle WhatsApp webhook verification timeout
docs(api): tambahkan endpoint dokumentasi untuk cron jobs
security(core): harden pairing token dengan constant-time comparison
```

---

## Code Standards

### Zig (aizen-core)

- **Allocator pattern**: Selalu pass allocator explicitly, jangan gunakan global allocator
- **Error handling**: Gunakan `try` dan `errdefer` untuk resource cleanup
- **Naming**: `snake_case` untuk functions/variables, `PascalCase` untuk types, `SCREAMING_SNAKE_CASE` untuk constants
- **Comments**: Doc comments (`///`) untuk public API, inline comments untuk logic complex
- **Safety**: Prioritaskan memory safety — Zig bukan C, gunakan bounds checking

**Example:**

```zig
/// Parse webhook payload dan extract routing information.
/// Caller owns returned memory.
pub fn parseWebhookRouting(
    allocator: std.mem.Allocator,
    body: []const u8,
) !WebhookRouting {
    var routing = WebhookRouting{};
    errdefer routing.deinit(allocator);
    
    // Parse JSON body
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        body,
        .{},
    );
    defer parsed.deinit();
    
    // Extract sender information
    routing.sender_id = try allocator.dupe(u8, parsed.value.object.get("sender_id").?.string);
    
    return routing;
}
```

### TypeScript

- **Strict mode**: Selalu aktifkan `strict: true` di tsconfig
- **Types**: Hindari `any`, gunakan `unknown` dengan type guards
- **Async**: Prefer `async/await` daripada raw Promises
- **Error handling**: Gunakan custom error classes, jangan throw generic Error

---

## Testing

### Zig Tests

```bash
# Run all tests
cd aizen-core
zig build test --summary all

# Run specific test
cd aizen-core
zig test src/gateway.zig

# Run with coverage (experimental)
zig build test -Dcoverage
```

### TypeScript Tests

```bash
# Run all tests
pnpm test

# Run specific package
pnpm --filter aizen-kanban test

# Run with coverage
pnpm test --coverage
```

### Integration Tests

```bash
# Build dan test full stack
docker compose -f docker/docker-compose.test.yml up --build

# Run smoke tests
./scripts/smoke-test.sh
```

### Test Requirements

- **Unit tests**: Setiap module harus memiliki tests
- **Integration tests**: Setiap feature harus memiliki minimal 1 integration test
- **Coverage target**: >80% untuk core logic
- **Flaky tests**: Tidak diperbolehkan — fix atau skip dengan TODO

---

## Documentation

### Dokumentasi Wajib

Setiap PR yang mengubah behavior harus update dokumen berikut:

| Dokumen | Kapan Update |
|---------|-------------|
| `docs/API.md` | Menambah/mengubah endpoint |
| `docs/architecture.md` | Mengubah arsitektur system |
| `docs/TROUBLESHOOTING.md` | Menambah known issue |
| `CHANGELOG.md` | Semua user-facing changes |
| `docs/gap-analysis.md` | Menyelesaikan gap |
| `docs/task-list.md` | Menyelesaikan task |

### Dokumentasi Code

- **Public API**: Harus memiliki doc comments
- **Complex logic**: Inline comments menjelaskan "why", bukan "what"
- **TODO comments**: Gunakan format `TODO(username): description`

---

## Commit Guidelines

### Pre-commit Checklist

```bash
# 1. Format code
zig fmt src/**/*.zig          # Zig files
pnpm format                    # TypeScript files

# 2. Run linter
zig build lint                 # Zig lint
pnpm lint                      # TypeScript lint

# 3. Run tests
zig build test --summary all   # Zig tests
pnpm test                      # TypeScript tests

# 4. Check documentation
# - Update CHANGELOG.md
# - Update relevant docs/*.md
# - Pastikan tidak ada broken links

# 5. Review sendiri
# - Baca diff dengan `git diff`
# - Pastikan tidak ada debug prints
# - Pastikan tidak ada secrets
```

### Commit Size

- **Ideal**: 1 concern per commit
- **Maximum**: 500 lines changed per commit (kecuali generated code)
- **Squash**: Gunakan `git rebase -i` untuk cleanup history sebelum PR

---

## Security

### Security Checklist

- [ ] Tidak ada hardcoded secrets (gunakan environment variables)
- [ ] Tidak ada debug prints yang expose sensitive data
- [ ] Input validation untuk semua user inputs
- [ ] Rate limiting untuk semua public endpoints
- [ ] Constant-time comparison untuk token verification
- [ ] Memory safety — tidak ada buffer overflows

### Reporting Security Issues

Jangan buka public issue untuk security vulnerabilities. Kirim email ke:

```
security@aizen.dev
```

Dengan subject: `[SECURITY] Brief description`

---

## Review Process

### PR Requirements

1. **Title**: Format `type(scope): description`
2. **Description**: Template berikut harus diisi:
   - What changed?
   - Why?
   - How to test?
   - Breaking changes?
3. **Tests**: Semua tests harus pass
4. **Docs**: Dokumentasi harus updated
5. **Size**: Prefer PR kecil (<500 lines)

### Review Timeline

- **Trivial fixes** (docs, typos): 1 reviewer, merge setelah 24 jam
- **Bug fixes**: 1 reviewer, merge setelah approval
- **Features**: 2 reviewers, merge setelah approval
- **Security**: 2 reviewers + security review, merge setelah approval

### Merge Strategy

- **Default**: Squash and merge
- **Exception**: Rebase and merge untuk PR yang sudah memiliki clean history

---

## Getting Help

- **Discord**: [Aizen Discord](https://discord.gg/aizen)
- **Issues**: GitHub Issues untuk bug reports dan feature requests
- **Discussions**: GitHub Discussions untuk questions dan ideas

---

## License

Dengan berkontribusi, Anda setuju bahwa kontribusi Anda akan dilisensikan di bawah [MIT License](LICENSE).
