# GitHub Terraform Azure Starter Project
A template for managing Azure infrastructure with Terraform, authenticated with GitHub Actions + OIDC, using a remote Terraform state in Azure Storage.

There are one-time scripts provided to bootstrap the tfstate backend in Azure Blob Storage and to create the OIDC configuration using Azure Entra ID.

# Acceptance Criteria

## Azure
- All infrastructure is created from code (IaC)
- No manual Azure Portal changes are required
- No Azure client secrets or passwords are stored in GitHub
- Separate Azure identities (Service Principals / Entra Apps) can be used for:
   - Non-Prod (Dev, Test, Stage, etc.)
   - Prod

## Terraform Bootstrap Script
- A single bootstrap script can:
  - Create all Terraform backend resources
  - Configure OIDC federated credentials
- The bootstrap script supports multiple non-prod environments in a single run
  - More environments can be added later using a smaller script
- Terraform state is stored remotely in Azure Blob Storage
- Each environment has a separate tfstate file
- There is a cleanup script that will delete all the resources created by the bootstrap script

## Azure/Terraform
- The same infrastructure will be deployed to all environments
- Environment differences are controlled only via variables
- Terraform code is not duplicated for each environment (aside from configs/tfvars)
- Each environment is deployed into its own Resource Group
- The Non-Prod infrastructure can be separated from the Prod infrastructure in a different Azure Tenant/Subscription
  
## Continuous Integration (CI)
- CI is triggered automatically on:
  - Pull Requests to `main` branch (will NOT trigger CD)
  - Pushes to `main` branch
  - Pushes to `releases/*` branches if using Release Flow
- CI can be triggered manually in GitHub
- CI includes:
  - Terraform validation
  - Terraform format checking (only run during PR Validation)
  - Unit Tests
  - Build

