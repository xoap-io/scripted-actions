<#
.SYNOPSIS
    Creates a new registration info in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new registration info in an Azure Virtual Desktop environment with the specified parameters.
    Uses the New-AzWvdRegistrationInfo cmdlet from the Az.DesktopVirtualization module.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER HostPoolName
    The name of the host pool.

.PARAMETER ExpirationTime
    The expiration time for the registration info.

.EXAMPLE
    PS C:\> .\New-AzWvdRegistrationInfo.ps1 -ResourceGroup "MyResourceGroup" -HostPoolName "MyHostPool" -ExpirationTime "2023-12-31T23:59:59Z"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdregistrationinfo?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory=$true, HelpMessage = "The expiration time for the registration info (ISO 8601 format).")]
    [ValidateNotNullOrEmpty()]
    [string]$ExpirationTime
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    ResourceGroupName = $ResourceGroup
    HostPoolName      = $HostPoolName
    ExpirationTime    = $ExpirationTime
}

try {
    # Create the registration info and capture the result
    $result = New-AzWvdRegistrationInfo @parameters

    # Output the result
    Write-Host "✅ Registration info created successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
