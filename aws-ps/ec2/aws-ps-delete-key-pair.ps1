<#
.SYNOPSIS
    Delete an existing EC2 key pair.

.DESCRIPTION
    This script deletes an EC2 key pair using the Remove-EC2KeyPair cmdlet from AWS.Tools.EC2.

.PARAMETER KeyPairName
    The name of the key pair to delete.

.EXAMPLE
    .\aws-ps-delete-key-pair.ps1 -KeyPairName myKey

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
    [Parameter(Mandatory = $true, HelpMessage = "The name of the key pair to delete (alphanumeric, dots, dashes, up to 64 characters).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$KeyPairName
)

$ErrorActionPreference = 'Stop'

try {
    Remove-EC2KeyPair -KeyName $KeyPairName
    Write-Host "Key pair '$KeyPairName' deleted successfully." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
