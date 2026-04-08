<#
.SYNOPSIS
    Delete an Azure Virtual Desktop Application Group with the Azure CLI.

.DESCRIPTION
    This script deletes an Azure Virtual Desktop Application Group using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER Name
    The name of the Azure Virtual Desktop Application Group to delete.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER Force
    Do not prompt for confirmation before deletion.

.EXAMPLE
    .\az-cli-avd-application-group-delete.ps1 -Name "MyAppGroup" -ResourceGroup "MyResourceGroup"

.EXAMPLE
    .\az-cli-avd-application-group-delete.ps1 -Name "MyAppGroup" -ResourceGroup "MyResourceGroup" -Force

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
    [Parameter(Mandatory, HelpMessage = "The name of the Azure Virtual Desktop Application Group to delete")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Do not prompt for confirmation before deletion")]
    [switch]$Force
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

    Write-Host "Checking if Application Group exists..." -ForegroundColor Cyan
    $existingAppGroup = az desktopvirtualization applicationgroup show --name $Name --resource-group $ResourceGroup --output json 2>$null
    if (-not $existingAppGroup) {
        Write-Warning "Application Group '$Name' not found in resource group '$ResourceGroup'"
        exit 0
    }

    $appGroupData = $existingAppGroup | ConvertFrom-Json
    Write-Host "Found Application Group: $($appGroupData.name)" -ForegroundColor Yellow
    Write-Host "  Type: $($appGroupData.applicationGroupType)" -ForegroundColor Yellow
    Write-Host "  Location: $($appGroupData.location)" -ForegroundColor Yellow

    if (-not $Force) {
        $confirmation = Read-Host "Are you sure you want to delete Application Group '$Name'? (y/N)"
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-Host "Deletion cancelled" -ForegroundColor Yellow
            exit 0
        }
    }

    Write-Host "Deleting Azure Virtual Desktop Application Group..." -ForegroundColor Cyan

    $azParams = @(
        'desktopvirtualization', 'applicationgroup', 'delete',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--yes'
    )

    & az @azParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }

    Write-Host "Azure Virtual Desktop Application Group '$Name' deleted successfully" -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
