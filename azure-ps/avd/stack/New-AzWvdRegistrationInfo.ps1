<#
.SYNOPSIS
    Creates a new registration info in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new registration info in an Azure Virtual Desktop environment with the specified parameters.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER HostPoolName
    The name of the host pool.

.PARAMETER ExpirationTime
    The expiration time for the registration info.

.EXAMPLE
    PS C:\> .\New-AzWvdRegistrationInfo.ps1 -ResourceGroup "MyResourceGroup" -HostPoolName "MyHostPool" -ExpirationTime "2023-12-31T23:59:59Z"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdregistrationinfo?view=azps-12.3.0

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
    [string]$HostPoolName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ExpirationTime
)

# Splatting parameters for better readability
$parameters = @{
    ResourceGroup = $ResourceGroup
    HostPoolName = $HostPoolName
    ExpirationTime = $ExpirationTime
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the registration info and capture the result
    $result = New-AzWvdRegistrationInfo @parameters

    # Output the result
    Write-Output "Registration info created successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to create the registration info: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
