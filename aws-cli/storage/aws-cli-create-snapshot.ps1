<#
.SYNOPSIS
    Create a snapshot of an EBS volume using AWS CLI.

.DESCRIPTION
    This script creates a snapshot of an EBS volume using the latest AWS CLI (v2.16+).
    It supports tagging, encryption, and progress monitoring.

.PARAMETER VolumeId
    The ID of the EBS volume to snapshot.

.PARAMETER Description
    Description for the snapshot (auto-generated if not provided).

.PARAMETER Tags
    JSON string of tags to apply to the snapshot.

.PARAMETER OutpostArn
    The ARN of the Outpost on which to create the snapshot.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER AwsProfile
    The AWS CLI profile to use (optional).

.PARAMETER WaitForCompletion
    Wait for the snapshot creation to complete.

.PARAMETER TimeoutMinutes
    Maximum time to wait for completion in minutes (default: 60).

.EXAMPLE
    .\aws-cli-create-snapshot.ps1 -VolumeId "vol-1234567890abcdef0"

.EXAMPLE
    .\aws-cli-create-snapshot.ps1 -VolumeId "vol-1234567890abcdef0" -Description "Backup before upgrade" -WaitForCompletion

.EXAMPLE
    .\aws-cli-create-snapshot.ps1 -VolumeId "vol-1234567890abcdef0" -Tags '{"Environment":"Production","Backup":"Daily"}'

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/create-snapshot.html

.COMPONENT
    AWS CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the EBS volume to snapshot")]
    [ValidatePattern('^vol-[a-f0-9]{8,17}$')]
    [string]$VolumeId,

    [Parameter(Mandatory = $false, HelpMessage = "Description for the snapshot (auto-generated if not provided)")]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "JSON string of tags to apply to the snapshot")]
    [string]$Tags,

    [Parameter(Mandatory = $false, HelpMessage = "The ARN of the Outpost on which to create the snapshot")]
    [string]$OutpostArn,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region to use")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d{1}$')]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS CLI profile to use")]
    [string]$AwsProfile,

    [Parameter(Mandatory = $false, HelpMessage = "Wait for the snapshot creation to complete")]
    [switch]$WaitForCompletion,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum time to wait for completion in minutes (default: 60)")]
    [ValidateRange(1, 1440)]
    [int]$TimeoutMinutes = 60
)

$ErrorActionPreference = 'Stop'

