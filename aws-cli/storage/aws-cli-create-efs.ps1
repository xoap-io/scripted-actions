<#
.SYNOPSIS
    Create an Amazon EFS (Elastic File System) using AWS CLI.

.DESCRIPTION
    This script creates an EFS file system using the latest AWS CLI (v2.16+).
    Supports encryption, performance mode configuration, and automatic mount target creation.

.PARAMETER CreationToken
    Unique string to identify the request (auto-generated if not provided).

.PARAMETER PerformanceMode
    Performance mode: generalPurpose or maxIO (default: generalPurpose).

.PARAMETER ThroughputMode
    Throughput mode: bursting or provisioned (default: bursting).

.PARAMETER ProvisionedThroughputInMibps
    Provisioned throughput in MiB/s (required when ThroughputMode is provisioned).

.PARAMETER Encrypted
    Enable encryption at rest.

.PARAMETER KmsKeyId
    KMS key ID for encryption (uses default if not specified).

.PARAMETER VpcId
    VPC ID where mount targets will be created.

.PARAMETER SubnetIds
    Comma-separated list of subnet IDs for mount targets.

.PARAMETER SecurityGroupIds
    Comma-separated list of security group IDs for mount targets.

.PARAMETER Tags
    JSON string of tags to apply to the file system.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER AwsProfile
    The AWS CLI profile to use (optional).

.PARAMETER WaitForAvailable
    Wait for the file system to become available.

.PARAMETER TimeoutMinutes
    Maximum time to wait for availability in minutes (default: 10).

.EXAMPLE
    .\aws-cli-create-efs.ps1 -VpcId "vpc-12345678" -SubnetIds "subnet-12345678,subnet-87654321"

.EXAMPLE
    .\aws-cli-create-efs.ps1 -VpcId "vpc-12345678" -SubnetIds "subnet-12345678" -Encrypted -PerformanceMode "maxIO"

.EXAMPLE
    .\aws-cli-create-efs.ps1 -VpcId "vpc-12345678" -SubnetIds "subnet-12345678" -ThroughputMode "provisioned" -ProvisionedThroughputInMibps 500

.NOTES
    Requires AWS CLI v2.16+ and appropriate IAM permissions for EFS operations.

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$CreationToken,

    [Parameter()]
    [ValidateSet("generalPurpose", "maxIO")]
    [string]$PerformanceMode = "generalPurpose",

    [Parameter()]
    [ValidateSet("bursting", "provisioned")]
    [string]$ThroughputMode = "bursting",

    [Parameter()]
    [ValidateRange(1, 1024)]
    [double]$ProvisionedThroughputInMibps,

    [Parameter()]
    [switch]$Encrypted,

    [Parameter()]
    [string]$KmsKeyId,

    [Parameter(Mandatory)]
    [ValidatePattern('^vpc-[a-f0-9]{8,17}$')]
    [string]$VpcId,

    [Parameter(Mandatory)]
    [string]$SubnetIds,

    [Parameter()]
    [string]$SecurityGroupIds,

    [Parameter()]
    [string]$Tags,

    [Parameter()]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d{1}$')]
    [string]$Region,

    [Parameter()]
    [string]$AwsProfile,

    [Parameter()]
    [switch]$WaitForAvailable,

    [Parameter()]
    [ValidateRange(1, 60)]
    [int]$TimeoutMinutes = 10
)

$ErrorActionPreference = 'Stop'

