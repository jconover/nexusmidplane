#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# setup-local.sh — Bootstrap local NexusMidplane dev environment
# ─────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Prerequisite checks ──────────────────────────────────────
check_prereqs() {
  info "Checking prerequisites..."
  local missing=()

  command -v docker      &>/dev/null || missing+=("docker")
  command -v docker      &>/dev/null && docker compose version &>/dev/null || missing+=("docker-compose (plugin)")
  command -v terraform   &>/dev/null || missing+=("terraform")
  command -v ansible     &>/dev/null || missing+=("ansible")
  command -v aws         &>/dev/null || missing+=("aws-cli")
  command -v java        &>/dev/null || missing+=("java (17+)")
  command -v mvn         &>/dev/null || command -v ./mvnw &>/dev/null 2>&1 || missing+=("maven")
  command -v dotnet      &>/dev/null || missing+=("dotnet-sdk (8+)")

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing prerequisites: ${missing[*]}"
    echo ""
    echo "Install guide:"
    echo "  docker      : https://docs.docker.com/get-docker/"
    echo "  terraform   : https://developer.hashicorp.com/terraform/downloads"
    echo "  ansible     : pip install ansible"
    echo "  aws-cli     : https://aws.amazon.com/cli/"
    echo "  java 17     : https://adoptium.net/"
    echo "  maven       : https://maven.apache.org/ (or use ./mvnw wrapper)"
    echo "  dotnet 8    : https://dotnet.microsoft.com/download"
    die "Please install missing tools and re-run."
  fi

  info "All prerequisites satisfied."
}

# ── Build Java app ───────────────────────────────────────────
build_java() {
  info "Building Java WAR..."
  cd "$PROJECT_ROOT/app/java-app"

  if [[ -f "./mvnw" ]]; then
    chmod +x ./mvnw
    ./mvnw clean package -DskipTests --no-transfer-progress
  else
    mvn clean package -DskipTests --no-transfer-progress
  fi

  local war
  war=$(find target -name "*.war" | head -1)
  [[ -n "$war" ]] || die "WAR not found after Maven build."
  info "Java build complete: $war"
  cd "$PROJECT_ROOT"
}

# ── Build .NET app ───────────────────────────────────────────
build_dotnet() {
  info "Building .NET app..."
  cd "$PROJECT_ROOT/app/dotnet-app"
  dotnet restore
  dotnet publish -c Release -o publish/
  info ".NET build complete: app/dotnet-app/publish/"
  cd "$PROJECT_ROOT"
}

# ── Start Docker on-prem stack ───────────────────────────────
start_docker() {
  info "Starting Docker on-prem stack..."
  cd "$PROJECT_ROOT/docker"

  docker compose pull --quiet
  docker compose up -d

  info "Docker stack started. Waiting for health checks..."
  local attempts=0
  local max_attempts=30

  while [[ $attempts -lt $max_attempts ]]; do
    if docker compose ps | grep -q "healthy"; then
      info "Services are healthy."
      break
    fi
    attempts=$((attempts + 1))
    if [[ $attempts -eq $max_attempts ]]; then
      warn "Timed out waiting for healthy status. Check: docker compose ps"
    fi
    sleep 2
  done

  docker compose ps
  cd "$PROJECT_ROOT"
}

# ── Smoke tests ──────────────────────────────────────────────
run_smoke_tests() {
  info "Running smoke tests against localhost..."
  chmod +x "$SCRIPT_DIR/smoke-test.sh"
  TARGET_HOST="localhost" bash "$SCRIPT_DIR/smoke-test.sh" || warn "Some smoke tests failed — check docker logs."
}

# ── Main ─────────────────────────────────────────────────────
main() {
  echo "================================================"
  echo "  NexusMidplane — Local Environment Setup"
  echo "================================================"
  echo ""

  check_prereqs
  build_java
  build_dotnet
  start_docker
  run_smoke_tests

  echo ""
  echo "================================================"
  info "Local environment ready!"
  echo ""
  echo "  Java app  : http://localhost:8080/java/health"
  echo "  .NET app  : http://localhost:5000/dotnet/health"
  echo "  Apache    : http://localhost:80"
  echo ""
  echo "  Logs      : docker compose -f docker/docker-compose.yml logs -f"
  echo "  Stop      : docker compose -f docker/docker-compose.yml down"
  echo "================================================"
}

main "$@"
