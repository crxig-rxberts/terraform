# Terraform foundation

Shared AWS state, locking, GitHub OIDC identities, and a reusable deployment
workflow for personal project repositories.

Each application repository owns its Terraform, following the same consumer
layout:

```text
.deploy/
├── provider-versions.tf
├── root.hcl
├── environments/
│   ├── global.hcl
│   ├── dev/env.hcl
│   └── prod/env.hcl
└── resources/projects/
    └── <project>/
        ├── terragrunt.hcl
        ├── providers.tf
        ├── variables.tf
        └── *.tf
```

The `templates/consumer` directory contains a working starting point.

## Responsibilities

This repository manages:

- the private, encrypted, versioned S3 state bucket;
- native S3 `.tflock` state locking;
- the GitHub Actions OIDC provider;
- repository- and environment-isolated plan/apply roles;
- permissions boundaries protecting IAM, account controls, and the backend;
- the pinned reusable Terraform/Terragrunt workflow.

Consumer repositories manage:

- their `.deploy` Terraform and Terragrunt configuration;
- environment inputs and project resources;
- one central `.deploy/provider-versions.tf` per repository;
- their generated `.terraform.lock.hcl` files.

## State layout

Every consumer sets a stable `state_prefix` in
`.deploy/environments/global.hcl`. State keys are isolated as:

```text
<environment>/<state-prefix>/<project-path>/terraform.tfstate
```

For example:

```text
dev/example-api/resources/projects/api/terraform.tfstate
prod/example-api/resources/projects/api/terraform.tfstate
```

The AWS role for a repository can access only that repository's configured
state prefix and environment.

## Onboard a consumer repository

1. Copy the contents of `templates/consumer` into the application repository.
2. Replace the repository name and stable state prefix in
   `.deploy/environments/global.hcl`.
3. Rename the `example-api` values and `api` project for the application, then
   update the workflow's project choices when it has multiple Terraform roots.
4. Get the immutable GitHub repository ID:

   ```bash
   gh api repos/crxig-rxberts/<repository> --jq .id
   ```

5. Add the repository to `github_repositories` in
   `bootstrap/terraform.tfvars`, then apply the bootstrap locally:

   ```hcl
   github_repositories = {
     terraform = {
       environments = ["dev", "prod"]
       repository_id = 1398512587
       state_prefix  = "terraform"
     }

     my_application = {
       environments = ["dev", "prod"]
       repository_id = 123456789
       state_prefix  = "my-application"
     }
   }
   ```

   ```bash
   aws sso login --profile personal
   AWS_PROFILE=personal terraform -chdir=bootstrap plan
   AWS_PROFILE=personal terraform -chdir=bootstrap apply
   ```

6. Create protected `dev` and `prod` GitHub environments in the consumer
   repository. Restrict both to protected branches.
7. Pin the reusable workflow reference in the consumer workflow to a reviewed
   commit SHA from this repository.
8. Add narrowly scoped workload permissions to the repository's roles in the
   bootstrap configuration. New roles intentionally receive only their state
   access; they do not receive `AdministratorAccess`.

The reusable workflow derives the correct role name from the caller's immutable
GitHub repository ID, environment, and requested `plan` or `apply` action. No
AWS role ARN or access key needs to be stored in the consumer repository.

## Provider versions

`templates/consumer/.deploy/provider-versions.tf` is the single provider
version source within each consumer repository. Terragrunt generates its
contents into every project root, so projects do not duplicate `versions.tf`.

Renovate natively detects Terraform requirements in this file. The supplied
`renovate.json5` extends `crxig-rxberts/renovate-config`, while requiring manual
review for Terraform and GitHub Actions updates.

Provider dependency lock files remain per Terraform root because checksums and
selected providers are properties of each independent root module. Commit each
generated `.terraform.lock.hcl`.

## Bootstrap operations

Bootstrap state is stored at:

```text
s3://crxig-rxberts-terraform-state/bootstrap/terraform.tfstate
```

Bootstrap controls the CI trust root and therefore remains a local SSO
operation rather than a self-modifying pipeline:

```bash
aws sso login --profile personal
AWS_PROFILE=personal terraform -chdir=bootstrap plan
AWS_PROFILE=personal terraform -chdir=bootstrap apply
```

Only execution is local; state and locking remain remote.

## Cost

For 5-10 small state files, S3 storage and request charges should remain a
fraction of a cent per month and commonly round to `$0.00`. There is no separate
charge for native S3 lock files beyond negligible S3 requests and storage.
