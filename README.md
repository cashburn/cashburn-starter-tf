# GitHub Terraform Azure Starter Project
A template for managing Azure infrastructure with Terraform, authenticated with GitHub Actions + OIDC, using a remote Terraform state in Azure Storage.

There are one-time scripts provided to bootstrap the tfstate backend in Azure Blob Storage and to create the OIDC configuration using Azure Entra ID.

# Steps to Run
1. Install [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
2. Configure `infra/env/backend.*.config` to the names you want for your project
   1. `resource_group_name` - The Azure Resource Group you would like to use for storing the Terraform backend/tfstate in Blob Storage (NOT your application resource group). *The RG will be created in the `/infra/bootstrap` script.*
   2. `storage_account_name` - The Storage Account you would like to use for storing the tfstate.
   3. `container_name` - The container inside the Storage Account you would like to use for storing the tfstate.
   4. `key` - The full name + environment of your application tfstate fiile, as you would like it to be stored in Azure Blob Storage.
3. Add/remove other terraform backend environment files to `infra/env/` if you would like (ex. `backend.stage.config`)
4. Configure `infra/env/*.tfvars` to the names you want for your project.

`project_name` and `env` will be concatenated (dash-separated) to create an overall env-specific application name. (Ex. "cashburn-starter-tf-dev", "cashburn-starter-tf-prod", etc.)
   1. `project_name` - The overall name of your application
   2. `env` - The environment name
   3. `location` - The Azure region to use

# Todos
1. Add starter project
2. Add documentation
3. Add shell script
4. Add branch policies/rulesets