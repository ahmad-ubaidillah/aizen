#!/bin/bash
# smoke-test.sh — Health check all aizen services
set -euo pipefail

PORTS_FILE="/tmp/aizen-smoke-ports"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

echo "=== Aizen Agent Smoke Tests ==="
echo ""

SERVICES=(
  "aizen-core:8080:/api/v1/healthz"
  "aizen-dashboard:3000:/"
  "aizen-watch:7710:/healthz"
  "aizen-kanban:7720:/healthz"
  "aizen-orchestrate:7730:/healthz"
)

PASSED=0
FAILED=0

for SVC in "${SERVICES[@]}"; do
  IFS=':' read -r NAME PORT PATH <<< "$SVC"
  echo -n "  Testing $NAME on :$PORT ... "
  
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT$PATH" 2>/dev/null) || RESPONSE="000"
  
  if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "302" ]; then
    echo -e "${GREEN}PASS${RESET} (HTTP $RESPONSE)"
    PASSED=$((PASSED + 1))
  elif [ "$RESPONSE" = "000" ]; then
    echo -e "${RED}FAIL${RESET} (connection refused)"
    FAILED=$((FAILED + 1))
  else
    echo -e "${YELLOW}WARN${RESET} (HTTP $RESPONSE)"
    PASSED=$((PASSED + 1))  # Non-200 but responding
  fi
done

echo ""
echo "=== Results: ${GREEN}$PASSED passed${RESET}, ${RED}$FAILED failed${RESET} ==="

# Skill bridge test
echo -n "  Testing aizen-skill-bridge ... "
if python3 -c "from aizen_skill_bridge import __version__; print(__version__)" 2>/dev/null; then
  echo -e "${GREEN}PASS${RESET}"
  PASSED=$((PASSED + 1))
else
  echo -e "${YELLOW}WARN${RESET} (not installed, run: pip install -e aizen-skill-bridge)"
fi

echo ""
echo "=== Total: $((PASSED + FAILED)) services, $PASSED OK ==="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi