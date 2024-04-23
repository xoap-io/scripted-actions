<#
.SYNOPSIS
    Deregister an AWS Directory from Workspaces.

.DESCRIPTION
    This script deregisters an AWS Directory from Workspaces.
    The script uses the AWS CLI to deregister the specified AWS Directory from Workspaces.
    The script uses the following AWS CLI command:
    aws workspaces deregister-workspace-directory --directory-id $AwsDirectoryId
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
    AWS CLI

.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AwsDirectoryId
    Defines the ID of the AWS Directory.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AwsDirectoryId = "myDirectoryId"
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

aws workspaces deregister-workspace-directory `
    --directory-id $AwsDirectoryId
