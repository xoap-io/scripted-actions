<#
.SYNOPSIS
    Creates an AWS EC2 Key Pair using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script robustly creates an EC2 Key Pair, saves the private key to a .pem file with
    secure permissions, and verifies creation.
    Uses aws ec2 create-key-pair to create the key pair.
    Compatible with AWS CLI v2.16+ (2025).

.PARAMETER KeyPairName
    The name of the AWS Key Pair.

.EXAMPLE
    .\aws-cli-create-ec2-key-pair.ps1 -KeyPairName myKeyPair

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/create-key-pair.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the AWS Key Pair.")]
    [ValidatePattern('^[A-Za-z0-9._-]{1,255}$')]
    [string]$KeyPairName
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

$pemFile = "$KeyPairName.pem"

try {
    # Check if key pair already exists
    aws ec2 describe-key-pairs --key-name $KeyPairName --output json 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Key pair '$KeyPairName' already exists. Skipping creation." -ForegroundColor Yellow
        exit 0
    }

    # Create key pair and save private key
    $keyMaterial = aws ec2 create-key-pair --key-name $KeyPairName --query 'KeyMaterial' --output text 2>&1
    if ($LASTEXITCODE -eq 0) {
        $keyMaterial | Out-File -FilePath $pemFile -Encoding ascii -Force
        if ($IsLinux -or $IsMacOS) {
            chmod 600 $pemFile
        }
        Write-Host "✅ Key pair created and saved to $pemFile" -ForegroundColor Green
    } else {
        throw "Failed to create key pair: $keyMaterial"
    }

    # Verify key pair exists
    $verify = aws ec2 describe-key-pairs --key-name $KeyPairName --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Key pair verified: $KeyPairName" -ForegroundColor Green
    } else {
        throw "Key pair creation verification failed: $verify"
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
