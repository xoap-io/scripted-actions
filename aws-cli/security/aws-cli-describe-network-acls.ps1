<#
.SYNOPSIS
    Describes AWS EC2 Network ACLs.
.DESCRIPTION
    This script lists or describes network ACLs using the latest AWS CLI (v2.16+).
.PARAMETER NetworkAclId
    The ID of the network ACL to describe (optional).
.EXAMPLE
    .\aws-cli-describe-network-acls.ps1 -NetworkAclId acl-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^acl-[a-zA-Z0-9]{8,}$')]
    [string]$NetworkAclId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    if ($NetworkAclId) {
        $result = aws ec2 describe-network-acls --network-acl-ids $NetworkAclId --output json 2>&1
    } else {
        $result = aws ec2 describe-network-acls --output json 2>&1
    }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Network ACL(s) described successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to describe network ACL(s): $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
