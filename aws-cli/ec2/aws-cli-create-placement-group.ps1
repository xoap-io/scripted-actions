<#
.SYNOPSIS
    Create and manage EC2 placement groups using AWS CLI.

.DESCRIPTION
    This script provides comprehensive management of EC2 placement groups including
    creation, deletion, listing, and validation. Supports cluster, partition, and spread strategies.

.PARAMETER PlacementGroupName
    The name of the placement group.

.PARAMETER Strategy
    The placement group strategy (cluster, partition, spread).

.PARAMETER PartitionCount
    Number of partitions (required for partition strategy, 1-7).

.PARAMETER SpreadLevel
    Spread level for spread strategy (host or rack).

.PARAMETER GroupId
    The ID of an existing placement group to operate on.

.PARAMETER Action
    The action to perform: Create, Delete, Describe, or List.

.PARAMETER Tags
    JSON string of tags to apply to the placement group.

.PARAMETER Force
    Force deletion without confirmation.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-create-placement-group.ps1 -PlacementGroupName "my-cluster" -Strategy "cluster" -Action "Create"

.EXAMPLE
    .\aws-cli-create-placement-group.ps1 -PlacementGroupName "my-partitions" -Strategy "partition" -PartitionCount 3 -Action "Create"

.EXAMPLE
    .\aws-cli-create-placement-group.ps1 -PlacementGroupName "my-spread" -Strategy "spread" -SpreadLevel "host" -Action "Create"

.EXAMPLE
    .\aws-cli-create-placement-group.ps1 -Action "List"

