<#
.SYNOPSIS
    This script reboots an AWS WorkSpace.

.DESCRIPTION
    This script reboots an AWS WorkSpace.
    The script uses the AWS PowerShell module to reboot the specified AWS WorkSpace.
    The script uses the following AWS PowerShell command:
    Restart-WKSWorkspace -WorkspaceId $AwsWorkspaceId
    The script sets the ErrorActionPreference to SilentlyContinue to suppress error messages.
    It does not return any output.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT
    AWS PowerShell

.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AwsWorkspaceId
    The ID of the WorkSpace to reboot.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AwsWorkspaceId = "myWorkspaceId"
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

Restart-WKSWorkspace -WorkspaceId $AwsWorkspaceId
