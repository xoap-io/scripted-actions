<#
.SYNOPSIS
    Modify properties of an AWS WorkSpace.

.DESCRIPTION
    This script changes properties such as compute type, volume size, or running mode for an existing
    AWS WorkSpace using the AWS CLI.
    Uses the following AWS CLI command:
    aws workspaces modify-workspace-properties

.PARAMETER AwsWorkspaceId
    The ID of the WorkSpace to modify.

.PARAMETER AwsRunningMode
    The running mode for the WorkSpace (AUTO_STOP or ALWAYS_ON) (optional).

.PARAMETER AwsRootVolumeSizeGib
    The size of the root volume in GiB (optional).

.PARAMETER AwsUserVolumeSizeGib
    The size of the user volume in GiB (optional).

.EXAMPLE
    .\aws-cli-modify-workspace-properties.ps1 -AwsWorkspaceId "ws-12345678" -AwsRunningMode "ALWAYS_ON" -AwsRootVolumeSizeGib 80

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/workspaces/modify-workspace-properties.html

.COMPONENT
    AWS CLI WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpace to modify")]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceId,

    [Parameter(Mandatory = $false, HelpMessage = "The running mode for the WorkSpace (AUTO_STOP or ALWAYS_ON)")]
    [ValidateSet('AUTO_STOP', 'ALWAYS_ON')]
    [string]$AwsRunningMode,

    [Parameter(Mandatory = $false, HelpMessage = "The size of the root volume in GiB")]
    [ValidateRange(10, 2000)]
    [int]$AwsRootVolumeSizeGib,

    [Parameter(Mandatory = $false, HelpMessage = "The size of the user volume in GiB")]
    [ValidateRange(10, 2000)]
    [int]$AwsUserVolumeSizeGib
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $props = @{}
    if ($AwsRunningMode) { $props["RunningMode"] = $AwsRunningMode }
    if ($AwsRootVolumeSizeGib) { $props["RootVolumeSizeGib"] = $AwsRootVolumeSizeGib }
    if ($AwsUserVolumeSizeGib) { $props["UserVolumeSizeGib"] = $AwsUserVolumeSizeGib }
    $propsJson = $props | ConvertTo-Json -Compress
    aws workspaces modify-workspace-properties `
        --workspace-id $AwsWorkspaceId `
        --workspace-properties $propsJson
    Write-Host "Successfully modified properties for Workspace $AwsWorkspaceId." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
