<#
.SYNOPSIS
    Update an Azure Virtual Desktop Workspace with the Azure CLI.

.DESCRIPTION
    This script updates an Azure Virtual Desktop Workspace using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER Name
    The name of the Azure Virtual Desktop Workspace to update.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER Add
    Add an object to a list of objects by specifying a path and key value pairs.

.PARAMETER ApplicationGroupReferences
    The application group references for the workspace.

.PARAMETER Description
    Optional new description for the workspace.

.PARAMETER ForceString
    Replace a string value with another string value.

.PARAMETER FriendlyName
    Optional new friendly name for the workspace.

.PARAMETER IDs
    One or more resource IDs (space-delimited). When provided, other parameters like Name and ResourceGroup are ignored.

.PARAMETER Remove
    Remove a property or an element from a list.

.PARAMETER Set
    Update an object by specifying a property path and value to set.

.PARAMETER Tags
    Optional tags in the format 'key1=value1 key2=value2'.

.EXAMPLE
    .\az-cli-avd-workspace-update.ps1 -Name "MyWorkspace" -ResourceGroup "MyResourceGroup" -Description "Updated description"

.EXAMPLE
    .\az-cli-avd-workspace-update.ps1 -Name "MyWorkspace" -ResourceGroup "MyRG" -FriendlyName "My Updated Workspace" -Tags "Environment=Prod Owner=TeamA"

.EXAMPLE
    .\az-cli-avd-workspace-update.ps1 -Name "MyWorkspace" -ResourceGroup "MyRG" -Set "description=NewDescription"

.EXAMPLE
    .\az-cli-avd-workspace-update.ps1 -IDs "/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.DesktopVirtualization/workspaces/myworkspace" -FriendlyName "Updated Workspace"

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
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/workspace

.COMPONENT
    Azure CLI Virtual Desktop
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, HelpMessage = "The name of the Azure Virtual Desktop Workspace to update")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Add an object to a list of objects by specifying a path and key value pairs")]
    [ValidateNotNullOrEmpty()]
    [string]$Add,

    [Parameter(HelpMessage = "The application group references for the workspace")]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationGroupReferences,

    [Parameter(HelpMessage = "Optional new description for the workspace")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(HelpMessage = "Replace a string value with another string value")]
    [ValidateNotNullOrEmpty()]
    [string]$ForceString,

    [Parameter(HelpMessage = "Optional new friendly name for the workspace")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(HelpMessage = "One or more resource IDs (space-delimited). When provided, Name and ResourceGroup are ignored")]
    [ValidateNotNullOrEmpty()]
    [string]$IDs,

    [Parameter(HelpMessage = "Remove a property or an element from a list")]
    [ValidateNotNullOrEmpty()]
    [string]$Remove,

    [Parameter(HelpMessage = "Update an object by specifying a property path and value to set")]
    [ValidateNotNullOrEmpty()]
    [string]$Set,

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

    Write-Host "Checking if Workspace exists..." -ForegroundColor Cyan
    $existingWorkspace = az desktopvirtualization workspace show --name $Name --resource-group $ResourceGroup --output json 2>$null
    if (-not $existingWorkspace) {
        throw "Workspace '$Name' not found in resource group '$ResourceGroup'"
    }

    $currentWorkspace = $existingWorkspace | ConvertFrom-Json
    Write-Host "Found Workspace: $($currentWorkspace.name)" -ForegroundColor Yellow
    Write-Host "  Current Description: $($currentWorkspace.description)" -ForegroundColor Yellow
    Write-Host "  Current Friendly Name: $($currentWorkspace.friendlyName)" -ForegroundColor Yellow
    Write-Host "  Current Application Group References: $($currentWorkspace.applicationGroupReferences -join ', ')" -ForegroundColor Yellow

    # Check if there are any updates to make
    $hasUpdates = $false

    Write-Host "Updating Azure Virtual Desktop Workspace..." -ForegroundColor Cyan

    # Build base command
    $updateParams = @(
        'desktopvirtualization', 'workspace', 'update',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--output', 'json'
    )

    # Add optional parameters if provided
    if ($Add) {
        $updateParams += '--add', $Add
        $hasUpdates = $true
        Write-Host "  Will add: $Add" -ForegroundColor Green
    }

    if ($ApplicationGroupReferences -and ($ApplicationGroupReferences -ne ($currentWorkspace.applicationGroupReferences -join ' '))) {
        $updateParams += '--application-group-references', $ApplicationGroupReferences
        $hasUpdates = $true
        Write-Host "  Will update application group references to: $ApplicationGroupReferences" -ForegroundColor Green
    }

    if ($Description -and $Description -ne $currentWorkspace.description) {
        $updateParams += '--description', $Description
        $hasUpdates = $true
        Write-Host "  Will update description to: $Description" -ForegroundColor Green
    }

    if ($ForceString) {
        $updateParams += '--force-string', $ForceString
        $hasUpdates = $true
        Write-Host "  Will apply force-string: $ForceString" -ForegroundColor Green
    }

    if ($FriendlyName -and $FriendlyName -ne $currentWorkspace.friendlyName) {
        $updateParams += '--friendly-name', $FriendlyName
        $hasUpdates = $true
        Write-Host "  Will update friendly name to: $FriendlyName" -ForegroundColor Green
    }

    if ($IDs) {
        $updateParams += '--ids', $IDs
        $hasUpdates = $true
        Write-Host "  Will use resource IDs: $IDs" -ForegroundColor Green
    }

    if ($Remove) {
        $updateParams += '--remove', $Remove
        $hasUpdates = $true
        Write-Host "  Will remove: $Remove" -ForegroundColor Green
    }

    if ($Set) {
        $updateParams += '--set', $Set
        $hasUpdates = $true
        Write-Host "  Will set: $Set" -ForegroundColor Green
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

    $result = & az @updateParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }

    $updatedWorkspace = $result | ConvertFrom-Json

    Write-Host "Azure Virtual Desktop Workspace updated successfully:" -ForegroundColor Green
    Write-Host "  Name: $($updatedWorkspace.name)" -ForegroundColor White
    Write-Host "  Resource Group: $($updatedWorkspace.resourceGroup)" -ForegroundColor White
    Write-Host "  Description: $($updatedWorkspace.description)" -ForegroundColor White
    Write-Host "  Friendly Name: $($updatedWorkspace.friendlyName)" -ForegroundColor White
    Write-Host "  Application Group References: $($updatedWorkspace.applicationGroupReferences -join ', ')" -ForegroundColor White
    Write-Host "  Location: $($updatedWorkspace.location)" -ForegroundColor White
    Write-Host "  ID: $($updatedWorkspace.id)" -ForegroundColor White

    return $updatedWorkspace
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
