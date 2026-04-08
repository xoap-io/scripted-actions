<#
.SYNOPSIS
    Moves an AWS account between organizational units using the AWS CLI.

.DESCRIPTION
    This script moves an account from one parent (root or OU) to another using the AWS CLI.
    Uses the following AWS CLI command:
    aws organizations move-account

.PARAMETER AccountId
    The ID of the AWS account to move.

.PARAMETER SourceParentId
    The ID of the source parent (root or OU).

.PARAMETER DestinationParentId
    The ID of the destination parent (root or OU).

.EXAMPLE
    .\aws-cli-move-account.ps1 -AccountId "123456789012" -SourceParentId "r-1234" -DestinationParentId "ou-5678abcd"

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
    https://docs.aws.amazon.com/cli/latest/reference/organizations/move-account.html

.COMPONENT
    AWS CLI Organizations
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the AWS account to move")]
    [ValidatePattern('^\d{12}$')]
    [string]$AccountId,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the source parent (root or OU)")]
    [ValidatePattern('^(r|ou)-[a-zA-Z0-9]{4,}$')]
    [string]$SourceParentId,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the destination parent (root or OU)")]
    [ValidatePattern('^(r|ou)-[a-zA-Z0-9]{4,}$')]
    [string]$DestinationParentId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws organizations move-account --account-id $AccountId --source-parent-id $SourceParentId --destination-parent-id $DestinationParentId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Account moved successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to move account: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
