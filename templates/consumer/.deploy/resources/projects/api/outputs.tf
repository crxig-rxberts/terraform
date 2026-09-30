output "aws_account_id" {
  description = "AWS account used by this environment."
  value       = data.aws_caller_identity.current.account_id
}

output "environment" {
  description = "Selected deployment environment."
  value       = var.environment
}
