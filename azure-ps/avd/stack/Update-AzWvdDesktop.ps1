<#
.SYNOPSIS
    Updates an Azure Virtual Desktop.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop.

.PARAMETER ApplicationGroupName
    The name of the application group.

.PARAMETER Name
    The name of the desktop.

.PARAMETER ResourceGroupName
    The name of the resource group.

.PARAMETER Description
    The description of the desktop.

.PARAMETER FriendlyName
    The friendly name of the desktop.

.PARAMETER Tags
    A hashtable of tags to assign to the desktop.

.EXAMPLE
    PS C:\> .\Update-AzWvdDesktop.ps1 -ApplicationGroupName "MyAppGroup" -Name "MyDesktop" -ResourceGroupName "MyResourceGroup" -Description "Updated Description"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvddesktop?view=azps-12.2.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationGroupName,

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
    [hashtable]$Tags
)

# Splatting parameters for better readability
$parameters = @{
    ApplicationGroupName = $ApplicationGroupName
    Name                 = $Name
    ResourceGroupName    = $ResourceGroupName
}

if ($Description) {
    $parameters.Description = $Description
}

if ($FriendlyName) {
    $parameters.FriendlyName = $FriendlyName
}

if ($Tags) {
    $parameters['Tag', $Tags
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Update the Azure Virtual Desktop and capture the result
    $result = Update-AzWvdDesktop @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop updated successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to update the Azure Virtual Desktop: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
