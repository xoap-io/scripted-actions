<#
.SYNOPSIS
    Detach an EBS volume from an EC2 instance using AWS CLI.

.DESCRIPTION
    This script detaches an EBS volume from an EC2 instance using the latest AWS CLI (v2.16+).
    It validates the volume attachment state and provides options for forced detachment.

.PARAMETER VolumeId
    The ID of the EBS volume to detach.

.PARAMETER InstanceId
    The ID of the EC2 instance (optional, for validation).

.PARAMETER Device
    The device name (optional, for validation).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER AwsProfile
    The AWS CLI profile to use (optional).

.PARAMETER Force
    Force detachment even if the volume is in use.

.PARAMETER WaitForDetachment
    Wait for the volume detachment to complete.

.EXAMPLE
    .\aws-cli-detach-volume.ps1 -VolumeId "vol-1234567890abcdef0"

.EXAMPLE
    .\aws-cli-detach-volume.ps1 -VolumeId "vol-1234567890abcdef0" -InstanceId "i-1234567890abcdef0" -Force

.EXAMPLE
    .\aws-cli-detach-volume.ps1 -VolumeId "vol-1234567890abcdef0" -WaitForDetachment -Region "us-west-2"

.NOTES
    Requires AWS CLI v2.16+ and appropriate IAM permissions for EC2 operations.
    Use Force parameter with caution as it may cause data loss.

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^vol-[a-f0-9]{8,17}$')]
    [string]$VolumeId,

    [Parameter()]
    [ValidatePattern('^i-[a-f0-9]{8,17}$')]
    [string]$InstanceId,

    [Parameter()]
    [ValidatePattern('^/dev/[a-zA-Z0-9]+$')]
    [string]$Device,

    [Parameter()]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d{1}$')]
    [string]$Region,

    [Parameter()]
    [string]$AwsProfile,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$WaitForDetachment
)

$ErrorActionPreference = 'Stop'

# Check AWS CLI availability
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    Write-Host "Starting EBS volume detachment process..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @()
    if ($Region) {
        $awsArgs += '--region', $Region
    }
    if ($AwsProfile) {
        $awsArgs += '--profile', $AwsProfile
    }

    # Get current volume state and attachment info
    Write-Host "Validating EBS volume..." -ForegroundColor Cyan
    $volumeResult = aws ec2 describe-volumes --volume-ids $VolumeId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe volume: $volumeResult"
    }

    $volumeData = $volumeResult | ConvertFrom-Json
    $volume = $volumeData.Volumes[0]
    $volumeState = $volume.State

    Write-Host "Volume $VolumeId is in state: $volumeState" -ForegroundColor Yellow

    if ($volumeState -ne 'in-use') {
        if ($volumeState -eq 'available') {
            Write-Host "Volume is already detached (available state)" -ForegroundColor Yellow
            exit 0
        }
        throw "Volume is not in a state that can be detached. Current state: $volumeState"
    }

    # Get attachment information
    if ($volume.Attachments.Count -eq 0) {
        Write-Host "Volume has no active attachments" -ForegroundColor Yellow
        exit 0
    }

    $attachment = $volume.Attachments[0]
    $attachedInstanceId = $attachment.InstanceId
    $attachedDevice = $attachment.Device
    $attachmentState = $attachment.State

    Write-Host "Volume attachment details:" -ForegroundColor Cyan
    Write-Host "  Instance: $attachedInstanceId" -ForegroundColor White
    Write-Host "  Device: $attachedDevice" -ForegroundColor White
    Write-Host "  State: $attachmentState" -ForegroundColor White

    # Validate provided parameters match attachment
    if ($InstanceId -and ($InstanceId -ne $attachedInstanceId)) {
        throw "Volume is attached to instance $attachedInstanceId, not $InstanceId"
    }

    if ($Device -and ($Device -ne $attachedDevice)) {
        throw "Volume is attached to device $attachedDevice, not $Device"
    }

    # Check instance state if we can
    try {
        $instanceResult = aws ec2 describe-instances --instance-ids $attachedInstanceId @awsArgs --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $instanceData = $instanceResult | ConvertFrom-Json
            $instance = $instanceData.Reservations[0].Instances[0]
            $instanceState = $instance.State.Name
            Write-Host "Instance $attachedInstanceId is in state: $instanceState" -ForegroundColor Yellow

            if ($instanceState -eq 'running' -and -not $Force) {
                Write-Warning "Instance is running. Detaching volumes from running instances may cause data loss."
                $confirm = Read-Host "Continue with detachment? (y/N)"
                if ($confirm -notmatch '^[Yy]') {
                    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                    exit 0
                }
            }
        }
    } catch {
        Write-Warning "Could not check instance state: $($_.Exception.Message)"
    }

    # Build detach command
    $detachArgs = @('ec2', 'detach-volume', '--volume-id', $VolumeId)
    $detachArgs += $awsArgs
    $detachArgs += '--output', 'json'

    if ($Force) {
        $detachArgs += '--force'
        Write-Host "⚠️  Using force detachment" -ForegroundColor Yellow
    }

    # Perform the detachment
    Write-Host "Detaching volume $VolumeId from instance $attachedInstanceId..." -ForegroundColor Cyan
    $detachResult = aws @detachArgs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to detach volume: $detachResult"
    }

    $detachData = $detachResult | ConvertFrom-Json
    Write-Host "✓ Volume detachment initiated successfully" -ForegroundColor Green
    Write-Host "Volume ID: $($detachData.VolumeId)" -ForegroundColor Cyan
    Write-Host "Instance ID: $($detachData.InstanceId)" -ForegroundColor Cyan
    Write-Host "State: $($detachData.State)" -ForegroundColor Cyan

    if ($WaitForDetachment) {
        Write-Host "Waiting for detachment to complete..." -ForegroundColor Yellow
        
        $timeout = 300 # 5 minutes
        $elapsed = 0
        $checkInterval = 10

        do {
            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval

            $statusResult = aws ec2 describe-volumes --volume-ids $VolumeId @awsArgs --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $statusData = $statusResult | ConvertFrom-Json
                $currentVolume = $statusData.Volumes[0]
                $currentState = $currentVolume.State
                
                Write-Host "Volume state: $currentState (${elapsed}s elapsed)" -ForegroundColor Gray
                
                if ($currentState -eq 'available') {
                    Write-Host "✓ Volume successfully detached!" -ForegroundColor Green
                    break
                }
                elseif ($currentVolume.Attachments.Count -gt 0) {
                    $attachmentState = $currentVolume.Attachments[0].State
                    if ($attachmentState -eq 'detaching') {
                        # Continue waiting
                        continue
                    }
                    else {
                        Write-Warning "Unexpected attachment state: $attachmentState"
                        break
                    }
                }
            }

            if ($elapsed -ge $timeout) {
                Write-Warning "Timeout waiting for detachment to complete after ${timeout}s"
                Write-Host "You can check the detachment status manually with:" -ForegroundColor Yellow
                Write-Host "aws ec2 describe-volumes --volume-ids $VolumeId" -ForegroundColor Gray
                break
            }
        } while ($true)
    }

    Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. The volume is now available for attachment to other instances" -ForegroundColor White
    Write-Host "2. Data on the volume is preserved and will be available when reattached" -ForegroundColor White
    Write-Host "3. You may want to create a snapshot for backup purposes" -ForegroundColor White

    Write-Host "`n✅ Volume detachment operation completed successfully!" -ForegroundColor Green

} catch {
    Write-Error "Failed to detach volume: $($_.Exception.Message)"
    exit 1
}
