<#
.SYNOPSIS
    Create an Azure Virtual Desktop Host Pool with the Azure CLI.

.DESCRIPTION
    This script creates an Azure Virtual Desktop Host Pool using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER Name
    The name of the Azure Virtual Desktop Host Pool.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER HostPoolType
    The type of the host pool. Valid values: 'BYODesktops', 'Pooled', 'Personal'

.PARAMETER LoadBalancerType
    The load balancer type. Valid values: 'BreadthFirst', 'DepthFirst', 'Persistent'

.PARAMETER PreferredAppGroupType
    The preferred application group type. Valid values: 'Desktop', 'None', 'RailApplications'

.PARAMETER Location
    The Azure region for the host pool.

.PARAMETER MaxSessionLimit
    Maximum session limit for pooled host pools (1-999999).

.PARAMETER PersonalDesktopAssignmentType
    Assignment type for personal host pools. Valid values: 'Automatic', 'Direct'

.PARAMETER Description
    Optional description for the host pool.

.PARAMETER FriendlyName
    Optional friendly name for the host pool.

.PARAMETER CustomRdpProperty
    Optional custom RDP properties.

.PARAMETER StartVmOnConnect
    Enable start VM on connect feature.

.PARAMETER ValidationEnvironment
    Mark as validation environment.

.PARAMETER Tags
    Optional tags in the format 'key1=value1 key2=value2'.

.EXAMPLE
    .\az-cli-avd-hostpool-create.ps1 -Name "MyHostPool" -ResourceGroup "MyResourceGroup" -HostPoolType "Pooled" -LoadBalancerType "BreadthFirst" -PreferredAppGroupType "Desktop" -Location "eastus"

.EXAMPLE
    .\az-cli-avd-hostpool-create.ps1 -Name "PersonalPool" -ResourceGroup "MyRG" -HostPoolType "Personal" -LoadBalancerType "Persistent" -PreferredAppGroupType "Desktop" -Location "westus2" -PersonalDesktopAssignmentType "Automatic"

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

    [Parameter(Mandatory)]
    [ValidateSet('BYODesktops', 'Pooled', 'Personal')]
    [string]$HostPoolType,

    [Parameter(Mandatory)]
    [ValidateSet('BreadthFirst', 'DepthFirst', 'Persistent')]
    [string]$LoadBalancerType,

    [Parameter(Mandatory)]
    [ValidateSet('Desktop', 'None', 'RailApplications')]
    [string]$PreferredAppGroupType,

    [Parameter(Mandatory)]
    [ValidateSet(
        'eastus', 'eastus2', 'southcentralus', 'westus2',
        'westus3', 'australiaeast', 'southeastasia', 'northeurope',
        'swedencentral', 'uksouth', 'westeurope', 'centralus',
        'southafricanorth', 'centralindia', 'eastasia', 'japaneast',
        'koreacentral', 'canadacentral', 'francecentral', 'germanywestcentral',
        'italynorth', 'norwayeast', 'polandcentral', 'switzerlandnorth',
        'uaenorth', 'brazilsouth', 'israelcentral', 'qatarcentral'
    )]
    [string]$Location,

    [Parameter()]
    [ValidateRange(1, 999999)]
    [int]$MaxSessionLimit,

    [Parameter()]
    [ValidateSet('Automatic', 'Direct')]
    [string]$PersonalDesktopAssignmentType,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CustomRdpProperty,

    [Parameter()]
    [switch]$StartVmOnConnect,

    [Parameter()]
    [switch]$ValidationEnvironment,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Tags
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

    # Validate parameter combinations
    if ($HostPoolType -eq 'Pooled' -and $PersonalDesktopAssignmentType) {
        Write-Warning "PersonalDesktopAssignmentType is only valid for Personal host pools. Ignoring parameter."
        $PersonalDesktopAssignmentType = $null
    }

    if ($HostPoolType -eq 'Personal' -and $MaxSessionLimit) {
        Write-Warning "MaxSessionLimit is only valid for Pooled host pools. Ignoring parameter."
        $MaxSessionLimit = $null
    }

    if ($HostPoolType -eq 'Personal' -and $LoadBalancerType -ne 'Persistent') {
        Write-Warning "Personal host pools should use Persistent load balancer type. Changing to Persistent."
        $LoadBalancerType = 'Persistent'
    }

    Write-Host "Creating Azure Virtual Desktop Host Pool..." -ForegroundColor Cyan

    $azParams = @(
        'desktopvirtualization', 'hostpool', 'create',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--host-pool-type', $HostPoolType,
        '--load-balancer-type', $LoadBalancerType,
        '--preferred-app-group-type', $PreferredAppGroupType,
        '--location', $Location
    )

    if ($MaxSessionLimit -and $HostPoolType -eq 'Pooled') {
        $azParams += '--max-session-limit', $MaxSessionLimit.ToString()
    }

    if ($PersonalDesktopAssignmentType -and $HostPoolType -eq 'Personal') {
        $azParams += '--personal-desktop-assignment-type', $PersonalDesktopAssignmentType
    }

    if ($Description) {
        $azParams += '--description', $Description
    }

    if ($FriendlyName) {
        $azParams += '--friendly-name', $FriendlyName
    }

    if ($CustomRdpProperty) {
        $azParams += '--custom-rdp-property', $CustomRdpProperty
    }

    if ($StartVmOnConnect) {
        $azParams += '--start-vm-on-connect', 'true'
    }

    if ($ValidationEnvironment) {
        $azParams += '--validation-environment', 'true'
    }

    if ($Tags) {
        $azParams += '--tags', $Tags
    }

    $azParams += '--output', 'json'

    $result = & az @azParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }

    $hostPool = $result | ConvertFrom-Json

    Write-Host "Azure Virtual Desktop Host Pool created successfully:" -ForegroundColor Green
    Write-Host "  Name: $($hostPool.name)" -ForegroundColor White
    Write-Host "  Resource Group: $($hostPool.resourceGroup)" -ForegroundColor White
    Write-Host "  Location: $($hostPool.location)" -ForegroundColor White
    Write-Host "  Type: $($hostPool.hostPoolType)" -ForegroundColor White
    Write-Host "  Load Balancer Type: $($hostPool.loadBalancerType)" -ForegroundColor White
    Write-Host "  Preferred App Group Type: $($hostPool.preferredAppGroupType)" -ForegroundColor White
    Write-Host "  ID: $($hostPool.id)" -ForegroundColor White

    if ($hostPool.maxSessionLimit) {
        Write-Host "  Max Session Limit: $($hostPool.maxSessionLimit)" -ForegroundColor White
    }

    if ($hostPool.personalDesktopAssignmentType) {
        Write-Host "  Personal Desktop Assignment: $($hostPool.personalDesktopAssignmentType)" -ForegroundColor White
    }

    return $hostPool
} catch {
    Write-Error "Failed to create Azure Virtual Desktop Host Pool: $_"
    exit 1
}
