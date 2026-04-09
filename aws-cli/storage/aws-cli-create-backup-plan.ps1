<#
.SYNOPSIS
    Create an AWS Backup plan using the AWS CLI.

.DESCRIPTION
    Creates an AWS Backup plan with a configurable backup rule, schedule, retention
    window, and vault. Uses the AWS CLI command: aws backup create-backup-plan.
    Outputs the BackupPlanId and BackupPlanArn on success.

.PARAMETER Region
    The AWS region in which to create the backup plan.

.PARAMETER PlanName
    The name of the backup plan.

.PARAMETER RuleName
    The name of the backup rule within the plan. Default is DailyBackup.

.PARAMETER ScheduleExpression
    A CRON expression for the backup schedule. Default is daily at 5 AM UTC:
    cron(0 5 ? * * *).

.PARAMETER StartWindowMinutes
    The number of minutes after the scheduled time when a backup job must start
    (60-43200). Default is 480 (8 hours).

.PARAMETER CompletionWindowMinutes
    The number of minutes within which the backup must complete (60-43200).
    Default is 10080 (7 days).

.PARAMETER DeleteAfterDays
    Number of days after creation to delete recovery points (1-36500). Default is 35.

.PARAMETER VaultName
    The name of the backup vault. If omitted, the Default vault is used.

.EXAMPLE
    .\aws-cli-create-backup-plan.ps1 -Region "us-east-1" -PlanName "DailyEC2Backup"

.EXAMPLE
    .\aws-cli-create-backup-plan.ps1 -Region "eu-west-1" -PlanName "WeeklyRDSBackup" -RuleName "WeeklyBackup" -ScheduleExpression "cron(0 3 ? * SUN *)" -DeleteAfterDays 90 -VaultName "rds-vault"

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
    https://docs.aws.amazon.com/cli/latest/reference/backup/create-backup-plan.html

.COMPONENT
    AWS CLI Backup
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region in which to create the backup plan.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the backup plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanName,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the backup rule within the plan. Default is DailyBackup.")]
    [string]$RuleName = 'DailyBackup',

    [Parameter(Mandatory = $false, HelpMessage = "CRON schedule expression. Default is daily at 5 AM UTC.")]
    [string]$ScheduleExpression = 'cron(0 5 ? * * *)',

    [Parameter(Mandatory = $false, HelpMessage = "Minutes after scheduled time when a backup job must start (60-43200). Default is 480.")]
    [ValidateRange(60, 43200)]
    [int]$StartWindowMinutes = 480,

    [Parameter(Mandatory = $false, HelpMessage = "Minutes within which the backup must complete (60-43200). Default is 10080.")]
    [ValidateRange(60, 43200)]
    [int]$CompletionWindowMinutes = 10080,

    [Parameter(Mandatory = $false, HelpMessage = "Days after creation to delete recovery points (1-36500). Default is 35.")]
    [ValidateRange(1, 36500)]
    [int]$DeleteAfterDays = 35,

    [Parameter(Mandatory = $false, HelpMessage = "The backup vault name. Defaults to the Default vault if omitted.")]
    [string]$VaultName
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

# Default vault name
if (-not $VaultName) { $VaultName = 'Default' }

try {
    Write-Host "🚀 Starting AWS Backup Plan Creation" -ForegroundColor Green
    Write-Host "🔍 Validating AWS CLI configuration..." -ForegroundColor Cyan
    aws sts get-caller-identity --region $Region --output json 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI authentication failed. Run 'aws configure'." }
    Write-Host "✅ AWS CLI authenticated." -ForegroundColor Green

    # Build backup plan JSON
    $backupPlan = @{
        BackupPlanName = $PlanName
        Rules          = @(
            @{
                RuleName                = $RuleName
                TargetBackupVaultName   = $VaultName
                ScheduleExpression      = $ScheduleExpression
                StartWindowMinutes      = $StartWindowMinutes
                CompletionWindowMinutes = $CompletionWindowMinutes
                Lifecycle               = @{ DeleteAfterDays = $DeleteAfterDays }
            }
        )
    }

    $backupPlanJson = @{ BackupPlan = $backupPlan } | ConvertTo-Json -Depth 6 -Compress

    Write-Host "🔧 Creating backup plan '$PlanName'..." -ForegroundColor Cyan
    $result = aws backup create-backup-plan `
        --region $Region `
        --backup-plan $backupPlanJson `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create backup plan: $result"
    }

    $data = $result | ConvertFrom-Json
    Write-Host "✅ Backup plan created successfully." -ForegroundColor Green

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  BackupPlanId:    $($data.BackupPlanId)" -ForegroundColor Cyan
    Write-Host "  BackupPlanArn:   $($data.BackupPlanArn)" -ForegroundColor Cyan
    Write-Host "  Plan name:       $PlanName" -ForegroundColor Cyan
    Write-Host "  Rule name:       $RuleName" -ForegroundColor Cyan
    Write-Host "  Schedule:        $ScheduleExpression" -ForegroundColor Cyan
    Write-Host "  Vault:           $VaultName" -ForegroundColor Cyan
    Write-Host "  Retention:       $DeleteAfterDays days" -ForegroundColor Cyan

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "  - Assign resources: aws backup create-backup-selection --backup-plan-id $($data.BackupPlanId)" -ForegroundColor Yellow
    Write-Host "  - Verify the plan: aws backup get-backup-plan --backup-plan-id $($data.BackupPlanId)" -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
