<#
.SYNOPSIS
    Removes a private endpoint connection from an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes a specified private endpoint connection from an Azure Virtual Desktop environment.

.PARAMETER Name
    The name of the private endpoint connection.

.PARAMETER ResourceGroupName
    The name of the resource group.

.PARAMETER WorkspaceName
    The name of the workspace.

.EXAMPLE
    PS C:\> .\Remove-AzWvdPrivateEndpointConnection.ps1 -Name "MyPrivateEndpoint" -ResourceGroupName "MyResourceGroup" -WorkspaceName "MyWorkspace"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdprivateendpointconnection?view=azps-12.3.0

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

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName
)

# Splatting parameters for better readability
$parameters = @{
    Name              = $Name
    ResourceGroupName = $ResourceGroupName
    WorkspaceName     = $WorkspaceName
    HostPoolName      = $HostPoolName
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Remove the private endpoint connection and capture the result
    $result = Remove-AzWvdPrivateEndpointConnection @parameters

    # Output the result
    Write-Output "Private endpoint connection removed successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to remove the private endpoint connection: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
