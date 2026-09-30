provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy  = "Terraform"
      Repository = "terraform"
    }
  }
}

terraform {
  backend "s3" {
    bucket       = "crxig-rxberts-terraform-state"
    encrypt      = true
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
  }
}

