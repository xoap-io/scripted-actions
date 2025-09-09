<#
.SYNOPSIS
    Attach an EBS volume to an EC2 instance using AWS CLI.

.DESCRIPTION
    This script attaches an EBS volume to an EC2 instance using the latest AWS CLI (v2.16+).
    It validates that both the instance and volume exist and are in the correct state before attachment.

.PARAMETER InstanceId
    The ID of the EC2 instance to attach the volume to.

.PARAMETER VolumeId
    The ID of the EBS volume to attach.

.PARAMETER Device
    The device name for the volume attachment (e.g., /dev/sdf, /dev/xvdf).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.PARAMETER WaitForAttachment
    Wait for the volume attachment to complete.

.PARAMETER Force
    Skip confirmation prompts.

.EXAMPLE
    .\aws-cli-attach-volume.ps1 -InstanceId "i-1234567890abcdef0" -VolumeId "vol-1234567890abcdef0" -Device "/dev/sdf"

.EXAMPLE
    .\aws-cli-attach-volume.ps1 -InstanceId "i-1234567890abcdef0" -VolumeId "vol-1234567890abcdef0" -Device "/dev/xvdf" -WaitForAttachment

.EXAMPLE
    .\aws-cli-attach-volume.ps1 -InstanceId "i-1234567890abcdef0" -VolumeId "vol-1234567890abcdef0" -Device "/dev/sdf" -Region "us-west-2" -Profile "myprofile"

.NOTES
    Requires AWS CLI v2.16+ and appropriate IAM permissions for EC2 operations.

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-f0-9]{8,17}$')]
    [string]$InstanceId,

    [Parameter(Mandatory)]
    [ValidatePattern('^vol-[a-f0-9]{8,17}$')]
    [string]$VolumeId,

    [Parameter(Mandatory)]
    [ValidatePattern('^/dev/[a-zA-Z0-9]+$')]
    [string]$Device,

    [Parameter()]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d{1}$')]
    [string]$Region,

    [Parameter()]
    [string]$Profile,

    [Parameter()]
    [switch]$WaitForAttachment,

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
    Write-Host "Starting EBS volume attachment process..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @()
    if ($Region) {
        $awsArgs += '--region', $Region
    }
    if ($Profile) {
        $awsArgs += '--profile', $Profile
    }

    # Validate instance exists and get its state
    Write-Host "Validating EC2 instance..." -ForegroundColor Cyan
    $instanceResult = aws ec2 describe-instances --instance-ids $InstanceId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe instance: $instanceResult"
    }

    $instanceData = $instanceResult | ConvertFrom-Json
    $instance = $instanceData.Reservations[0].Instances[0]
    $instanceState = $instance.State.Name

    Write-Host "Instance $InstanceId is in state: $instanceState" -ForegroundColor Yellow

    if ($instanceState -notin @('running', 'stopped')) {
        if (-not $Force) {
            $confirm = Read-Host "Instance is in state '$instanceState'. Continue anyway? (y/N)"
            if ($confirm -notmatch '^[Yy]') {
                Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                exit 0
            }
        }
    }

    # Validate volume exists and get its state
    Write-Host "Validating EBS volume..." -ForegroundColor Cyan
    $volumeResult = aws ec2 describe-volumes --volume-ids $VolumeId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe volume: $volumeResult"
    }

    $volumeData = $volumeResult | ConvertFrom-Json
    $volume = $volumeData.Volumes[0]
    $volumeState = $volume.State

    Write-Host "Volume $VolumeId is in state: $volumeState" -ForegroundColor Yellow

    if ($volumeState -ne 'available') {
        if ($volumeState -eq 'in-use') {
            $attachedInstance = $volume.Attachments[0].InstanceId
            throw "Volume is already attached to instance: $attachedInstance"
        }
        throw "Volume is not available for attachment. Current state: $volumeState"
    }

    # Check if device is already in use
    $existingDevices = $instance.BlockDeviceMappings | ForEach-Object { $_.DeviceName }
    if ($Device -in $existingDevices) {
        throw "Device $Device is already in use on instance $InstanceId"
    }

    # Perform the attachment
    Write-Host "Attaching volume $VolumeId to instance $InstanceId on device $Device..." -ForegroundColor Cyan
    $attachResult = aws ec2 attach-volume --volume-id $VolumeId --instance-id $InstanceId --device $Device @awsArgs --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to attach volume: $attachResult"
    }

    $attachData = $attachResult | ConvertFrom-Json
    Write-Host "✓ Volume attachment initiated successfully" -ForegroundColor Green
    Write-Host "Attachment ID: $($attachData.VolumeId)" -ForegroundColor Cyan
    Write-Host "State: $($attachData.State)" -ForegroundColor Cyan

    if ($WaitForAttachment) {
        Write-Host "Waiting for attachment to complete..." -ForegroundColor Yellow
        
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
                
                if ($currentVolume.Attachments.Count -gt 0) {
                    $attachmentState = $currentVolume.Attachments[0].State
                    Write-Host "Attachment state: $attachmentState (${elapsed}s elapsed)" -ForegroundColor Gray
                    
                    if ($attachmentState -eq 'attached') {
                        Write-Host "✓ Volume successfully attached!" -ForegroundColor Green
                        Write-Host "Device: $($currentVolume.Attachments[0].Device)" -ForegroundColor Cyan
                        Write-Host "Attach Time: $($currentVolume.Attachments[0].AttachTime)" -ForegroundColor Cyan
                        break
                    }
                    elseif ($attachmentState -eq 'attaching') {
                        # Continue waiting
                        continue
                    }
                    else {
                        Write-Warning "Attachment failed with state: $attachmentState"
                        break
                    }
                }
            }

            if ($elapsed -ge $timeout) {
                Write-Warning "Timeout waiting for attachment to complete after ${timeout}s"
                Write-Host "You can check the attachment status manually with:" -ForegroundColor Yellow
                Write-Host "aws ec2 describe-volumes --volume-ids $VolumeId" -ForegroundColor Gray
                break
            }
        } while ($true)
    }

    Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. The volume may need to be formatted if it's new" -ForegroundColor White
    Write-Host "2. Mount the volume in the operating system" -ForegroundColor White
    Write-Host "3. For Linux: Use 'lsblk' to see the attached device" -ForegroundColor White
    Write-Host "4. For Windows: Use Disk Management to initialize and format" -ForegroundColor White

    Write-Host "`n✅ Volume attachment operation completed successfully!" -ForegroundColor Green

} catch {
    Write-Error "Failed to attach volume: $($_.Exception.Message)"
    exit 1
}
