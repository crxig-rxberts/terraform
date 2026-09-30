resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}

resource "aws_iam_policy" "github_actions_boundary" {
  name        = "github-actions-terraform-boundary"
  description = "Security boundary for Terraform roles assumed by GitHub Actions."
  policy = jsonencode(jsondecode(templatefile("${path.module}/files/github-actions-boundary.json", {
    state_bucket_arn = aws_s3_bucket.terraform_state.arn
  })))
}

resource "aws_iam_role" "github_actions" {
  for_each = local.github_actions_roles

  name = "github-actions-terraform-${each.value.repository_id}-${each.value.environment}-${each.value.access}"
  assume_role_policy = jsonencode(jsondecode(templatefile("${path.module}/files/github-actions-trust-policy.json", {
    oidc_provider_arn = aws_iam_openid_connect_provider.github_actions.arn
    oidc_subject      = "repo:${var.github_owner}@${var.github_owner_id}/${each.value.repository_name}@${each.value.repository_id}:environment:${each.value.environment}"
  })))
  max_session_duration = 3600
  permissions_boundary = aws_iam_policy.github_actions_boundary.arn
}

resource "aws_iam_role_policy" "github_actions_state" {
  for_each = local.github_actions_roles

  name = "terraform-${each.value.environment}-state"
  role = aws_iam_role.github_actions[each.key].id
  policy = jsonencode(jsondecode(templatefile("${path.module}/files/github-actions-state-policy.json", {
    state_bucket_arn = aws_s3_bucket.terraform_state.arn
    state_objects_arn = join("/", [
      aws_s3_bucket.terraform_state.arn,
      each.value.environment,
      each.value.state_prefix,
      "*",
    ])
    state_prefix = "${each.value.environment}/${each.value.state_prefix}/*"
  })))
}
