<#
.SYNOPSIS
    Updates an Azure Virtual Desktop Workspace.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop Workspace.

.PARAMETER Name
    The name of the workspace.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER ApplicationGroupReference
    References to application groups.

.PARAMETER Description
    The description of the workspace.

.PARAMETER FriendlyName
    The friendly name of the workspace.

.PARAMETER PublicNetworkAccess
    Specifies whether the workspace is accessible over a public network.

.PARAMETER Tags
    A hashtable of tags to assign to the workspace.

.EXAMPLE
    PS C:\> .\Update-AzWvdWorkspace.ps1 -Name "MyWorkspace" -ResourceGroup "MyResourceGroup" -Description "Updated Description"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvdworkspace?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationGroupReference,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Enabled",
        "Disabled"
    )]
    [string]$PublicNetworkAccess,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags
)

# Splatting parameters for better readability
$parameters = @{
    Name                    = $Name
    ResourceGroup       = $ResourceGroup
}

if ($ApplicationGroupReference) {
    $parameters['ApplicationGroupReference'], $ApplicationGroupReference
}

if ($Description) {
    $parameters['Description'], $Description
}

if ($FriendlyName) {
    $parameters['FriendlyName'], $FriendlyName
}

if ($PublicNetworkAccess) {
    $parameters['PublicNetworkAccess'], $PublicNetworkAccess
}

if ($Tags) {
    $parameters['Tag'], $Tags
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Update the Azure Virtual Desktop Workspace and capture the result
    $result = Update-AzWvdWorkspace @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Workspace updated successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to update the Azure Virtual Desktop Workspace: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
