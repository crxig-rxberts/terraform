locals {
  aws_region     = "eu-west-1"
  state_prefix   = "example-api"
  tfstate_bucket = "crxig-rxberts-terraform-state"

  default_tags = {
    ManagedBy  = "Terraform"
    Project    = "Example API"
    Repository = "example-api"
  }
}
