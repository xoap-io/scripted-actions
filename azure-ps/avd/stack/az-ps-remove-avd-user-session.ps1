<#
.SYNOPSIS
    Removes a user session from an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes a specified user session from an Azure Virtual Desktop environment.
    Uses the Remove-AzWvdUserSession cmdlet from the Az.DesktopVirtualization module.

.PARAMETER HostPoolName
    The name of the host pool.

.PARAMETER Id
    The ID of the user session.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER SessionHostName
    The name of the session host.

.EXAMPLE
    PS C:\> .\Remove-AzWvdUserSession.ps1 -HostPoolName "MyHostPool" -Id "12345" -ResourceGroup "MyResourceGroup" -SessionHostName "MySessionHost"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdusersession?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory=$true, HelpMessage = "The ID of the user session to remove.")]
    [ValidateNotNullOrEmpty()]
    [string]$Id,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the session host.")]
    [ValidateNotNullOrEmpty()]
    [string]$SessionHostName
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    HostPoolName      = $HostPoolName
    Id                = $Id
    ResourceGroupName = $ResourceGroup
    SessionHostName   = $SessionHostName
}

try {
    # Remove the user session and capture the result
    $result = Remove-AzWvdUserSession @parameters

    # Output the result
    Write-Host "✅ User session removed successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
