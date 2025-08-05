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

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/applicationgroup

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Filter,

    [Parameter()]
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
    Write-Error "Failed to list Azure Virtual Desktop Application Groups: $_"
    exit 1
}
