<#
.SYNOPSIS
    Deletes an entry from an AWS EC2 Network ACL using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script deletes an entry from a network ACL.
.PARAMETER NetworkAclId
    The ID of the network ACL.
.PARAMETER RuleNumber
    The rule number for the entry.
.PARAMETER Egress
    Whether the rule is egress (true/false).
.EXAMPLE
    .\aws-cli-delete-network-acl-entry.ps1 -NetworkAclId acl-12345678 -RuleNumber 100 -Egress true
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^acl-[a-zA-Z0-9]{8,}$')]
    [string]$NetworkAclId,
    [Parameter(Mandatory)]
    [ValidatePattern('^\d{1,4}$')]
    [int]$RuleNumber,
    [Parameter(Mandatory)]
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
    Write-Error "Unexpected error: $_"
    exit 1
}
