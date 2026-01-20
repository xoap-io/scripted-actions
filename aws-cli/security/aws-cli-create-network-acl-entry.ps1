<#
.SYNOPSIS
    Creates an entry in an AWS EC2 Network ACL using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script adds an entry to a network ACL.
.PARAMETER NetworkAclId
    The ID of the network ACL.
.PARAMETER RuleNumber
    The rule number for the entry.
.PARAMETER Protocol
    The protocol (tcp, udp, icmp, all).
.PARAMETER RuleAction
    The action (allow or deny).
.PARAMETER Egress
    Whether the rule is egress (true/false).
.PARAMETER CidrBlock
    The CIDR block.
.EXAMPLE
    .\aws-cli-create-network-acl-entry.ps1 -NetworkAclId acl-12345678 -RuleNumber 100 -Protocol tcp -RuleAction allow -Egress true -CidrBlock 0.0.0.0/0
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
    [ValidateSet('tcp','udp','icmp','all')]
    [string]$Protocol,
    [Parameter(Mandatory)]
    [ValidateSet('allow','deny')]
    [string]$RuleAction,
    [Parameter(Mandatory)]
    [bool]$Egress,
    [Parameter(Mandatory)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$CidrBlock
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws ec2 create-network-acl-entry --network-acl-id $NetworkAclId --rule-number $RuleNumber --protocol $Protocol --rule-action $RuleAction --egress $Egress --cidr-block $CidrBlock --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Network ACL entry created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to create Network ACL entry: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
