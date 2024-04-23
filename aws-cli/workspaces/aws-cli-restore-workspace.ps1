<#
.SYNOPSIS
    This script restores an Amazon WorkSpace that has been terminated.

.DESCRIPTION
    This script restores an Amazon WorkSpace that has been terminated. The WorkSpace is restored to the state it was in when the last snapshot was taken.

    The script requires the AWS CLI to be installed and configured. The script uses the AWS CLI command restore-workspace to restore the WorkSpace.

    The script requires the WorkSpace ID as a parameter. The WorkSpace ID can be found in the AWS Management Console or by using the AWS CLI command describe-workspaces.

    The script sets the ErrorActionPreference to SilentlyContinue to suppress error messages. If an error occurs, the script will not display an error message, but the error will be written to the error stream.

    The script does not return any output. If the WorkSpace is successfully restored, the script will not display any output. If an error occurs, the error will be written to the error stream.

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

.PARAMETER AwsWorkspaceId
    The ID of the WorkSpace to restore.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AwsWorkspaceId = "myWorkspaceId"
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

aws workspaces restore-workspace `
    --workspace-id $AwsWorkspaceId
