variable "aws_region" {
  description = "AWS region for the Terraform state bucket."
  type        = string
  default     = "eu-west-1"
}

variable "github_owner" {
  description = "GitHub repository owner."
  type        = string
  default     = "crxig-rxberts"
}

variable "github_owner_id" {
  description = "Immutable GitHub ID of the repository owner."
  type        = number
  default     = 80485388
}

variable "github_repositories" {
  description = "GitHub repositories allowed to deploy, keyed by repository name."
  type = map(object({
    environments  = set(string)
    repository_id = number
    state_prefix  = string
  }))

  validation {
    condition = alltrue([
      for repository in values(var.github_repositories) :
      repository.repository_id > 0 && length(repository.state_prefix) > 0
    ])
    error_message = "Every repository requires a positive repository_id and non-empty state_prefix."
  }
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket used for Terraform state and locking."
  type        = string
  default     = "crxig-rxberts-terraform-state"
}

locals {
  github_actions_roles = {
    for role in flatten([
      for repository_name, repository in var.github_repositories : [
        for combination in setproduct(repository.environments, ["plan", "apply"]) : {
          access          = combination[1]
          environment     = combination[0]
          repository_id   = repository.repository_id
          repository_name = repository_name
          state_prefix    = repository.state_prefix
        }
      ]
    ]) : "${role.repository_name}-${role.environment}-${role.access}" => role
  }

  github_actions_role_arns = {
    for repository_name, repository in var.github_repositories :
    repository_name => {
      for role in flatten([
        for environment in repository.environments : [
          for access in ["plan", "apply"] : {
            access      = access
            environment = environment
          }
        ]
      ]) : "${role.environment}-${role.access}" =>
      aws_iam_role.github_actions["${repository_name}-${role.environment}-${role.access}"].arn
    }
  }
}

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}