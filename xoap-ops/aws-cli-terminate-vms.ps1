<#
.SYNOPSIS
Deletes all EC2 instances, related snapshots, Elastic IPs, and key pairs in the AWS account.

.DESCRIPTION
This script uses AWS CLI to find and delete all EC2 instances, their associated snapshots, all Elastic IP addresses, and all EC2 key pairs in the current AWS account and region. Use with caution!

.EXAMPLE
.\aws-ps-terminate-vms.ps1 -Region us-east-1

.PARAMETER Region
The AWS region to target for resource deletion.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter()]
    [switch]$DeleteInstances = $true,

    [Parameter()]
    [switch]$DeleteSnapshots = $true,

    [Parameter()]
    [switch]$DeleteAMIs = $true,

    [Parameter()]
    [switch]$DeleteEIPs = $true,

    [Parameter()]
    [switch]$DeleteKeyPairs = $true,

    [Parameter()]
    [switch]$DeleteSecurityGroups = $true
)

$ErrorActionPreference = 'Stop'

try {
    if ($DeleteInstances) {
        Write-Host "Deleting all EC2 instances in region $Region..."
        $instanceIds = aws ec2 describe-instances --region $Region --query "Reservations[].Instances[].InstanceId" --output text
        if ($instanceIds) {
            $idsArray = $instanceIds -split "\s+"
            Write-Host "Terminating instances: $($idsArray -join ', ')"
            aws ec2 terminate-instances --region $Region --instance-ids $idsArray
            Write-Host "Waiting for instances to terminate..."
            aws ec2 wait instance-terminated --region $Region --instance-ids $idsArray
            Write-Host "Terminated instances: $($idsArray -join ', ')"
        } else {
            Write-Host "No EC2 instances found."
        }
    } else {
        Write-Host "Skipping EC2 instance deletion."
    }

    if ($DeleteSnapshots) {
        Write-Host "Deleting all EC2 snapshots in region $Region..."
        $snapshotIds = aws ec2 describe-snapshots --region $Region --owner-ids self --query "Snapshots[].SnapshotId" --output text
        if ($snapshotIds) {
            $deletedSnapshots = @()
            foreach ($snapId in $snapshotIds -split "\s+") {
                if ($DeleteAMIs) {
                    # Check if snapshot is used by an AMI
                    $amiIds = aws ec2 describe-images --region $Region --owners self --query "Images[?BlockDeviceMappings[?Ebs.SnapshotId=='$snapId']].ImageId" --output text
                    if ($amiIds) {
                        foreach ($amiId in $amiIds -split "\s+") {
                            Write-Host "Deregistering AMI $amiId using snapshot $snapId..."
                            aws ec2 deregister-image --region $Region --image-id $amiId
                            Write-Host "Deregistered AMI: $amiId"
                        }
                    }
                }
                Write-Host "Deleting snapshot $snapId..."
                aws ec2 delete-snapshot --region $Region --snapshot-id $snapId
                $deletedSnapshots += $snapId
            }
            Write-Host "Deleted snapshots: $($deletedSnapshots -join ', ')"
        } else {
            Write-Host "No EC2 snapshots found."
        }
    } else {
        Write-Host "Skipping EC2 snapshot deletion."
    }

    if ($DeleteEIPs) {
        Write-Host "Releasing all Elastic IP addresses in region $Region..."
        $eipAllocIds = aws ec2 describe-addresses --region $Region --query "Addresses[].AllocationId" --output text
        if ($eipAllocIds) {
            $releasedEIPs = @()
            foreach ($allocId in $eipAllocIds -split "\s+") {
                aws ec2 release-address --region $Region --allocation-id $allocId
                Write-Host "Released Elastic IP: $allocId"
                $releasedEIPs += $allocId
            }
            Write-Host "Released Elastic IPs: $($releasedEIPs -join ', ')"
        } else {
            Write-Host "No Elastic IP addresses found."
        }
    } else {
        Write-Host "Skipping Elastic IP release."
    }

    if ($DeleteKeyPairs) {
        Write-Host "Deleting all EC2 key pairs in region $Region..."
        $keyNames = aws ec2 describe-key-pairs --region $Region --query "KeyPairs[].KeyName" --output text
        if ($keyNames) {
            $deletedKeys = @()
            foreach ($keyName in $keyNames -split "\s+") {
                aws ec2 delete-key-pair --region $Region --key-name $keyName
                Write-Host "Deleted key pair: $keyName"
                $deletedKeys += $keyName
            }
            Write-Host "Deleted key pairs: $($deletedKeys -join ', ')"
        } else {
            Write-Host "No EC2 key pairs found."
        }
    } else {
        Write-Host "Skipping EC2 key pair deletion."
    }

    if ($DeleteSecurityGroups) {
        Write-Host "Deleting security groups associated with terminated EC2 instances in region $Region..."
        $sgIds = aws ec2 describe-instances --region $Region --query "Reservations[].Instances[].SecurityGroups[].GroupId" --output text
        if ($sgIds) {
            $sgIdArray = $sgIds -split "\s+"
            $deletedSGs = @()
            foreach ($sgId in $sgIdArray) {
                # Skip default security group
                $sgName = aws ec2 describe-security-groups --region $Region --group-ids $sgId --query "SecurityGroups[].GroupName" --output text
                if ($sgName -ne "default") {
                    Write-Host "Deleting security group: $sgId ($sgName)"
                    aws ec2 delete-security-group --region $Region --group-id $sgId
                    $deletedSGs += $sgId
                } else {
                    Write-Host "Skipping default security group: $sgId"
                }
            }
            if ($deletedSGs) {
                Write-Host "Deleted security groups: $($deletedSGs -join ', ')"
            } else {
                Write-Host "No non-default security groups deleted."
            }
        } else {
            Write-Host "No security groups found for terminated instances."
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