# Check AWS CLI availability
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    Write-Host "Starting EFS file system creation..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @()
    if ($Region) {
        $awsArgs += '--region', $Region
    }
    if ($AwsProfile) {
        $awsArgs += '--profile', $AwsProfile
    }

    # Generate creation token if not provided
    if (-not $CreationToken) {
        $CreationToken = "efs-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$((New-Guid).ToString().Substring(0,8))"
    }

    # Validate throughput mode parameters
    if ($ThroughputMode -eq "provisioned" -and -not $ProvisionedThroughputInMibps) {
        throw "ProvisionedThroughputInMibps is required when ThroughputMode is 'provisioned'"
    }

    if ($ThroughputMode -eq "bursting" -and $ProvisionedThroughputInMibps) {
        throw "ProvisionedThroughputInMibps cannot be specified when ThroughputMode is 'bursting'"
    }

    # Validate VPC exists
    Write-Host "Validating VPC..." -ForegroundColor Cyan
    $vpcResult = aws ec2 describe-vpcs --vpc-ids $VpcId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "VPC not found or not accessible: $VpcId"
    }

    $vpcData = $vpcResult | ConvertFrom-Json
    $vpc = $vpcData.Vpcs[0]
    Write-Host "VPC found: $($vpc.VpcId) ($($vpc.CidrBlock))" -ForegroundColor Yellow

    # Validate subnets
    Write-Host "Validating subnets..." -ForegroundColor Cyan
    $subnetIdList = $SubnetIds -split ','
    $subnetResult = aws ec2 describe-subnets --subnet-ids $subnetIdList @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "One or more subnets not found: $SubnetIds"
    }

    $subnetData = $subnetResult | ConvertFrom-Json
    $subnets = $subnetData.Subnets

    Write-Host "Subnets validated:" -ForegroundColor Yellow
    foreach ($subnet in $subnets) {
        Write-Host "  $($subnet.SubnetId) - AZ: $($subnet.AvailabilityZone) - CIDR: $($subnet.CidrBlock)" -ForegroundColor Gray
    }

    # Display configuration
    Write-Host "EFS Configuration:" -ForegroundColor Cyan
    Write-Host "  Creation Token: $CreationToken" -ForegroundColor White
    Write-Host "  Performance Mode: $PerformanceMode" -ForegroundColor White
    Write-Host "  Throughput Mode: $ThroughputMode" -ForegroundColor White
    if ($ProvisionedThroughputInMibps) {
        Write-Host "  Provisioned Throughput: $ProvisionedThroughputInMibps MiB/s" -ForegroundColor White
    }
    Write-Host "  Encrypted: $Encrypted" -ForegroundColor White
    if ($KmsKeyId) {
        Write-Host "  KMS Key: $KmsKeyId" -ForegroundColor White
    }

    # Build create-file-system command
    $createArgs = @('efs', 'create-file-system', '--creation-token', $CreationToken)
    $createArgs += '--performance-mode', $PerformanceMode
    $createArgs += '--throughput-mode', $ThroughputMode
    $createArgs += $awsArgs
    $createArgs += '--output', 'json'

    if ($ProvisionedThroughputInMibps) {
        $createArgs += '--provisioned-throughput-in-mibps', $ProvisionedThroughputInMibps.ToString()
    }

    if ($Encrypted) {
        $createArgs += '--encrypted'
        if ($KmsKeyId) {
            $createArgs += '--kms-key-id', $KmsKeyId
        }
    }

    # Create the file system
    Write-Host "Creating EFS file system..." -ForegroundColor Cyan
    $efsResult = aws @createArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create EFS file system: $efsResult"
    }

    $efsData = $efsResult | ConvertFrom-Json
    $fileSystemId = $efsData.FileSystemId

    Write-Host "✓ EFS file system created successfully" -ForegroundColor Green
    Write-Host "File System ID: $fileSystemId" -ForegroundColor Cyan
    Write-Host "State: $($efsData.LifeCycleState)" -ForegroundColor Cyan

    # Apply tags if provided
    if ($Tags) {
        try {
            Write-Host "Applying tags to file system..." -ForegroundColor Cyan
            $tagsData = $Tags | ConvertFrom-Json
            $tagSpecs = @()

            foreach ($key in $tagsData.PSObject.Properties.Name) {
                $tagSpecs += @{
                    Key = $key
                    Value = $tagsData.$key
                }
            }

            $tagJson = $tagSpecs | ConvertTo-Json -Compress
            $tagResult = aws efs tag-resource --resource-id $fileSystemId --tags $tagJson @awsArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ Tags applied successfully" -ForegroundColor Green
            } else {
                Write-Warning "Failed to apply tags: $tagResult"
            }
        } catch {
            Write-Warning "Failed to parse or apply tags: $($_.Exception.Message)"
        }
    }

    # Wait for file system to be available before creating mount targets
    if ($WaitForAvailable -or $subnetIdList.Count -gt 0) {
        Write-Host "Waiting for file system to become available..." -ForegroundColor Yellow

        $timeout = $TimeoutMinutes * 60
        $elapsed = 0
        $checkInterval = 10

        do {
            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval

            $statusResult = aws efs describe-file-systems --file-system-id $fileSystemId @awsArgs --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $statusData = $statusResult | ConvertFrom-Json
                $currentEfs = $statusData.FileSystems[0]
                $state = $currentEfs.LifeCycleState

                Write-Host "File system state: $state (${elapsed}s elapsed)" -ForegroundColor Gray

                if ($state -eq 'available') {
                    Write-Host "✓ File system is now available" -ForegroundColor Green
                    break
                }
                elseif ($state -eq 'error') {
                    throw "File system creation failed"
                }
            }

            if ($elapsed -ge $timeout) {
                Write-Warning "Timeout waiting for file system to become available after ${TimeoutMinutes} minutes"
                break
            }
        } while ($true)
    }

    # Create mount targets
    if ($subnetIdList.Count -gt 0) {
        Write-Host "Creating mount targets..." -ForegroundColor Cyan

        $mountTargets = @()
        foreach ($subnetId in $subnetIdList) {
            try {
                $mountArgs = @('efs', 'create-mount-target', '--file-system-id', $fileSystemId, '--subnet-id', $subnetId.Trim())
                $mountArgs += $awsArgs
                $mountArgs += '--output', 'json'

                if ($SecurityGroupIds) {
                    $sgList = $SecurityGroupIds -split ','
                    $mountArgs += '--security-groups'
                    $mountArgs += $sgList
                }

                Write-Host "  Creating mount target in subnet $subnetId..." -ForegroundColor Gray
                $mountResult = aws @mountArgs 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $mountData = $mountResult | ConvertFrom-Json
                    $mountTargets += $mountData
                    Write-Host "    ✓ Mount target created: $($mountData.MountTargetId)" -ForegroundColor Green
                } else {
                    Write-Warning "    Failed to create mount target in $subnetId : $mountResult"
                }
            } catch {
                Write-Warning "    Error creating mount target in $subnetId : $($_.Exception.Message)"
            }
        }

        if ($mountTargets.Count -gt 0) {
            Write-Host "✓ Created $($mountTargets.Count) mount target(s)" -ForegroundColor Green
        }
    }

    # Get final file system information
    Write-Host "Getting final file system details..." -ForegroundColor Cyan
    $finalResult = aws efs describe-file-systems --file-system-id $fileSystemId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        $finalData = $finalResult | ConvertFrom-Json
        $finalEfs = $finalData.FileSystems[0]

        Write-Host "`nEFS File System Details:" -ForegroundColor Cyan
        Write-Host "  File System ID: $($finalEfs.FileSystemId)" -ForegroundColor White
        Write-Host "  DNS Name: $($finalEfs.FileSystemId).efs.$Region.amazonaws.com" -ForegroundColor White
        Write-Host "  State: $($finalEfs.LifeCycleState)" -ForegroundColor White
        Write-Host "  Performance Mode: $($finalEfs.PerformanceMode)" -ForegroundColor White
        Write-Host "  Throughput Mode: $($finalEfs.ThroughputMode)" -ForegroundColor White
        if ($finalEfs.ProvisionedThroughputInMibps) {
            Write-Host "  Provisioned Throughput: $($finalEfs.ProvisionedThroughputInMibps) MiB/s" -ForegroundColor White
        }
        Write-Host "  Encrypted: $($finalEfs.Encrypted)" -ForegroundColor White
        Write-Host "  Number of Mount Targets: $($finalEfs.NumberOfMountTargets)" -ForegroundColor White
    }

    Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Configure security groups to allow NFS traffic (port 2049)" -ForegroundColor White
    Write-Host "2. Mount the file system on EC2 instances using:" -ForegroundColor White
    Write-Host "   sudo mount -t efs ${fileSystemId}:/ /mnt/efs" -ForegroundColor Gray
    Write-Host "3. Consider setting up automatic mounting via /etc/fstab" -ForegroundColor White
    Write-Host "4. Install the EFS utilities for improved performance and features" -ForegroundColor White

    Write-Host "`n✅ EFS file system creation completed!" -ForegroundColor Green
    Write-Host "File System ID: $fileSystemId" -ForegroundColor Cyan

} catch {
    Write-Error "Failed to create EFS file system: $($_.Exception.Message)"
    exit 1
}
