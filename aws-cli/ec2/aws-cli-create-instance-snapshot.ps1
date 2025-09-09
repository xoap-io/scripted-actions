<#
.SYNOPSIS
    Create EBS snapshots from EC2 instance volumes using AWS CLI.

.DESCRIPTION
    This script creates EBS snapshots of all volumes attached to EC2 instances with
    proper naming conventions, tagging, and support for application-consistent snapshots.

.PARAMETER InstanceId
    The ID of the EC2 instance to create snapshots from (for single instance).

.PARAMETER InstanceIds
    Comma-separated list of instance IDs (for bulk operations).

.PARAMETER VolumeId
    Specific volume ID to snapshot (optional - if not specified, snapshots all attached volumes).

.PARAMETER Description
    Description for the snapshots (will be auto-generated if not provided).

.PARAMETER Tags
    JSON string of tags to apply to the snapshots.

.PARAMETER NoReboot
    Create snapshots without stopping the instance (may affect consistency).

.PARAMETER ApplicationConsistent
    Use AWS Systems Manager to create application-consistent snapshots (requires SSM agent).

.PARAMETER RetentionDays
    Number of days to retain snapshots (adds DeleteOn tag for automation).

.PARAMETER WaitForCompletion
    Wait for snapshot creation to complete.

.PARAMETER MaxWaitTime
    Maximum time to wait for completion in seconds (default: 300).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-create-instance-snapshot.ps1 -InstanceId "i-1234567890abcdef0"

.EXAMPLE
    .\aws-cli-create-instance-snapshot.ps1 -InstanceId "i-1234567890abcdef0" -Description "Weekly backup" -RetentionDays 7

.EXAMPLE
    .\aws-cli-create-instance-snapshot.ps1 -InstanceIds "i-123,i-456" -ApplicationConsistent -WaitForCompletion

.EXAMPLE
    .\aws-cli-create-instance-snapshot.ps1 -InstanceId "i-1234567890abcdef0" -VolumeId "vol-12345678" -NoReboot

