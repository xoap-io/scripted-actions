<#
.SYNOPSIS
    Associates an Elastic IP with an EC2 instance using the AWS CLI.

.DESCRIPTION
    This script associates an Elastic IP address with an EC2 instance using the AWS CLI.
    Uses aws ec2 associate-address to perform the association.

.PARAMETER InstanceId
    The ID of the EC2 instance to associate the Elastic IP with.

.PARAMETER AllocationId
    The allocation ID of the Elastic IP to associate.

.EXAMPLE
    .\aws-cli-allocate-elastic-ip.ps1 -InstanceId i-1234567890abcdef0 -AllocationId eipalloc-12345678

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/associate-address.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the EC2 instance to associate the Elastic IP with.")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $true, HelpMessage = "The allocation ID of the Elastic IP to associate.")]
    [ValidatePattern('^eipalloc-[a-zA-Z0-9]{8,}$')]
    [string]$AllocationId
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    $result = aws ec2 associate-address --instance-id $InstanceId --allocation-id $AllocationId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Elastic IP associated successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        throw "Failed to associate Elastic IP: $result"
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
