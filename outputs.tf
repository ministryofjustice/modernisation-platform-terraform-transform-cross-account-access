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

output "transform_bucket_name" {
  description = "Name of the AWS Transform S3 bucket created in the target account"
  value       = module.transform_s3_bucket.bucket.id
}

output "transform_bucket_arn" {
  description = "ARN of the AWS Transform S3 bucket created in the target account"
  value       = module.transform_s3_bucket.bucket.arn
}

output "transform_bucket_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the AWS Transform S3 bucket"
  value       = aws_kms_key.transform_bucket.arn
}
