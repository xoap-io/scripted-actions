<#
.SYNOPSIS
    Terminate EC2 instances and optionally delete associated resources in an AWS account
    using the AWS PowerShell module.

.DESCRIPTION
    This script uses AWS.Tools.EC2 cmdlets to discover and terminate all EC2 instances in
    the specified region, then optionally deregisters AMIs, deletes snapshots, releases
    Elastic IPs, removes key pairs, and deletes non-default security groups.
    Writes a detailed log file recording every resource that was removed.
    Includes post-operation verification to confirm no running instances remain.

    The script uses the AWS.Tools.EC2 cmdlets:
    Get-EC2Instance, Remove-EC2Instance, Get-EC2InstanceStatus, and related cmdlets.

.PARAMETER Region
    The AWS region to target (e.g. eu-central-1).

.PARAMETER WhatIf
    Show what resources would be deleted without making any changes.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER DeleteSnapshots
    Delete all EBS snapshots owned by this account.

.PARAMETER DeleteAMIs
    Deregister AMIs before deleting their backing snapshots. Requires -DeleteSnapshots.

.PARAMETER DeleteEIPs
    Release all Elastic IP addresses.

.PARAMETER DeleteKeyPairs
    Delete all EC2 key pairs.

.PARAMETER DeleteSecurityGroups
    Delete all non-default security groups.

.EXAMPLE
    .\aws-ps-terminate-vms.ps1 -Region eu-central-1 -WhatIf
    Shows all EC2 instances that would be terminated without making any changes.

.EXAMPLE
    .\aws-ps-terminate-vms.ps1 -Region eu-central-1 -Force
    Terminates all EC2 instances in eu-central-1 without a confirmation prompt.

.EXAMPLE
    .\aws-ps-terminate-vms.ps1 -Region us-east-1 -DeleteSnapshots -DeleteAMIs -DeleteEIPs -DeleteKeyPairs -DeleteSecurityGroups -Force
    Full cleanup of all EC2 resources in us-east-1 without confirmation.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.EC2, AWS.Tools.SecurityToken (Install-Module AWS.Tools.EC2)

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/items/Remove-EC2Instance.html

.COMPONENT
    AWS PowerShell EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "AWS region to target")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(HelpMessage = "Show what would be deleted without making changes")]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Skip confirmation prompts")]
    [switch]$Force,

    [Parameter(HelpMessage = "Delete all EBS snapshots owned by this account")]
    [switch]$DeleteSnapshots,

    [Parameter(HelpMessage = "Deregister AMIs before deleting their snapshots (requires -DeleteSnapshots)")]
    [switch]$DeleteAMIs,

    [Parameter(HelpMessage = "Release all Elastic IP addresses")]
    [switch]$DeleteEIPs,

    [Parameter(HelpMessage = "Delete all EC2 key pairs")]
    [switch]$DeleteKeyPairs,

    [Parameter(HelpMessage = "Delete all non-default security groups")]
    [switch]$DeleteSecurityGroups
)

$ErrorActionPreference = 'Stop'

$LogFile = "aws-ps-terminate-vms-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $LogFile -Value "[$timestamp] $Message"
    Write-Host $Message -ForegroundColor $Color
}