# Check AWS CLI availability
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    Write-Host "Starting EBS snapshot creation process..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @()
    if ($Region) {
        $awsArgs += '--region', $Region
    }
    if ($AwsProfile) {
        $awsArgs += '--profile', $AwsProfile
    }

    # Validate volume exists and get its information
    Write-Host "Validating EBS volume..." -ForegroundColor Cyan
    $volumeResult = aws ec2 describe-volumes --volume-ids $VolumeId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe volume: $volumeResult"
    }

    $volumeData = $volumeResult | ConvertFrom-Json
    $volume = $volumeData.Volumes[0]

    Write-Host "Volume Information:" -ForegroundColor Cyan
    Write-Host "  Volume ID: $($volume.VolumeId)" -ForegroundColor White
    Write-Host "  Size: $($volume.Size) GiB" -ForegroundColor White
    Write-Host "  Type: $($volume.VolumeType)" -ForegroundColor White
    Write-Host "  State: $($volume.State)" -ForegroundColor White
    Write-Host "  Availability Zone: $($volume.AvailabilityZone)" -ForegroundColor White

    if ($volume.Attachments.Count -gt 0) {
        Write-Host "  Attached to: $($volume.Attachments[0].InstanceId)" -ForegroundColor White
        Write-Host "  Device: $($volume.Attachments[0].Device)" -ForegroundColor White
    }

    # Generate description if not provided
    if (-not $Description) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
        $Description = "Snapshot of $VolumeId created on $timestamp"
    }

    Write-Host "Snapshot description: $Description" -ForegroundColor Yellow

    # Build create-snapshot command
    $createArgs = @('ec2', 'create-snapshot', '--volume-id', $VolumeId, '--description', $Description)
    $createArgs += $awsArgs
    $createArgs += '--output', 'json'

    if ($OutpostArn) {
        $createArgs += '--outpost-arn', $OutpostArn
    }

    # Create the snapshot
    Write-Host "Creating snapshot for volume $VolumeId..." -ForegroundColor Cyan
    $snapshotResult = aws @createArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create snapshot: $snapshotResult"
    }

    $snapshotData = $snapshotResult | ConvertFrom-Json
    $snapshotId = $snapshotData.SnapshotId

    Write-Host "✓ Snapshot creation initiated successfully" -ForegroundColor Green
    Write-Host "Snapshot ID: $snapshotId" -ForegroundColor Cyan
    Write-Host "State: $($snapshotData.State)" -ForegroundColor Cyan
    Write-Host "Start Time: $($snapshotData.StartTime)" -ForegroundColor Cyan

    # Apply tags if provided
    if ($Tags) {
        try {
            Write-Host "Applying tags to snapshot..." -ForegroundColor Cyan
            $tagsData = $Tags | ConvertFrom-Json
            $tagSpecs = @()

            foreach ($key in $tagsData.PSObject.Properties.Name) {
                $tagSpecs += "Key=$key,Value=$($tagsData.$key)"
            }

            $tagString = $tagSpecs -join ' '
            $tagResult = aws ec2 create-tags --resources $snapshotId --tags $tagString @awsArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ Tags applied successfully" -ForegroundColor Green
            } else {
                Write-Warning "Failed to apply tags: $tagResult"
            }
        } catch {
            Write-Warning "Failed to parse or apply tags: $($_.Exception.Message)"
        }
    }

    if ($WaitForCompletion) {
        Write-Host "Waiting for snapshot creation to complete..." -ForegroundColor Yellow
        Write-Host "This may take several minutes to hours depending on volume size and data changes." -ForegroundColor Gray

        $timeout = $TimeoutMinutes * 60
        $elapsed = 0
        $checkInterval = 30
        $lastProgress = -1

        do {
            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval

            $statusResult = aws ec2 describe-snapshots --snapshot-ids $snapshotId @awsArgs --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $statusData = $statusResult | ConvertFrom-Json
                $currentSnapshot = $statusData.Snapshots[0]
                $state = $currentSnapshot.State
                $progress = if ($currentSnapshot.Progress) { $currentSnapshot.Progress } else { "0%" }

                # Only show progress updates when progress changes
                $progressInt = [int]($progress -replace '%', '')
                if ($progressInt -ne $lastProgress) {
                    $lastProgress = $progressInt
                    Write-Host "Progress: $progress - State: $state (${elapsed}s elapsed)" -ForegroundColor Gray
                }

                if ($state -eq 'completed') {
                    Write-Host "✓ Snapshot creation completed successfully!" -ForegroundColor Green
                    Write-Host "Final Details:" -ForegroundColor Cyan
                    Write-Host "  Snapshot ID: $($currentSnapshot.SnapshotId)" -ForegroundColor White
                    Write-Host "  Volume ID: $($currentSnapshot.VolumeId)" -ForegroundColor White
                    Write-Host "  Volume Size: $($currentSnapshot.VolumeSize) GiB" -ForegroundColor White
                    Write-Host "  Start Time: $($currentSnapshot.StartTime)" -ForegroundColor White
                    Write-Host "  Completion Time: $(Get-Date)" -ForegroundColor White
                    Write-Host "  Encrypted: $($currentSnapshot.Encrypted)" -ForegroundColor White
                    if ($currentSnapshot.KmsKeyId) {
                        Write-Host "  KMS Key: $($currentSnapshot.KmsKeyId)" -ForegroundColor White
                    }
                    break
                }
                elseif ($state -eq 'error') {
                    Write-Warning "Snapshot creation failed with error state"
                    Write-Host "Check the AWS console for more details" -ForegroundColor Yellow
                    break
                }
            }

            if ($elapsed -ge $timeout) {
                Write-Warning "Timeout waiting for snapshot completion after ${TimeoutMinutes} minutes"
                Write-Host "Snapshot creation may still be in progress." -ForegroundColor Yellow
                Write-Host "You can check the status manually with:" -ForegroundColor Yellow
                Write-Host "aws ec2 describe-snapshots --snapshot-ids $snapshotId" -ForegroundColor Gray
                break
            }
        } while ($true)
    }

    Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. The snapshot can be used to create new volumes" -ForegroundColor White
    Write-Host "2. Snapshots are stored in Amazon S3 and are incremental" -ForegroundColor White
    Write-Host "3. Consider creating a lifecycle policy for snapshot management" -ForegroundColor White
    Write-Host "4. Monitor snapshot costs in your AWS billing" -ForegroundColor White

    Write-Host "`n✅ Snapshot creation operation completed!" -ForegroundColor Green
    Write-Host "Snapshot ID: $snapshotId" -ForegroundColor Cyan

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
