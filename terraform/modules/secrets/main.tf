# Secrets Manager module — stores sensitive credentials for the application stack.
# Initial secret values are auto-generated; rotate via Secrets Manager rotation policies.

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── Random passwords ──────────────────────────────────────────────────────────

resource "random_password" "wildfly_admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ── WildFly Admin Credentials ─────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "wildfly_admin" {
  name        = "${local.name_prefix}/wildfly/admin-credentials"
  description = "WildFly management console admin credentials"

  # Prevent accidental deletion; set to 0 for dev environments
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = {
    Name = "${local.name_prefix}-wildfly-admin-secret"
    app  = "wildfly"
  }
}

resource "aws_secretsmanager_secret_version" "wildfly_admin" {
  secret_id = aws_secretsmanager_secret.wildfly_admin.id

  secret_string = jsonencode({
    username = "admin"
    password = random_password.wildfly_admin.result
  })

  lifecycle {
    # Don't overwrite if manually rotated
    ignore_changes = [secret_string]
  }
}

# ── Database Connection String ─────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "db_connection" {
  name        = "${local.name_prefix}/database/connection-string"
  description = "Database connection strings for application servers"

  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = {
    Name = "${local.name_prefix}-db-connection-secret"
    app  = "database"
  }
}

resource "aws_secretsmanager_secret_version" "db_connection" {
  secret_id = aws_secretsmanager_secret.db_connection.id

  secret_string = jsonencode({
    # Placeholder — update with actual RDS endpoint when provisioned
    java_datasource_url  = "jdbc:postgresql://db.${local.name_prefix}.internal:5432/nexusdb"
    dotnet_connection    = "Server=db.${local.name_prefix}.internal;Database=nexusdb;User Id=appuser;Password=${random_password.db_password.result};"
    username             = "appuser"
    password             = random_password.db_password.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ── SSL Private Key ───────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "ssl_private_key" {
  name        = "${local.name_prefix}/tls/private-key"
  description = "TLS private key for application-level mTLS (distinct from ACM cert)"

  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = {
    Name = "${local.name_prefix}-ssl-key-secret"
    app  = "tls"
  }
}

resource "aws_secretsmanager_secret_version" "ssl_private_key" {
  secret_id = aws_secretsmanager_secret.ssl_private_key.id

  # Placeholder — replace with actual private key via CLI or rotation lambda
  secret_string = jsonencode({
    private_key  = "REPLACE_WITH_ACTUAL_PRIVATE_KEY"
    certificate  = "REPLACE_WITH_ACTUAL_CERTIFICATE"
    created_date = timestamp()
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
