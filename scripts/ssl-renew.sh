#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# ssl-renew.sh — On-prem SSL certificate renewal workflow
#
# Demonstrates manual cert lifecycle management vs. AWS ACM
# auto-renewal.  Supports self-signed (dev) and CA-signed (prod).
# ─────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { error "$*"; exit 1; }

# ── Configuration ────────────────────────────────────────────
DOMAIN="${DOMAIN:-nexusmidplane.internal}"
CERT_DIR="${CERT_DIR:-/etc/ssl/nexusmidplane}"
APACHE_CERT_DIR="${APACHE_CERT_DIR:-/etc/apache2/ssl}"
WILDFLY_KEYSTORE="${WILDFLY_KEYSTORE:-/opt/wildfly/standalone/configuration/keystore.jks}"
KEYSTORE_PASS="${KEYSTORE_PASS:-changeit}"
CERT_DAYS="${CERT_DAYS:-365}"
MODE="${1:-self-signed}"    # self-signed | ca-signed | check

# Docker-aware paths (on-prem sim)
DOCKER_CERT_VOLUME="${DOCKER_CERT_VOLUME:-./docker/certs}"

# ── Check expiry ─────────────────────────────────────────────
check_expiry() {
  local cert_file="${1:-$CERT_DIR/$DOMAIN.crt}"

  if [[ ! -f "$cert_file" ]]; then
    warn "Certificate not found: $cert_file"
    return 1
  fi

  local expiry_date
  expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
  local expiry_epoch
  expiry_epoch=$(date -d "$expiry_date" +%s)
  local now_epoch
  now_epoch=$(date +%s)
  local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

  echo "  Certificate : $cert_file"
  echo "  Domain      : $(openssl x509 -subject -noout -in "$cert_file" | sed 's/.*CN=//')"
  echo "  Expires     : $expiry_date"
  echo "  Days left   : $days_left"

  if [[ $days_left -lt 30 ]]; then
    warn "Certificate expires in $days_left days — RENEWAL RECOMMENDED"
    return 2
  elif [[ $days_left -lt 0 ]]; then
    error "Certificate EXPIRED $((days_left * -1)) days ago!"
    return 3
  else
    info "Certificate is valid for $days_left more days."
    return 0
  fi
}

# ── Generate self-signed cert (dev/on-prem) ──────────────────
generate_self_signed() {
  info "Generating self-signed certificate for: $DOMAIN"
  mkdir -p "$CERT_DIR" "$DOCKER_CERT_VOLUME"

  # Generate private key
  openssl genrsa -out "$CERT_DIR/$DOMAIN.key" 2048
  info "Private key: $CERT_DIR/$DOMAIN.key"

  # Generate CSR
  openssl req -new \
    -key "$CERT_DIR/$DOMAIN.key" \
    -out "$CERT_DIR/$DOMAIN.csr" \
    -subj "/C=US/ST=State/L=City/O=NexusMidplane/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN,IP:127.0.0.1"
  info "CSR: $CERT_DIR/$DOMAIN.csr"

  # Self-sign
  openssl x509 -req \
    -in "$CERT_DIR/$DOMAIN.csr" \
    -signkey "$CERT_DIR/$DOMAIN.key" \
    -out "$CERT_DIR/$DOMAIN.crt" \
    -days "$CERT_DAYS" \
    -extensions v3_req \
    -extfile <(printf "[v3_req]\nsubjectAltName=DNS:%s,DNS:*.%s,IP:127.0.0.1\n" "$DOMAIN" "$DOMAIN")
  info "Certificate: $CERT_DIR/$DOMAIN.crt (valid $CERT_DAYS days)"

  # Copy to Docker cert volume for use by containers
  cp "$CERT_DIR/$DOMAIN.crt" "$DOCKER_CERT_VOLUME/$DOMAIN.crt"
  cp "$CERT_DIR/$DOMAIN.key" "$DOCKER_CERT_VOLUME/$DOMAIN.key"
  info "Copied to Docker volume: $DOCKER_CERT_VOLUME/"
}

# ── Generate CSR for CA-signed cert (prod workflow) ──────────
generate_csr_for_ca() {
  info "Generating CSR for CA-signed certificate: $DOMAIN"
  mkdir -p "$CERT_DIR"

  openssl genrsa -out "$CERT_DIR/$DOMAIN.key" 4096
  openssl req -new \
    -key "$CERT_DIR/$DOMAIN.key" \
    -out "$CERT_DIR/$DOMAIN.csr" \
    -subj "/C=US/ST=State/L=City/O=NexusMidplane Inc/OU=IT/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN"

  info "CSR generated: $CERT_DIR/$DOMAIN.csr"
  echo ""
  warn "MANUAL STEP REQUIRED:"
  echo "  1. Submit CSR to your CA (DigiCert, Entrust, internal CA, etc.):"
  echo "     cat $CERT_DIR/$DOMAIN.csr"
  echo ""
  echo "  2. Receive signed certificate from CA and save as:"
  echo "     $CERT_DIR/$DOMAIN.crt"
  echo ""
  echo "  3. (Optional) Download CA intermediate chain:"
  echo "     $CERT_DIR/ca-chain.crt"
  echo ""
  echo "  4. Re-run this script with MODE=install-ca to deploy the cert."
  echo ""
  warn "AWS CONTRAST: AWS ACM handles all of this automatically via DNS/email validation."
}

