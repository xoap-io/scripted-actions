<#
.SYNOPSIS
    Describes an AWS account in the organization.

.DESCRIPTION
    This script describes a specific account in the AWS organization using the AWS CLI.
    Uses the following AWS CLI command:
    aws organizations describe-account

.PARAMETER AccountId
    The ID of the AWS account to describe.

.EXAMPLE
    .\aws-cli-describe-account.ps1 -AccountId "123456789012"

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
    https://docs.aws.amazon.com/cli/latest/reference/organizations/describe-account.html

.COMPONENT
    AWS CLI Organizations
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the AWS account to describe")]
    [ValidatePattern('^\d{12}$')]
    [string]$AccountId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws organizations describe-account --account-id $AccountId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Account described successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to describe account: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
