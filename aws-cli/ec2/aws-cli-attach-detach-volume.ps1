<#
.SYNOPSIS
    Attach or detach EBS volumes to/from EC2 instances using AWS CLI.

.DESCRIPTION
    This script provides functionality to attach EBS volumes to EC2 instances or detach them.
    Supports multiple volumes and includes validation of volume availability and instance state.

.PARAMETER Action
    The action to perform: Attach or Detach.

.PARAMETER InstanceId
    The ID of the EC2 instance.

.PARAMETER VolumeId
    The ID of the EBS volume (required for single volume operations).

.PARAMETER VolumeIds
    Comma-separated list of EBS volume IDs (for bulk operations).

.PARAMETER Device
    The device name for attaching the volume (e.g., /dev/sdf, /dev/xvdf).

.PARAMETER Force
    Force detachment even if the volume is in use (use with caution).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-attach-detach-volume.ps1 -Action Attach -InstanceId "i-1234567890abcdef0" -VolumeId "vol-1234567890abcdef0" -Device "/dev/sdf"

.EXAMPLE
    .\aws-cli-attach-detach-volume.ps1 -Action Detach -InstanceId "i-1234567890abcdef0" -VolumeId "vol-1234567890abcdef0"

.EXAMPLE
    .\aws-cli-attach-detach-volume.ps1 -Action Detach -InstanceId "i-1234567890abcdef0" -VolumeIds "vol-123,vol-456" -Force

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/attach-volume.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The action to perform: Attach or Detach.")]
    [ValidateSet('Attach', 'Detach')]
    [string]$Action,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the EC2 instance.")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $false, HelpMessage = "The ID of the EBS volume (required for single volume operations).")]
    [ValidatePattern('^vol-[a-zA-Z0-9]{8,}$')]
    [string]$VolumeId,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of EBS volume IDs (for bulk operations).")]
    [string]$VolumeIds,

    [Parameter(Mandatory = $false, HelpMessage = "The device name for attaching the volume (e.g., /dev/sdf, /dev/xvdf).")]
    [ValidatePattern('^/dev/[a-z]+[0-9]*$')]
    [string]$Device,

    [Parameter(Mandatory = $false, HelpMessage = "Force detachment even if the volume is in use (use with caution).")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region to use (optional, uses default if not specified).")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS CLI profile to use (optional).")]
    [string]$Profile
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    # Build base AWS CLI arguments
    $awsArgs = @()
    if ($Region) { $awsArgs += @('--region', $Region) }
    if ($Profile) { $awsArgs += @('--profile', $Profile) }

    # Determine volume list
    $volumes = @()
    if ($VolumeId) {
        $volumes += $VolumeId
    }
    if ($VolumeIds) {
        $volumes += $VolumeIds -split ',' | ForEach-Object { $_.Trim() }
    }

    if ($volumes.Count -eq 0) {
        throw "Either VolumeId or VolumeIds must be specified."
    }

    # Validate device parameter for attach operation
    if ($Action -eq 'Attach' -and $volumes.Count -eq 1 -and -not $Device) {
        throw "Device parameter is required when attaching a single volume."
    }
    if ($Action -eq 'Attach' -and $volumes.Count -gt 1 -and $Device) {
        throw "Device parameter cannot be used with multiple volumes. Use VolumeId for single volume operations."
    }

    Write-Output "$Action operation for volumes: $($volumes -join ', ')"

    # Verify instance exists
    Write-Output "Verifying instance: $InstanceId"
    $instanceResult = aws ec2 describe-instances --instance-ids $InstanceId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe instance: $instanceResult"
    }

    $instanceData = $instanceResult | ConvertFrom-Json
    $instance = $instanceData.Reservations[0].Instances[0]
    Write-Output "Instance state: $($instance.State.Name)"

    foreach ($volume in $volumes) {
        Write-Output "`nProcessing volume: $volume"

        # Get volume information
        $volumeResult = aws ec2 describe-volumes --volume-ids $volume @awsArgs --output json 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to describe volume $volume : $volumeResult"
            continue
        }

        $volumeData = $volumeResult | ConvertFrom-Json
        $volumeInfo = $volumeData.Volumes[0]

        Write-Output "Volume state: $($volumeInfo.State)"
        Write-Output "Volume size: $($volumeInfo.Size) GB"
        Write-Output "Volume type: $($volumeInfo.VolumeType)"

        if ($Action -eq 'Attach') {
            # Check if volume is available
            if ($volumeInfo.State -ne 'available') {
                Write-Warning "Volume $volume is not in 'available' state. Current state: $($volumeInfo.State)"
                continue
            }

            # For multiple volumes, suggest device names
            $deviceName = $Device
            if ($volumes.Count -gt 1) {
                # Auto-suggest device names
                $existingDevices = @()
                foreach ($attachment in $instance.BlockDeviceMappings) {
                    $existingDevices += $attachment.DeviceName
                }

                # Generate available device name
                $deviceLetters = 'fghijklmnopqrstuvwxyz'
                foreach ($letter in $deviceLetters.ToCharArray()) {
                    $suggestedDevice = "/dev/sd$letter"
                    if ($suggestedDevice -notin $existingDevices) {
                        $deviceName = $suggestedDevice
                        break
                    }
                }

                if (-not $deviceName) {
                    Write-Warning "Could not find available device name for volume $volume"
                    continue
                }
            }

            Write-Output "Attaching volume $volume to device $deviceName"
            $attachResult = aws ec2 attach-volume --volume-id $volume --instance-id $InstanceId --device $deviceName @awsArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Output "✅ Successfully initiated attachment of volume $volume to device $deviceName"

                # Wait for attachment to complete
                Write-Output "Waiting for attachment to complete..."
                $maxWait = 60
                $waited = 0

                do {
                    Start-Sleep -Seconds 5
                    $waited += 5

                    $checkResult = aws ec2 describe-volumes --volume-ids $volume @awsArgs --output json 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $checkData = $checkResult | ConvertFrom-Json
                        $checkVolume = $checkData.Volumes[0]

                        if ($checkVolume.Attachments -and $checkVolume.Attachments[0].State -eq 'attached') {
                            Write-Output "✅ Volume $volume successfully attached"
                            break
                        }

                        Write-Output "Attachment state: $($checkVolume.Attachments[0].State)"
                    }
                } while ($waited -lt $maxWait)

                if ($waited -ge $maxWait) {
                    Write-Warning "Attachment of volume $volume may still be in progress after $maxWait seconds"
                }

            } else {
                Write-Warning "Failed to attach volume $volume : $attachResult"
            }

        } elseif ($Action -eq 'Detach') {
            # Check if volume is attached to this instance
            $attachedToInstance = $false
            $attachmentState = 'unknown'

            if ($volumeInfo.Attachments) {
                foreach ($attachment in $volumeInfo.Attachments) {
                    if ($attachment.InstanceId -eq $InstanceId) {
                        $attachedToInstance = $true
                        $attachmentState = $attachment.State
                        $deviceName = $attachment.Device
                        break
                    }
                }
            }

            if (-not $attachedToInstance) {
                Write-Warning "Volume $volume is not attached to instance $InstanceId"
                continue
            }

            Write-Output "Current attachment state: $attachmentState"
            Write-Output "Attached device: $deviceName"

            # Build detach command
            $detachArgs = @('ec2', 'detach-volume', '--volume-id', $volume)
            $detachArgs += $awsArgs

            if ($Force) {
                $detachArgs += @('--force')
                Write-Output "⚠️  Force detach enabled - this may cause data loss!"
            }

            Write-Output "Detaching volume $volume"
            $detachResult = & aws @detachArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Output "✅ Successfully initiated detachment of volume $volume"

                # Wait for detachment to complete
                Write-Output "Waiting for detachment to complete..."
                $maxWait = 60
                $waited = 0

                do {
                    Start-Sleep -Seconds 5
                    $waited += 5

                    $checkResult = aws ec2 describe-volumes --volume-ids $volume @awsArgs --output json 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $checkData = $checkResult | ConvertFrom-Json
                        $checkVolume = $checkData.Volumes[0]

                        if ($checkVolume.State -eq 'available') {
                            Write-Output "✅ Volume $volume successfully detached and is now available"
                            break
                        }

                        if ($checkVolume.Attachments) {
                            Write-Output "Detachment state: $($checkVolume.Attachments[0].State)"
                        }
                    }
                } while ($waited -lt $maxWait)

                if ($waited -ge $maxWait) {
                    Write-Warning "Detachment of volume $volume may still be in progress after $maxWait seconds"
                }

            } else {
                Write-Warning "Failed to detach volume $volume : $detachResult"
            }
        }
    }

    Write-Output "`n✅ Volume $Action operation completed."

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
