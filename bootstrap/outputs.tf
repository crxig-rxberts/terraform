output "github_actions_role_arns" {
  description = "Plan and apply role ARNs for every registered repository and environment."
  value       = local.github_actions_role_arns
}

output "state_bucket_name" {
  description = "S3 bucket used for Terraform state and native lock files."
  value       = aws_s3_bucket.terraform_state.id
}
