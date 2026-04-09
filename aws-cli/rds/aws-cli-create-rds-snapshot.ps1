<#
.SYNOPSIS
    Create a manual snapshot of an Amazon RDS database instance using AWS CLI.

.DESCRIPTION
    This script creates a manual DB snapshot of an existing Amazon RDS instance.
    Manual snapshots are retained until explicitly deleted, unlike automated
    snapshots. The snapshot creation is asynchronous — it enters a 'creating'
    state and becomes available after completion. Uses
    aws rds create-db-snapshot to initiate the snapshot.

.PARAMETER DBInstanceIdentifier
    The identifier of the source RDS DB instance to snapshot.

.PARAMETER DBSnapshotIdentifier
    A unique identifier for the DB snapshot. Must start with a letter and contain
    only alphanumeric characters and hyphens, up to 255 characters.

.PARAMETER Region
    The AWS region where the DB instance resides.
    Example: us-east-1, eu-west-1

.PARAMETER Tags
    A JSON array string of tag objects with Key and Value properties to apply to
    the snapshot. Example: '[{"Key":"Environment","Value":"prod"},{"Key":"Owner","Value":"team"}]'

.EXAMPLE
    .\aws-cli-create-rds-snapshot.ps1 `
        -DBInstanceIdentifier "my-db-01" `
        -DBSnapshotIdentifier "my-db-01-snapshot-20260408"

.EXAMPLE
    .\aws-cli-create-rds-snapshot.ps1 `
        -DBInstanceIdentifier "prod-postgres-01" `
        -DBSnapshotIdentifier "prod-postgres-backup-20260408" `
        -Region "us-east-1" `
        -Tags '[{"Key":"Environment","Value":"prod"},{"Key":"Purpose","Value":"manual-backup"}]'

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI v2

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/rds/create-db-snapshot.html

.COMPONENT
    AWS CLI Relational Database Service
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The identifier of the source RDS DB instance to snapshot.")]
    [ValidateNotNullOrEmpty()]
    [string]$DBInstanceIdentifier,

    [Parameter(Mandatory = $true, HelpMessage = "A unique identifier for the DB snapshot (letters, digits, hyphens; up to 255 chars; must start with a letter).")]
    [ValidatePattern('^[a-zA-Z][a-zA-Z0-9-]{0,254}$')]
    [string]$DBSnapshotIdentifier,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region where the DB instance resides. Example: us-east-1.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "JSON array of tag objects to apply. Example: '[{Key:Env,Value:prod}]'.")]
    [ValidateNotNullOrEmpty()]
    [string]$Tags
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "`n🚀 Starting RDS snapshot creation..." -ForegroundColor Green

    # Check AWS CLI availability
    Write-Host "🔍 Checking AWS CLI availability..." -ForegroundColor Cyan
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI is not installed or not in PATH. Install from https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    }

    Write-Host "ℹ️  DB Instance   : $($DBInstanceIdentifier)" -ForegroundColor Yellow
    Write-Host "ℹ️  Snapshot ID   : $($DBSnapshotIdentifier)" -ForegroundColor Yellow

    # Build AWS CLI arguments
    $awsArgs = @(
        'rds', 'create-db-snapshot',
        '--db-instance-identifier', $DBInstanceIdentifier,
        '--db-snapshot-identifier', $DBSnapshotIdentifier,
        '--output', 'json'
    )

    if ($Tags) {
        # Validate that Tags is valid JSON
        try {
            $null = $Tags | ConvertFrom-Json
        }
        catch {
            throw "Invalid Tags JSON format. Expected a JSON array of {Key, Value} objects."
        }
        $awsArgs += '--tags', $Tags
    }

    if ($Region) {
        $awsArgs += '--region', $Region
        Write-Host "ℹ️  Region        : $($Region)" -ForegroundColor Yellow
    }

    Write-Host "🔧 Initiating snapshot creation..." -ForegroundColor Cyan

    $result = & aws @awsArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "aws rds create-db-snapshot failed: $result"
    }

    $snapshotInfo = $result | ConvertFrom-Json
    $snapshot = $snapshotInfo.DBSnapshot

    Write-Host "`n✅ RDS snapshot creation initiated successfully!" -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Snapshot ID      : $($snapshot.DBSnapshotIdentifier)" -ForegroundColor Green
    Write-Host "   Source Instance  : $($snapshot.DBInstanceIdentifier)" -ForegroundColor Green
    Write-Host "   Status           : $($snapshot.Status)" -ForegroundColor Green
    Write-Host "   Engine           : $($snapshot.Engine) $($snapshot.EngineVersion)" -ForegroundColor Green
    Write-Host "   Created At       : $($snapshot.SnapshotCreateTime)" -ForegroundColor Green
    Write-Host "   Storage (GB)     : $($snapshot.AllocatedStorage)" -ForegroundColor Green
    Write-Host "   Encrypted        : $($snapshot.Encrypted)" -ForegroundColor Green

    Write-Host "`n⚠️  Note: Snapshot creation is asynchronous and may take several minutes." -ForegroundColor Yellow
    Write-Host "💡 Next Steps:" -ForegroundColor Yellow

    $waitCmd = "   aws rds wait db-snapshot-completed --db-snapshot-identifier $($DBSnapshotIdentifier)"
    if ($Region) {
        $waitCmd += " --region $($Region)"
    }
    Write-Host "   Wait for completion:" -ForegroundColor Yellow
    Write-Host $waitCmd -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
