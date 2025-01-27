<#
.SYNOPSIS
    Update an Azure Virtual Desktop Application Group with the Azure CLI.

.DESCRIPTION
    This script updates an Azure Virtual Desktop Application Group with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization applicationgroup update --name $AzAppGroupName --resource-group $AzResourceGroup

.PARAMETER Add
    Add an object to a list of objects by specifying a path and key value pairs.

.PARAMETER ApplicationGroupType
    Defines the type of the Azure Virtual Desktop Application Group.

.PARAMETER Description
    Defines the description of the Azure Virtual Desktop Application Group.

.PARAMETER ForceString
    Replace a string value with another string value.

.PARAMETER FriendlyName
    Defines the friendly name of the Azure Virtual Desktop Application Group.

.PARAMETER HostPoolArmPath
    Defines the ARM path of the Azure Virtual Desktop Host Pool.

.PARAMETER IDs
    One or more resource IDs (space-delimited).

.PARAMETER Name
    Defines the name of the Azure Virtual Desktop Application Group.

.PARAMETER Remove
    Remove a property or an element from a list.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER Set
    Update an object by specifying a property path and value to set.

.PARAMETER Tags
    Defines the tags for the Azure Virtual Desktop Application Group.

.EXAMPLE
    .\az-cli-avd-applicationgroup-update.ps1 -AzAppGroupName "MyAppGroup" -AzResourceGroup "MyResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/applicationgroup

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/applicationgroup?view=azure-cli-latest

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Add,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Desktop',
        'RemoteApp'
    )]
    [string]$ApplicationGroupType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        '0',
        '1',
        'f',
        'false',
        'n',
        'no',
        't',
        'true',
        'y',
        'yes'
    )]
    [string]$ForceString,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolArmPath,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$IDs,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Remove,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Set,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Tags
)

# Splatting parameters for better readability
$parameters = `
    '--add', $Add
    '--application-group-type', $ApplicationGroupType
    '--description', $Description
    '--force-string', $ForceString
    '--friendly-name', $FriendlyName
    '--host-pool-arm-path', $HostPoolArmPath
    '--ids', $IDs
    '--name', $Name
    '--remove', $Remove
    '--resource-group', $ResourceGroup
    '--set', $Set

if ($Tags) {
    $parameters += '--tags', $Tags
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Update the Azure Virtual Desktop Application Group
    az desktopvirtualization applicationgroup update @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Application Group updated successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to update the Azure Virtual Desktop Application Group: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
