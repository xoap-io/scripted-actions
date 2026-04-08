<#
.SYNOPSIS
    Deletes an AWS EC2 Network ACL using the AWS CLI.

.DESCRIPTION
    This script deletes a network ACL by its ID using the AWS CLI.
    Uses the following AWS CLI command:
    aws ec2 delete-network-acl

.PARAMETER NetworkAclId
    The ID of the network ACL to delete.

.EXAMPLE
    .\aws-cli-delete-network-acl.ps1 -NetworkAclId "acl-12345678"

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/delete-network-acl.html

.COMPONENT
    AWS CLI Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the network ACL to delete")]
    [ValidatePattern('^acl-[a-zA-Z0-9]{8,}$')]
    [string]$NetworkAclId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws ec2 delete-network-acl --network-acl-id $NetworkAclId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Network ACL deleted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to delete Network ACL: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
