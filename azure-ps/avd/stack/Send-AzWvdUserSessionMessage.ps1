<#
.SYNOPSIS
    Sends a message to an Azure Virtual Desktop user session.

.DESCRIPTION
    This script sends a message to a specified user session in an Azure Virtual Desktop environment.
    Uses the Send-AzWvdUserSessionMessage cmdlet from the Az.DesktopVirtualization module.

.PARAMETER HostPoolName
    The name of the host pool.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER SessionHostName
    The name of the session host.

.PARAMETER UserSessionId
    The ID of the user session.

.PARAMETER MessageBody
    The body of the message.

.PARAMETER MessageTitle
    The title of the message.

.EXAMPLE
    PS C:\> .\Send-AzWvdUserSessionMessage.ps1 -HostPoolName "MyHostPool" -ResourceGroup "MyResourceGroup" -SessionHostName "MySessionHost" -UserSessionId "12345" -MessageBody "Hello, User!" -MessageTitle "Greeting"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/send-azwvdusersessionmessage?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the session host.")]
    [ValidateNotNullOrEmpty()]
    [string]$SessionHostName,

    [Parameter(Mandatory=$true, HelpMessage = "The ID of the user session to send the message to.")]
    [ValidateNotNullOrEmpty()]
    [string]$UserSessionId,

    [Parameter(Mandatory=$true, HelpMessage = "The body text of the message to send.")]
    [ValidateNotNullOrEmpty()]
    [string]$MessageBody,

    [Parameter(Mandatory=$true, HelpMessage = "The title of the message to send.")]
    [ValidateNotNullOrEmpty()]
    [string]$MessageTitle
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    HostPoolName      = $HostPoolName
    ResourceGroupName = $ResourceGroup
    SessionHostName   = $SessionHostName
    UserSessionId     = $UserSessionId
    MessageBody       = $MessageBody
    MessageTitle      = $MessageTitle
}

try {
    # Send the message to the Azure Virtual Desktop user session and capture the result
    $result = Send-AzWvdUserSessionMessage @parameters

    # Output the result
    Write-Host "✅ Message sent to Azure Virtual Desktop user session successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
