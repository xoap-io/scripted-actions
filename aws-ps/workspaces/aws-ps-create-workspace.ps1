<#
.SYNOPSIS
    This script creates an AWS WorkSpace.

.DESCRIPTION
    This script creates an AWS WorkSpace.
    The script uses the AWS PowerShell module to create the specified AWS WorkSpace.
    The script uses the following AWS PowerShell command:
    New-WKSWorkspace -Workspace @{"BundleID" = $AwsWorkspaceBundleIdBundleId; "DirectoryId" = $AwsWorkspaceDirectoryId; "UserName" = $AwsWorkspaceUserName}
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

.PARAMETER AwsWorkspaceBundleIdBundleId
    The identifier of the bundle to create the WorkSpace from.

.PARAMETER AwsWorkspaceDirectoryId
    The identifier of the directory for the WorkSpace.

.PARAMETER AwsWorkspaceUserName
    The user name of the user for the WorkSpace.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AwsWorkspaceBundleIdBundleId,
    [Parameter(Mandatory)]
    [string]$AwsWorkspaceDirectoryId,
    [Parameter(Mandatory)]
    [string]$AwsWorkspaceUserName
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

New-WKSWorkspace -Workspace @{"BundleID" = $AwsWorkspaceBundleIdBundleId; "DirectoryId" = $AwsWorkspaceDirectoryId; "UserName" = $AwsWorkspaceUserName}
