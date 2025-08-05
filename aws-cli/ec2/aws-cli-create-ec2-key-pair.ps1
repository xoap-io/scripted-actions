
<#!
.SYNOPSIS
    Creates an AWS EC2 Key Pair using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script robustly creates an EC2 Key Pair, saves the private key to a .pem file with secure permissions, and verifies creation. Compatible with AWS CLI v2.16+ (2025).

.PARAMETER KeyPairName
    The name of the AWS Key Pair.

.EXAMPLE
    .\aws-cli-create-ec2-key-pair.ps1 -KeyPairName myKeyPair

.LINK
    https://github.com/xoap-io/scripted-actions
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9._-]{1,255}$')]
    [string]$KeyPairName
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

$pemFile = "$KeyPairName.pem"

try {
    # Check if key pair already exists
    $exists = aws ec2 describe-key-pairs --key-name $KeyPairName --output json 2>&1
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
        Write-Host "Key pair created and saved to $pemFile" -ForegroundColor Green
    } else {
        Write-Error "Failed to create key pair: $keyMaterial"
        exit $LASTEXITCODE
    }

    # Verify key pair exists
    $verify = aws ec2 describe-key-pairs --key-name $KeyPairName --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Key pair verified: $KeyPairName" -ForegroundColor Green
    } else {
        Write-Error "Key pair creation verification failed: $verify"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
