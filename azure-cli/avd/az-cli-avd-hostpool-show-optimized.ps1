<#
.SYNOPSIS
    Show details of an Azure Virtual Desktop Host Pool with the Azure CLI.

.DESCRIPTION
    This script shows details of an Azure Virtual Desktop Host Pool using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER Name
    The name of the Azure Virtual Desktop Host Pool.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER IDs
    One or more resource IDs (space-delimited). When provided, Name and ResourceGroup parameters are ignored.

.EXAMPLE
    .\az-cli-avd-hostpool-show.ps1 -Name "MyHostPool" -ResourceGroup "MyResourceGroup"

.EXAMPLE
    .\az-cli-avd-hostpool-show.ps1 -IDs "/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.DesktopVirtualization/hostPools/mypool"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/hostpool

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
    
    Write-Host "Retrieving Host Pool details..." -ForegroundColor Cyan
    
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $azParams = @(
            'desktopvirtualization', 'hostpool', 'show',
            '--name', $Name,
            '--resource-group', $ResourceGroup,
            '--output', 'json'
        )
        Write-Host "  Host Pool: $Name" -ForegroundColor Yellow
        Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Yellow
    } else {
        $azParams = @(
            'desktopvirtualization', 'hostpool', 'show',
            '--ids', $IDs,
            '--output', 'json'
        )
        Write-Host "  Using Resource IDs: $IDs" -ForegroundColor Yellow
    }
    
    $result = & az @azParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }
    
    $hostPool = $result | ConvertFrom-Json
    
    Write-Host "✓ Host Pool details retrieved successfully!" -ForegroundColor Green
    Write-Host "`nHost Pool Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($hostPool.name)" -ForegroundColor White
    Write-Host "  Resource Group: $($hostPool.resourceGroup)" -ForegroundColor White
    Write-Host "  Location: $($hostPool.location)" -ForegroundColor White
    Write-Host "  Type: $($hostPool.hostPoolType)" -ForegroundColor White
    Write-Host "  Load Balancer Type: $($hostPool.loadBalancerType)" -ForegroundColor White
    Write-Host "  Max Session Limit: $($hostPool.maxSessionLimit)" -ForegroundColor White
    Write-Host "  Personal Desktop Assignment Type: $($hostPool.personalDesktopAssignmentType)" -ForegroundColor White
    Write-Host "  Preferred App Group Type: $($hostPool.preferredAppGroupType)" -ForegroundColor White
    Write-Host "  Description: $($hostPool.description)" -ForegroundColor White
    Write-Host "  Friendly Name: $($hostPool.friendlyName)" -ForegroundColor White
    Write-Host "  Validation Environment: $($hostPool.validationEnvironment)" -ForegroundColor White
    Write-Host "  Start VM on Connect: $($hostPool.startVmOnConnect)" -ForegroundColor White
    Write-Host "  Custom RDP Property: $($hostPool.customRdpProperty)" -ForegroundColor White
    Write-Host "  VM Template: $($hostPool.vmTemplate)" -ForegroundColor White
    Write-Host "  ID: $($hostPool.id)" -ForegroundColor DarkGray
    
    # Show registration info if available
    if ($hostPool.registrationInfo) {
        Write-Host "`nRegistration Info:" -ForegroundColor Cyan
        Write-Host "  Expiration Time: $($hostPool.registrationInfo.expirationTime)" -ForegroundColor White
        Write-Host "  Registration Token Enabled: $($hostPool.registrationInfo.registrationTokenOperation)" -ForegroundColor White
    }
    
    return $hostPool
} catch {
    Write-Error "Failed to retrieve Host Pool details: $_"
    exit 1
}
