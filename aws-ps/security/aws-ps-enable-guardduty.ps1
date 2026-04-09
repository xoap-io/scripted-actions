<#
.SYNOPSIS
    Enables AWS GuardDuty in a region using AWS.Tools.GuardDuty.

.DESCRIPTION
    This script enables AWS GuardDuty in the specified region using the
    New-GDDetector cmdlet from AWS.Tools.GuardDuty. Before creating a new
    detector, it checks for existing detectors with Get-GDDetectorList. If a
    detector already exists, the script reports its status without creating a
    duplicate. Optional data sources (S3 logs, Kubernetes audit logs, malware
    protection) can be enabled at creation time.

.PARAMETER Region
    The AWS region in which to enable GuardDuty (e.g. eu-central-1).

.PARAMETER FindingPublishingFrequency
    How often GuardDuty publishes updated findings to CloudWatch Events:
    FIFTEEN_MINUTES, ONE_HOUR (default), or SIX_HOURS.

.PARAMETER EnableS3Logs
    If specified, enables S3 data events as a GuardDuty data source.

.PARAMETER EnableKubernetesAuditLogs
    If specified, enables Kubernetes audit logs as a GuardDuty data source.

.PARAMETER EnableMalwareProtection
    If specified, enables EBS malware protection as a GuardDuty data source.

.EXAMPLE
    .\aws-ps-enable-guardduty.ps1 -Region eu-central-1
    Enables GuardDuty in eu-central-1 with default settings.

.EXAMPLE
    .\aws-ps-enable-guardduty.ps1 -Region us-east-1 -FindingPublishingFrequency FIFTEEN_MINUTES -EnableS3Logs -EnableKubernetesAuditLogs -EnableMalwareProtection
    Enables GuardDuty with all data sources and 15-minute finding publishing.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.GuardDuty

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/items/New-GDDetector.html

.COMPONENT
    AWS PowerShell GuardDuty
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region in which to enable GuardDuty (e.g. eu-central-1).")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(HelpMessage = "How often GuardDuty publishes updated findings: FIFTEEN_MINUTES, ONE_HOUR (default), or SIX_HOURS.")]
    [ValidateSet('FIFTEEN_MINUTES', 'ONE_HOUR', 'SIX_HOURS')]
    [string]$FindingPublishingFrequency = 'ONE_HOUR',

    [Parameter(HelpMessage = "If specified, enables S3 data events as a GuardDuty data source.")]
    [switch]$EnableS3Logs,

    [Parameter(HelpMessage = "If specified, enables Kubernetes audit logs as a GuardDuty data source.")]
    [switch]$EnableKubernetesAuditLogs,

    [Parameter(HelpMessage = "If specified, enables EBS malware protection as a GuardDuty data source.")]
    [switch]$EnableMalwareProtection
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting GuardDuty enablement" -ForegroundColor Green
    Write-Host "🔍 Importing AWS.Tools.GuardDuty module..." -ForegroundColor Cyan
    Import-Module AWS.Tools.GuardDuty -ErrorAction Stop

    # Check for existing detectors
    Write-Host "🔍 Checking for existing GuardDuty detectors in $Region..." -ForegroundColor Cyan
    $existingDetectors = @(Get-GDDetectorList -Region $Region)

    if ($existingDetectors.Count -gt 0) {
        $detectorId = $existingDetectors[0]
        Write-Host "ℹ️  GuardDuty detector already exists in $Region." -ForegroundColor Yellow
        Write-Host "   DetectorId: $detectorId" -ForegroundColor White

        $detector = Get-GDDetector -DetectorId $detectorId -Region $Region
        Write-Host "" -ForegroundColor White
        Write-Host "📊 Summary:" -ForegroundColor Blue
        Write-Host "   DetectorId:               $detectorId" -ForegroundColor White
        Write-Host "   Status:                   $($detector.Status)" -ForegroundColor White
        Write-Host "   FindingPublishingFrequency: $($detector.FindingPublishingFrequency)" -ForegroundColor White
        Write-Host "   Region:                   $Region" -ForegroundColor White
        return
    }

    Write-Host "🔧 Enabling GuardDuty detector in $Region..." -ForegroundColor Cyan
    Write-Host "   FindingPublishingFrequency: $FindingPublishingFrequency" -ForegroundColor Gray

    # Build data sources configuration
    $dataSourcesConfig = [Amazon.GuardDuty.Model.DataSourceConfigurations]::new()

    if ($EnableS3Logs) {
        $s3Logs = [Amazon.GuardDuty.Model.S3LogsConfiguration]::new()
        $s3Logs.Enable = $true
        $dataSourcesConfig.S3Logs = $s3Logs
        Write-Host "   S3 Logs: enabled" -ForegroundColor Gray
    }

    if ($EnableKubernetesAuditLogs) {
        $k8sConfig     = [Amazon.GuardDuty.Model.KubernetesConfiguration]::new()
        $k8sAuditLogs  = [Amazon.GuardDuty.Model.KubernetesAuditLogsConfiguration]::new()
        $k8sAuditLogs.Enable = $true
        $k8sConfig.AuditLogs = $k8sAuditLogs
        $dataSourcesConfig.Kubernetes = $k8sConfig
        Write-Host "   Kubernetes Audit Logs: enabled" -ForegroundColor Gray
    }

    if ($EnableMalwareProtection) {
        $malwareConfig  = [Amazon.GuardDuty.Model.MalwareProtectionConfiguration]::new()
        $scanEc2Config  = [Amazon.GuardDuty.Model.ScanEc2InstanceWithFindings]::new()
        $ebsVolumes     = [Amazon.GuardDuty.Model.EbsVolumes]::new()
        $ebsVolumes.Enable = $true
        $scanEc2Config.EbsVolumes       = $ebsVolumes
        $malwareConfig.ScanEc2InstanceWithFindings = $scanEc2Config
        $dataSourcesConfig.MalwareProtection = $malwareConfig
        Write-Host "   Malware Protection: enabled" -ForegroundColor Gray
    }

    $createParams = @{
        Enable                     = $true
        FindingPublishingFrequency = $FindingPublishingFrequency
        Region                     = $Region
        DataSource                 = $dataSourcesConfig
    }

    $detectorId = New-GDDetector @createParams
    Write-Host "✅ GuardDuty detector created: $detectorId" -ForegroundColor Green

    $detector = Get-GDDetector -DetectorId $detectorId -Region $Region

    Write-Host "" -ForegroundColor White
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   DetectorId:               $detectorId" -ForegroundColor White
    Write-Host "   Status:                   $($detector.Status)" -ForegroundColor White
    Write-Host "   FindingPublishingFrequency: $($detector.FindingPublishingFrequency)" -ForegroundColor White
    Write-Host "   Region:                   $Region" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
