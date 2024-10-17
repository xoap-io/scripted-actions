<#
.SYNOPSIS
    Unregisters an Azure Virtual Desktop Application Group.

.DESCRIPTION
    This script unregisters an Azure Virtual Desktop Application Group.

.PARAMETER ResourceGroupName
    The name of the resource group.

.PARAMETER WorkspaceName
    The name of the workspace.

.PARAMETER ApplicationGroupPath
    The path of the application group.

.EXAMPLE
    PS C:\> .\Unregister-AzWvdApplicationGroup.ps1 -ResourceGroupName "MyResourceGroup" -WorkspaceName "MyWorkspace" -ApplicationGroupPath "MyAppGroupPath"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/unregister-azwvdapplicationgroup?view=azps-12.2.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationGroupPath
)

# Splatting parameters for better readability
$parameters = @{
    ResourceGroupName    = $ResourceGroupName
    WorkspaceName        = $WorkspaceName
    ApplicationGroupPath = $ApplicationGroupPath
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Unregister the Azure Virtual Desktop Application Group and capture the result
    $result = Unregister-AzWvdApplicationGroup @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Application Group unregistered successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to unregister the Azure Virtual Desktop Application Group: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
