<#
.SYNOPSIS
    Create AMI (Amazon Machine Image) from an existing EC2 instance using AWS CLI.

.DESCRIPTION
    This script creates a custom AMI from an existing EC2 instance with proper tagging,
    naming conventions, and optional no-reboot functionality for consistent backups.

.PARAMETER InstanceId
    The ID of the EC2 instance to create AMI from.

.PARAMETER Name
    The name for the AMI (will be auto-generated if not provided).

.PARAMETER Description
    Description for the AMI (optional).

.PARAMETER NoReboot
    Create AMI without rebooting the instance (may affect file system consistency).

.PARAMETER Tags
    JSON string of tags to apply to the AMI (optional).

.PARAMETER BlockDeviceMappings
    JSON string of block device mappings (optional).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-create-ami-from-instance.ps1 -InstanceId "i-1234567890abcdef0" -Name "MyApp-Backup-20250806"

.EXAMPLE
    .\aws-cli-create-ami-from-instance.ps1 -InstanceId "i-1234567890abcdef0" -NoReboot -Description "Production backup"

.EXAMPLE
    .\aws-cli-create-ami-from-instance.ps1 -InstanceId "i-1234567890abcdef0" -Tags '[{"Key":"Environment","Value":"Production"},{"Key":"Purpose","Value":"Backup"}]'

