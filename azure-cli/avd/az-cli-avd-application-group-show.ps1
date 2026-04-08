<#
.SYNOPSIS
    Show details of an Azure Virtual Desktop Application Group with the Azure CLI.

.DESCRIPTION
    This script shows details of an Azure Virtual Desktop Application Group using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER Name
    The name of the Azure Virtual Desktop Application Group.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.EXAMPLE
    .\az-cli-avd-application-group-show.ps1 -Name "MyAppGroup" -ResourceGroup "MyResourceGroup"

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
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/applicationgroup

.COMPONENT
    Azure CLI Virtual Desktop
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, HelpMessage = "The name of the Azure Virtual Desktop Application Group")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup
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

    Write-Host "Retrieving Application Group details..." -ForegroundColor Cyan

    $azParams = @(
        'desktopvirtualization', 'applicationgroup', 'show',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--output', 'json'
    )

    $result = & az @azParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }

    $appGroup = $result | ConvertFrom-Json

    Write-Host "Application Group Details:" -ForegroundColor Green
    Write-Host "  Name: $($appGroup.name)" -ForegroundColor White
    Write-Host "  Resource Group: $($appGroup.resourceGroup)" -ForegroundColor White
    Write-Host "  Location: $($appGroup.location)" -ForegroundColor White
    Write-Host "  Type: $($appGroup.applicationGroupType)" -ForegroundColor White
    Write-Host "  Host Pool: $($appGroup.hostPoolArmPath)" -ForegroundColor White
    Write-Host "  Description: $($appGroup.description)" -ForegroundColor White
    Write-Host "  Friendly Name: $($appGroup.friendlyName)" -ForegroundColor White
    Write-Host "  ID: $($appGroup.id)" -ForegroundColor White

    return $appGroup
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