try {
    Write-Log '===== AWS PowerShell EC2 Cleanup Script Started =====' -Color Blue
    Write-Log "Log file: $LogFile" -Color Cyan
    Write-Log "Region:   $Region" -Color Cyan

    # Verify module
    Import-Module AWS.Tools.EC2 -ErrorAction Stop
    Import-Module AWS.Tools.SecurityToken -ErrorAction Stop

    # Verify authentication and log account identity
    $identity = Get-STSCallerIdentity
    Write-Log "Account:  $($identity.Account)" -Color Cyan
    Write-Log "ARN:      $($identity.Arn)" -Color Cyan

    # Discover active instances
    Write-Log '🔍 Discovering EC2 instances...' -Color Cyan
    $reservations = Get-EC2Instance -Region $Region
    $allInstances = @($reservations.Instances | Where-Object { $_.State.Name -ne 'terminated' })

    if ($allInstances.Count -eq 0) {
        Write-Log 'ℹ️ No active EC2 instances found in this region.' -Color Yellow
    }
    else {
        $runningInstances = @($allInstances | Where-Object { $_.State.Name -eq 'running' })

        Write-Log "Found $($allInstances.Count) active instance(s) ($($runningInstances.Count) running):" -Color Cyan
        foreach ($inst in $allInstances) {
            $nameTag = ($inst.Tags | Where-Object { $_.Key -eq 'Name' }).Value
            if (-not $nameTag) { $nameTag = '(no Name tag)' }
            Write-Log "   • $($inst.InstanceId) | $($inst.State.Name) | $($inst.InstanceType) | $nameTag" -Color White
        }

        if ($WhatIf) {
            Write-Log '🔍 WhatIf mode — no changes will be made.' -Color Cyan
            Write-Log "Would terminate $($allInstances.Count) instance(s)." -Color Yellow
        }
        else {
            if (-not $Force) {
                Write-Log '' -Color White
                Write-Log "⚠️  About to terminate $($allInstances.Count) instance(s) in region '$Region' (Account: $($identity.Account))" -Color Yellow
                $confirmation = Read-Host "Type 'YES' to confirm"
                if ($confirmation -ne 'YES') {
                    Write-Log 'Operation cancelled by user.' -Color Yellow
                    exit 0
                }
            }

            $instanceIds = $allInstances | Select-Object -ExpandProperty InstanceId

            Write-Log '🛑 Terminating instances...' -Color Cyan
            Remove-EC2Instance -InstanceId $instanceIds -Region $Region -Force | Out-Null

            # Wait for all instances to reach terminated state
            Write-Log '⏳ Waiting for instances to reach terminated state...' -Color Cyan
            $maxWait = 300  # seconds
            $waited  = 0
            $interval = 10

            do {
                Start-Sleep -Seconds $interval
                $waited += $interval
                $stillActive = @(
                    (Get-EC2Instance -InstanceId $instanceIds -Region $Region).Instances |
                    Where-Object { $_.State.Name -ne 'terminated' }
                )
                Write-Log "   Waiting... $($stillActive.Count) instance(s) still terminating ($waited/$maxWait s)" -Color Gray
            } while ($stillActive.Count -gt 0 -and $waited -lt $maxWait)

            if ($stillActive.Count -gt 0) {
                Write-Log "   ⚠️  $($stillActive.Count) instance(s) did not terminate within $maxWait seconds." -Color Yellow
            }
            else {
                foreach ($id in $instanceIds) {
                    Write-Log "   ✅ Terminated: $id" -Color Green
                }
            }
        }
    }

    if ($WhatIf) {
        Write-Log '🔍 WhatIf mode active — skipping all deletion steps.' -Color Cyan
        exit 0
    }

    # Delete snapshots (and optionally deregister AMIs first)
    if ($DeleteSnapshots) {
        Write-Log '' -Color White
        Write-Log '🔍 Discovering EBS snapshots...' -Color Cyan
        $snapshots = @(Get-EC2Snapshot -OwnerId 'self' -Region $Region)

        if ($snapshots.Count -gt 0) {
            Write-Log "Found $($snapshots.Count) snapshot(s)." -Color Cyan
            foreach ($snap in $snapshots) {
                try {
                    if ($DeleteAMIs) {
                        $amis = @(Get-EC2Image -OwnerId 'self' -Region $Region |
                            Where-Object { $_.BlockDeviceMappings.Ebs.SnapshotId -contains $snap.SnapshotId })

                        foreach ($ami in $amis) {
                            Unregister-EC2Image -ImageId $ami.ImageId -Region $Region | Out-Null
                            Write-Log "   ✅ Deregistered AMI: $($ami.ImageId) (backed by $($snap.SnapshotId))" -Color Green
                        }
                    }

                    Remove-EC2Snapshot -SnapshotId $snap.SnapshotId -Region $Region -Force | Out-Null
                    Write-Log "   ✅ Deleted snapshot: $($snap.SnapshotId) ($($snap.VolumeSize) GiB)" -Color Green
                }
                catch {
                    Write-Log "   ❌ Failed to delete snapshot $($snap.SnapshotId): $($_.Exception.Message)" -Color Red
                }
            }
        }
        else {
            Write-Log 'ℹ️ No snapshots found.' -Color Yellow
        }
    }

    # Release Elastic IPs
    if ($DeleteEIPs) {
        Write-Log '' -Color White
        Write-Log '🔍 Discovering Elastic IPs...' -Color Cyan
        $addresses = @(Get-EC2Address -Region $Region)

        if ($addresses.Count -gt 0) {
            Write-Log "Found $($addresses.Count) Elastic IP(s)." -Color Cyan
            foreach ($eip in $addresses) {
                try {
                    Remove-EC2Address -AllocationId $eip.AllocationId -Region $Region -Force | Out-Null
                    Write-Log "   ✅ Released EIP: $($eip.PublicIp) ($($eip.AllocationId))" -Color Green
                }
                catch {
                    Write-Log "   ❌ Failed to release EIP $($eip.AllocationId): $($_.Exception.Message)" -Color Red
                }
            }
        }
        else {
            Write-Log 'ℹ️ No Elastic IPs found.' -Color Yellow
        }
    }

    # Delete key pairs
    if ($DeleteKeyPairs) {
        Write-Log '' -Color White
        Write-Log '🔍 Discovering key pairs...' -Color Cyan
        $keyPairs = @(Get-EC2KeyPair -Region $Region)

        if ($keyPairs.Count -gt 0) {
            Write-Log "Found $($keyPairs.Count) key pair(s)." -Color Cyan
            foreach ($kp in $keyPairs) {
                try {
                    Remove-EC2KeyPair -KeyName $kp.KeyName -Region $Region -Force | Out-Null
                    Write-Log "   ✅ Deleted key pair: $($kp.KeyName)" -Color Green
                }
                catch {
                    Write-Log "   ❌ Failed to delete key pair $($kp.KeyName): $($_.Exception.Message)" -Color Red
                }
            }
        }
        else {
            Write-Log 'ℹ️ No key pairs found.' -Color Yellow
        }
    }

    # Delete non-default security groups
    if ($DeleteSecurityGroups) {
        Write-Log '' -Color White
        Write-Log '🔍 Discovering non-default security groups...' -Color Cyan
        $sgs = @(Get-EC2SecurityGroup -Region $Region | Where-Object { $_.GroupName -ne 'default' })

        if ($sgs.Count -gt 0) {
            Write-Log "Found $($sgs.Count) non-default security group(s)." -Color Cyan
            foreach ($sg in $sgs) {
                try {
                    Remove-EC2SecurityGroup -GroupId $sg.GroupId -Region $Region -Force | Out-Null
                    Write-Log "   ✅ Deleted security group: $($sg.GroupName) ($($sg.GroupId))" -Color Green
                }
                catch {
                    Write-Log "   ❌ Failed to delete security group $($sg.GroupId): $($_.Exception.Message)" -Color Red
                }
            }
        }
        else {
            Write-Log 'ℹ️ No non-default security groups found.' -Color Yellow
        }
    }

    # Post-operation verification
    Write-Log '' -Color White
    Write-Log '🔎 Verifying no running instances remain...' -Color Cyan
    $remaining = @(
        (Get-EC2Instance -Region $Region).Instances |
        Where-Object { $_.State.Name -in @('running', 'pending', 'stopping', 'stopped') }
    )

    if ($remaining.Count -gt 0) {
        Write-Log "   ⚠️  $($remaining.Count) instance(s) still active after cleanup:" -Color Yellow
        foreach ($inst in $remaining) {
            Write-Log "      • $($inst.InstanceId) | $($inst.State.Name) | $($inst.InstanceType)" -Color Yellow
        }
    }
    else {
        Write-Log '   ✅ Verified: no active instances remain in this region.' -Color Green
    }

    Write-Log '' -Color White
    Write-Log '===== Operation Complete =====' -Color White
    Write-Log "Region:   $Region" -Color White
    Write-Log "Account:  $($identity.Account)" -Color White
    Write-Log "Log file: $LogFile" -Color Gray
    Write-Log '=============================' -Color White
}
catch {
    Write-Log "❌ Script failed: $($_.Exception.Message)" -Color Red
    exit 1
}
finally {
    Write-Log '' -Color White
    Write-Log '🏁 Script execution completed' -Color Green
}
