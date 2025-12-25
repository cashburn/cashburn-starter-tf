param(
    [Parameter(Mandatory=$true)]
    [string]$AppId,

    [Parameter(Mandatory=$true)]
    [string]$GitHubOrg,

    [Parameter(Mandatory=$true)]
    [string]$GitHubRepo,

    [Parameter(Mandatory=$true)]
    [string]$Env
)

# Create GitHub OIDC Federated Credential for the specified environment
$federatedCred = @{
  name    = "github-oidc-$Env"
  issuer  = "https://token.actions.githubusercontent.com"
  subject = "repo:$GitHubOrg/$GitHubRepo`:environment:$Env"
  audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Depth 3

$federatedCred | Out-File "github-fed-cred.json"

az ad app federated-credential create `
  --id $AppId `
  --parameters @github-fed-cred.json

Remove-Item "github-fed-cred.json"

Write-Host "Federated credential for environment '$Env' created for AppId $AppId."