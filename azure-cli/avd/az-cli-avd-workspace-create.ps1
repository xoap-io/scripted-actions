<#
.SYNOPSIS
    Create an Azure Virtual Desktop workspace with the Azure CLI.

.DESCRIPTION
    This script creates an Azure Virtual Desktop workspace using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER Name
    The name of the Azure Virtual Desktop workspace.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER Location
    The Azure region for the workspace.

.PARAMETER ApplicationGroupReferences
    Optional application group references (space-separated ARM paths).

.PARAMETER Description
    Optional description of the workspace.

.PARAMETER FriendlyName
    Optional friendly name of the workspace.

.PARAMETER Tags
    Optional tags in the format 'key1=value1 key2=value2'.

.EXAMPLE
    .\az-cli-avd-workspace-create.ps1 -Name "MyWorkspace" -ResourceGroup "MyResourceGroup" -Location "eastus"

.EXAMPLE
    .\az-cli-avd-workspace-create.ps1 -Name "MyWorkspace" -ResourceGroup "MyRG" -Location "westus2" -FriendlyName "My AVD Workspace" -Description "Production workspace"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/workspace

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [ValidateSet(
        'eastus', 'eastus2', 'southcentralus', 'westus2',
        'westus3', 'australiaeast', 'southeastasia', 'northeurope',
        'swedencentral', 'uksouth', 'westeurope', 'centralus',
        'southafricanorth', 'centralindia', 'eastasia', 'japaneast',
        'koreacentral', 'canadacentral', 'francecentral', 'germanywestcentral',
        'italynorth', 'norwayeast', 'polandcentral', 'switzerlandnorth',
        'uaenorth', 'brazilsouth', 'israelcentral', 'qatarcentral'
    )]
    [string]$Location,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$ApplicationGroupReferences,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Tags
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating Azure CLI is available..." -ForegroundColor Cyan
    $azVersion = az version --output tsv --query '"azure-cli"' 2>$null
    if (-not $azVersion) {
        throw "Azure CLI is not installed or not available in PATH"
    }
    
    Write-Host "Checking Azure CLI login status..." -ForegroundColor Cyan
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $account) {
        throw "Not logged in to Azure CLI. Please run 'az login' first"
    }
    Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
    
    Write-Host "Creating Azure Virtual Desktop workspace..." -ForegroundColor Cyan
    
    $azParams = @(
        'desktopvirtualization', 'workspace', 'create',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--location', $Location
    )
    
    if ($ApplicationGroupReferences -and $ApplicationGroupReferences.Count -gt 0) {
        $azParams += '--application-group-references', ($ApplicationGroupReferences -join ' ')
        Write-Host "  Adding $($ApplicationGroupReferences.Count) application group reference(s)" -ForegroundColor Yellow
    }
    
    if ($Description) {
        $azParams += '--description', $Description
    }
    
    if ($FriendlyName) {
        $azParams += '--friendly-name', $FriendlyName
    }
    
    if ($Tags) {
        $azParams += '--tags', $Tags
    }
    
    $azParams += '--output', 'json'
    
    $result = & az @azParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }
    
    $workspace = $result | ConvertFrom-Json
    
    Write-Host "Azure Virtual Desktop workspace created successfully:" -ForegroundColor Green
    Write-Host "  Name: $($workspace.name)" -ForegroundColor White
    Write-Host "  Resource Group: $($workspace.resourceGroup)" -ForegroundColor White
    Write-Host "  Location: $($workspace.location)" -ForegroundColor White
    Write-Host "  Friendly Name: $($workspace.friendlyName)" -ForegroundColor White
    Write-Host "  Description: $($workspace.description)" -ForegroundColor White
    Write-Host "  ID: $($workspace.id)" -ForegroundColor White
    
    if ($workspace.applicationGroupReferences -and $workspace.applicationGroupReferences.Count -gt 0) {
        Write-Host "  Application Groups: $($workspace.applicationGroupReferences.Count)" -ForegroundColor White
    }
    
    return $workspace
} catch {
    Write-Error "Failed to create Azure Virtual Desktop workspace: $_"
    exit 1
}
