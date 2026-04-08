<#
.SYNOPSIS
    List Azure Virtual Desktop Workspaces with the Azure CLI.

.DESCRIPTION
    This script lists Azure Virtual Desktop Workspaces using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER ResourceGroup
    Optional name of the Azure Resource Group to filter results.

.PARAMETER MaxItems
    Optional maximum number of items to return.

.PARAMETER NextToken
    Optional token to retrieve the next page of results.

.EXAMPLE
    .\az-cli-avd-workspace-list.ps1

.EXAMPLE
    .\az-cli-avd-workspace-list.ps1 -ResourceGroup "MyResourceGroup"

.EXAMPLE
    .\az-cli-avd-workspace-list.ps1 -ResourceGroup "MyResourceGroup" -MaxItems 10

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
    [Parameter(HelpMessage = "Optional name of the Azure Resource Group to filter results")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Optional maximum number of items to return (1-1000)")]
    [ValidateRange(1, 1000)]
    [int]$MaxItems,

    [Parameter(HelpMessage = "Optional token to retrieve the next page of results")]
    [ValidateNotNullOrEmpty()]
    [string]$NextToken
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

    Write-Host "Listing Azure Virtual Desktop Workspaces..." -ForegroundColor Cyan

    # Build command parameters
    $listParams = @(
        'desktopvirtualization', 'workspace', 'list',
        '--output', 'json'
    )

    if ($ResourceGroup) {
        $listParams += '--resource-group', $ResourceGroup
        Write-Host "  Filtering by Resource Group: $ResourceGroup" -ForegroundColor Yellow
    }

    if ($MaxItems) {
        $listParams += '--max-items', $MaxItems
        Write-Host "  Limiting results to: $MaxItems items" -ForegroundColor Yellow
    }

    if ($NextToken) {
        $listParams += '--next-token', $NextToken
        Write-Host "  Using next token for pagination" -ForegroundColor Yellow
    }

    $result = & az @listParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }

    $workspaces = $result | ConvertFrom-Json

    if ($workspaces -and $workspaces.Count -gt 0) {
        Write-Host "✓ Found $($workspaces.Count) Workspace(s)" -ForegroundColor Green
        Write-Host "`nWorkspace Summary:" -ForegroundColor Cyan

        foreach ($workspace in $workspaces) {
            Write-Host "  Name: $($workspace.name)" -ForegroundColor White
            Write-Host "    Resource Group: $($workspace.resourceGroup)" -ForegroundColor Gray
            Write-Host "    Location: $($workspace.location)" -ForegroundColor Gray
            Write-Host "    Description: $($workspace.description)" -ForegroundColor Gray
            Write-Host "    Friendly Name: $($workspace.friendlyName)" -ForegroundColor Gray
            if ($workspace.applicationGroupReferences -and $workspace.applicationGroupReferences.Count -gt 0) {
                Write-Host "    Application Groups: $($workspace.applicationGroupReferences.Count)" -ForegroundColor Gray
            }
            Write-Host "    ID: $($workspace.id)" -ForegroundColor DarkGray
            Write-Host ""
        }
    } else {
        Write-Host "No Workspaces found" -ForegroundColor Yellow
        if ($ResourceGroup) {
            Write-Host "  In Resource Group: $ResourceGroup" -ForegroundColor Yellow
        }
    }

    return $workspaces
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
