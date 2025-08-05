<#
.SYNOPSIS
    Create a new EC2 key pair and save the private key locally.
.DESCRIPTION
    This script creates a new EC2 key pair using AWS.Tools.EC2 and saves the private key to a file.
.PARAMETER KeyPairName
    The name of the key pair to create.
.PARAMETER OutputPath
    The path to save the private key file.
.EXAMPLE
    .\aws-ps-create-key-pair.ps1 -KeyPairName myKey -OutputPath ./myKey.pem
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$KeyPairName,
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
try {
    $key = New-EC2KeyPair -KeyName $KeyPairName
    Set-Content -Path $OutputPath -Value $key.KeyMaterial
    Write-Host "Key pair '$KeyPairName' created and saved to '$OutputPath'." -ForegroundColor Green
} catch {
    Write-Error "Failed to create key pair: $_"
    exit 1
}
