output "execution_role_arn" {
  description = "Paste into the AWS Transform console when configuring this workspace's target account connection"
  value       = aws_iam_role.transform_exec.arn
}
