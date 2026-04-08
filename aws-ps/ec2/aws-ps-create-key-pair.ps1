<#
.SYNOPSIS
    Create a new EC2 key pair and save the private key locally.

.DESCRIPTION
    This script creates a new EC2 key pair using the New-EC2KeyPair cmdlet from AWS.Tools.EC2 and saves the private key to a local file.

.PARAMETER KeyPairName
    The name of the key pair to create.

.PARAMETER OutputPath
    The local file path to save the private key file.

.EXAMPLE
    .\aws-ps-create-key-pair.ps1 -KeyPairName myKey -OutputPath ./myKey.pem

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.EC2

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/

.COMPONENT
    AWS PowerShell EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name for the new key pair (alphanumeric, dots, dashes, up to 64 characters).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$KeyPairName,

    [Parameter(Mandatory = $true, HelpMessage = "The local file path to save the private key (e.g. ./myKey.pem).")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

try {
    $key = New-EC2KeyPair -KeyName $KeyPairName
    Set-Content -Path $OutputPath -Value $key.KeyMaterial
    Write-Host "Key pair '$KeyPairName' created and saved to '$OutputPath'." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
