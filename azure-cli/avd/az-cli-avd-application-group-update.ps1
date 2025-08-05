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

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/applicationgroup

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
    [ValidateNotNullOrEmpty()]
    [string]$Add,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Desktop', 'RemoteApp')]
    [string]$ApplicationGroupType,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('0', '1', 'f', 'false', 'n', 'no', 't', 'true', 'y', 'yes')]
    [string]$ForceString,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolArmPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$IDs,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Remove,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Set,

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
    Write-Error "Failed to update Azure Virtual Desktop Application Group: $_"
    exit 1
}