.NOTES
    Author: XOAP
    Date: 2025-08-06
    Version: 1.0
    Requires: AWS CLI v2.16+

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $false)]
    [string]$InstanceIds,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^vol-[a-zA-Z0-9]{8,}$')]
    [string]$VolumeId,

    [Parameter(Mandatory = $false)]
    [string]$Description,

    [Parameter(Mandatory = $false)]
    [string]$Tags,

    [Parameter(Mandatory = $false)]
    [switch]$NoReboot,

    [Parameter(Mandatory = $false)]
    [switch]$ApplicationConsistent,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 365)]
    [int]$RetentionDays,

    [Parameter(Mandatory = $false)]
    [switch]$WaitForCompletion,

    [Parameter(Mandatory = $false)]
    [ValidateRange(60, 3600)]
    [int]$MaxWaitTime = 300,

    [Parameter(Mandatory = $false)]
    [string]$Region,

    [Parameter(Mandatory = $false)]
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

    # Determine target instances
    $targetInstances = @()
    if ($InstanceId) {
        $targetInstances += $InstanceId
    }
    if ($InstanceIds) {
        $targetInstances += $InstanceIds -split ',' | ForEach-Object { $_.Trim() }
    }

    if ($targetInstances.Count -eq 0) {
        throw "Either InstanceId or InstanceIds must be specified."
    }

    Write-Output "Creating snapshots for instances: $($targetInstances -join ', ')"

    # Track all snapshots created
    $createdSnapshots = @()

    foreach ($instanceId in $targetInstances) {
        Write-Output "`n" + "=" * 60
        Write-Output "Processing instance: $instanceId"

        # Get instance information
        $instanceResult = aws ec2 describe-instances --instance-ids $instanceId @awsArgs --output json 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Instance $instanceId not found or not accessible: $instanceResult"
            continue
        }

        $instanceData = $instanceResult | ConvertFrom-Json
        $instance = $instanceData.Reservations[0].Instances[0]
        
        # Get instance name
        $instanceName = $instanceId
        if ($instance.Tags) {
            $nameTag = $instance.Tags | Where-Object { $_.Key -eq 'Name' } | Select-Object -First 1
            if ($nameTag) {
                $instanceName = $nameTag.Value
            }
        }

        Write-Output "Instance name: $instanceName"
        Write-Output "Instance state: $($instance.State.Name)"
        Write-Output "Instance type: $($instance.InstanceType)"

        # Determine volumes to snapshot
        $volumesToSnapshot = @()
        
        if ($VolumeId) {
            # Verify the specific volume is attached to this instance
            $attachedVolume = $instance.BlockDeviceMappings | Where-Object { $_.Ebs.VolumeId -eq $VolumeId }
            if ($attachedVolume) {
                $volumesToSnapshot += @{
                    VolumeId = $VolumeId
                    DeviceName = $attachedVolume.DeviceName
                    DeleteOnTermination = $attachedVolume.Ebs.DeleteOnTermination
                }
            } else {
                Write-Warning "Volume $VolumeId is not attached to instance $instanceId"
                continue
            }
        } else {
            # Get all attached volumes
            foreach ($mapping in $instance.BlockDeviceMappings) {
                if ($mapping.Ebs) {
                    $volumesToSnapshot += @{
                        VolumeId = $mapping.Ebs.VolumeId
                        DeviceName = $mapping.DeviceName
                        DeleteOnTermination = $mapping.Ebs.DeleteOnTermination
                    }
                }
            }
        }

        Write-Output "Volumes to snapshot: $($volumesToSnapshot.Count)"
        foreach ($vol in $volumesToSnapshot) {
            Write-Output "  - $($vol.VolumeId) ($($vol.DeviceName))"
        }

        # Handle application-consistent snapshots
        if ($ApplicationConsistent) {
            Write-Output "`n📋 Creating application-consistent snapshots using SSM..."
            
            # Use SSM to create snapshots with application consistency
            $ssmDocumentName = "AWS-CreateSnapshot"
            $ssmParameters = @{
                InstanceId = @($instanceId)
                CreateImage = @("False")
                NoReboot = @($NoReboot.ToString())
            }

            $ssmParamsJson = $ssmParameters | ConvertTo-Json -Depth 3 -Compress
            
            $ssmResult = aws ssm send-command --document-name $ssmDocumentName --instance-ids $instanceId --parameters $ssmParamsJson @awsArgs --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $ssmData = $ssmResult | ConvertFrom-Json
                Write-Output "✅ SSM command sent successfully: $($ssmData.Command.CommandId)"
                Write-Output "Monitor the command execution in SSM for snapshot creation status."
            } else {
                Write-Warning "Failed to send SSM command for application-consistent snapshot: $ssmResult"
                Write-Output "Falling back to standard snapshot creation..."
                $ApplicationConsistent = $false
            }
        }

        # Create standard snapshots if not using application-consistent method
        if (-not $ApplicationConsistent) {
            # Stop instance if not using NoReboot and instance is running
            $instanceStopped = $false
            if (-not $NoReboot -and $instance.State.Name -eq 'running') {
                Write-Output "`n⏸️  Stopping instance for consistent snapshot..."
                $stopResult = aws ec2 stop-instances --instance-ids $instanceId @awsArgs 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    # Wait for instance to stop
                    Write-Output "Waiting for instance to stop..."
                    $maxStopWait = 300
                    $stopWait = 0
                    
                    do {
                        Start-Sleep -Seconds 10
                        $stopWait += 10
                        
                        $statusResult = aws ec2 describe-instances --instance-ids $instanceId @awsArgs --query 'Reservations[0].Instances[0].State.Name' --output text 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $currentState = $statusResult.Trim()
                            Write-Output "Instance state: $currentState"
                            
                            if ($currentState -eq 'stopped') {
                                $instanceStopped = $true
                                break
                            }
                        }
                    } while ($stopWait -lt $maxStopWait)
                    
                    if (-not $instanceStopped) {
                        Write-Warning "Instance did not stop within $maxStopWait seconds. Proceeding with snapshot creation anyway."
                    }
                } else {
                    Write-Warning "Failed to stop instance: $stopResult"
                }
            }

            # Create snapshots for each volume
            foreach ($volume in $volumesToSnapshot) {
                $volumeId = $volume.VolumeId
                $deviceName = $volume.DeviceName
                
                Write-Output "`n📸 Creating snapshot for volume: $volumeId ($deviceName)"

                # Generate snapshot description
                $snapshotDescription = $Description
                if (-not $snapshotDescription) {
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
                    $snapshotDescription = "Snapshot of $volumeId ($deviceName) from instance $instanceName ($instanceId) created on $timestamp"
                }

                # Create the snapshot
                $snapshotResult = aws ec2 create-snapshot --volume-id $volumeId --description $snapshotDescription @awsArgs --output json 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $snapshotData = $snapshotResult | ConvertFrom-Json
                    $snapshotId = $snapshotData.SnapshotId
                    
                    Write-Output "✅ Snapshot created: $snapshotId"
                    Write-Output "Volume: $volumeId"
                    Write-Output "Progress: $($snapshotData.Progress)"
                    Write-Output "State: $($snapshotData.State)"

                    $createdSnapshots += @{
                        SnapshotId = $snapshotId
                        VolumeId = $volumeId
                        InstanceId = $instanceId
                        DeviceName = $deviceName
                    }

                    # Apply tags to snapshot
                    $snapshotTags = @()
                    
                    # Default tags
                    $snapshotTags += @{Key = "Name"; Value = "$instanceName-$deviceName-$(Get-Date -Format 'yyyyMMdd-HHmm')"}
                    $snapshotTags += @{Key = "SourceInstance"; Value = $instanceId}
                    $snapshotTags += @{Key = "SourceVolume"; Value = $volumeId}
                    $snapshotTags += @{Key = "Device"; Value = $deviceName}
                    $snapshotTags += @{Key = "CreatedBy"; Value = "aws-cli-create-instance-snapshot"}
                    
                    # Add retention tag if specified
                    if ($RetentionDays) {
                        $deleteDate = (Get-Date).AddDays($RetentionDays).ToString("yyyy-MM-dd")
                        $snapshotTags += @{Key = "DeleteOn"; Value = $deleteDate}
                    }

                    # Add custom tags if provided
                    if ($Tags) {
                        try {
                            $customTags = $Tags | ConvertFrom-Json
                            $snapshotTags += $customTags
                        } catch {
                            Write-Warning "Invalid JSON format for tags: $($_.Exception.Message)"
                        }
                    }

                    # Apply the tags
                    $tagsJson = $snapshotTags | ConvertTo-Json -Depth 3 -Compress
                    $tagResult = aws ec2 create-tags --resources $snapshotId --tags $tagsJson @awsArgs 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Output "✅ Tags applied to snapshot"
                    } else {
                        Write-Warning "Failed to apply tags to snapshot: $tagResult"
                    }

                } else {
                    Write-Warning "Failed to create snapshot for volume $volumeId : $snapshotResult"
                }
            }

            # Restart instance if it was stopped
            if ($instanceStopped) {
                Write-Output "`n▶️  Starting instance back up..."
                $startResult = aws ec2 start-instances --instance-ids $instanceId @awsArgs 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Output "✅ Instance start initiated"
                } else {
                    Write-Warning "Failed to start instance: $startResult"
                }
            }
        }
    }

    # Wait for completion if requested
    if ($WaitForCompletion -and $createdSnapshots.Count -gt 0) {
        Write-Output "`n⏳ Monitoring snapshot completion..."
        
        $waitTime = 0
        $checkInterval = 30
        
        do {
            Start-Sleep -Seconds $checkInterval
            $waitTime += $checkInterval
            
            $completedSnapshots = 0
            $totalSnapshots = $createdSnapshots.Count
            
            foreach ($snapshot in $createdSnapshots) {
                $statusResult = aws ec2 describe-snapshots --snapshot-ids $snapshot.SnapshotId @awsArgs --query 'Snapshots[0].State' --output text 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $state = $statusResult.Trim()
                    if ($state -eq 'completed') {
                        $completedSnapshots++
                    }
                }
            }
            
            $progressPercent = [math]::Round(($completedSnapshots / $totalSnapshots) * 100, 1)
            Write-Output "[$([math]::Round($waitTime/60, 1)) min] Progress: $completedSnapshots/$totalSnapshots ($progressPercent%) snapshots completed"
            
            if ($completedSnapshots -eq $totalSnapshots) {
                break
            }
            
        } while ($waitTime -lt $MaxWaitTime)
        
        if ($waitTime -ge $MaxWaitTime) {
            Write-Warning "Snapshot monitoring timed out after $($MaxWaitTime/60) minutes."
        }
    }

    # Final summary
    Write-Output "`n" + "=" * 60
    Write-Output "📊 Snapshot Creation Summary:"
    Write-Output "Instances processed: $($targetInstances.Count)"
    Write-Output "Snapshots created: $($createdSnapshots.Count)"

    if ($createdSnapshots.Count -gt 0) {
        Write-Output "`n📋 Created Snapshots:"
        foreach ($snapshot in $createdSnapshots) {
            Write-Output "  • $($snapshot.SnapshotId) - $($snapshot.VolumeId) ($($snapshot.DeviceName)) from $($snapshot.InstanceId)"
        }
        
        if ($RetentionDays) {
            Write-Output "`n🗓️  Retention: Snapshots will be marked for deletion after $RetentionDays days"
        }
    }

    Write-Output "`n✅ Snapshot creation process completed."

} catch {
    Write-Error "Failed to create instance snapshots: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
