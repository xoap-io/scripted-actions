<#
.SYNOPSIS
    Synchronize local directory with S3 bucket using AWS CLI.

.DESCRIPTION
    This script synchronizes a local directory with an S3 bucket using the latest AWS CLI (v2.16+).
    Supports various sync options including exclude patterns, delete, and dry-run.

.PARAMETER LocalPath
    Local directory path to synchronize.

.PARAMETER S3Path
    S3 bucket path (s3://bucket-name/prefix).

.PARAMETER Direction
    Sync direction: Upload (local to S3), Download (S3 to local), or Bidirectional.

.PARAMETER Delete
    Delete files that don't exist in the source.

.PARAMETER DryRun
    Show what would be done without actually performing the sync.

.PARAMETER ExcludePatterns
    Comma-separated list of patterns to exclude.

.PARAMETER IncludePatterns
    Comma-separated list of patterns to include.

.PARAMETER StorageClass
    S3 storage class for uploaded files.

.PARAMETER ServerSideEncryption
    Server-side encryption method (AES256, aws:kms).

.PARAMETER KmsKeyId
    KMS key ID for encryption (when using aws:kms).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER AwsProfile
    The AWS CLI profile to use (optional).

.PARAMETER Recursive
    Recursively sync subdirectories.

.PARAMETER Force
    Skip confirmation prompts.

.EXAMPLE
    .\aws-cli-sync-s3.ps1 -LocalPath "C:\Data" -S3Path "s3://my-bucket/data" -Direction "Upload"

.EXAMPLE
    .\aws-cli-sync-s3.ps1 -LocalPath "./backup" -S3Path "s3://backup-bucket" -Direction "Download" -Delete

.EXAMPLE
    .\aws-cli-sync-s3.ps1 -LocalPath "./docs" -S3Path "s3://docs-bucket" -Direction "Upload" -ExcludePatterns "*.tmp,*.log" -DryRun

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
    https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html

.COMPONENT
    AWS CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Local directory path to synchronize")]
    [string]$LocalPath,

    [Parameter(Mandatory = $true, HelpMessage = "S3 bucket path (s3://bucket-name/prefix)")]
    [ValidatePattern('^s3://[a-z0-9][a-z0-9\-]*[a-z0-9](/.*)?$')]
    [string]$S3Path,

    [Parameter(Mandatory = $true, HelpMessage = "Sync direction: Upload (local to S3), Download (S3 to local), or Bidirectional")]
    [ValidateSet("Upload", "Download", "Bidirectional")]
    [string]$Direction,

    [Parameter(Mandatory = $false, HelpMessage = "Delete files that don't exist in the source")]
    [switch]$Delete,

    [Parameter(Mandatory = $false, HelpMessage = "Show what would be done without actually performing the sync")]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of patterns to exclude")]
    [string]$ExcludePatterns,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of patterns to include")]
    [string]$IncludePatterns,

    [Parameter(Mandatory = $false, HelpMessage = "S3 storage class for uploaded files")]
    [ValidateSet("STANDARD", "REDUCED_REDUNDANCY", "STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING", "GLACIER", "DEEP_ARCHIVE", "GLACIER_IR")]
    [string]$StorageClass,

    [Parameter(Mandatory = $false, HelpMessage = "Server-side encryption method (AES256, aws:kms)")]
    [ValidateSet("AES256", "aws:kms")]
    [string]$ServerSideEncryption,

    [Parameter(Mandatory = $false, HelpMessage = "KMS key ID for encryption (when using aws:kms)")]
    [string]$KmsKeyId,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region to use")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d{1}$')]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS CLI profile to use")]
    [string]$AwsProfile,

    [Parameter(Mandatory = $false, HelpMessage = "Recursively sync subdirectories")]
    [switch]$Recursive,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Check AWS CLI availability
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    Write-Host "Starting S3 synchronization process..." -ForegroundColor Green

    # Validate local path
    if ($Direction -in @("Upload", "Bidirectional")) {
        if (-not (Test-Path $LocalPath)) {
            throw "Local path does not exist: $LocalPath"
        }
    }

    # Build AWS CLI arguments
    $awsArgs = @()
    if ($Region) {
        $awsArgs += '--region', $Region
    }
    if ($AwsProfile) {
        $awsArgs += '--profile', $AwsProfile
    }

    # Extract bucket name for validation
    $bucketName = ($S3Path -replace '^s3://', '') -split '/' | Select-Object -First 1

    # Validate S3 bucket access
    Write-Host "Validating S3 bucket access..." -ForegroundColor Cyan
    $bucketResult = aws s3api head-bucket --bucket $bucketName @awsArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot access S3 bucket '$bucketName': $bucketResult"
    }

    # Display sync configuration
    Write-Host "Sync Configuration:" -ForegroundColor Cyan
    Write-Host "  Local Path: $LocalPath" -ForegroundColor White
    Write-Host "  S3 Path: $S3Path" -ForegroundColor White
    Write-Host "  Direction: $Direction" -ForegroundColor White
    Write-Host "  Recursive: $Recursive" -ForegroundColor White
    Write-Host "  Delete: $Delete" -ForegroundColor White
    Write-Host "  Dry Run: $DryRun" -ForegroundColor White

    if ($ExcludePatterns) {
        Write-Host "  Exclude Patterns: $ExcludePatterns" -ForegroundColor White
    }
    if ($IncludePatterns) {
        Write-Host "  Include Patterns: $IncludePatterns" -ForegroundColor White
    }
    if ($StorageClass) {
        Write-Host "  Storage Class: $StorageClass" -ForegroundColor White
    }
    if ($ServerSideEncryption) {
        Write-Host "  Encryption: $ServerSideEncryption" -ForegroundColor White
    }

    # Function to build sync command
    function Build-SyncCommand {
        param($Source, $Destination, $Direction)

        $syncArgs = @('s3', 'sync', $Source, $Destination)
        $syncArgs += $awsArgs

        if ($Delete) {
            $syncArgs += '--delete'
        }

        if ($DryRun) {
            $syncArgs += '--dryrun'
        }

        if (-not $Recursive) {
            $syncArgs += '--exclude', '*/*'
        }

        if ($ExcludePatterns) {
            $patterns = $ExcludePatterns -split ','
            foreach ($pattern in $patterns) {
                $syncArgs += '--exclude', $pattern.Trim()
            }
        }

        if ($IncludePatterns) {
            $patterns = $IncludePatterns -split ','
            foreach ($pattern in $patterns) {
                $syncArgs += '--include', $pattern.Trim()
            }
        }

        if ($StorageClass -and $Direction -eq "Upload") {
            $syncArgs += '--storage-class', $StorageClass
        }

        if ($ServerSideEncryption -and $Direction -eq "Upload") {
            $syncArgs += '--sse', $ServerSideEncryption
            if ($KmsKeyId -and $ServerSideEncryption -eq 'aws:kms') {
                $syncArgs += '--sse-kms-key-id', $KmsKeyId
            }
        }

        return $syncArgs
    }

    # Confirmation unless Force or DryRun
    if (-not $Force -and -not $DryRun) {
        Write-Host "`n⚠️  This operation will modify files/objects" -ForegroundColor Yellow
        if ($Delete) {
            Write-Host "⚠️  Delete option is enabled - files not in source will be removed" -ForegroundColor Red
        }
        $confirm = Read-Host "Proceed with synchronization? (y/N)"
        if ($confirm -notmatch '^[Yy]') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Execute sync based on direction
    switch ($Direction) {
        "Upload" {
            Write-Host "`nSyncing from local to S3..." -ForegroundColor Cyan
            $syncArgs = Build-SyncCommand -Source $LocalPath -Destination $S3Path -Direction "Upload"

            Write-Host "Executing: aws $($syncArgs -join ' ')" -ForegroundColor Gray
            $result = aws @syncArgs 2>&1

            if ($LASTEXITCODE -ne 0) {
                throw "Upload sync failed: $result"
            }

            Write-Host "✓ Upload sync completed" -ForegroundColor Green
            Write-Output $result
        }

        "Download" {
            Write-Host "`nSyncing from S3 to local..." -ForegroundColor Cyan

            # Create local directory if it doesn't exist
            if (-not (Test-Path $LocalPath)) {
                New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
                Write-Host "Created local directory: $LocalPath" -ForegroundColor Yellow
            }

            $syncArgs = Build-SyncCommand -Source $S3Path -Destination $LocalPath -Direction "Download"

            Write-Host "Executing: aws $($syncArgs -join ' ')" -ForegroundColor Gray
            $result = aws @syncArgs 2>&1

            if ($LASTEXITCODE -ne 0) {
                throw "Download sync failed: $result"
            }

            Write-Host "✓ Download sync completed" -ForegroundColor Green
            Write-Output $result
        }

        "Bidirectional" {
            Write-Host "`nPerforming bidirectional sync..." -ForegroundColor Cyan
            Write-Host "Note: Bidirectional sync requires careful consideration of file timestamps and conflicts" -ForegroundColor Yellow

            # First sync: Local to S3
            Write-Host "`nStep 1: Syncing local changes to S3..." -ForegroundColor Cyan
            $uploadArgs = Build-SyncCommand -Source $LocalPath -Destination $S3Path -Direction "Upload"

            Write-Host "Executing: aws $($uploadArgs -join ' ')" -ForegroundColor Gray
            $uploadResult = aws @uploadArgs 2>&1

            if ($LASTEXITCODE -ne 0) {
                throw "Upload sync failed: $uploadResult"
            }

            Write-Host "✓ Upload sync completed" -ForegroundColor Green

            # Second sync: S3 to Local (without delete to avoid conflicts)
            Write-Host "`nStep 2: Syncing S3 changes to local..." -ForegroundColor Cyan
            $downloadArgs = Build-SyncCommand -Source $S3Path -Destination $LocalPath -Direction "Download"

            # Remove delete flag for download in bidirectional sync to avoid conflicts
            $downloadArgs = $downloadArgs | Where-Object { $_ -ne '--delete' }

            Write-Host "Executing: aws $($downloadArgs -join ' ')" -ForegroundColor Gray
            $downloadResult = aws @downloadArgs 2>&1

            if ($LASTEXITCODE -ne 0) {
                throw "Download sync failed: $downloadResult"
            }

            Write-Host "✓ Download sync completed" -ForegroundColor Green
            Write-Host "✓ Bidirectional sync completed" -ForegroundColor Green
        }
    }

    # Summary statistics if not dry run
    if (-not $DryRun) {
        Write-Host "`nGetting sync summary..." -ForegroundColor Cyan

        # Get bucket size and object count
        $listResult = aws s3 ls $S3Path --recursive --summarize @awsArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            $lines = $listResult -split "`n"
            $totalObjects = ($lines | Where-Object { $_ -match "Total Objects:" }) -replace ".*Total Objects: ", ""
            $totalSize = ($lines | Where-Object { $_ -match "Total Size:" }) -replace ".*Total Size: ", ""

            if ($totalObjects -and $totalSize) {
                Write-Host "S3 Path Summary:" -ForegroundColor Cyan
                Write-Host "  Total Objects: $totalObjects" -ForegroundColor White
                Write-Host "  Total Size: $totalSize" -ForegroundColor White
            }
        }

        # Get local directory info if syncing to local
        if ($Direction -in @("Download", "Bidirectional") -and (Test-Path $LocalPath)) {
            $localFiles = Get-ChildItem -Path $LocalPath -Recurse -File
            $localCount = $localFiles.Count
            $localSize = ($localFiles | Measure-Object -Property Length -Sum).Sum

            Write-Host "Local Path Summary:" -ForegroundColor Cyan
            Write-Host "  Total Files: $localCount" -ForegroundColor White
            Write-Host "  Total Size: $([math]::Round($localSize / 1MB, 2)) MB" -ForegroundColor White
        }
    }

    Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Verify that all expected files were synchronized" -ForegroundColor White
    Write-Host "2. Monitor S3 costs if uploading large amounts of data" -ForegroundColor White
    Write-Host "3. Consider setting up S3 lifecycle policies for cost optimization" -ForegroundColor White
    Write-Host "4. Set up CloudWatch monitoring for S3 bucket metrics" -ForegroundColor White

    if ($DryRun) {
        Write-Host "`n💡 This was a dry run. No files were actually modified." -ForegroundColor Yellow
        Write-Host "Remove the -DryRun parameter to perform the actual sync." -ForegroundColor Yellow
    }

    Write-Host "`n✅ S3 synchronization operation completed!" -ForegroundColor Green

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
