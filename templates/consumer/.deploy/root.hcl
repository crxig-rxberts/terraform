locals {
  environment = get_env("TG_ENV")

  global_config      = read_terragrunt_config(find_in_parent_folders("environments/global.hcl")).locals
  environment_config = read_terragrunt_config(find_in_parent_folders("environments/${local.environment}/env.hcl")).locals

  config = merge(
    local.global_config,
    local.environment_config,
    {
      default_tags = merge(
        local.global_config.default_tags,
        try(local.environment_config.default_tags, {}),
      )
    },
  )
}

generate "provider_versions" {
  path      = "provider_versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = file(find_in_parent_folders("provider-versions.tf"))
}

remote_state {
  backend = "s3"

  config = {
    bucket                = local.config.tfstate_bucket
    disable_bucket_update = true
    encrypt               = true
    key                   = "${local.environment}/${local.config.state_prefix}/${path_relative_to_include()}/terraform.tfstate"
    region                = local.config.aws_region
    skip_bucket_creation  = true
    use_lockfile          = true
  }
}

terraform {
  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=5m"]
  }
}

inputs = local.config

