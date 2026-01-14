<#
.SYNOPSIS
    Delete an Azure Virtual Desktop Workspace with the Azure CLI.

.DESCRIPTION
    This script deletes an Azure Virtual Desktop Workspace using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER Name
    The name of the Azure Virtual Desktop Workspace to delete.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER IDs
    One or more resource IDs (space-delimited). When provided, Name and ResourceGroup parameters are ignored.

.PARAMETER Force
    Do not prompt for confirmation before deletion.

.EXAMPLE
    .\az-cli-avd-workspace-delete.ps1 -Name "MyWorkspace" -ResourceGroup "MyResourceGroup"

.EXAMPLE
    .\az-cli-avd-workspace-delete.ps1 -Name "MyWorkspace" -ResourceGroup "MyResourceGroup" -Force

.EXAMPLE
    .\az-cli-avd-workspace-delete.ps1 -IDs "/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.DesktopVirtualization/workspaces/myworkspace" -Force

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/workspace

.COMPONENT
    Azure CLI
#>

[CmdletBinding(DefaultParameterSetName='ByName')]
param(
    [Parameter(Mandatory, ParameterSetName='ByName')]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory, ParameterSetName='ByName')]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory, ParameterSetName='ByID')]
    [ValidateNotNullOrEmpty()]
    [string]$IDs,

    [Parameter()]
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

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        Write-Host "Checking if Workspace exists..." -ForegroundColor Cyan
        $existingWorkspace = az desktopvirtualization workspace show --name $Name --resource-group $ResourceGroup --output json 2>$null
        if (-not $existingWorkspace) {
            Write-Warning "Workspace '$Name' not found in resource group '$ResourceGroup'"
            exit 0
        }

        $workspaceData = $existingWorkspace | ConvertFrom-Json
        Write-Host "Found Workspace: $($workspaceData.name)" -ForegroundColor Yellow
        Write-Host "  Location: $($workspaceData.location)" -ForegroundColor Yellow
        Write-Host "  Description: $($workspaceData.description)" -ForegroundColor Yellow
        if ($workspaceData.applicationGroupReferences -and $workspaceData.applicationGroupReferences.Count -gt 0) {
            Write-Host "  Associated Application Groups: $($workspaceData.applicationGroupReferences.Count)" -ForegroundColor Yellow
        }

        if (-not $Force) {
            $confirmation = Read-Host "Are you sure you want to delete Workspace '$Name'? This action cannot be undone! (y/N)"
            if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                Write-Host "Deletion cancelled" -ForegroundColor Yellow
                exit 0
            }
        }

        Write-Host "Deleting Azure Virtual Desktop Workspace..." -ForegroundColor Red
        $deleteParams = @(
            'desktopvirtualization', 'workspace', 'delete',
            '--name', $Name,
            '--resource-group', $ResourceGroup,
            '--yes'
        )

        $displayName = $Name
    } else {
        Write-Host "Deleting Workspace using resource IDs..." -ForegroundColor Red
        $deleteParams = @(
            'desktopvirtualization', 'workspace', 'delete',
            '--ids', $IDs,
            '--yes'
        )

        $displayName = $IDs
    }

    & az @deleteParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }

    Write-Host "✓ Azure Virtual Desktop Workspace deleted successfully!" -ForegroundColor Green
    Write-Host "  Deleted: $displayName" -ForegroundColor White

} catch {
    Write-Error "Failed to delete Azure Virtual Desktop Workspace: $_"
    exit 1
}
