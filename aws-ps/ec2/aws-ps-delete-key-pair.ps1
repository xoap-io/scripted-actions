<#
.SYNOPSIS
    Delete an existing EC2 key pair.
.DESCRIPTION
    This script deletes an EC2 key pair using AWS.Tools.EC2.
.PARAMETER KeyPairName
    The name of the key pair to delete.
.EXAMPLE
    .\aws-ps-delete-key-pair.ps1 -KeyPairName myKey
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$KeyPairName
)

$ErrorActionPreference = 'Stop'
try {
    Remove-EC2KeyPair -KeyName $KeyPairName
    Write-Host "Key pair '$KeyPairName' deleted successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to delete key pair: $_"
    exit 1
}
