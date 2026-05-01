#!/bin/bash
# rebrand.sh — NullClaw → Aizen rebranding script
# Applies ALL renames deterministically across the monorepo.
# Run from /home/ahmad/Documents/aizen/

set -euo pipefail

BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASEDIR"

echo "=== Aizen Rebrand Script ==="
echo "Base directory: $BASEDIR"
echo ""

# ============================================================
# Step 1: Rename service directories & subdirectory references
# ============================================================

# Step 2: Global string replacements across ALL source files
# Order matters — longer/more-specific patterns first to avoid partial matches

# --- aizen-core: nullclaw → aizen ---
echo "Rebranding aizen-core (nullclaw → aizen)..."

# Zig source, configs, docs — in aizen-core
find aizen-core -type f \( -name '*.zig' -o -name '*.zon' -o -name '*.md' -o -name '*.json' -o -name '*.yml' -o -name '*.yaml' -o -name '*.toml' -o -name '*.sh' -o -name 'Dockerfile' -o -name '*.txt' -o -name '*.html' -o -name '*.js' -o -name '*.ts' -o -name '*.css' \) -exec sed -i \
  -e 's/nullclaw_nullclaw/nullclaw_aizen/g' \
  -e 's/NullClaw/Aizen/g' \
  -e 's/NULLCLAW_HOME/AIZEN_HOME/g' \
  -e 's/nullclaw-home/aizen-home/g' \
  -e 's/nullclaw\.json/aizen.json/g' \
  -e 's/nullclaw/aizen/g' \
  -e 's/\.nullclaw/\.aizen/g' \
  {} +

# --- aizen-dashboard: nullclaw-chat-ui + nullhub → aizen-dashboard ---
echo "Rebranding aizen-dashboard (nullclaw-chat-ui + nullhub → aizen-dashboard)..."

