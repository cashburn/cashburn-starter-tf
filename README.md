# GitHub Terraform Azure Starter Project
A template for managing Azure infrastructure with Terraform, authenticated with GitHub Actions + OIDC, using a remote Terraform state in Azure Storage.

There are one-time scripts provided to bootstrap the tfstate backend in Azure Blob Storage and to create the OIDC configuration using Azure Entra ID.

# Steps to use this in your project
## Run Bootstrap Script
This will create a Resource Group for storing the Terraform backend/tfstate in Blob Storage (NOT your application resource group), an Azure Storage Account with a tfstate container, a Microsoft Entra App and Service Principal (for authenticating from GitHub Actions using OIDC), and federated credentials for each environment name.
1. Install [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
   1. You might want to try running `az login` before running the script to make sure it works as expected. 
   2. Also, log into the Azure Portal and make sure to go to your Subscription and register all of the Resource Providers you will need if you have not done so (this project at least uses Microsoft.Storage).
2. Install [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell)
3. Copy `/infra` into your project
4. Run `pwsh ./infra/boostrap-tfstate/setup.ps1` with your configured parameters for all the Non-Prod environments (this creates tfstate storage and federated credentials for ALL NPD environments at once: ex. dev, test, stage, etc).
   1. `TfStateResourceGroup` (Ex. `cashburn-starter-tf-tfstate-npd`) - The Azure Resource Group you would like to use for storing the Terraform backend/tfstate in Blob Storage (NOT your application resource group).
   2. `AppName` (Ex. `cashburn-starter-tf-npd`) - The name of your application to be used for the Entra App/Service Principal. It will be the same for all non-prod environments (dev, test, stage, etc). *As such, I like to call it `{YourApplicationName}-npd`*
   3. `Location` (Ex. `centralus`) - The Azure region to use for the RG/Storage Account
   4. `StorageAccountName` (Ex. `cashburnstartertfnpd`) - The name of the Storage Account to create (must be globally unique, alphanumeric with NO dashes, and only 3-24 chars)
   5. `GitHubOrg` (Ex. `cashburn`) - The name of your GitHub Organization or username (wherever your repo will be hosted)
   6. `GitHubRepo` (Ex. `cashburn-starter-tf`) - Your project repo name
   7. `ContainerName` (Ex. `tfstate`) - Defaults to tfstate, so no need to pass this in unless you want to customize it
   8. `Envs` (Ex. `dev,test,stage`) - Comma-separated list of non-prod environment names as they will exist in GitHub Actions. This is how GitHub Actions will authenticate to Azure; every GitHub environment name you pass here will have a federated credential created in Azure (only for your Org/Repo) with the Contributor role.
        - You can add additional environments later using the `setup-env.ps1` script.
        - Note: You should NOT pass the "prod" environment here yet! That will be created separately with its own RG/SA for security reasons, as you may want to lock it down more.

   Ex. 
   ```
   pwsh ./infra/bootstrap-tfstate/setup.ps1 -TfStateResourceGroup cashburn-starter-tf-tfstate-npd -AppName cashburn-starter-tf-npd -Location centralus -StorageAccountName cashburnstartertfnpd -GitHubOrg cashburn -GitHubRepo cashburn-starter-tf -Envs dev,test
   ```

## Configure Terraform configs
1. Configure `/infra/env/backend.*.config` to the names you want for your project
   1. `resource_group_name` - The Azure Resource Group you would like to use for storing the Terraform backend/tfstate in Blob Storage (NOT your application resource group). *The RG will be created in the `/infra/bootstrap` script.*
   2. `storage_account_name` - The Storage Account you would like to use for storing the tfstate.
   3. `container_name` - The container inside the Storage Account you would like to use for storing the tfstate.
   4. `key` - The full name + environment of your application tfstate fiile, as you would like it to be stored in Azure Blob Storage.
2. Add/remove other terraform backend environment files to `/infra/env/` if you would like (ex. `backend.stage.config`)
3. Configure `/infra/env/*.tfvars` to the names you want for your project.

`project_name` and `env` will be concatenated (dash-separated) to create an overall env-specific application name. (Ex. "cashburn-starter-tf-dev", "cashburn-starter-tf-prod", etc.)
   1. `project_name` - The overall name of your application
   2. `env` - The environment name
   3. `location` - The Azure region to use

# GitHub 

# Todos
1. Add starter project with CI/CD workflows
2. Add CI trigger in addition to workflow_dispatch
3. Add documentation for how to deploy
4. Add shell script in addition to pwsh
5. Add branch policies/rulesets
   1. Add this as a separate repo, with a GH Actions workflow (triggered on push to /github folder) to auto update settings