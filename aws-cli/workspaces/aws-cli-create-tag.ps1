<#
.SYNOPSIS
    Tag an AWS Workspace.

.DESCRIPTION
    This script tags an AWS Workspace.
    The script uses the AWS CLI to tag the specified AWS Workspace. The script uses the following AWS CLI command:
    aws workspaces create-tags --resource-id $AwsWorkspaceId --tags $AwsTagSpecifications
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

.PARAMETER AwsWorkspaceId
    Defines the ID of the AWS Workspace.

.PARAMETER AwsTagSpecifications
    Defines the tags for the AWS Workspace.

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceId,
    [Parameter(Mandatory)]
    [string]$AwsTagSpecifications
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws workspaces create-tags --resource-id $AwsWorkspaceId --tags $AwsTagSpecifications --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Tags created successfully for workspace." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to create tags: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
