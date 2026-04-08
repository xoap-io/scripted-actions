<#
.SYNOPSIS
    List Azure Virtual Desktop Application Groups with the Azure CLI.

.DESCRIPTION
    This script lists Azure Virtual Desktop Application Groups using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER ResourceGroup
    Optional name of the Azure Resource Group to filter results.

.PARAMETER Filter
    Optional OData filter expression.

.PARAMETER MaxItems
    Optional maximum number of items to return.

.EXAMPLE
    .\az-cli-avd-application-group-list.ps1

.EXAMPLE
    .\az-cli-avd-application-group-list.ps1 -ResourceGroup "MyResourceGroup"

.EXAMPLE
    .\az-cli-avd-application-group-list.ps1 -ResourceGroup "MyResourceGroup" -MaxItems 10

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
    [Parameter(HelpMessage = "Optional name of the Azure Resource Group to filter results")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Optional OData filter expression")]
    [ValidateNotNullOrEmpty()]
    [string]$Filter,

    [Parameter(HelpMessage = "Optional maximum number of items to return (1-1000)")]
    [ValidateRange(1, 1000)]
    [int]$MaxItems
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

    Write-Host "Listing Azure Virtual Desktop Application Groups..." -ForegroundColor Cyan

    $azParams = @(
        'desktopvirtualization', 'applicationgroup', 'list',
        '--output', 'json'
    )

    if ($ResourceGroup) {
        $azParams += '--resource-group', $ResourceGroup
        Write-Host "  Filtering by Resource Group: $ResourceGroup" -ForegroundColor Yellow
    }

    if ($Filter) {
        $azParams += '--filter', $Filter
        Write-Host "  Applying filter: $Filter" -ForegroundColor Yellow
    }

    if ($MaxItems) {
        $azParams += '--max-items', $MaxItems.ToString()
        Write-Host "  Limiting results to: $MaxItems items" -ForegroundColor Yellow
    }

    $result = & az @azParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }

    $appGroups = $result | ConvertFrom-Json

    if ($appGroups -and $appGroups.Count -gt 0) {
        Write-Host "Found $($appGroups.Count) Application Group(s):" -ForegroundColor Green

        $appGroups | Format-Table -Property @(
            @{Name='Name'; Expression={$_.name}},
            @{Name='Type'; Expression={$_.applicationGroupType}},
            @{Name='Resource Group'; Expression={$_.resourceGroup}},
            @{Name='Location'; Expression={$_.location}},
            @{Name='Host Pool'; Expression={($_.hostPoolArmPath -split '/')[-1]}}
        ) -AutoSize

        return $appGroups
    } else {
        Write-Host "No Application Groups found" -ForegroundColor Yellow
        return @()
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
