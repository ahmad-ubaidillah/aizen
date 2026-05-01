#!/bin/bash
# build-all.sh — Build all aizen services
set -euo pipefail

BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASEDIR"

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

echo "=== Building Aizen Agent Services ==="
echo ""

FAILED=()
BUILT=()

build_service() {
  local name=$1
  local dir=$2
  
  echo -e "${BOLD}Building $name...${RESET}"
  cd "$BASEDIR/$dir"
  
  if [ -f "build.zig" ]; then
    if zig build -Doptimize=ReleaseSmall 2>&1; then
      echo -e "  ${GREEN}✓ $name built successfully${RESET}"
      BUILT+=("$name")
    else
      echo -e "  ${RED}✗ $name build failed${RESET}"
      FAILED+=("$name")
    fi
  elif [ -f "package.json" ]; then
    if npm install && npm run build 2>&1; then
      echo -e "  ${GREEN}✓ $name built successfully${RESET}"
      BUILT+=("$name")
    else
      echo -e "  ${RED}✗ $name build failed${RESET}"
      FAILED+=("$name")
    fi
  else
    echo -e "  ${RED}✗ $name: no build system found${RESET}"
    FAILED+=("$name")
  fi
  cd "$BASEDIR"
}

# Build Zig services
build_service "aizen-core" "aizen-core"
build_service "aizen-dashboard" "aizen-dashboard"
build_service "aizen-watch" "aizen-watch"
build_service "aizen-kanban" "aizen-kanban"
build_service "aizen-orchestrate" "aizen-orchestrate"

# Build Python skill bridge
echo -e "${BOLD}Building aizen-skill-bridge...${RESET}"
cd "$BASEDIR/aizen-skill-bridge"
if pip install -e . 2>&1; then
  echo -e "  ${GREEN}✓ aizen-skill-bridge installed${RESET}"
  BUILT+=("aizen-skill-bridge")
else
  echo -e "  ${RED}✗ aizen-skill-bridge install failed${RESET}"
  FAILED+=("aizen-skill-bridge")
fi
cd "$BASEDIR"

echo ""
echo "=== Build Summary ==="
echo -e "  ${GREEN}Built: ${#BUILT[@]}${RESET} ${BUILT[*]}"
if [ ${#FAILED[@]} -gt 0 ]; then
  echo -e "  ${RED}Failed: ${#FAILED[@]}${RESET} ${FAILED[*]}"
  exit 1
fi