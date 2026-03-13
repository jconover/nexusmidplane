#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# smoke-test.sh — Health check all NexusMidplane endpoints
#
# Usage:
#   ./smoke-test.sh                         # localhost (on-prem)
#   TARGET_HOST=my-alb.us-east-1.elb.amazonaws.com ./smoke-test.sh
#   TARGET_HOST=my-alb.us-east-1.elb.amazonaws.com TARGET_SCHEME=https ./smoke-test.sh
# ─────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✔ PASS${NC}  $*"; }
fail() { echo -e "  ${RED}✘ FAIL${NC}  $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

TARGET_HOST="${TARGET_HOST:-localhost}"
TARGET_SCHEME="${TARGET_SCHEME:-http}"
TIMEOUT="${TIMEOUT:-10}"
RETRIES="${RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"

PASSED=0
FAILED=0
SKIPPED=0

# ── HTTP check with retry ────────────────────────────────────
# Usage: check_endpoint <label> <url> [expected_status] [expected_body] [optional]
# Set optional to "true" to skip without counting as failure
check_endpoint() {
  local label="$1"
  local url="$2"
  local expected_status="${3:-200}"
  local expected_body="${4:-}"
  local optional="${5:-false}"

  local attempt=1
  while [[ $attempt -le $RETRIES ]]; do
    local http_status
    local body

    http_status=$(curl -s -o /tmp/smoke_body -w "%{http_code}" \
      --max-time "$TIMEOUT" \
      --connect-timeout 5 \
      "$url" 2>/dev/null || echo "000")
    body=$(cat /tmp/smoke_body 2>/dev/null || true)

    if [[ "$http_status" == "$expected_status" ]]; then
      if [[ -n "$expected_body" ]] && ! echo "$body" | grep -q "$expected_body"; then
        if [[ $attempt -lt $RETRIES ]]; then
          sleep "$RETRY_DELAY"
          attempt=$((attempt + 1))
          continue
        fi
        if [[ "$optional" == "true" ]]; then
          echo -e "  ${YELLOW}⊘ SKIP${NC}  $label — HTTP $http_status but body missing '$expected_body' (optional) | URL: $url"
          SKIPPED=$((SKIPPED + 1))
          return 0
        fi
        fail "$label — HTTP $http_status but body missing '$expected_body' | URL: $url"
        FAILED=$((FAILED + 1))
        return 1
      fi
      pass "$label — HTTP $http_status | URL: $url"
      PASSED=$((PASSED + 1))
      return 0
    else
      if [[ $attempt -lt $RETRIES ]]; then
        echo -e "    ${YELLOW}[retry $attempt/$RETRIES]${NC} HTTP $http_status — waiting ${RETRY_DELAY}s..."
        sleep "$RETRY_DELAY"
        attempt=$((attempt + 1))
        continue
      fi
      if [[ "$optional" == "true" ]]; then
        echo -e "  ${YELLOW}⊘ SKIP${NC}  $label — HTTP $http_status (optional) | URL: $url"
        SKIPPED=$((SKIPPED + 1))
        return 0
      fi
      fail "$label — HTTP $http_status (expected $expected_status) | URL: $url"
      FAILED=$((FAILED + 1))
      return 1
    fi
  done
}

# ── Main ─────────────────────────────────────────────────────
main() {
  echo ""
  echo "══════════════════════════════════════════════════"
  echo "  NexusMidplane — Smoke Tests"
  echo "══════════════════════════════════════════════════"
  echo "  Target  : ${TARGET_SCHEME}://${TARGET_HOST}"
  echo "  Timeout : ${TIMEOUT}s per request"
  echo "  Retries : ${RETRIES}"
  echo "──────────────────────────────────────────────────"

  BASE="${TARGET_SCHEME}://${TARGET_HOST}"

  # Java app endpoints
  info "Java (WildFly) endpoints"
  check_endpoint "Java health"  "${BASE}/java/health"  200 ""
  check_endpoint "Java hello"   "${BASE}/java/hello"   200 ""
  check_endpoint "Java metrics" "${BASE}/java/metrics" 200 "" true

  echo ""
  # .NET app endpoints
  info ".NET endpoints"
  check_endpoint ".NET health"  "${BASE}/dotnet/health"  200 ""
  check_endpoint ".NET hello"   "${BASE}/dotnet/hello"   200 ""
  check_endpoint ".NET metrics" "${BASE}/dotnet/metrics" 200 "" true

  echo ""
  # Apache proxy (on-prem only)
  if [[ "$TARGET_HOST" == "localhost" ]]; then
    info "Apache proxy endpoints"
    check_endpoint "Apache root"   "${BASE}/"         200 ""
    check_endpoint "Apache status" "${BASE}/server-status" 200 "" true
  fi

  # ── Summary ────────────────────────────────────────────────
  echo ""
  echo "──────────────────────────────────────────────────"
  echo -e "  Results: ${GREEN}${PASSED} passed${NC}  ${RED}${FAILED} failed${NC}  ${YELLOW}${SKIPPED} skipped${NC}"
  echo "══════════════════════════════════════════════════"

  if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo -e "${RED}Smoke tests FAILED. Check service logs:${NC}"
    if [[ "$TARGET_HOST" == "localhost" ]]; then
      echo "  docker compose -f docker/docker-compose.yml logs"
    else
      echo "  aws logs tail /nexusmidplane/app --follow"
    fi
    exit 1
  fi

  echo ""
  echo -e "${GREEN}All smoke tests passed!${NC}"
  exit 0
}

main "$@"
