<#
.SYNOPSIS
    Deletes an AWS EC2 Network ACL using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script deletes a network ACL by its ID.
.PARAMETER NetworkAclId
    The ID of the network ACL to delete.
.EXAMPLE
    .\aws-cli-delete-network-acl.ps1 -NetworkAclId acl-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
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
    Write-Error "Unexpected error: $_"
    exit 1
}