# ── Install cert to Apache ───────────────────────────────────
install_apache() {
  local cert="$CERT_DIR/$DOMAIN.crt"
  local key="$CERT_DIR/$DOMAIN.key"

  [[ -f "$cert" ]] || die "Certificate not found: $cert"
  [[ -f "$key"  ]] || die "Private key not found: $key"

  info "Installing certificate to Apache..."
  mkdir -p "$APACHE_CERT_DIR"
  cp "$cert" "$APACHE_CERT_DIR/$DOMAIN.crt"
  cp "$key"  "$APACHE_CERT_DIR/$DOMAIN.key"
  chmod 640  "$APACHE_CERT_DIR/$DOMAIN.key"

  # Verify Apache config references the new cert
  if command -v apache2ctl &>/dev/null; then
    apache2ctl configtest && info "Apache config valid."
    apache2ctl graceful  && info "Apache reloaded (graceful restart)."
  elif command -v httpd &>/dev/null; then
    httpd -t && info "Apache config valid."
    systemctl reload httpd && info "httpd reloaded."
  else
    warn "Apache not running locally — cert copied to $APACHE_CERT_DIR/. Restart Apache container manually."
  fi
}

# ── Install cert to WildFly keystore ────────────────────────
install_wildfly_keystore() {
  local cert="$CERT_DIR/$DOMAIN.crt"
  local key="$CERT_DIR/$DOMAIN.key"
  local p12="$CERT_DIR/$DOMAIN.p12"

  [[ -f "$cert" ]] || die "Certificate not found: $cert"
  [[ -f "$key"  ]] || die "Private key not found: $key"

  info "Installing certificate to WildFly JKS keystore..."

  # Convert to PKCS12
  openssl pkcs12 -export \
    -in "$cert" \
    -inkey "$key" \
    -out "$p12" \
    -name "$DOMAIN" \
    -passout "pass:$KEYSTORE_PASS"

  # Import to JKS (or create new keystore)
  if command -v keytool &>/dev/null; then
    keytool -importkeystore \
      -srckeystore "$p12" \
      -srcstoretype PKCS12 \
      -srcstorepass "$KEYSTORE_PASS" \
      -destkeystore "$WILDFLY_KEYSTORE" \
      -deststorepass "$KEYSTORE_PASS" \
      -alias "$DOMAIN" \
      -noprompt
    info "Certificate imported to keystore: $WILDFLY_KEYSTORE"
  else
    warn "keytool not found — PKCS12 file ready at $p12"
    warn "Copy to WildFly container and import with keytool."
  fi
}

# ── Post-renewal verification ────────────────────────────────
verify_renewal() {
  info "Verifying renewed certificate..."
  check_expiry "$CERT_DIR/$DOMAIN.crt"

  if command -v openssl &>/dev/null; then
    echo ""
    info "TLS handshake test (Apache):"
    echo | openssl s_client -connect "localhost:443" -servername "$DOMAIN" 2>/dev/null \
      | openssl x509 -noout -subject -enddate 2>/dev/null \
      || warn "Could not connect to localhost:443 — verify Apache is running."
  fi
}

# ── AWS ACM contrast note ─────────────────────────────────────
show_acm_contrast() {
  echo ""
  echo -e "${CYAN}── AWS ACM Comparison ──────────────────────────────────${NC}"
  echo "  On-prem (this script)         │  AWS ACM"
  echo "  ──────────────────────────────┼──────────────────────────────"
  echo "  Manual key generation          │  ACM generates + stores key"
  echo "  Submit CSR to CA               │  ACM validates via DNS/email"
  echo "  Download + install cert        │  Auto-provisioned to ALB/CF"
  echo "  Annual renewal workflow        │  Auto-renewed 60 days before"
  echo "  Key stored on disk (risk)      │  Key never leaves HSM"
  echo "  Admin effort: ~2 hours/year    │  Admin effort: ~5 minutes"
  echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
}

# ── Main ─────────────────────────────────────────────────────
main() {
  echo "════════════════════════════════════════════════════"
  echo "  NexusMidplane — SSL Certificate Renewal"
  echo "  Domain : $DOMAIN | Mode: $MODE"
  echo "════════════════════════════════════════════════════"
  echo ""

  case "$MODE" in
    check)
      check_expiry "$CERT_DIR/$DOMAIN.crt" || true
      ;;
    self-signed)
      generate_self_signed
      install_apache
      install_wildfly_keystore
      verify_renewal
      ;;
    ca-signed)
      generate_csr_for_ca
      ;;
    install-ca)
      install_apache
      install_wildfly_keystore
      verify_renewal
      ;;
    *)
      die "Unknown mode: $MODE. Use: check | self-signed | ca-signed | install-ca"
      ;;
  esac

  show_acm_contrast
  echo ""
  info "SSL renewal workflow complete."
}

main "$@"
