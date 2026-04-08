<#
.SYNOPSIS
    Creates an AWS Organizational Unit using the AWS CLI.

.DESCRIPTION
    This script creates an organizational unit under a specified parent (root or OU) using the AWS CLI.
    Uses the following AWS CLI command:
    aws organizations create-organizational-unit

.PARAMETER ParentId
    The ID of the parent (root or OU).

.PARAMETER Name
    The name of the organizational unit.

.EXAMPLE
    .\aws-cli-create-organizational-unit.ps1 -ParentId "r-1234" -Name "Finance"

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
    https://docs.aws.amazon.com/cli/latest/reference/organizations/create-organizational-unit.html

.COMPONENT
    AWS CLI Organizations
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the parent (root or OU)")]
    [ValidatePattern('^(r|ou)-[a-zA-Z0-9]{4,}$')]
    [string]$ParentId,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the organizational unit")]
    [string]$Name
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws organizations create-organizational-unit --parent-id $ParentId --name $Name --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Organizational unit created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to create organizational unit: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
