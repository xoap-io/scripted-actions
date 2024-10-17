<#
.SYNOPSIS
    Updates an Azure Virtual Desktop Application Group.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop Application Group.

.PARAMETER Name
    The name of the application group.

.PARAMETER ResourceGroupName
    The name of the resource group.

.PARAMETER Description
    The description of the application group.

.PARAMETER FriendlyName
    The friendly name of the application group.

.PARAMETER ShowInFeed
    Specifies whether to show the application group in the feed.

.PARAMETER Tags
    A hashtable of tags to assign to the application group.

.EXAMPLE
    PS C:\> .\ v.ps1 -Name "MyAppGroup" -ResourceGroupName "MyResourceGroup" -Description "Updated Description"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvdapplicationgroup?view=azps-12.3.0

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
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$ShowInFeed,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags
)

# Splatting parameters for better readability
$parameters = @{
    Name              = $Name
    ResourceGroupName = $ResourceGroupName
}

if ($Description) {
    $parameters['Description'], $Description
}

if ($FriendlyName) {
    $parameters['FriendlyName'], $FriendlyName
}

if ($ShowInFeed) {
    $parameters['ShowInFeed'], $ShowInFeed
}

if ($Tags) {
    $parameters['Tag'], $Tags
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Update the Azure Virtual Desktop Application Group and capture the result
    $result = Update-AzWvdApplicationGroup @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Application Group updated successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to update the Azure Virtual Desktop Application Group: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
