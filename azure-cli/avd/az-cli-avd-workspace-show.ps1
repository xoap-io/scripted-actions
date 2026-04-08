<#
.SYNOPSIS
    Show details of an Azure Virtual Desktop Workspace with the Azure CLI.

.DESCRIPTION
    This script shows details of an Azure Virtual Desktop Workspace using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER Name
    The name of the Azure Virtual Desktop Workspace.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER IDs
    One or more resource IDs (space-delimited). When provided, Name and ResourceGroup parameters are ignored.

.EXAMPLE
    .\az-cli-avd-workspace-show.ps1 -Name "MyWorkspace" -ResourceGroup "MyResourceGroup"

.EXAMPLE
    .\az-cli-avd-workspace-show.ps1 -IDs "/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.DesktopVirtualization/workspaces/myworkspace"

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

[CmdletBinding(DefaultParameterSetName='ByName')]
param(
    [Parameter(Mandatory, ParameterSetName='ByName', HelpMessage = "The name of the Azure Virtual Desktop Workspace")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory, ParameterSetName='ByName', HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory, ParameterSetName='ByID', HelpMessage = "One or more resource IDs (space-delimited). When provided, Name and ResourceGroup parameters are ignored")]
    [ValidateNotNullOrEmpty()]
    [string]$IDs
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

    Write-Host "Retrieving Workspace details..." -ForegroundColor Cyan

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $azParams = @(
            'desktopvirtualization', 'workspace', 'show',
            '--name', $Name,
            '--resource-group', $ResourceGroup,
            '--output', 'json'
        )
        Write-Host "  Workspace: $Name" -ForegroundColor Yellow
        Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Yellow
    } else {
        $azParams = @(
            'desktopvirtualization', 'workspace', 'show',
            '--ids', $IDs,
            '--output', 'json'
        )
        Write-Host "  Using Resource IDs: $IDs" -ForegroundColor Yellow
    }

    $result = & az @azParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }

    $workspace = $result | ConvertFrom-Json

    Write-Host "✓ Workspace details retrieved successfully!" -ForegroundColor Green
    Write-Host "`nWorkspace Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($workspace.name)" -ForegroundColor White
    Write-Host "  Resource Group: $($workspace.resourceGroup)" -ForegroundColor White
    Write-Host "  Location: $($workspace.location)" -ForegroundColor White
    Write-Host "  Description: $($workspace.description)" -ForegroundColor White
    Write-Host "  Friendly Name: $($workspace.friendlyName)" -ForegroundColor White
    Write-Host "  ID: $($workspace.id)" -ForegroundColor DarkGray

    # Show application group references if available
    if ($workspace.applicationGroupReferences -and $workspace.applicationGroupReferences.Count -gt 0) {
        Write-Host "`nAssociated Application Groups:" -ForegroundColor Cyan
        foreach ($appGroupRef in $workspace.applicationGroupReferences) {
            Write-Host "  - $appGroupRef" -ForegroundColor White
        }
    } else {
        Write-Host "`nNo Application Groups associated with this Workspace" -ForegroundColor Yellow
    }

    return $workspace
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
