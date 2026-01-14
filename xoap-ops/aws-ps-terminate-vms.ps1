<#
.SYNOPSIS
Deletes all EC2 instances, related snapshots, Elastic IPs, key pairs, and associated security groups in the AWS account using AWS PowerShell module.

.DESCRIPTION
This script uses AWS.Tools.EC2 cmdlets to find and delete all EC2 instances, their associated snapshots, all Elastic IP addresses, all EC2 key pairs, and security groups (excluding default) in the specified AWS region.

.EXAMPLE
.\aws-ps-terminate-vms.ps1 -Region eu-central-1

.PARAMETER Region
The AWS region to target for resource deletion.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter()]
    [switch]$DeleteInstances,

    [Parameter()]
    [switch]$DeleteSnapshots,

    [Parameter()]
    [switch]$DeleteAMIs,

    [Parameter()]
    [switch]$DeleteEIPs,

    [Parameter()]
    [switch]$DeleteKeyPairs,

    [Parameter()]
    [switch]$DeleteSecurityGroups
)

$ErrorActionPreference = 'Stop'

try {
    Import-Module AWS.Tools.EC2 -ErrorAction Stop

    if ($DeleteInstances) {
        Write-Host "Deleting all EC2 instances in region $Region..."
        $instances = Get-EC2Instance -Region $Region
        $instanceIds = $instances.Instances.InstanceId
        if ($instanceIds) {
            Write-Host "Terminating instances: $($instanceIds -join ', ')"
            Stop-EC2Instance -InstanceId $instanceIds -Region $Region -Force
            Write-Host "Waiting for instances to terminate..."
            $terminated = $instanceIds | ForEach-Object {
                do {
                    $state = (Get-EC2Instance -InstanceId $_ -Region $Region).Instances.State.Name
                    Start-Sleep -Seconds 5
                } while ($state -ne 'terminated')
            }
            Write-Host "Terminated instances: $($instanceIds -join ', ')"
        } else {
            Write-Host "No EC2 instances found."
        }
    } else {
        Write-Host "Skipping EC2 instance deletion."
    }

    if ($DeleteSnapshots) {
        Write-Host "Deleting all EC2 snapshots in region $Region..."
        $snapshots = Get-EC2Snapshot -OwnerId self -Region $Region
        $deletedSnapshots = @()
        foreach ($snap in $snapshots) {
            $snapId = $snap.SnapshotId
            if ($DeleteAMIs) {
                $amis = Get-EC2Image -Region $Region | Where-Object {
                    $_.BlockDeviceMappings | Where-Object { $_.Ebs.SnapshotId -eq $snapId }
                }
                foreach ($ami in $amis) {
                    Write-Host "Deregistering AMI $($ami.ImageId) using snapshot $snapId..."
                    Unregister-EC2Image -ImageId $ami.ImageId -Region $Region
                    Write-Host "Deregistered AMI: $($ami.ImageId)"
                }
            }
            Write-Host "Deleting snapshot $snapId..."
            Remove-EC2Snapshot -SnapshotId $snapId -Region $Region
            $deletedSnapshots += $snapId
        }
        if ($deletedSnapshots) {
            Write-Host "Deleted snapshots: $($deletedSnapshots -join ', ')"
        } else {
            Write-Host "No EC2 snapshots found."
        }
    } else {
        Write-Host "Skipping EC2 snapshot deletion."
    }

    if ($DeleteEIPs) {
        Write-Host "Releasing all Elastic IP addresses in region $Region..."
        $addresses = Get-EC2Address -Region $Region
        $releasedEIPs = @()
        foreach ($eip in $addresses) {
            if ($eip.AllocationId) {
                Remove-EC2Address -AllocationId $eip.AllocationId -Region $Region
                Write-Host "Released Elastic IP: $($eip.AllocationId)"
                $releasedEIPs += $eip.AllocationId
            }
        }
        if ($releasedEIPs) {
            Write-Host "Released Elastic IPs: $($releasedEIPs -join ', ')"
        } else {
            Write-Host "No Elastic IP addresses found."
        }
    } else {
        Write-Host "Skipping Elastic IP release."
    }

    if ($DeleteKeyPairs) {
        Write-Host "Deleting all EC2 key pairs in region $Region..."
        $keyPairs = Get-EC2KeyPair -Region $Region
        $deletedKeys = @()
        foreach ($key in $keyPairs) {
            Remove-EC2KeyPair -KeyName $key.KeyName -Region $Region
            Write-Host "Deleted key pair: $($key.KeyName)"
            $deletedKeys += $key.KeyName
        }
        if ($deletedKeys) {
            Write-Host "Deleted key pairs: $($deletedKeys -join ', ')"
        } else {
            Write-Host "No EC2 key pairs found."
        }
    } else {
        Write-Host "Skipping EC2 key pair deletion."
    }

    if ($DeleteSecurityGroups) {
        Write-Host "Deleting security groups associated with terminated EC2 instances in region $Region..."
        $sgs = Get-EC2SecurityGroup -Region $Region | Where-Object { $_.GroupName -ne 'default' }
        $deletedSGs = @()
        foreach ($sg in $sgs) {
            try {
                Remove-EC2SecurityGroup -GroupId $sg.GroupId -Region $Region
                Write-Host "Deleted security group: $($sg.GroupId) ($($sg.GroupName))"
                $deletedSGs += $sg.GroupId
            } catch {
                Write-Host "Could not delete security group $($sg.GroupId): $_"
            }
        }
        if ($deletedSGs) {
            Write-Host "Deleted security groups: $($deletedSGs -join ', ')"
        } else {
            Write-Host "No non-default security groups deleted."
        }
    } else {
        Write-Host "Skipping security group deletion."
    }

    Write-Host "All EC2 resources deleted successfully in region $Region."
}
catch {
    Write-Error "Error occurred: $_"
    exit 1
}
