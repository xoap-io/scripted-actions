<#
.SYNOPSIS
    Modify default creation properties for an AWS WorkSpaces directory.

.DESCRIPTION
    This script updates default creation properties for a directory, such as enabling/disabling WorkDocs
    and specifying running mode, using the AWS CLI.
    Uses the following AWS CLI command:
    aws workspaces modify-workspace-creation-properties

.PARAMETER AwsDirectoryId
    The ID of the AWS Directory to modify.

.PARAMETER EnableWorkDocs
    Enable or disable WorkDocs (true/false) (optional).

.PARAMETER AwsRunningMode
    The default running mode (AUTO_STOP or ALWAYS_ON) (optional).

.EXAMPLE
    .\aws-cli-modify-workspace-creation-properties.ps1 -AwsDirectoryId "d-12345678" -EnableWorkDocs $true -AwsRunningMode "AUTO_STOP"

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
    https://docs.aws.amazon.com/cli/latest/reference/workspaces/modify-workspace-creation-properties.html

.COMPONENT
    AWS CLI WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the AWS Directory to modify")]
    [ValidatePattern('^d-[a-zA-Z0-9]{8,}$')]
    [string]$AwsDirectoryId,

    [Parameter(Mandatory = $false, HelpMessage = "Enable or disable WorkDocs (true/false)")]
    [bool]$EnableWorkDocs,

    [Parameter(Mandatory = $false, HelpMessage = "The default running mode (AUTO_STOP or ALWAYS_ON)")]
    [ValidateSet('AUTO_STOP', 'ALWAYS_ON')]
    [string]$AwsRunningMode
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $props = @{}
    if ($PSBoundParameters.ContainsKey('EnableWorkDocs')) { $props["EnableWorkDocs"] = $EnableWorkDocs }
    if ($AwsRunningMode) { $props["DefaultRunningMode"] = $AwsRunningMode }
    $propsJson = $props | ConvertTo-Json -Compress
    aws workspaces modify-workspace-creation-properties `
        --resource-id $AwsDirectoryId `
        --workspace-creation-properties $propsJson
    Write-Host "Successfully modified creation properties for directory $AwsDirectoryId." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
