<#
.SYNOPSIS
    Deletes an entry from an AWS EC2 Network ACL using the AWS CLI.

.DESCRIPTION
    This script deletes an entry from a network ACL using the AWS CLI.
    Uses the following AWS CLI command:
    aws ec2 delete-network-acl-entry

.PARAMETER NetworkAclId
    The ID of the network ACL.

.PARAMETER RuleNumber
    The rule number for the entry.

.PARAMETER Egress
    Whether the rule is egress (true/false).

.EXAMPLE
    .\aws-cli-delete-network-acl-entry.ps1 -NetworkAclId "acl-12345678" -RuleNumber 100 -Egress $true

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/delete-network-acl-entry.html

.COMPONENT
    AWS CLI Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the network ACL")]
    [ValidatePattern('^acl-[a-zA-Z0-9]{8,}$')]
    [string]$NetworkAclId,

    [Parameter(Mandatory = $true, HelpMessage = "The rule number for the entry")]
    [ValidatePattern('^\d{1,4}$')]
    [int]$RuleNumber,

    [Parameter(Mandatory = $true, HelpMessage = "Whether the rule is egress (true/false)")]
    [bool]$Egress
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws ec2 delete-network-acl-entry --network-acl-id $NetworkAclId --rule-number $RuleNumber --egress $Egress --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Network ACL entry deleted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to delete Network ACL entry: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
