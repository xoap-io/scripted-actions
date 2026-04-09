<#
.SYNOPSIS
    Enables AWS GuardDuty in the specified region and configures optional protections.

.DESCRIPTION
    This script enables AWS GuardDuty by creating a detector in the target region
    using the AWS CLI. Before creating a new detector it checks whether GuardDuty
    is already enabled and reports the existing detector ID and status. Optional
    data-source protections (S3, EKS, Malware) can be activated at the same time.
    Uses the following AWS CLI commands:
    aws guardduty list-detectors
    aws guardduty get-detector
    aws guardduty create-detector

.PARAMETER Region
    The AWS region in which to enable GuardDuty (e.g. us-east-1).

.PARAMETER FindingPublishingFrequency
    How often GuardDuty publishes updated findings.
    Valid values: FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS. Defaults to ONE_HOUR.

.PARAMETER EnableS3Protection
    If specified, enables GuardDuty S3 protection.

.PARAMETER EnableEksProtection
    If specified, enables GuardDuty EKS audit log protection.

.PARAMETER EnableMalwareProtection
    If specified, enables GuardDuty malware protection for EC2.

.PARAMETER Tags
    Optional comma-separated Key=Value tag pairs, e.g. 'Env=prod,Team=security'.

.EXAMPLE
    .\aws-cli-enable-guardduty.ps1 -Region "us-east-1"

.EXAMPLE
    .\aws-cli-enable-guardduty.ps1 `
        -Region "eu-west-1" `
        -FindingPublishingFrequency "FIFTEEN_MINUTES" `
        -EnableS3Protection `
        -EnableEksProtection `
        -Tags "Env=prod,Team=security"

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
    https://docs.aws.amazon.com/cli/latest/reference/guardduty/create-detector.html

.COMPONENT
    AWS CLI Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region in which to enable GuardDuty (e.g. us-east-1).")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Finding publishing frequency. Defaults to ONE_HOUR.")]
    [ValidateSet('FIFTEEN_MINUTES', 'ONE_HOUR', 'SIX_HOURS')]
    [string]$FindingPublishingFrequency = 'ONE_HOUR',

    [Parameter(Mandatory = $false, HelpMessage = "Enable GuardDuty S3 protection.")]
    [switch]$EnableS3Protection,

    [Parameter(Mandatory = $false, HelpMessage = "Enable GuardDuty EKS audit log protection.")]
    [switch]$EnableEksProtection,

    [Parameter(Mandatory = $false, HelpMessage = "Enable GuardDuty malware protection for EC2.")]
    [switch]$EnableMalwareProtection,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated Key=Value tag pairs, e.g. 'Env=prod,Team=security'.")]
    [string]$Tags
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    Write-Host "🚀 Checking GuardDuty status in region: $Region" -ForegroundColor Green

    # Check if GuardDuty is already enabled
    $listResult = aws guardduty list-detectors --region $Region --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list GuardDuty detectors: $listResult"
    }

    $listData    = $listResult | ConvertFrom-Json
    $detectorIds = $listData.DetectorIds

    if ($detectorIds -and $detectorIds.Count -gt 0) {
        $existingId = $detectorIds[0]
        Write-Host "ℹ️  GuardDuty is already enabled in $Region." -ForegroundColor Yellow

        $getResult = aws guardduty get-detector `
            --region $Region `
            --detector-id $existingId `
            --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            $detectorData = $getResult | ConvertFrom-Json
            Write-Host "📊 Summary:" -ForegroundColor Blue
            Write-Host "   DetectorId : $existingId"
            Write-Host "   Status     : $($detectorData.Status)"
            Write-Host "   CreatedAt  : $($detectorData.CreatedAt)"
        }
        exit 0
    }

    Write-Host "🔧 Enabling GuardDuty..." -ForegroundColor Cyan

    # Build data sources feature block
    $featuresJson = @()

    if ($EnableS3Protection) {
        $featuresJson += '{"Name":"S3_DATA_EVENTS","Status":"ENABLED"}'
    }
    if ($EnableEksProtection) {
        $featuresJson += '{"Name":"EKS_AUDIT_LOGS","Status":"ENABLED"}'
    }
    if ($EnableMalwareProtection) {
        $featuresJson += '{"Name":"EBS_MALWARE_PROTECTION","Status":"ENABLED"}'
    }

    $createArgs = @(
        'guardduty', 'create-detector',
        '--region', $Region,
        '--enable',
        '--finding-publishing-frequency', $FindingPublishingFrequency,
        '--output', 'json'
    )

    if ($featuresJson.Count -gt 0) {
        $featuresArg = "[$(($featuresJson) -join ',')]"
        $createArgs += '--features', $featuresArg
    }

    if ($Tags) {
        $tagObj = @{}
        $Tags -split ',' | ForEach-Object {
            $kv = $_ -split '=', 2
            $tagObj[$kv[0].Trim()] = $kv[1].Trim()
        }
        $tagsJson = $tagObj | ConvertTo-Json -Compress
        $createArgs += '--tags', $tagsJson
    }

    $result = aws @createArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to enable GuardDuty: $result"
    }

    $detectorData = $result | ConvertFrom-Json

    Write-Host "✅ GuardDuty enabled successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   DetectorId              : $($detectorData.DetectorId)"
    Write-Host "   FindingPublishFrequency : $FindingPublishingFrequency"
    Write-Host "   S3 Protection           : $($EnableS3Protection.IsPresent)"
    Write-Host "   EKS Protection          : $($EnableEksProtection.IsPresent)"
    Write-Host "   Malware Protection      : $($EnableMalwareProtection.IsPresent)"

    Write-Host "💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   Review findings at: https://$Region.console.aws.amazon.com/guardduty"
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
