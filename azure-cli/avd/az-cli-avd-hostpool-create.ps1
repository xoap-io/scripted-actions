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
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/hostpool

.COMPONENT
    Azure CLI Virtual Desktop
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, HelpMessage = "The name of the Azure Virtual Desktop Host Pool")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory, HelpMessage = "The type of the host pool. Valid values: 'BYODesktops', 'Pooled', 'Personal'")]
    [ValidateSet('BYODesktops', 'Pooled', 'Personal')]
    [string]$HostPoolType,

    [Parameter(Mandatory, HelpMessage = "The load balancer type. Valid values: 'BreadthFirst', 'DepthFirst', 'Persistent'")]
    [ValidateSet('BreadthFirst', 'DepthFirst', 'Persistent')]
    [string]$LoadBalancerType,

    [Parameter(Mandatory, HelpMessage = "The preferred application group type. Valid values: 'Desktop', 'None', 'RailApplications'")]
    [ValidateSet('Desktop', 'None', 'RailApplications')]
    [string]$PreferredAppGroupType,

    [Parameter(Mandatory, HelpMessage = "The Azure region for the host pool")]
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

    [Parameter(HelpMessage = "Maximum session limit for pooled host pools (1-999999)")]
    [ValidateRange(1, 999999)]
    [int]$MaxSessionLimit,

    [Parameter(HelpMessage = "Assignment type for personal host pools. Valid values: 'Automatic', 'Direct'")]
    [ValidateSet('Automatic', 'Direct')]
    [string]$PersonalDesktopAssignmentType,

    [Parameter(HelpMessage = "Optional description for the host pool")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(HelpMessage = "Optional friendly name for the host pool")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(HelpMessage = "Optional custom RDP properties")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomRdpProperty,

    [Parameter(HelpMessage = "Enable start VM on connect feature")]
    [switch]$StartVmOnConnect,

    [Parameter(HelpMessage = "Mark as validation environment")]
    [switch]$ValidationEnvironment,

    [Parameter(HelpMessage = "Optional tags in the format 'key1=value1 key2=value2'")]
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
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
