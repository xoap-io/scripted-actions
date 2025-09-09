<#
.SYNOPSIS
    Modify EBS volume properties using AWS CLI.

.DESCRIPTION
    This script modifies EBS volume properties such as size, volume type, and IOPS
    using the latest AWS CLI (v2.16+). Supports monitoring of modification progress.

.PARAMETER VolumeId
    The ID of the EBS volume to modify.

.PARAMETER Size
    New size for the volume in GiB (can only increase).

.PARAMETER VolumeType
    New volume type (gp2, gp3, io1, io2, st1, sc1).

.PARAMETER Iops
    Provisioned IOPS for io1, io2, or gp3 volumes.

.PARAMETER Throughput
    Throughput in MB/s for gp3 volumes (125-1000).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER AwsProfile
    The AWS CLI profile to use (optional).

.PARAMETER WaitForCompletion
    Wait for the modification to complete.

.PARAMETER TimeoutMinutes
    Maximum time to wait for completion in minutes (default: 60).

.PARAMETER Force
    Skip confirmation prompts.

.EXAMPLE
    .\aws-cli-modify-volume.ps1 -VolumeId "vol-1234567890abcdef0" -Size 100

.EXAMPLE
    .\aws-cli-modify-volume.ps1 -VolumeId "vol-1234567890abcdef0" -VolumeType "gp3" -WaitForCompletion

.EXAMPLE
    .\aws-cli-modify-volume.ps1 -VolumeId "vol-1234567890abcdef0" -VolumeType "gp3" -Iops 3000 -Throughput 250

