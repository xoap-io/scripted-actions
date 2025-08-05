<#
.SYNOPSIS
    List Azure Virtual Desktop Host Pools with the Azure CLI.

.DESCRIPTION
    This script lists Azure Virtual Desktop Host Pools using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER ResourceGroup
    Optional name of the Azure Resource Group to filter results.

.PARAMETER MaxItems
    Optional maximum number of items to return.

.PARAMETER NextToken
    Optional token to retrieve the next page of results.

.EXAMPLE
    .\az-cli-avd-hostpool-list.ps1

.EXAMPLE
    .\az-cli-avd-hostpool-list.ps1 -ResourceGroup "MyResourceGroup"

.EXAMPLE
    .\az-cli-avd-hostpool-list.ps1 -ResourceGroup "MyResourceGroup" -MaxItems 10

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/hostpool

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter()]
    [ValidateRange(1, 1000)]
    [int]$MaxItems,

    [Parameter()]
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
    
    Write-Host "Listing Azure Virtual Desktop Host Pools..." -ForegroundColor Cyan
    
    # Build command parameters
    $listParams = @(
        'desktopvirtualization', 'hostpool', 'list',
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
    
    $hostPools = $result | ConvertFrom-Json
    
    if ($hostPools -and $hostPools.Count -gt 0) {
        Write-Host "✓ Found $($hostPools.Count) Host Pool(s)" -ForegroundColor Green
        Write-Host "`nHost Pool Summary:" -ForegroundColor Cyan
        
        foreach ($pool in $hostPools) {
            Write-Host "  Name: $($pool.name)" -ForegroundColor White
            Write-Host "    Resource Group: $($pool.resourceGroup)" -ForegroundColor Gray
            Write-Host "    Location: $($pool.location)" -ForegroundColor Gray
            Write-Host "    Type: $($pool.hostPoolType)" -ForegroundColor Gray
            Write-Host "    Load Balancer Type: $($pool.loadBalancerType)" -ForegroundColor Gray
            Write-Host "    Max Session Limit: $($pool.maxSessionLimit)" -ForegroundColor Gray
            Write-Host "    Validation Environment: $($pool.validationEnvironment)" -ForegroundColor Gray
            Write-Host "    ID: $($pool.id)" -ForegroundColor DarkGray
            Write-Host ""
        }
    } else {
        Write-Host "No Host Pools found" -ForegroundColor Yellow
        if ($ResourceGroup) {
            Write-Host "  In Resource Group: $ResourceGroup" -ForegroundColor Yellow
        }
    }
    
    return $hostPools
} catch {
    Write-Error "Failed to list Azure Virtual Desktop Host Pools: $_"
    exit 1
}
