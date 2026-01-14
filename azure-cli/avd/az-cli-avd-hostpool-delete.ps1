<#
.SYNOPSIS
    Delete an Azure Virtual Desktop Host Pool with the Azure CLI.

.DESCRIPTION
    This script deletes an Azure Virtual Desktop Host Pool using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER Name
    The name of the Azure Virtual Desktop Host Pool to delete.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER Force
    Do not prompt for confirmation before deletion.

.EXAMPLE
    .\az-cli-avd-hostpool-delete.ps1 -Name "MyHostPool" -ResourceGroup "MyResourceGroup"

.EXAMPLE
    .\az-cli-avd-hostpool-delete.ps1 -Name "MyHostPool" -ResourceGroup "MyResourceGroup" -Force

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/hostpool

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

    Write-Host "Checking if Host Pool exists..." -ForegroundColor Cyan
    $existingHostPool = az desktopvirtualization hostpool show --name $Name --resource-group $ResourceGroup --output json 2>$null
    if (-not $existingHostPool) {
        Write-Warning "Host Pool '$Name' not found in resource group '$ResourceGroup'"
        exit 0
    }

    $hostPoolData = $existingHostPool | ConvertFrom-Json
    Write-Host "Found Host Pool: $($hostPoolData.name)" -ForegroundColor Yellow
    Write-Host "  Type: $($hostPoolData.hostPoolType)" -ForegroundColor Yellow
    Write-Host "  Location: $($hostPoolData.location)" -ForegroundColor Yellow
    Write-Host "  Load Balancer Type: $($hostPoolData.loadBalancerType)" -ForegroundColor Yellow

    if (-not $Force) {
        $confirmation = Read-Host "Are you sure you want to delete Host Pool '$Name'? This action cannot be undone! (y/N)"
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-Host "Deletion cancelled" -ForegroundColor Yellow
            exit 0
        }
    }

    Write-Host "Deleting Azure Virtual Desktop Host Pool..." -ForegroundColor Cyan

    $azParams = @(
        'desktopvirtualization', 'hostpool', 'delete',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--yes'
    )

    & az @azParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }

    Write-Host "Azure Virtual Desktop Host Pool '$Name' deleted successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to delete Azure Virtual Desktop Host Pool: $_"
    exit 1
}
