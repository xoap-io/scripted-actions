<#
.SYNOPSIS
    Registers an application group in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script registers a specified application group in an Azure Virtual Desktop environment.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER WorkspaceName
        The name of the workspace.

.PARAMETER ApplicationGroupPath
    The path of the application group.

.EXAMPLE
    PS C:\> .\Register-AzWvdApplicationGroup.ps1 -ResourceGroup "MyResourceGroup" -WorkspaceName "MyWorkspace" -ApplicationGroupPath "MyAppGroupPath"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/register-azwvdapplicationgroup?view=azps-12.2.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationGroupPath
)

# Splatting parameters for better readability
$parameters = @{
    ResourceGroup = $ResourceGroup
    WorkspaceName = $WorkspaceName
    ApplicationGroupPath = $ApplicationGroupPath
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Register the application group and capture the result
    $result = Register-AzWvdApplicationGroup @parameters

    # Output the result
    Write-Output "Application group registered successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to register the application group: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
