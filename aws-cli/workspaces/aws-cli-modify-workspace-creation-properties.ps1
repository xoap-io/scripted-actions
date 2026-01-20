<#
.SYNOPSIS
    Modify default creation properties for an AWS WorkSpaces directory.
.DESCRIPTION
    This script updates default creation properties for a directory, such as enabling/disabling WorkDocs and specifying running mode, using the AWS CLI.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.PARAMETER AwsDirectoryId
    The ID of the AWS Directory to modify.
.PARAMETER EnableWorkDocs
    (Optional) Enable or disable WorkDocs (true/false).
.PARAMETER AwsRunningMode
    (Optional) The default running mode (AUTO_STOP or ALWAYS_ON).
.EXAMPLE
    .\aws-cli-modify-workspace-creation-properties.ps1 -AwsDirectoryId d-12345678 -EnableWorkDocs $true -AwsRunningMode AUTO_STOP
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^d-[a-zA-Z0-9]{8,}$')]
    [string]$AwsDirectoryId,
    [Parameter()]
    [bool]$EnableWorkDocs,
    [Parameter()]
    [ValidateSet('AUTO_STOP','ALWAYS_ON')]
    [string]$AwsRunningMode
)

$ErrorActionPreference = 'Stop'
try {
    $props = @{}
    if ($EnableWorkDocs -ne $null) { $props["EnableWorkDocs"] = $EnableWorkDocs }
    if ($AwsRunningMode) { $props["DefaultRunningMode"] = $AwsRunningMode }
    $propsJson = $props | ConvertTo-Json -Compress
    aws workspaces modify-workspace-creation-properties `
        --resource-id $AwsDirectoryId `
        --workspace-creation-properties $propsJson
    Write-Host "Successfully modified creation properties for directory $AwsDirectoryId."
} catch {
    Write-Error "Failed to modify creation properties: $_"
    exit 1
}