## Continuous Deployment (CD)
- CD is part of the same workflow as CI
- CD only runs if all CI checks succeed
- CD does NOT run on PR Validation
- CD can deploy to multiple environments
- CD can be triggered automatically by pushes to `main` branch
  - This should deploy to ALL environments (different if using [Release Flow](#release-flow))
- CD can be triggered manually via `workflow_dispatch`, and supports:
  - Selecting just one environment to deploy
  - Selecting a specific branch to deploy
  - An option to destroy the infra for an environment
- CD supports using [Release Flow](#release-flow) branching strategy

## GitHub Environment Configuration
- Non-Environment-specific variables are stored as Repo-level environment variables (`AZURE_TENANT_ID`, etc.)
- Repo-level environment variables can be overridden by environment-specific variables just by adding a variable for that environment (Prod can use a different `AZURE_TENANT_ID`, etc.)
- Prod environment requires an approval
- Only one approval per environment for all deployment steps

## Branching Strategy
### Trunk-Based Development
- The `main` branch is the main development branch
- All new code is merged from a Feature Branch into `main` using a Pull Request
- Commits into `main` are squashed to maintain a linear Git history

### Release Flow
This is *optional* and is mostly in the code as a demonstration, as [Release Flow](http://releaseflow.org/) may not be the right choice for you. It is mostly used for large projects with slower/predictable deployment timelines.

To only use the `main` branch with trunk-based development, simply remove the `if` conditions from all environments in the CD workflow.

To use Release Flow, in addition to the Trunk-Based Development `main` branch guidelines above:
- CI triggers from the `main` branch deploy to Dev/Test environments (NOT Stage/Prod)
- After reaching a release milestone and you are ready to deploy to Stage/Prod (end of a sprint, completed major features with breaking changes, etc.), create a new `releases/*` branch (ex. `releases/v10`)
- Pushes to a Release Branch (including branch creation) trigger CI/CD for the Stage/Prod environments
- Any additional changes in the `main` branch related to that Release must be cherry-picked from `main` to the Release Branch

# Steps to use this in your project
## Run Bootstrap Script
This will create a Resource Group for storing the Terraform backend/tfstate in Blob Storage (NOT your application resource group), an Azure Storage Account with a tfstate container, a Microsoft Entra App and Service Principal (for authenticating from GitHub Actions using OIDC), and federated credentials for each environment name.
1. Install [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
   1. You might want to try running `az login` before running the script to make sure it works as expected. 
   2. Also, log into the Azure Portal and make sure to go to your Subscription and register all of the Resource Providers you will need if you have not done so (this project at least uses Microsoft.Storage).
2. Install [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell)
3. Copy `/infra` into your project
4. Run `pwsh ./infra/bootstrap-tfstate/setup.ps1` with your configured parameters for all the Non-Prod environments (this creates tfstate storage and federated credentials for ALL NPD environments at once: ex. dev, test, stage, etc).
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
5. The Bootstrap script will output your `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID`. You will add these later in GitHub.
6. If you want to create any additional environments later, they will need federated credentials created in Azure. You can create these one at a time by running the `setup-env.ps1` script:
   1. The only new variable is: `AppId` - The `AZURE_CLIENT_ID` created in the bootstrap script
   2. Ex. `pwsh ./infra/bootstrap-tfstate/setup-env.ps1 -GitHubOrg cashburn -GitHubRepo cashburn-starter-tf -Env stage -AppId YOUR_CLIENT_ID_HERE`

## Configure Terraform configs
1. Configure `/infra/env/backend.*.config` to the names you want for your project
   1. `resource_group_name` - The Azure Resource Group you would like to use for storing the Terraform backend/tfstate in Blob Storage (NOT your application resource group). *The RG should have been created in the `/infra/bootstrap-tfstate/setup.ps1` script.*
   2. `storage_account_name` - The Storage Account you would like to use for storing the tfstate.
   3. `container_name` - The container inside the Storage Account you would like to use for storing the tfstate.
   4. `key` - The full name + environment of your application tfstate fiile, as you would like it to be stored in Azure Blob Storage.
2. Add/remove other terraform backend environment files in `/infra/env/` if you would like (ex. `backend.stage.config`)
3. Configure `/infra/env/*.tfvars` to the names you want for your project.

`project_name` and `env` will be concatenated (dash-separated) to create an overall env-specific application name. (Ex. "cashburn-starter-tf-dev", "cashburn-starter-tf-prod", etc.)
   1. `project_name` - The overall name of your application
   2. `env` - The environment name
   3. `location` - The Azure region to use

## Setup GitHub Workflows
1. In GitHub, go to your repository Settings, then under Security, select `Secrets and variables -> Actions`.
   1. Go to the `Variables` tab
   2. Under `Repository variables`, add the Azure variables output from the Bootstrap script.
   The choice was made to use Variables instead of Secrets for these, because we are using OIDC for authenticating between GitHub and Azure, so these are not truly secrets/credentials.
      1. `AZURE_CLIENT_ID` - App Id of the Non-Prod Entra App/Service Principal
      2. `AZURE_TENANT_ID` - Entra Id for your Azure Organization/Tenant/Directory
      3. `AZURE_SUBSCRIPTION_ID` - Azure Subscription Id where your resources will be created
   The choice was made to use Variables instead of Secrets for these, because we are using OIDC for authenticating between GitHub and Azure, so these are not truly secrets/credentials.
2. Copy `/.github` folder into your project
3. On push, GitHub will automatically create CI and CD workflows in GitHub Actions and deploy to the Dev/Test environments.

## Setup Prod Configuration
You typically want Prod to have its own Service Principal for security reasons, and you can also enforce additional restrictions/policies for the Prod environment in GitHub and Azure (it may also be in a separate Azure Tenant/Subscription).
1. When you are ready to create your Prod environment, run the Bootstrap script again with your Prod variables:
   
   Ex.
   ```
   pwsh ./infra/bootstrap-tfstate/setup.ps1 -TfStateResourceGroup cashburn-starter-tf-tfstate-prod -AppName cashburn-starter-tf-prod -Location centralus -StorageAccountName cashburnstartertfprod -GitHubOrg cashburn -GitHubRepo cashburn-starter-tf -Envs prod
   ```
2. Note down your Prod `AZURE_CLIENT_ID`, as you will add it in GitHub as an Environment Variable. (If you used a separate Tenant or Subscription for Prod, note those down as well.)
   1. In GitHub, go to your repository Settings, then under `Code and automation`, select `Environments`.
   2. Select `New environment` and enter `prod`
   3. Add any required reviewers (you should probably require an approval to deploy to Prod)
   4. Under `Environment variables`, Add an environment variable:
      1. `AZURE_CLIENT_ID` - App Id of the Prod Entra App/Service Principal
      2. If you used a separate Tenant or Subscription for Prod, add `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID` as well

# Project Structure
```
cashburn-starter-tf/
├── .github/
│   └── workflows/
│       ├── ci-cd.yml              # CI (validate, build, test) + CD (tf plan/apply)
|       └── deploy-template.yml    # Used by ci-cd.yml for deployment to each env. Modify this to add your deployment steps
|
├── .vscode/                       # Recommended VS Code settings/extensions
│
├── infra/
│   ├── main.tf                    # Add your terraform resources here
│   ├── providers.tf               # Azure + required providers
│   ├── backend.tf                 # Backend definition (no hardcoded values, all values in env/backend.*.config)
│   ├── variables.tf               # Input variables (env, location, app name)
│   ├── locals.tf                  # Combines the input vars together
│   │
|   └── bootstrap-tfstate/
│       ├── setup.ps1              # Azure Storage tfstate setup script (run once for all non-prod envs, once for prod)
|       ├── setup-env.ps1          # Azure OIDC federated credential script (run for each env during setup.ps1)
│       └── cleanup.ps1            # Delete Azure Storage resource group and Entra App/fed creds
|
│   └── env/
│       ├── backend.dev.config     # tfstate backend config (dev)
│       ├── backend.test.config    # tfstate backend config (test)
│       ├── backend.stage.config   # tfstate backend config (stage)
│       ├── backend.prod.config    # tfstate backend config (prod)
│       │
│       ├── dev.tfvars             # Environment variables (dev)
│       ├── test.tfvars            # Environment variables (test)
|       ├── stage.tfvars           # Environment variables (stage)
│       └── prod.tfvars            # Environment variables (prod)
│
├── .editorconfig
├── .gitignore
└── README.md                      # You are here!
```

# Cleanup
To clean up all the resources created by the bootstrap script, there is a `cleanup.ps1` script. This deletes:
- The tfstate Resource Group 
- The Entra App/Service Principal (the script searches for the App Name and deletes the id associated)
  - This includes all OIDC fed creds for all environments associated with the Entra App

1. **Make sure to destroy all resources in each environment before running the cleanup script!**
2. Run `pwsh ./infra/bootstrap-tfstate/cleanup.ps1` with your configured parameters for all the Non-Prod environments
   1. `TfStateResourceGroup` (Ex. `cashburn-starter-tf-tfstate-npd`) - The Azure Resource Group you would like to use for storing the Terraform backend/tfstate in Blob Storage (NOT your application resource group).
   2. `AppName` (Ex. `cashburn-starter-tf-npd`) - The name of your application used for the Entra App/Service Principal
3. Run `pwsh ./infra/bootstrap-tfstate/cleanup.ps1` again for Prod (make sure to log in to your other tenant/subscription if necessary)

Ex.
```
pwsh ./infra/bootstrap-tfstate/cleanup.ps1 -TfStateResourceGroup cashburn-starter-tf-tfstate-npd -AppName cashburn-starter-tf-npd
```
