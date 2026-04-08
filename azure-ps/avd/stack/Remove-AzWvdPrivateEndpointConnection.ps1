<#
.SYNOPSIS
    Removes a private endpoint connection from an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes a specified private endpoint connection from an Azure Virtual Desktop environment.
    Uses the Remove-AzWvdPrivateEndpointConnection cmdlet from the Az.DesktopVirtualization module.

.PARAMETER Name
    The name of the private endpoint connection.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER WorkspaceName
    The name of the workspace.

.PARAMETER HostPoolName
    The name of the host pool.

.EXAMPLE
    PS C:\> .\Remove-AzWvdPrivateEndpointConnection.ps1 -Name "MyPrivateEndpoint" -ResourceGroup "MyResourceGroup" -WorkspaceName "MyWorkspace"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdprivateendpointconnection?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the private endpoint connection to remove.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    Name              = $Name
    ResourceGroupName = $ResourceGroup
    WorkspaceName     = $WorkspaceName
    HostPoolName      = $HostPoolName
}

try {
    # Remove the private endpoint connection and capture the result
    $result = Remove-AzWvdPrivateEndpointConnection @parameters

    # Output the result
    Write-Host "✅ Private endpoint connection removed successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
