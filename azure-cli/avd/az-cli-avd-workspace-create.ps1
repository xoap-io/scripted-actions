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

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/workspace

.COMPONENT
    Azure CLI Virtual Desktop
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, HelpMessage = "The name of the Azure Virtual Desktop workspace")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory, HelpMessage = "The Azure region for the workspace")]
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

    [Parameter(HelpMessage = "Optional application group references (space-separated ARM paths)")]
    [ValidateNotNullOrEmpty()]
    [string[]]$ApplicationGroupReferences,

    [Parameter(HelpMessage = "Optional description of the workspace")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(HelpMessage = "Optional friendly name of the workspace")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(HelpMessage = "Optional tags in the format 'key1=value1 key2=value2'")]
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
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
