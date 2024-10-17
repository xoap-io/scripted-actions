<#
.SYNOPSIS
    Removes an Azure Virtual Desktop Workspace.

.DESCRIPTION
    This script removes an Azure Virtual Desktop Workspace.

.PARAMETER Name
    The name of the workspace.

.PARAMETER ResourceGroupName
    The name of the resource group.

.EXAMPLE
    PS C:\> .\Remove-AzWvdWorkspace.ps1 -Name "MyWorkspace" -ResourceGroupName "MyResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdworkspace?view=azps-12.3.0

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
    [string]$ResourceGroupName
)

# Splatting parameters for better readability
$parameters = @{
    Name              = $Name
    ResourceGroupName = $ResourceGroupName
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Remove the Azure Virtual Desktop Workspace and capture the result
    $result = Remove-AzWvdWorkspace @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Workspace removed successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to remove the Azure Virtual Desktop Workspace: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
