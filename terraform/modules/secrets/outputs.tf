output "wildfly_secret_arn" {
  description = "ARN of the WildFly admin credentials secret"
  value       = aws_secretsmanager_secret.wildfly_admin.arn
}

output "wildfly_secret_name" {
  description = "Name of the WildFly admin credentials secret"
  value       = aws_secretsmanager_secret.wildfly_admin.name
}

output "db_connection_secret_arn" {
  description = "ARN of the database connection string secret"
  value       = aws_secretsmanager_secret.db_connection.arn
}

output "ssl_private_key_secret_arn" {
  description = "ARN of the SSL private key secret"
  value       = aws_secretsmanager_secret.ssl_private_key.arn
}