.NOTES
    Author: XOAP
    Date: 2025-08-06

    Requires: AWS CLI v2.16+

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $false)]
    [ValidateLength(3, 128)]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [string]$Description,

    [Parameter(Mandatory = $false)]
    [switch]$NoReboot,

    [Parameter(Mandatory = $false)]
    [string]$Tags,

    [Parameter(Mandatory = $false)]
    [string]$BlockDeviceMappings,

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

    Write-Output "Creating AMI from instance: $InstanceId"

    # Get instance information
    Write-Output "Retrieving instance information..."
    $instanceResult = aws ec2 describe-instances --instance-ids $InstanceId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe instance: $instanceResult"
    }

    $instanceData = $instanceResult | ConvertFrom-Json
    $instance = $instanceData.Reservations[0].Instances[0]

    Write-Output "Instance details:"
    Write-Output "  State: $($instance.State.Name)"
    Write-Output "  Instance Type: $($instance.InstanceType)"
    Write-Output "  Platform: $(if ($instance.Platform) { $instance.Platform } else { 'Linux/Unix' })"
    Write-Output "  Architecture: $($instance.Architecture)"

    # Get instance name from tags if available
    $instanceName = "Unknown"
    if ($instance.Tags) {
        $nameTag = $instance.Tags | Where-Object { $_.Key -eq 'Name' } | Select-Object -First 1
        if ($nameTag) {
            $instanceName = $nameTag.Value
        }
    }
    Write-Output "  Name: $instanceName"

    # Generate AMI name if not provided
    if (-not $Name) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
        $Name = "$instanceName-AMI-$timestamp"
        Write-Output "Auto-generated AMI name: $Name"
    }

    # Generate description if not provided
    if (-not $Description) {
        $Description = "AMI created from instance $InstanceId ($instanceName) on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    }

    # Warn about reboot implications
    if ($NoReboot) {
        Write-Warning "No-reboot option selected. This may result in an inconsistent file system state."
        Write-Output "Consider stopping applications and syncing file systems before creating AMI."
    } else {
        Write-Output "Instance will be rebooted during AMI creation to ensure file system consistency."

        if ($instance.State.Name -eq 'running') {
            Write-Output "⚠️  The running instance will be temporarily rebooted."
        }
    }

    # Build create-image command
    $createImageArgs = @(
        'ec2', 'create-image',
        '--instance-id', $InstanceId,
        '--name', $Name,
        '--description', $Description
    )

    $createImageArgs += $awsArgs

    if ($NoReboot) {
        $createImageArgs += @('--no-reboot')
    }

    if ($BlockDeviceMappings) {
        $createImageArgs += @('--block-device-mappings', $BlockDeviceMappings)
    }

    $createImageArgs += @('--output', 'json')

    # Create the AMI
    Write-Output "`nCreating AMI..."
    Write-Output "AMI Name: $Name"
    Write-Output "Description: $Description"

    $result = & aws @createImageArgs 2>&1

    if ($LASTEXITCODE -eq 0) {
        $amiData = $result | ConvertFrom-Json
        $amiId = $amiData.ImageId

        Write-Output "✅ AMI creation initiated successfully!"
        Write-Output "AMI ID: $amiId"
        Write-Output "AMI Name: $Name"

        # Apply tags if provided
        if ($Tags) {
            Write-Output "`nApplying tags to AMI..."

            try {
                # Validate JSON format
                $null = $Tags | ConvertFrom-Json

                $tagArgs = @('ec2', 'create-tags', '--resources', $amiId, '--tags', $Tags)
                $tagArgs += $awsArgs

                $tagResult = & aws @tagArgs 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Output "✅ Tags applied successfully"
                } else {
                    Write-Warning "Failed to apply tags: $tagResult"
                }
            } catch {
                Write-Warning "Invalid JSON format for tags: $($_.Exception.Message)"
            }
        }

        # Monitor AMI creation progress
        Write-Output "`n📊 Monitoring AMI creation progress..."
        Write-Output "This may take several minutes depending on instance size and EBS volume configuration."

        $maxWaitTime = 1800  # 30 minutes
        $waitTime = 0
        $checkInterval = 30  # Check every 30 seconds

        do {
            Start-Sleep -Seconds $checkInterval
            $waitTime += $checkInterval

            $statusResult = aws ec2 describe-images --image-ids $amiId @awsArgs --output json 2>&1

            if ($LASTEXITCODE -eq 0) {
                $statusData = $statusResult | ConvertFrom-Json
                $ami = $statusData.Images[0]
                $state = $ami.State

                Write-Output "[$([math]::Round($waitTime/60, 1)) min] AMI State: $state"

                if ($state -eq 'available') {
                    Write-Output "✅ AMI creation completed successfully!"
                    Write-Output "`n📋 AMI Details:"
                    Write-Output "  AMI ID: $amiId"
                    Write-Output "  Name: $($ami.Name)"
                    Write-Output "  State: $($ami.State)"
                    Write-Output "  Architecture: $($ami.Architecture)"
                    Write-Output "  Root Device Type: $($ami.RootDeviceType)"
                    Write-Output "  Virtualization Type: $($ami.VirtualizationType)"
                    Write-Output "  Creation Date: $($ami.CreationDate)"

                    if ($ami.BlockDeviceMappings) {
                        Write-Output "  Block Device Mappings:"
                        foreach ($mapping in $ami.BlockDeviceMappings) {
                            if ($mapping.Ebs) {
                                Write-Output "    Device: $($mapping.DeviceName) -> Volume: $($mapping.Ebs.VolumeSize)GB ($($mapping.Ebs.VolumeType))"
                            }
                        }
                    }

                    break
                } elseif ($state -eq 'failed') {
                    throw "AMI creation failed. Check AWS console for details."
                } elseif ($state -eq 'error') {
                    throw "AMI creation encountered an error. Check AWS console for details."
                }
            } else {
                Write-Warning "Failed to check AMI status: $statusResult"
            }

        } while ($waitTime -lt $maxWaitTime)

        if ($waitTime -ge $maxWaitTime) {
            Write-Warning "AMI creation is taking longer than expected ($($maxWaitTime/60) minutes)."
            Write-Output "AMI ID: $amiId"
            Write-Output "You can check the status manually using: aws ec2 describe-images --image-ids $amiId"
        }

    } else {
        throw "Failed to create AMI: $result"
    }

} catch {
    Write-Error "Failed to create AMI from instance: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