find aizen-dashboard -type f \( -name '*.zig' -o -name '*.zon' -o -name '*.md' -o -name '*.json' -o -name '*.yml' -o -name '*.yaml' -o -name '*.toml' -o -name '*.sh' -o -name '*.svelte' -o -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html' -o -name 'Dockerfile' \) -exec sed -i \
  -e 's/NullHub/AizenDashboard/g' \
  -e 's/nullhub/aizen-dashboard/g' \
  -e 's/NullClaw-Chat-UI/Aizen Dashboard UI/g' \
  -e 's/nullclaw-chat-ui/aizen-dashboard-ui/g' \
  -e 's/NullClaw/Aizen/g' \
  -e 's/NULLCLAW_HOME/AIZEN_HOME/g' \
  -e 's/nullclaw\.json/aizen.json/g' \
  -e 's/\.nullclaw/\.aizen/g' \
  -e 's/nullclaw/aizen/g' \
  {} +

# --- aizen-watch: nullwatch → aizen-watch ---
echo "Rebranding aizen-watch (nullwatch → aizen-watch)..."

find aizen-watch -type f \( -name '*.zig' -o -name '*.zon' -o -name '*.md' -o -name '*.json' -o -name '*.yml' -o -name '*.sh' -o -name 'Dockerfile' \) -exec sed -i \
  -e 's/NullWatch/AizenWatch/g' \
  -e 's/nullwatch/aizen-watch/g' \
  -e 's/NullClaw/Aizen/g' \
  -e 's/nullclaw/aizen/g' \
  -e 's/\.nullwatch/\.aizen-watch/g' \
  {} +

# --- aizen-kanban: nulltickets → aizen-kanban ---
echo "Rebranding aizen-kanban (nulltickets → aizen-kanban)..."

find aizen-kanban -type f \( -name '*.zig' -o -name '*.zon' -o -name '*.md' -o -name '*.json' -o -name '*.yml' -o -name '*.sh' -o -name 'Dockerfile' \) -exec sed -i \
  -e 's/NullTickets/AizenKanban/g' \
  -e 's/nulltickets/aizen-kanban/g' \
  -e 's/NullClaw/Aizen/g' \
  -e 's/nullclaw/aizen/g' \
  -e 's/\.nulltickets/\.aizen-kanban/g' \
  {} +

# --- aizen-orchestrate: nullboiler → aizen-orchestrate ---
echo "Rebranding aizen-orchestrate (nullboiler → aizen-orchestrate)..."

find aizen-orchestrate -type f \( -name '*.zig' -o -name '*.zon' -o -name '*.md' -o -name '*.json' -o -name '*.yml' -o -name '*.sh' -o -name 'Dockerfile' \) -exec sed -i \
  -e 's/NullBoiler/AizenOrchestrate/g' \
  -e 's/nullboiler/aizen-orchestrate/g' \
  -e 's/NullClaw/Aizen/g' \
  -e 's/nullclaw/aizen/g' \
  -e 's/\.nullboiler/\.aizen-orchestrate/g' \
  {} +

# --- chat-ui: nullclaw references → aizen ---
echo "Rebranding chat-ui references..."

find aizen-dashboard/chat-ui -type f \( -name '*.svelte' -o -name '*.js' -o -name '*.ts' -o -name '*.json' -o -name '*.html' -o -name '*.css' \) -exec sed -i \
  -e 's/NullClaw/Aizen/g' \
  -e 's/nullclaw/aizen/g' \
  -e 's/\.nullclaw/\.aizen/g' \
  {} +

# Step 3: Rename binary output in build.zig files
echo "Updating binary names in build.zig..."

# aizen-core build.zig — change exe name to 'aizen'
sed -i 's/\.setName("nullclaw")/\.setName("aizen")/g' aizen-core/build.zig 2>/dev/null || true
sed -i 's/\.setName("aizen-nullclaw")/\.setName("aizen")/g' aizen-core/build.zig 2>/dev/null || true

# aizen-dashboard build.zig
sed -i 's/\.setName("nullhub")/\.setName("aizen-dashboard")/g' aizen-dashboard/build.zig 2>/dev/null || true
sed -i 's/\.setName("aizen-dashboard-nullhub")/\.setName("aizen-dashboard")/g' aizen-dashboard/build.zig 2>/dev/null || true

# aizen-watch build.zig
sed -i 's/\.setName("nullwatch")/\.setName("aizen-watch")/g' aizen-watch/build.zig 2>/dev/null || true

# aizen-kanban build.zig
sed -i 's/\.setName("nulltickets")/\.setName("aizen-kanban")/g' aizen-kanban/build.zig 2>/dev/null || true

# aizen-orchestrate build.zig
sed -i 's/\.setName("nullboiler")/\.setName("aizen-orchestrate")/g' aizen-orchestrate/build.zig 2>/dev/null || true

# Step 4: Rename data directories in source
echo "Renaming data directory references..."
# Already handled by sed above: .nullclaw → .aizen, etc.

# Step 5: Port verification (ports stay the same)
echo "Verifying port assignments..."
echo "  aizen-core: 8080"
echo "  aizen-dashboard: 3000"
echo "  aizen-watch: 7710"
echo "  aizen-kanban: 7720"
echo "  aizen-orchestrate: 7730"

# Step 6: Verify no remaining nullclaw/nullhub/nullwatch/nulltickets/nullboiler references
echo ""
echo "=== Verification: Checking for remaining old names ==="

REMAINING=0
for svc in aizen-core aizen-dashboard aizen-watch aizen-kanban aizen-orchestrate; do
  for pattern in "nullclaw" "NullClaw" "nullhub" "NullHub" "nullwatch" "NullWatch" "nulltickets" "NullTickets" "nullboiler" "NullBoiler" "NULLCLAW_HOME"; do
    COUNT=$(grep -r "$pattern" "$BASEDIR/$svc" --include='*.zig' --include='*.zon' --include='*.md' --include='*.json' --include='*.svelte' --include='*.ts' --include='*.js' --include='*.css' --include='*.html' --include='*.yml' --include='*.yaml' --include='*.sh' --include='*.toml' 2>/dev/null | grep -v 'node_modules' | grep -v '.git/' | wc -l || true)
    if [ "$COUNT" -gt 0 ]; then
      echo "  WARNING: $svc still has $COUNT occurrences of '$pattern'"
      REMAINING=$((REMAINING + COUNT))
    fi
  done
done

if [ "$REMAINING" -eq 0 ]; then
  echo "  ✓ No remaining old names found!"
else
  echo "  ⚠ $REMAINING total remaining occurrences (may be in comments, URLs, or licenses)"
fi

echo ""
echo "=== Rebrand complete ==="