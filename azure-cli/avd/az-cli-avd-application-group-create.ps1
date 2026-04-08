<#
.SYNOPSIS
    Create an Azure Virtual Desktop Application Group with the Azure CLI.

.DESCRIPTION
    This script creates an Azure Virtual Desktop Application Group using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER AppGroupType
    The type of the Azure Virtual Desktop Application Group.
    Valid values: 'Desktop', 'RemoteApp'

.PARAMETER HostPoolArmPath
    The ARM path of the Azure Virtual Desktop Host Pool.

.PARAMETER Name
    The name of the Azure Virtual Desktop Application Group.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER Description
    Optional description of the Azure Virtual Desktop Application Group.

.PARAMETER FriendlyName
    Optional friendly name of the Azure Virtual Desktop Application Group.

.PARAMETER Location
    Optional location of the Azure Virtual Desktop Application Group.

.PARAMETER Tags
    Optional tags for the Azure Virtual Desktop Application Group in the format 'key1=value1 key2=value2'.

.EXAMPLE
    .\az-cli-avd-application-group-create.ps1 -ResourceGroup "MyResourceGroup" -Name "MyAppGroup" -Location "eastus" -HostPoolArmPath "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myResourceGroup/providers/Microsoft.DesktopVirtualization/hostPools/myHostPool" -AppGroupType "RemoteApp"

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
    [Parameter(Mandatory, HelpMessage = "The type of the Application Group. Valid values: 'Desktop', 'RemoteApp'")]
    [ValidateSet('Desktop', 'RemoteApp')]
    [string]$AppGroupType,

    [Parameter(Mandatory, HelpMessage = "The ARM path of the Azure Virtual Desktop Host Pool")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolArmPath,

    [Parameter(Mandatory, HelpMessage = "The name of the Azure Virtual Desktop Application Group")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Optional description of the Azure Virtual Desktop Application Group")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(HelpMessage = "Optional friendly name of the Azure Virtual Desktop Application Group")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(HelpMessage = "Optional location of the Azure Virtual Desktop Application Group")]
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

    [Parameter(HelpMessage = "Optional tags for the Application Group in the format 'key1=value1 key2=value2'")]
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

    Write-Host "Creating Azure Virtual Desktop Application Group..." -ForegroundColor Cyan

    # Build command parameters
    $azParams = @(
        'desktopvirtualization', 'applicationgroup', 'create',
        '--resource-group', $ResourceGroup,
        '--name', $Name,
        '--application-group-type', $AppGroupType,
        '--host-pool-arm-path', $HostPoolArmPath
    )

    if ($Location) {
        $azParams += '--location', $Location
    }

    if ($Description) {
        $azParams += '--description', $Description
    }

    if ($FriendlyName) {
        $azParams += '--friendly-name', $FriendlyName
    }

    if ($Tags) {
        $azParams += '--tags', $Tags
    }

    $azParams += '--output', 'json'

    $result = & az @azParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }

    $appGroup = $result | ConvertFrom-Json

    Write-Host "Azure Virtual Desktop Application Group created successfully:" -ForegroundColor Green
    Write-Host "  Name: $($appGroup.name)" -ForegroundColor White
    Write-Host "  Resource Group: $($appGroup.resourceGroup)" -ForegroundColor White
    Write-Host "  Location: $($appGroup.location)" -ForegroundColor White
    Write-Host "  Type: $($appGroup.applicationGroupType)" -ForegroundColor White
    Write-Host "  ID: $($appGroup.id)" -ForegroundColor White

    return $appGroup
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
