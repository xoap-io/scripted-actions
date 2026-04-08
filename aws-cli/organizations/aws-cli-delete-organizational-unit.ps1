<#
.SYNOPSIS
    Deletes an AWS Organizational Unit using the AWS CLI.

.DESCRIPTION
    This script deletes an organizational unit by its ID using the AWS CLI.
    Uses the following AWS CLI command:
    aws organizations delete-organizational-unit

.PARAMETER OrganizationalUnitId
    The ID of the organizational unit to delete.

.EXAMPLE
    .\aws-cli-delete-organizational-unit.ps1 -OrganizationalUnitId "ou-1234abcd"

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
    https://docs.aws.amazon.com/cli/latest/reference/organizations/delete-organizational-unit.html

.COMPONENT
    AWS CLI Organizations
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the organizational unit to delete")]
    [ValidatePattern('^ou-[a-zA-Z0-9]{4,}$')]
    [string]$OrganizationalUnitId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws organizations delete-organizational-unit --organizational-unit-id $OrganizationalUnitId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Organizational unit deleted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to delete organizational unit: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
