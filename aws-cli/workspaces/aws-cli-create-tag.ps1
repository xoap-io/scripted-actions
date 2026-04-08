<#
.SYNOPSIS
    Tag an AWS Workspace.

.DESCRIPTION
    This script tags an AWS Workspace using the AWS CLI.
    Uses the following AWS CLI command:
    aws workspaces create-tags

.PARAMETER AwsWorkspaceId
    Defines the ID of the AWS Workspace.

.PARAMETER AwsTagSpecifications
    Defines the tags for the AWS Workspace.

.EXAMPLE
    .\aws-cli-create-tag.ps1 -AwsWorkspaceId "ws-12345678" -AwsTagSpecifications "Key=Environment,Value=Production"

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
    https://docs.aws.amazon.com/cli/latest/reference/workspaces/create-tags.html

.COMPONENT
    AWS CLI WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the AWS Workspace")]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceId,

    [Parameter(Mandatory = $true, HelpMessage = "The tags for the AWS Workspace")]
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
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
