<#
.SYNOPSIS
    Delete an EBS snapshot using AWS CLI.

.DESCRIPTION
    This script deletes an EBS snapshot using the latest AWS CLI (v2.16+).
    It includes validation and safety checks before deletion.

.PARAMETER SnapshotId
    The ID of the EBS snapshot to delete.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER AwsProfile
    The AWS CLI profile to use (optional).

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER CheckDependencies
    Check if snapshot is being used to create volumes or AMIs.

.EXAMPLE
    .\aws-cli-delete-snapshot.ps1 -SnapshotId "snap-1234567890abcdef0"

.EXAMPLE
    .\aws-cli-delete-snapshot.ps1 -SnapshotId "snap-1234567890abcdef0" -Force

.EXAMPLE
    .\aws-cli-delete-snapshot.ps1 -SnapshotId "snap-1234567890abcdef0" -CheckDependencies -Region "us-west-2"

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/delete-snapshot.html

.COMPONENT
    AWS CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the EBS snapshot to delete")]
    [ValidatePattern('^snap-[a-f0-9]{8,17}$')]
    [string]$SnapshotId,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region to use")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d{1}$')]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS CLI profile to use")]
    [string]$AwsProfile,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Check if snapshot is being used to create volumes or AMIs")]
    [switch]$CheckDependencies
)

$ErrorActionPreference = 'Stop'

# Check AWS CLI availability
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    Write-Host "Starting EBS snapshot deletion process..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @()
    if ($Region) {
        $awsArgs += '--region', $Region
    }
    if ($AwsProfile) {
        $awsArgs += '--profile', $AwsProfile
    }

    # Validate snapshot exists and get its information
    Write-Host "Validating EBS snapshot..." -ForegroundColor Cyan
    $snapshotResult = aws ec2 describe-snapshots --snapshot-ids $SnapshotId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe snapshot: $snapshotResult"
    }

    $snapshotData = $snapshotResult | ConvertFrom-Json
    $snapshot = $snapshotData.Snapshots[0]

    Write-Host "Snapshot Information:" -ForegroundColor Cyan
    Write-Host "  Snapshot ID: $($snapshot.SnapshotId)" -ForegroundColor White
    Write-Host "  Description: $($snapshot.Description)" -ForegroundColor White
    Write-Host "  Volume ID: $($snapshot.VolumeId)" -ForegroundColor White
    Write-Host "  Volume Size: $($snapshot.VolumeSize) GiB" -ForegroundColor White
    Write-Host "  State: $($snapshot.State)" -ForegroundColor White
    Write-Host "  Start Time: $($snapshot.StartTime)" -ForegroundColor White
    Write-Host "  Progress: $($snapshot.Progress)" -ForegroundColor White
    Write-Host "  Owner ID: $($snapshot.OwnerId)" -ForegroundColor White
    Write-Host "  Encrypted: $($snapshot.Encrypted)" -ForegroundColor White

    if ($snapshot.Tags) {
        Write-Host "  Tags:" -ForegroundColor White
        foreach ($tag in $snapshot.Tags) {
            Write-Host "    $($tag.Key): $($tag.Value)" -ForegroundColor Gray
        }
    }

    # Check snapshot state
    if ($snapshot.State -ne 'completed') {
        Write-Warning "Snapshot is in state '$($snapshot.State)'. It may not be safe to delete."
        if (-not $Force) {
            $confirm = Read-Host "Continue with deletion anyway? (y/N)"
            if ($confirm -notmatch '^[Yy]') {
                Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                exit 0
            }
        }
    }

    # Check for dependencies if requested
    if ($CheckDependencies) {
        Write-Host "Checking for dependencies..." -ForegroundColor Cyan

        # Check if snapshot is used by any AMIs
        try {
            $amiResult = aws ec2 describe-images --filters "Name=block-device-mapping.snapshot-id,Values=$SnapshotId" @awsArgs --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $amiData = $amiResult | ConvertFrom-Json
                if ($amiData.Images.Count -gt 0) {
                    Write-Warning "Snapshot is used by the following AMIs:"
                    foreach ($ami in $amiData.Images) {
                        Write-Host "  AMI ID: $($ami.ImageId) - Name: $($ami.Name)" -ForegroundColor Yellow
                    }
                    if (-not $Force) {
                        $confirm = Read-Host "Deleting this snapshot will affect these AMIs. Continue? (y/N)"
                        if ($confirm -notmatch '^[Yy]') {
                            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                            exit 0
                        }
                    }
                }
            }
        } catch {
            Write-Warning "Could not check AMI dependencies: $($_.Exception.Message)"
        }

        # Check if snapshot is being used to create volumes (harder to detect)
        Write-Host "Note: Cannot easily detect if snapshot is being used for volume creation" -ForegroundColor Gray
    }

    # Final confirmation unless Force is specified
    if (-not $Force) {
        Write-Host "`n⚠️  WARNING: Snapshot deletion is irreversible!" -ForegroundColor Red
        Write-Host "This will permanently delete snapshot $SnapshotId" -ForegroundColor Yellow
        $confirm = Read-Host "Are you sure you want to proceed? (y/N)"
        if ($confirm -notmatch '^[Yy]') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Perform the deletion
    Write-Host "Deleting snapshot $SnapshotId..." -ForegroundColor Cyan
    $deleteResult = aws ec2 delete-snapshot --snapshot-id $SnapshotId @awsArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to delete snapshot: $deleteResult"
    }

    Write-Host "✓ Snapshot deletion initiated successfully" -ForegroundColor Green

    # Verify deletion by trying to describe the snapshot
    Write-Host "Verifying snapshot deletion..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2

    $verifyResult = aws ec2 describe-snapshots --snapshot-ids $SnapshotId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        if ($verifyResult -like "*InvalidSnapshot.NotFound*") {
            Write-Host "✓ Snapshot successfully deleted and no longer exists" -ForegroundColor Green
        } else {
            Write-Warning "Could not verify deletion: $verifyResult"
        }
    } else {
        $verifyData = $verifyResult | ConvertFrom-Json
        if ($verifyData.Snapshots.Count -eq 0) {
            Write-Host "✓ Snapshot successfully deleted and no longer exists" -ForegroundColor Green
        } else {
            Write-Warning "Snapshot still exists. Deletion may be in progress."
        }
    }

    Write-Host "`n📝 Important Notes:" -ForegroundColor Cyan
    Write-Host "1. Snapshot deletion is permanent and cannot be undone" -ForegroundColor White
    Write-Host "2. Any AMIs using this snapshot may become unusable" -ForegroundColor White
    Write-Host "3. You will no longer be charged for storage of this snapshot" -ForegroundColor White
    Write-Host "4. Consider creating new snapshots for ongoing backup needs" -ForegroundColor White

    Write-Host "`n✅ Snapshot deletion operation completed!" -ForegroundColor Green

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
