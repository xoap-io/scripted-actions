<#
.SYNOPSIS
    Create a Route 53 private hosted zone using the AWS CLI.

.DESCRIPTION
    Creates an Amazon Route 53 private hosted zone and associates it with the
    specified VPC. DNS queries from within the VPC will resolve using the private
    hosted zone records. Uses the AWS CLI command:
    aws route53 create-hosted-zone.
    Outputs the HostedZoneId and DomainName on success.

.PARAMETER DomainName
    The domain name for the private hosted zone (e.g. corp.internal).

.PARAMETER VpcId
    The ID of the VPC to associate with the private hosted zone.

.PARAMETER VpcRegion
    The AWS region of the VPC.

.PARAMETER Comment
    An optional comment for the hosted zone.

.PARAMETER CallerReference
    A unique string that identifies the request. Auto-generated from a UUID if omitted.

.EXAMPLE
    .\aws-cli-create-private-hosted-zone.ps1 -DomainName "corp.internal" -VpcId "vpc-0a1b2c3d4e5f67890" -VpcRegion "us-east-1"

.EXAMPLE
    .\aws-cli-create-private-hosted-zone.ps1 -DomainName "services.internal" -VpcId "vpc-0fedcba9876543210" -VpcRegion "eu-west-1" -Comment "Internal microservices DNS zone"

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
    https://docs.aws.amazon.com/cli/latest/reference/route53/create-hosted-zone.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The domain name for the private hosted zone (e.g. corp.internal).")]
    [ValidateNotNullOrEmpty()]
    [string]$DomainName,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the VPC to associate with the private hosted zone.")]
    [ValidatePattern('^vpc-[a-f0-9]{8,17}$')]
    [string]$VpcId,

    [Parameter(Mandatory = $true, HelpMessage = "The AWS region of the VPC.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$VpcRegion,

    [Parameter(Mandatory = $false, HelpMessage = "An optional comment for the hosted zone.")]
    [string]$Comment,

    [Parameter(Mandatory = $false, HelpMessage = "Unique string identifying the request. Auto-generated if omitted.")]
    [string]$CallerReference
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

# Auto-generate caller reference if not provided
if (-not $CallerReference) {
    $CallerReference = [System.Guid]::NewGuid().ToString()
}

# Ensure domain name ends with a dot (Route 53 convention)
if (-not $DomainName.EndsWith('.')) {
    $DomainName = "$DomainName."
}

try {
    Write-Host "🚀 Starting Route 53 Private Hosted Zone Creation" -ForegroundColor Green
    Write-Host "🔍 Validating AWS CLI configuration..." -ForegroundColor Cyan
    aws sts get-caller-identity --output json 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI authentication failed. Run 'aws configure'." }
    Write-Host "✅ AWS CLI authenticated." -ForegroundColor Green

    Write-Host "🔍 Verifying VPC '$VpcId' in region '$VpcRegion'..." -ForegroundColor Cyan
    aws ec2 describe-vpcs --region $VpcRegion --vpc-ids $VpcId --output json 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "VPC '$VpcId' not found in region '$VpcRegion'." }
    Write-Host "✅ VPC verified." -ForegroundColor Green

    # Build hosted zone configuration
    $hostedZoneConfig = @{ PrivateZone = $true }
    if ($Comment) { $hostedZoneConfig['Comment'] = $Comment }
    $configJson = $hostedZoneConfig | ConvertTo-Json -Compress

    $vpcJson = (@{ VPCRegion = $VpcRegion; VPCId = $VpcId }) | ConvertTo-Json -Compress

    Write-Host "🔧 Creating private hosted zone '$DomainName'..." -ForegroundColor Cyan
    $result = aws route53 create-hosted-zone `
        --name $DomainName `
        --caller-reference $CallerReference `
        --hosted-zone-config $configJson `
        --vpc $vpcJson `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create hosted zone: $result"
    }

    $data       = $result | ConvertFrom-Json
    $zone       = $data.HostedZone
    $zoneId     = $zone.Id -replace '^/hostedzone/', ''

    Write-Host "✅ Private hosted zone created successfully." -ForegroundColor Green

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  HostedZoneId:   $zoneId" -ForegroundColor Cyan
    Write-Host "  DomainName:     $($zone.Name)" -ForegroundColor Cyan
    Write-Host "  Private zone:   $($zone.Config.PrivateZone)" -ForegroundColor Cyan
    Write-Host "  VPC:            $VpcId ($VpcRegion)" -ForegroundColor Cyan
    Write-Host "  Resource count: $($zone.ResourceRecordSetCount)" -ForegroundColor Cyan

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "  - Add DNS records: aws route53 change-resource-record-sets --hosted-zone-id $zoneId" -ForegroundColor Yellow
    Write-Host "  - Associate additional VPCs: aws route53 associate-vpc-with-hosted-zone --hosted-zone-id $zoneId --vpc VPCRegion=<region>,VPCId=<vpc-id>" -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
