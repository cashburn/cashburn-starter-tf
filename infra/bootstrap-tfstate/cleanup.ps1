# ./infra/bootstrap-tfstate/cleanup.ps1 -TfStateResourceGroup cashburn-starter-tf-tfstate-npd -AppName cashburn-starter-tf-npd

param(
    [Parameter(Mandatory=$true)]
    [string]$TfStateResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$AppName 
)

Write-Host "Logging into Azure..."
az login

$subId    = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv

# Delete tfstate Resource Group
Write-Host "Deleting Resource Group $TfStateResourceGroup ..."
az group delete `
  --name $TfStateResourceGroup `

# Delete Entra App and Service Principal
$appId = az ad app list `
  --display-name $AppName `
  --query "[0].appId" -o tsv

if (-not [string]::IsNullOrEmpty($appId)) {
  Write-Host "Deleting Entra App and Service Principal with AppId $appId ..."
  az ad app delete --id $appId
} else {
  Write-Host "Entra App with name $AppName not found. Skipping deletion."
}