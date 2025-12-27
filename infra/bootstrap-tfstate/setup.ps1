# ./infra/bootstrap-tfstate/setup.ps1 -TfStateResourceGroup cashburn-starter-tf-tfstate-npd -AppName cashburn-starter-tf-npd -Location centralus -StorageAccountName cashburnstartertfnpd -GitHubOrg cashburn -GitHubRepo cashburn-starter-tf

param(
    [Parameter(Mandatory=$true)]
    [string]$TfStateResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$AppName,

    [Parameter(Mandatory=$true)]
    [string]$Location,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory=$true)]
    [string]$GitHubOrg,

    [Parameter(Mandatory=$true)]
    [string]$GitHubRepo,

    [Parameter(Mandatory=$false)]
    [string]$ContainerName = "tfstate",

    [Parameter(Mandatory=$false)]
    [string]$Envs = "dev,test" # Comma-separated list of environments
)

Write-Host "Logging into Azure..."
az login

$subId    = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv

# Create tfstate Resource Group and Storage Account
az group create `
  --name $TfStateResourceGroup `
  --location $Location

az storage account create `
  --name $StorageAccountName `
  --resource-group $TfStateResourceGroup `
  --location $Location `
  --sku Standard_LRS

$storageAccountKey = az storage account keys list `
  --resource-group $TfStateResourceGroup `
  --account-name $StorageAccountName `
  --query "[0].value" -o tsv

# Enable versioning + soft delete
az storage account blob-service-properties update `
  --resource-group $TfStateResourceGroup `
  --account-name $StorageAccountName `
  --enable-versioning true `
  --enable-delete-retention true `
  --delete-retention-days 14

az storage container create `
  --account-name $StorageAccountName `
  --name $ContainerName `
  --account-key $storageAccountKey

# Create Entra App and Service Principal
$appId = az ad app create `
  --display-name $AppName `
  --query appId -o tsv

if ([string]::IsNullOrEmpty($appId)) {
  $appId = az ad app list `
    --display-name $AppName `
    --query "[0].appId" -o tsv
}

az ad sp create --id $appId

# Add Contributor role for Terraform-managed infra
az role assignment create `
  --assignee $appId `
  --role "Contributor" `
  --scope "/subscriptions/$subId" 


# Call setup-env.ps1 for each environment in the comma-separated list
$setupEnvScript = Join-Path $PSScriptRoot "setup-env.ps1"
$envList = $Envs -split ',' | ForEach-Object { $_.Trim() }
foreach ($env in $envList) {
    Write-Host "Running setup-env.ps1 for environment '$env'..."
    & $setupEnvScript -AppId $appId -GitHubOrg $GitHubOrg -GitHubRepo $GitHubRepo -Env $env
}

Write-Host "----------------------------------------"
Write-Host "AZURE_CLIENT_ID       = $appId"
Write-Host "AZURE_TENANT_ID       = $tenantId"
Write-Host "AZURE_SUBSCRIPTION_ID = $subId"
Write-Host "----------------------------------------"