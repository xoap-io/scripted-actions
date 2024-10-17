<#
.SYNOPSIS
    Sends a message to an Azure Virtual Desktop user session.

.DESCRIPTION
    This script sends a message to a specified user session in an Azure Virtual Desktop environment.

.PARAMETER HostPoolName
    The name of the host pool.

.PARAMETER ResourceGroupName
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
    PS C:\> .\Send-AzWvdUserSessionMessage.ps1 -HostPoolName "MyHostPool" -ResourceGroupName "MyResourceGroup" -SessionHostName "MySessionHost" -UserSessionId "12345" -MessageBody "Hello, User!" -MessageTitle "Greeting"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/send-azwvdusersessionmessage?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SessionHostName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserSessionId,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$MessageBody,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$MessageTitle
)

# Splatting parameters for better readability
$parameters = @{
    HostPoolName      = $HostPoolName
    ResourceGroupName = $ResourceGroupName
    SessionHostName   = $SessionHostName
    UserSessionId     = $UserSessionId
    MessageBody       = $MessageBody
    MessageTitle      = $MessageTitle
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Send the message to the Azure Virtual Desktop user session and capture the result
    $result = Send-AzWvdUserSessionMessage @parameters

    # Output the result
    Write-Output "Message sent to Azure Virtual Desktop user session successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to send the message to the Azure Virtual Desktop user session: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
