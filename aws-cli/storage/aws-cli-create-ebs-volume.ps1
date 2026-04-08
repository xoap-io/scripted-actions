<#
.SYNOPSIS
    Creates an AWS EBS Volume.

.DESCRIPTION
    This script creates an EBS volume using the AWS CLI.
    Uses the following AWS CLI command:
    aws ec2 create-volume

.PARAMETER AvailabilityZone
    The availability zone for the volume.

.PARAMETER Size
    The size of the volume in GiB.

.EXAMPLE
    .\aws-cli-create-ebs-volume.ps1 -AvailabilityZone "us-east-1a" -Size 10

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/create-volume.html

.COMPONENT
    AWS CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The availability zone for the volume")]
    [string]$AvailabilityZone,

    [Parameter(Mandatory = $true, HelpMessage = "The size of the volume in GiB")]
    [ValidatePattern('^\d+$')]
    [int]$Size
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws ec2 create-volume --availability-zone $AvailabilityZone --size $Size --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "EBS volume created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to create EBS volume: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
