<#
.SYNOPSIS
    Attaches a policy to a target in AWS Organizations.

.DESCRIPTION
    This script attaches a policy to a target (account, OU, or root) using the AWS CLI.
    Uses the following AWS CLI command:
    aws organizations attach-policy

.PARAMETER PolicyId
    The ID of the policy to attach.

.PARAMETER TargetId
    The ID of the target (account, OU, or root).

.EXAMPLE
    .\aws-cli-attach-policy.ps1 -PolicyId "p-12345678" -TargetId "r-1234"

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
    https://docs.aws.amazon.com/cli/latest/reference/organizations/attach-policy.html

.COMPONENT
    AWS CLI Organizations
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the policy to attach")]
    [ValidatePattern('^p-[a-zA-Z0-9]{8,}$')]
    [string]$PolicyId,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the target (account, OU, or root)")]
    [ValidatePattern('^(r|ou|\d{12})-[a-zA-Z0-9]{4,}$|^\d{12}$')]
    [string]$TargetId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws organizations attach-policy --policy-id $PolicyId --target-id $TargetId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Policy attached successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to attach policy: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