.NOTES
    Requires AWS CLI v2.16+ and appropriate IAM permissions for EC2 operations.
    Volume size can only be increased, not decreased.
    Modifications may take time to complete and can affect performance.

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^vol-[a-f0-9]{8,17}$')]
    [string]$VolumeId,

    [Parameter()]
    [ValidateRange(1, 65536)]
    [int]$Size,

    [Parameter()]
    [ValidateSet("gp2", "gp3", "io1", "io2", "st1", "sc1")]
    [string]$VolumeType,

    [Parameter()]
    [ValidateRange(100, 64000)]
    [int]$Iops,

    [Parameter()]
    [ValidateRange(125, 1000)]
    [int]$Throughput,

    [Parameter()]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d{1}$')]
    [string]$Region,

    [Parameter()]
    [string]$AwsProfile,

    [Parameter()]
    [switch]$WaitForCompletion,

    [Parameter()]
    [ValidateRange(1, 1440)]
    [int]$TimeoutMinutes = 60,

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Check AWS CLI availability
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    Write-Host "Starting EBS volume modification process..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @()
    if ($Region) {
        $awsArgs += '--region', $Region
    }
    if ($AwsProfile) {
        $awsArgs += '--profile', $AwsProfile
    }

    # Get current volume information
    Write-Host "Getting current volume information..." -ForegroundColor Cyan
    $volumeResult = aws ec2 describe-volumes --volume-ids $VolumeId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe volume: $volumeResult"
    }

    $volumeData = $volumeResult | ConvertFrom-Json
    $volume = $volumeData.Volumes[0]

    Write-Host "Current Volume Configuration:" -ForegroundColor Cyan
    Write-Host "  Volume ID: $($volume.VolumeId)" -ForegroundColor White
    Write-Host "  Current Size: $($volume.Size) GiB" -ForegroundColor White
    Write-Host "  Current Type: $($volume.VolumeType)" -ForegroundColor White
    Write-Host "  Current State: $($volume.State)" -ForegroundColor White
    
    if ($volume.Iops) {
        Write-Host "  Current IOPS: $($volume.Iops)" -ForegroundColor White
    }
    if ($volume.Throughput) {
        Write-Host "  Current Throughput: $($volume.Throughput) MB/s" -ForegroundColor White
    }

    # Validate current state
    if ($volume.State -notin @('available', 'in-use')) {
        throw "Volume must be in 'available' or 'in-use' state for modification. Current state: $($volume.State)"
    }

    # Check for existing modifications
    $modResult = aws ec2 describe-volumes-modifications --volume-ids $VolumeId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        $modData = $modResult | ConvertFrom-Json
        $activeMods = $modData.VolumesModifications | Where-Object { $_.ModificationState -in @('modifying', 'optimizing') }
        
        if ($activeMods.Count -gt 0) {
            Write-Warning "Volume has active modifications in progress:"
            foreach ($mod in $activeMods) {
                Write-Host "  State: $($mod.ModificationState)" -ForegroundColor Yellow
                Write-Host "  Start Time: $($mod.StartTime)" -ForegroundColor Yellow
                Write-Host "  Progress: $($mod.Progress)%" -ForegroundColor Yellow
            }
            
            if (-not $Force) {
                $confirm = Read-Host "Continue with new modification? (y/N)"
                if ($confirm -notmatch '^[Yy]') {
                    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                    exit 0
                }
            }
        }
    }

    # Validate parameters
    $changes = @()
    
    if ($Size) {
        if ($Size -le $volume.Size) {
            throw "New size ($Size GiB) must be larger than current size ($($volume.Size) GiB)"
        }
        $changes += "Size: $($volume.Size) → $Size GiB"
    }

    if ($VolumeType) {
        if ($VolumeType -ne $volume.VolumeType) {
            $changes += "Type: $($volume.VolumeType) → $VolumeType"
        }
    }

    if ($Iops) {
        $currentIops = if ($volume.Iops) { $volume.Iops } else { "default" }
        $changes += "IOPS: $currentIops → $Iops"
        
        # Validate IOPS for volume type
        $targetType = if ($VolumeType) { $VolumeType } else { $volume.VolumeType }
        if ($targetType -notin @('gp3', 'io1', 'io2')) {
            throw "IOPS can only be specified for gp3, io1, or io2 volume types"
        }
    }

    if ($Throughput) {
        $currentThroughput = if ($volume.Throughput) { $volume.Throughput } else { "default" }
        $changes += "Throughput: $currentThroughput → $Throughput MB/s"
        
        # Validate throughput for volume type
        $targetType = if ($VolumeType) { $VolumeType } else { $volume.VolumeType }
        if ($targetType -ne 'gp3') {
            throw "Throughput can only be specified for gp3 volume types"
        }
    }

    if ($changes.Count -eq 0) {
        Write-Host "No changes specified. Nothing to modify." -ForegroundColor Yellow
        exit 0
    }

    # Display planned changes
    Write-Host "`nPlanned Changes:" -ForegroundColor Cyan
    foreach ($change in $changes) {
        Write-Host "  $change" -ForegroundColor Yellow
    }

    # Confirmation unless Force is specified
    if (-not $Force) {
        Write-Host "`n⚠️  Volume modifications can take time and may affect performance" -ForegroundColor Yellow
        $confirm = Read-Host "Proceed with modification? (y/N)"
        if ($confirm -notmatch '^[Yy]') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Build modify-volume command
    $modifyArgs = @('ec2', 'modify-volume', '--volume-id', $VolumeId)
    $modifyArgs += $awsArgs
    $modifyArgs += '--output', 'json'

    if ($Size) {
        $modifyArgs += '--size', $Size.ToString()
    }

    if ($VolumeType) {
        $modifyArgs += '--volume-type', $VolumeType
    }

    if ($Iops) {
        $modifyArgs += '--iops', $Iops.ToString()
    }

    if ($Throughput) {
        $modifyArgs += '--throughput', $Throughput.ToString()
    }

    # Execute modification
    Write-Host "Executing volume modification..." -ForegroundColor Cyan
    $modifyResult = aws @modifyArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to modify volume: $modifyResult"
    }

    $modifyData = $modifyResult | ConvertFrom-Json
    $modification = $modifyData.VolumeModification

    Write-Host "✓ Volume modification initiated successfully" -ForegroundColor Green
    Write-Host "Modification ID: $($modification.ModificationState)" -ForegroundColor Cyan
    Write-Host "Start Time: $($modification.StartTime)" -ForegroundColor Cyan

    if ($WaitForCompletion) {
        Write-Host "Waiting for modification to complete..." -ForegroundColor Yellow
        Write-Host "This may take several minutes depending on the volume size and type." -ForegroundColor Gray
        
        $timeout = $TimeoutMinutes * 60
        $elapsed = 0
        $checkInterval = 30

        do {
            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval

            $statusResult = aws ec2 describe-volumes-modifications --volume-ids $VolumeId @awsArgs --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $statusData = $statusResult | ConvertFrom-Json
                $currentMod = $statusData.VolumesModifications | Sort-Object StartTime -Descending | Select-Object -First 1
                
                $state = $currentMod.ModificationState
                $progress = if ($currentMod.Progress) { $currentMod.Progress } else { 0 }
                
                Write-Host "State: $state - Progress: $progress% (${elapsed}s elapsed)" -ForegroundColor Gray
                
                if ($state -eq 'completed') {
                    Write-Host "✓ Volume modification completed successfully!" -ForegroundColor Green
                    
                    # Get updated volume info
                    $updatedResult = aws ec2 describe-volumes --volume-ids $VolumeId @awsArgs --output json 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $updatedData = $updatedResult | ConvertFrom-Json
                        $updatedVolume = $updatedData.Volumes[0]
                        
                        Write-Host "Updated Volume Configuration:" -ForegroundColor Cyan
                        Write-Host "  Size: $($updatedVolume.Size) GiB" -ForegroundColor White
                        Write-Host "  Type: $($updatedVolume.VolumeType)" -ForegroundColor White
                        if ($updatedVolume.Iops) {
                            Write-Host "  IOPS: $($updatedVolume.Iops)" -ForegroundColor White
                        }
                        if ($updatedVolume.Throughput) {
                            Write-Host "  Throughput: $($updatedVolume.Throughput) MB/s" -ForegroundColor White
                        }
                    }
                    break
                }
                elseif ($state -eq 'failed') {
                    Write-Warning "Volume modification failed"
                    Write-Host "Status: $($currentMod.StatusMessage)" -ForegroundColor Red
                    break
                }
            }

            if ($elapsed -ge $timeout) {
                Write-Warning "Timeout waiting for modification completion after ${TimeoutMinutes} minutes"
                Write-Host "Modification may still be in progress." -ForegroundColor Yellow
                Write-Host "Check status with: aws ec2 describe-volumes-modifications --volume-ids $VolumeId" -ForegroundColor Gray
                break
            }
        } while ($true)
    }

    Write-Host "`n📝 Important Notes:" -ForegroundColor Cyan
    Write-Host "1. Volume modifications may take time to complete" -ForegroundColor White
    Write-Host "2. Performance may be affected during modification" -ForegroundColor White
    Write-Host "3. For filesystem size increase, extend the filesystem after modification" -ForegroundColor White
    Write-Host "4. Monitor volume performance after modification completes" -ForegroundColor White

    Write-Host "`n✅ Volume modification operation completed!" -ForegroundColor Green

} catch {
    Write-Error "Failed to modify volume: $($_.Exception.Message)"
    exit 1
}
