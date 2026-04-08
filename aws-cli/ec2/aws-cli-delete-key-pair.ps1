<#
.SYNOPSIS
    Deletes an AWS EC2 key pair using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script deletes a key pair by name, with parameter validation and error handling.
    Uses aws ec2 delete-key-pair to perform the operation.

.PARAMETER KeyPairName
    The name of the key pair to delete.

.EXAMPLE
    .\aws-cli-delete-key-pair.ps1 -KeyPairName myKey

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/delete-key-pair.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the key pair to delete.")]
    [ValidatePattern('^[a-zA-Z0-9-_]{1,255}$')]
    [string]$KeyPairName
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    $result = aws ec2 delete-key-pair --key-name $KeyPairName --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Key pair deleted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        throw "Failed to delete key pair: $result"
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
