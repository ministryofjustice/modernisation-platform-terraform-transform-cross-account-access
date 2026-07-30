output "execution_role_arn" {
  description = "Paste into the AWS Transform console when configuring this workspace's target account connection"
  value       = aws_iam_role.transform_exec.arn
}

output "external_id_secret_name" {
  description = "Secrets Manager secret name containing the generated AWS Transform external ID"
  value       = aws_secretsmanager_secret.transform_external_id.name
}

output "external_id_secret_arn" {
  description = "Secrets Manager secret ARN containing the generated AWS Transform external ID"
  value       = aws_secretsmanager_secret.transform_external_id.arn
}

output "external_id" {
  description = "Generated AWS Transform external ID used in the role trust policy"
  value       = random_string.external_id.result
  sensitive   = true
}
