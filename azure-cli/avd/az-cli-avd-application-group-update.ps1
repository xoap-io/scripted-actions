<#
.SYNOPSIS
    Update an Azure Virtual Desktop Application Group with the Azure CLI.

.DESCRIPTION
    This script updates an Azure Virtual Desktop Application Group using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER Name
    The name of the Azure Virtual Desktop Application Group to update.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER Add
    Add an object to a list of objects by specifying a path and key value pairs.

.PARAMETER ApplicationGroupType
    The type of the Azure Virtual Desktop Application Group. Valid values: 'Desktop', 'RemoteApp'

.PARAMETER Description
    Optional new description for the Application Group.

.PARAMETER ForceString
    Replace a string value with another string value. Valid values: '0', '1', 'f', 'false', 'n', 'no', 't', 'true', 'y', 'yes'

.PARAMETER FriendlyName
    Optional new friendly name for the Application Group.

.PARAMETER HostPoolArmPath
    Optional new host pool ARM path to associate with the Application Group.

.PARAMETER IDs
    One or more resource IDs (space-delimited). When provided, other parameters like Name and ResourceGroup are ignored.

.PARAMETER Remove
    Remove a property or an element from a list.

.PARAMETER Set
    Update an object by specifying a property path and value to set.

.PARAMETER Tags
    Optional tags to update in the format 'key1=value1 key2=value2'.

.EXAMPLE
    .\az-cli-avd-application-group-update.ps1 -Name "MyAppGroup" -ResourceGroup "MyResourceGroup" -Description "Updated description"

.EXAMPLE
    .\az-cli-avd-application-group-update.ps1 -Name "MyAppGroup" -ResourceGroup "MyRG" -FriendlyName "My Updated App Group" -Tags "Environment=Prod Owner=TeamA"

.EXAMPLE
    .\az-cli-avd-application-group-update.ps1 -Name "MyAppGroup" -ResourceGroup "MyRG" -HostPoolArmPath "/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.DesktopVirtualization/hostPools/newpool"

.EXAMPLE
    .\az-cli-avd-application-group-update.ps1 -Name "MyAppGroup" -ResourceGroup "MyRG" -Set "friendlyName=NewFriendlyName"