.EXAMPLE
    .\aws-cli-create-placement-group.ps1 -PlacementGroupName "my-cluster" -Action "Delete" -Force

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
    [ValidateLength(1, 255)]
    [string]$PlacementGroupName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('cluster', 'partition', 'spread')]
    [string]$Strategy = 'cluster',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 7)]
    [int]$PartitionCount,

    [Parameter(Mandatory = $false)]
    [ValidateSet('host', 'rack')]
    [string]$SpreadLevel = 'host',

    [Parameter(Mandatory = $false)]
    [string]$GroupId,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Create', 'Delete', 'Describe', 'List')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$Tags,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

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

    Write-Output "🔧 Managing EC2 Placement Groups"
    Write-Output "Action: $Action"
    if ($Region) { Write-Output "Region: $Region" }

    switch ($Action) {
        'Create' {
            if (-not $PlacementGroupName) {
                throw "PlacementGroupName is required for Create action."
            }

            Write-Output "`n📋 Creating placement group: $PlacementGroupName"
            Write-Output "Strategy: $Strategy"

            # Build placement group creation arguments
            $createArgs = @(
                'ec2', 'create-placement-group',
                '--group-name', $PlacementGroupName,
                '--strategy', $Strategy
            ) + $awsArgs

            # Add strategy-specific parameters
            switch ($Strategy) {
                'partition' {
                    if (-not $PartitionCount) {
                        throw "PartitionCount is required for partition strategy (1-7)."
                    }
                    $createArgs += @('--partition-count', $PartitionCount.ToString())
                    Write-Output "Partition count: $PartitionCount"
                }
                'spread' {
                    $createArgs += @('--spread-level', $SpreadLevel)
                    Write-Output "Spread level: $SpreadLevel"
                }
            }

            # Create the placement group
            $createResult = aws @createArgs --output json 2>&1

            if ($LASTEXITCODE -eq 0) {
                $placementData = $createResult | ConvertFrom-Json
                Write-Output "✅ Placement group created successfully"
                Write-Output "Group ID: $($placementData.GroupId)"
                Write-Output "State: $($placementData.State)"

                # Apply tags if provided
                if ($Tags) {
                    Write-Output "`n🏷️  Applying tags..."
                    try {
                        $tagsArray = $Tags | ConvertFrom-Json
                        $tagsJson = $tagsArray | ConvertTo-Json -Depth 3 -Compress
                        
                        $tagResult = aws ec2 create-tags --resources $placementData.GroupId --tags $tagsJson @awsArgs 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Output "✅ Tags applied successfully"
                        } else {
                            Write-Warning "Failed to apply tags: $tagResult"
                        }
                    } catch {
                        Write-Warning "Invalid JSON format for tags: $($_.Exception.Message)"
                    }
                }

                # Display the created placement group details
                Write-Output "`n📊 Placement Group Details:"
                $describeResult = aws ec2 describe-placement-groups --group-names $PlacementGroupName @awsArgs --output json 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $pgData = $describeResult | ConvertFrom-Json
                    $pg = $pgData.PlacementGroups[0]
                    
                    Write-Output "Name: $($pg.GroupName)"
                    Write-Output "ID: $($pg.GroupId)"
                    Write-Output "Strategy: $($pg.Strategy)"
                    Write-Output "State: $($pg.State)"
                    
                    if ($pg.PartitionCount) {
                        Write-Output "Partition Count: $($pg.PartitionCount)"
                    }
                    if ($pg.SpreadLevel) {
                        Write-Output "Spread Level: $($pg.SpreadLevel)"
                    }
                    
                    Write-Output "`n💡 Placement Group Usage Tips:"
                    switch ($Strategy) {
                        'cluster' {
                            Write-Output "• Use for high-performance computing workloads requiring low latency"
                            Write-Output "• All instances are placed in the same Availability Zone"
                            Write-Output "• Recommended for applications that benefit from high network performance"
                        }
                        'partition' {
                            Write-Output "• Use for large distributed workloads (HDFS, HBase, Cassandra)"
                            Write-Output "• Each partition has its own set of racks"
                            Write-Output "• Reduces likelihood of correlated hardware failures"
                            Write-Output "• Can span multiple Availability Zones"
                        }
                        'spread' {
                            Write-Output "• Use for applications with small number of critical instances"
                            Write-Output "• Each instance is placed on distinct underlying hardware"
                            Write-Output "• Reduces risk of simultaneous failures"
                            Write-Output "• Limited to 7 instances per AZ per group"
                        }
                    }
                }

            } else {
                Write-Error "Failed to create placement group: $createResult"
            }
        }

        'Delete' {
            if (-not $PlacementGroupName) {
                throw "PlacementGroupName is required for Delete action."
            }

            # Check if placement group exists and get details
            $describeResult = aws ec2 describe-placement-groups --group-names $PlacementGroupName @awsArgs --output json 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Placement group '$PlacementGroupName' not found or not accessible"
                exit 0
            }

            $pgData = $describeResult | ConvertFrom-Json
            $pg = $pgData.PlacementGroups[0]

            Write-Output "`n📋 Placement Group to Delete:"
            Write-Output "Name: $($pg.GroupName)"
            Write-Output "ID: $($pg.GroupId)"
            Write-Output "Strategy: $($pg.Strategy)"
            Write-Output "State: $($pg.State)"

            # Check for instances in the placement group
            $instancesResult = aws ec2 describe-instances --filters "Name=placement-group-name,Values=$PlacementGroupName" @awsArgs --query 'Reservations[].Instances[?State.Name!=`terminated`].[InstanceId,State.Name]' --output text 2>&1
            
            if ($LASTEXITCODE -eq 0 -and $instancesResult.Trim()) {
                $runningInstances = $instancesResult.Trim() -split "`n"
                Write-Warning "⚠️  Placement group contains $($runningInstances.Count) running instances:"
                foreach ($instance in $runningInstances) {
                    Write-Output "  • $instance"
                }
                Write-Output "`n❌ Cannot delete placement group with running instances."
                Write-Output "Please stop or terminate all instances first."
                exit 1
            }

            # Confirmation prompt
            if (-not $Force) {
                Write-Output "`n⚠️  You are about to delete placement group: $PlacementGroupName"
                $confirmation = Read-Host "Are you sure you want to continue? (y/N)"
                
                if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                    Write-Output "❌ Operation cancelled by user."
                    exit 0
                }
            }

            # Delete the placement group
            Write-Output "`n🗑️  Deleting placement group: $PlacementGroupName"
            $deleteResult = aws ec2 delete-placement-group --group-name $PlacementGroupName @awsArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Output "✅ Placement group deleted successfully"
            } else {
                Write-Error "Failed to delete placement group: $deleteResult"
            }
        }

        'Describe' {
            if (-not $PlacementGroupName) {
                throw "PlacementGroupName is required for Describe action."
            }

            Write-Output "`n📋 Describing placement group: $PlacementGroupName"
            
            $describeResult = aws ec2 describe-placement-groups --group-names $PlacementGroupName @awsArgs --output json 2>&1

            if ($LASTEXITCODE -eq 0) {
                $pgData = $describeResult | ConvertFrom-Json
                
                if ($pgData.PlacementGroups.Count -eq 0) {
                    Write-Warning "Placement group '$PlacementGroupName' not found"
                    exit 0
                }

                $pg = $pgData.PlacementGroups[0]
                
                Write-Output "`n📊 Placement Group Details:"
                Write-Output "=" * 50
                Write-Output "Name: $($pg.GroupName)"
                Write-Output "ID: $($pg.GroupId)"
                Write-Output "Strategy: $($pg.Strategy)"
                Write-Output "State: $($pg.State)"
                
                if ($pg.PartitionCount) {
                    Write-Output "Partition Count: $($pg.PartitionCount)"
                }
                if ($pg.SpreadLevel) {
                    Write-Output "Spread Level: $($pg.SpreadLevel)"
                }

                # Get tags
                if ($pg.Tags -and $pg.Tags.Count -gt 0) {
                    Write-Output "`n🏷️  Tags:"
                    foreach ($tag in $pg.Tags) {
                        Write-Output "  • $($tag.Key): $($tag.Value)"
                    }
                }

                # Get instances in this placement group
                $instancesResult = aws ec2 describe-instances --filters "Name=placement-group-name,Values=$PlacementGroupName" @awsArgs --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,AvailabilityZone,Placement.PartitionNumber]' --output text 2>&1
                
                if ($LASTEXITCODE -eq 0 -and $instancesResult.Trim()) {
                    $instances = $instancesResult.Trim() -split "`n"
                    Write-Output "`n🖥️  Instances in Placement Group ($($instances.Count)):"
                    Write-Output "Instance ID`t`tType`t`tState`t`tAZ`t`tPartition"
                    Write-Output "-" * 80
                    foreach ($instance in $instances) {
                        $instanceParts = $instance -split "`t"
                        $partitionInfo = if ($instanceParts[4] -and $instanceParts[4] -ne "None") { $instanceParts[4] } else { "N/A" }
                        Write-Output "$($instanceParts[0])`t$($instanceParts[1])`t$($instanceParts[2])`t$($instanceParts[3])`t$partitionInfo"
                    }
                } else {
                    Write-Output "`n🖥️  No instances found in this placement group"
                }

            } else {
                Write-Error "Failed to describe placement group: $describeResult"
            }
        }

        'List' {
            Write-Output "`n📋 Listing all placement groups..."
            
            $listResult = aws ec2 describe-placement-groups @awsArgs --output json 2>&1

            if ($LASTEXITCODE -eq 0) {
                $pgData = $listResult | ConvertFrom-Json
                
                if ($pgData.PlacementGroups.Count -eq 0) {
                    Write-Output "No placement groups found in this region"
                    exit 0
                }

                Write-Output "`n📊 Placement Groups ($($pgData.PlacementGroups.Count)):"
                Write-Output "=" * 80
                Write-Output "Name`t`t`tStrategy`t`tState`t`tPartitions`tSpread Level"
                Write-Output "-" * 80

                foreach ($pg in $pgData.PlacementGroups) {
                    $partitionInfo = if ($pg.PartitionCount) { $pg.PartitionCount } else { "N/A" }
                    $spreadInfo = if ($pg.SpreadLevel) { $pg.SpreadLevel } else { "N/A" }
                    
                    Write-Output "$($pg.GroupName.PadRight(20))`t$($pg.Strategy.PadRight(10))`t$($pg.State.PadRight(10))`t$partitionInfo`t`t$spreadInfo"
                }

                # Summary by strategy
                $strategyGroups = $pgData.PlacementGroups | Group-Object Strategy
                Write-Output "`n📈 Summary by Strategy:"
                foreach ($group in $strategyGroups) {
                    Write-Output "  • $($group.Name): $($group.Count) placement groups"
                }

            } else {
                Write-Error "Failed to list placement groups: $listResult"
            }
        }
    }

    Write-Output "`n✅ Placement group operation completed successfully."

} catch {
    Write-Error "Failed to manage placement group: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
