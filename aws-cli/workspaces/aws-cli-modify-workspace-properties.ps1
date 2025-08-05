<#
.SYNOPSIS
    Modify properties of an AWS WorkSpace.
.DESCRIPTION
    This script changes properties such as compute type, volume size, or running mode for an existing AWS WorkSpace using the AWS CLI.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.PARAMETER AwsWorkspaceId
    The ID of the WorkSpace to modify.
.PARAMETER AwsRunningMode
    (Optional) The running mode for the WorkSpace (AUTO_STOP or ALWAYS_ON).
.PARAMETER AwsRootVolumeSizeGib
    (Optional) The size of the root volume in GiB.
.PARAMETER AwsUserVolumeSizeGib
    (Optional) The size of the user volume in GiB.
.EXAMPLE
    .\aws-cli-modify-workspace-properties.ps1 -AwsWorkspaceId ws-12345678 -AwsRunningMode ALWAYS_ON -AwsRootVolumeSizeGib 80
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceId,
    [Parameter()]
    [ValidateSet('AUTO_STOP','ALWAYS_ON')]
    [string]$AwsRunningMode,
    [Parameter()]
    [ValidateRange(10, 2000)]
    [int]$AwsRootVolumeSizeGib,
    [Parameter()]
    [ValidateRange(10, 2000)]
    [int]$AwsUserVolumeSizeGib
)

$ErrorActionPreference = 'Stop'
try {
    $props = @{}
    if ($AwsRunningMode) { $props["RunningMode"] = $AwsRunningMode }
    if ($AwsRootVolumeSizeGib) { $props["RootVolumeSizeGib"] = $AwsRootVolumeSizeGib }
    if ($AwsUserVolumeSizeGib) { $props["UserVolumeSizeGib"] = $AwsUserVolumeSizeGib }
    $propsJson = $props | ConvertTo-Json -Compress
    aws workspaces modify-workspace-properties `
        --workspace-id $AwsWorkspaceId `
        --workspace-properties $propsJson
    Write-Host "Successfully modified properties for Workspace $AwsWorkspaceId."
} catch {
    Write-Error "Failed to modify Workspace properties: $_"
    exit 1
}