.EXAMPLE
    .\az-cli-avd-application-group-update.ps1 -IDs "/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.DesktopVirtualization/applicationGroups/myapp" -ApplicationGroupType "RemoteApp"

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
    [Parameter(Mandatory, HelpMessage = "The name of the Azure Virtual Desktop Application Group to update")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Add an object to a list of objects by specifying a path and key value pairs")]
    [ValidateNotNullOrEmpty()]
    [string]$Add,

    [Parameter(HelpMessage = "The type of the Application Group. Valid values: 'Desktop', 'RemoteApp'")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Desktop', 'RemoteApp')]
    [string]$ApplicationGroupType,

    [Parameter(HelpMessage = "Optional new description for the Application Group")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(HelpMessage = "Replace a string value with another string value")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('0', '1', 'f', 'false', 'n', 'no', 't', 'true', 'y', 'yes')]
    [string]$ForceString,

    [Parameter(HelpMessage = "Optional new friendly name for the Application Group")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(HelpMessage = "Optional new host pool ARM path to associate with the Application Group")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolArmPath,

    [Parameter(HelpMessage = "One or more resource IDs (space-delimited). When provided, Name and ResourceGroup are ignored")]
    [ValidateNotNullOrEmpty()]
    [string]$IDs,

    [Parameter(HelpMessage = "Remove a property or an element from a list")]
    [ValidateNotNullOrEmpty()]
    [string]$Remove,

    [Parameter(HelpMessage = "Update an object by specifying a property path and value to set")]
    [ValidateNotNullOrEmpty()]
    [string]$Set,

    [Parameter(HelpMessage = "Optional tags to update in the format 'key1=value1 key2=value2'")]
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

    Write-Host "Checking if Application Group exists..." -ForegroundColor Cyan
    $existingAppGroup = az desktopvirtualization applicationgroup show --name $Name --resource-group $ResourceGroup --output json 2>$null
    if (-not $existingAppGroup) {
        throw "Application Group '$Name' not found in resource group '$ResourceGroup'"
    }

    $currentAppGroup = $existingAppGroup | ConvertFrom-Json
    Write-Host "Found Application Group: $($currentAppGroup.name)" -ForegroundColor Yellow
    Write-Host "  Current Type: $($currentAppGroup.applicationGroupType)" -ForegroundColor Yellow
    Write-Host "  Current Description: $($currentAppGroup.description)" -ForegroundColor Yellow
    Write-Host "  Current Friendly Name: $($currentAppGroup.friendlyName)" -ForegroundColor Yellow
    Write-Host "  Current Host Pool ARM Path: $($currentAppGroup.hostPoolArmPath)" -ForegroundColor Yellow

    # Check if there are any updates to make
    $hasUpdates = $false
    $updateParams = @(
        'desktopvirtualization', 'applicationgroup', 'update',
        '--name', $Name,
        '--resource-group', $ResourceGroup
    )

    if ($Description -and $Description -ne $currentAppGroup.description) {
        $updateParams += '--description', $Description
        $hasUpdates = $true
        Write-Host "  Will update description to: $Description" -ForegroundColor Green
    }

    if ($FriendlyName -and $FriendlyName -ne $currentAppGroup.friendlyName) {
        $updateParams += '--friendly-name', $FriendlyName
        $hasUpdates = $true
        Write-Host "  Will update friendly name to: $FriendlyName" -ForegroundColor Green
    }

    if ($HostPoolArmPath -and $HostPoolArmPath -ne $currentAppGroup.hostPoolArmPath) {
        $updateParams += '--host-pool-arm-path', $HostPoolArmPath
        $hasUpdates = $true
        Write-Host "  Will update host pool ARM path to: $HostPoolArmPath" -ForegroundColor Green
    }

    if ($Tags) {
        $updateParams += '--tags', $Tags
        $hasUpdates = $true
        Write-Host "  Will update tags to: $Tags" -ForegroundColor Green
    }

    if (-not $hasUpdates) {
        Write-Host "No updates specified or no changes detected" -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Updating Azure Virtual Desktop Application Group..." -ForegroundColor Cyan

    # Add output format
    $updateParams += '--output', 'json'

    # Add optional parameters if provided
    if ($Add) {
        $updateParams += '--add', $Add
        Write-Host "  Will add: $Add" -ForegroundColor Green
    }

    if ($ApplicationGroupType -and $ApplicationGroupType -ne $currentAppGroup.applicationGroupType) {
        $updateParams += '--application-group-type', $ApplicationGroupType
        Write-Host "  Will update application group type to: $ApplicationGroupType" -ForegroundColor Green
    }

    if ($ForceString) {
        $updateParams += '--force-string', $ForceString
        Write-Host "  Will apply force-string: $ForceString" -ForegroundColor Green
    }

    if ($IDs) {
        $updateParams += '--ids', $IDs
        Write-Host "  Will use resource IDs: $IDs" -ForegroundColor Green
    }

    if ($Remove) {
        $updateParams += '--remove', $Remove
        Write-Host "  Will remove: $Remove" -ForegroundColor Green
    }

    if ($Set) {
        $updateParams += '--set', $Set
        Write-Host "  Will set: $Set" -ForegroundColor Green
    }

    $result = & az @updateParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }

    $updatedAppGroup = $result | ConvertFrom-Json

    Write-Host "Azure Virtual Desktop Application Group updated successfully:" -ForegroundColor Green
    Write-Host "  Name: $($updatedAppGroup.name)" -ForegroundColor White
    Write-Host "  Resource Group: $($updatedAppGroup.resourceGroup)" -ForegroundColor White
    Write-Host "  Type: $($updatedAppGroup.applicationGroupType)" -ForegroundColor White
    Write-Host "  Description: $($updatedAppGroup.description)" -ForegroundColor White
    Write-Host "  Friendly Name: $($updatedAppGroup.friendlyName)" -ForegroundColor White
    Write-Host "  Host Pool ARM Path: $($updatedAppGroup.hostPoolArmPath)" -ForegroundColor White
    Write-Host "  ID: $($updatedAppGroup.id)" -ForegroundColor White

    return $updatedAppGroup
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
