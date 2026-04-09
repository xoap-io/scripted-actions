<#
.SYNOPSIS
    Create a Google Cloud SQL instance using gcloud CLI.

.DESCRIPTION
    This script provisions a new Google Cloud SQL instance with configurable
    database version, machine tier, region, storage, availability, and root
    password. Supports MySQL, PostgreSQL, and SQL Server database engines.
    Uses gcloud sql instances create to provision the instance.

.PARAMETER InstanceName
    The name of the Cloud SQL instance to create. Must start with a lowercase
    letter and contain only lowercase letters, digits, and hyphens (up to 86
    characters).

.PARAMETER DatabaseVersion
    The database engine version to use. Supported values:
    MYSQL_8_0, MYSQL_5_7, POSTGRES_15, POSTGRES_14, POSTGRES_13,
    SQLSERVER_2019_STANDARD, SQLSERVER_2019_WEB.

.PARAMETER Tier
    The machine type (tier) for the Cloud SQL instance.
    Defaults to db-f1-micro. Example: db-n1-standard-2, db-custom-2-7680.

.PARAMETER Region
    The region in which to create the Cloud SQL instance.
    Defaults to us-central1. Example: europe-west1, asia-east1.

.PARAMETER ProjectId
    The Google Cloud project ID. If omitted, the active gcloud project is used.

.PARAMETER StorageSize
    The storage size in GB for the Cloud SQL instance (10-65536). Defaults to 20.

.PARAMETER StorageAutoIncrease
    Enable automatic storage increase when storage usage approaches the limit.

.PARAMETER HighAvailability
    Enable regional high availability (availability-type=REGIONAL). Provides
    automatic failover to a standby instance in the same region.

.PARAMETER RootPassword
    The root/admin password for the instance. Required for MySQL and SQL Server
    instances.

.EXAMPLE
    .\gce-cli-create-cloud-sql.ps1 `
        -InstanceName "my-mysql-instance" `
        -DatabaseVersion "MYSQL_8_0" `
        -RootPassword "MySecureRootPass123!"

.EXAMPLE
    .\gce-cli-create-cloud-sql.ps1 `
        -InstanceName "prod-postgres-01" `
        -DatabaseVersion "POSTGRES_15" `
        -Tier "db-n1-standard-2" `
        -Region "europe-west1" `
        -ProjectId "my-project-123" `
        -StorageSize 50 `
        -StorageAutoIncrease `
        -HighAvailability

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Google Cloud SDK

.LINK
    https://cloud.google.com/sdk/gcloud/reference/sql/instances/create

.COMPONENT
    Google Cloud CLI Cloud SQL
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Cloud SQL instance (lowercase letters, digits, hyphens; up to 86 chars; must start with a letter).")]
    [ValidatePattern('^[a-z][a-z0-9-]{0,85}$')]
    [string]$InstanceName,

    [Parameter(Mandatory = $true, HelpMessage = "The database version: MYSQL_8_0, MYSQL_5_7, POSTGRES_15, POSTGRES_14, POSTGRES_13, SQLSERVER_2019_STANDARD, SQLSERVER_2019_WEB.")]
    [ValidateSet(
        'MYSQL_8_0',
        'MYSQL_5_7',
        'POSTGRES_15',
        'POSTGRES_14',
        'POSTGRES_13',
        'SQLSERVER_2019_STANDARD',
        'SQLSERVER_2019_WEB'
    )]
    [string]$DatabaseVersion,

    [Parameter(Mandatory = $false, HelpMessage = "The machine tier for the Cloud SQL instance. Defaults to db-f1-micro. Example: db-n1-standard-2.")]
    [ValidateNotNullOrEmpty()]
    [string]$Tier = 'db-f1-micro',

    [Parameter(Mandatory = $false, HelpMessage = "The region for the Cloud SQL instance. Defaults to us-central1.")]
    [ValidatePattern('^[a-z]+-[a-z]+\d+$')]
    [string]$Region = 'us-central1',

    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID. If omitted, the active gcloud project is used.")]
    [ValidatePattern('^[a-z][a-z0-9-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $false, HelpMessage = "The storage size in GB (10-65536). Defaults to 20.")]
    [ValidateRange(10, 65536)]
    [int]$StorageSize = 20,

    [Parameter(Mandatory = $false, HelpMessage = "Enable automatic storage increase when storage usage approaches the limit.")]
    [switch]$StorageAutoIncrease,

    [Parameter(Mandatory = $false, HelpMessage = "Enable regional high availability (REGIONAL availability type) for automatic failover.")]
    [switch]$HighAvailability,

    [Parameter(Mandatory = $false, HelpMessage = "The root/admin password. Required for MySQL and SQL Server instances.")]
    [ValidateNotNullOrEmpty()]
    [string]$RootPassword
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "`n🚀 Starting Cloud SQL instance creation..." -ForegroundColor Green

    # Check gcloud availability
    Write-Host "🔍 Checking gcloud CLI availability..." -ForegroundColor Cyan
    if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
        throw "gcloud CLI is not installed or not in PATH. Please install the Google Cloud SDK."
    }

    # Warn if MySQL or SQL Server without root password
    if (($DatabaseVersion -like 'MYSQL*' -or $DatabaseVersion -like 'SQLSERVER*') -and -not $RootPassword) {
        Write-Host "⚠️  Warning: RootPassword is recommended for MySQL and SQL Server instances." -ForegroundColor Yellow
    }

    # Set project if specified
    if ($ProjectId) {
        Write-Host "🔧 Setting active project to '$($ProjectId)'..." -ForegroundColor Cyan
        $setProject = & gcloud config set project $ProjectId 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set project '$($ProjectId)': $setProject"
        }
    }

    Write-Host "ℹ️  Instance Name     : $($InstanceName)" -ForegroundColor Yellow
    Write-Host "ℹ️  Database Version  : $($DatabaseVersion)" -ForegroundColor Yellow
    Write-Host "ℹ️  Tier              : $($Tier)" -ForegroundColor Yellow
    Write-Host "ℹ️  Region            : $($Region)" -ForegroundColor Yellow
    Write-Host "ℹ️  Storage           : $($StorageSize) GB" -ForegroundColor Yellow
    Write-Host "ℹ️  High Availability : $($HighAvailability.IsPresent)" -ForegroundColor Yellow

    # Build gcloud arguments
    $gcloudArgs = @(
        'sql', 'instances', 'create', $InstanceName,
        '--database-version', $DatabaseVersion,
        '--tier', $Tier,
        '--region', $Region,
        '--storage-size', $StorageSize
    )

    if ($ProjectId) {
        $gcloudArgs += '--project', $ProjectId
    }

    if ($StorageAutoIncrease) {
        $gcloudArgs += '--storage-auto-increase'
    }

    if ($HighAvailability) {
        $gcloudArgs += '--availability-type', 'REGIONAL'
    }
    else {
        $gcloudArgs += '--availability-type', 'ZONAL'
    }

    if ($RootPassword) {
        $gcloudArgs += '--root-password', $RootPassword
    }

    $gcloudArgs += '--format=json'

    Write-Host "🔧 Creating Cloud SQL instance '$($InstanceName)'..." -ForegroundColor Cyan

    $result = & gcloud @gcloudArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "gcloud sql instances create failed: $result"
    }

    $instanceInfo = $result | ConvertFrom-Json

    Write-Host "`n✅ Cloud SQL instance created successfully!" -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Instance Name    : $($instanceInfo.name)" -ForegroundColor Green
    Write-Host "   State            : $($instanceInfo.state)" -ForegroundColor Green
    Write-Host "   Database Version : $($instanceInfo.databaseVersion)" -ForegroundColor Green
    Write-Host "   Connection Name  : $($instanceInfo.connectionName)" -ForegroundColor Green
    Write-Host "   Region           : $($instanceInfo.region)" -ForegroundColor Green

    if ($instanceInfo.ipAddresses) {
        $primaryIp = ($instanceInfo.ipAddresses | Where-Object { $_.type -eq 'PRIMARY' }).ipAddress
        if ($primaryIp) {
            Write-Host "   Primary IP       : $($primaryIp)" -ForegroundColor Green
        }
    }

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   Connect using Cloud SQL Proxy or the gcloud CLI:" -ForegroundColor Yellow
    Write-Host "   gcloud sql connect $($InstanceName) --user=root" -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
