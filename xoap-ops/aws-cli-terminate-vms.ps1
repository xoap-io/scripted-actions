<#
.SYNOPSIS
    Terminate EC2 instances and optionally delete associated resources in an AWS account
    using the AWS CLI.

.DESCRIPTION
    This script uses the AWS CLI to discover and terminate all EC2 instances in the
    specified region, then optionally deregisters AMIs, deletes snapshots, releases
    Elastic IPs, removes key pairs, and deletes non-default security groups.
    Writes a detailed log file recording every resource that was removed.
    Includes post-operation verification to confirm no running instances remain.

    The script uses the AWS CLI commands:
    aws ec2 describe-instances, aws ec2 terminate-instances, aws ec2 wait instance-terminated

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
    .\aws-cli-terminate-vms.ps1 -Region eu-central-1 -WhatIf
    Shows all EC2 instances that would be terminated without making any changes.

.EXAMPLE
    .\aws-cli-terminate-vms.ps1 -Region eu-central-1 -Force
    Terminates all EC2 instances in eu-central-1 without a confirmation prompt.

.EXAMPLE
    .\aws-cli-terminate-vms.ps1 -Region us-east-1 -DeleteSnapshots -DeleteAMIs -DeleteEIPs -DeleteKeyPairs -DeleteSecurityGroups -Force
    Full cleanup of all EC2 resources in us-east-1 without confirmation.

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/terminate-instances.html

.COMPONENT
    AWS CLI EC2
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

$LogFile = "aws-cli-terminate-vms-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $LogFile -Value "[$timestamp] $Message"
    Write-Host $Message -ForegroundColor $Color
}

function Invoke-AwsCli {
    param([string[]]$Arguments)
    $result = & aws @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI error: $result"
    }
    return $result
}

try {
    Write-Log '===== AWS CLI EC2 Cleanup Script Started =====' -Color Blue
    Write-Log "Log file: $LogFile" -Color Cyan
    Write-Log "Region:   $Region" -Color Cyan

    # Verify AWS CLI
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI not found in PATH. Install from https://aws.amazon.com/cli/"
    }

    # Verify authentication
    $identity = Invoke-AwsCli @('sts', 'get-caller-identity', '--output', 'json') | ConvertFrom-Json
    Write-Log "Account:  $($identity.Account)" -Color Cyan
    Write-Log "ARN:      $($identity.Arn)" -Color Cyan

    # Discover running instances
    Write-Log '🔍 Discovering EC2 instances...' -Color Cyan
    $instanceJson = Invoke-AwsCli @(
        'ec2', 'describe-instances',
        '--region', $Region,
        '--query', 'Reservations[].Instances[?State.Name!=`terminated`][].[InstanceId,State.Name,InstanceType,Tags[?Key==`Name`].Value|[0]]',
        '--output', 'json'
    ) | ConvertFrom-Json

    if (-not $instanceJson -or $instanceJson.Count -eq 0) {
        Write-Log 'ℹ️ No active EC2 instances found in this region.' -Color Yellow
    }
    else {
        Write-Log "Found $($instanceJson.Count) active instance(s):" -Color Cyan
        foreach ($inst in $instanceJson) {
            $nameTag = if ($inst[3]) { $inst[3] } else { '(no Name tag)' }
            Write-Log "   • $($inst[0]) | $($inst[1]) | $($inst[2]) | $nameTag" -Color White
        }

        $runningInstances = @($instanceJson | Where-Object { $_[1] -eq 'running' })
        Write-Log "   Running: $($runningInstances.Count) | Other active states: $($instanceJson.Count - $runningInstances.Count)" -Color Cyan

        if ($WhatIf) {
            Write-Log '🔍 WhatIf mode — no changes will be made.' -Color Cyan
            Write-Log "Would terminate $($instanceJson.Count) instance(s)." -Color Yellow
        }
        else {
            if (-not $Force) {
                Write-Log '' -Color White
                Write-Log "⚠️  About to terminate $($instanceJson.Count) instance(s) in region '$Region' (Account: $($identity.Account))" -Color Yellow
                $confirmation = Read-Host "Type 'YES' to confirm"
                if ($confirmation -ne 'YES') {
                    Write-Log 'Operation cancelled by user.' -Color Yellow
                    exit 0
                }
            }

            $instanceIds = $instanceJson | ForEach-Object { $_[0] }

            Write-Log '🛑 Terminating instances...' -Color Cyan
            Invoke-AwsCli @(
                'ec2', 'terminate-instances',
                '--region', $Region,
                '--instance-ids') + $instanceIds | Out-Null

            Write-Log '⏳ Waiting for instances to reach terminated state...' -Color Cyan
            Invoke-AwsCli @(
                'ec2', 'wait', 'instance-terminated',
                '--region', $Region,
                '--instance-ids') + $instanceIds | Out-Null

            foreach ($id in $instanceIds) {
                Write-Log "   ✅ Terminated: $id" -Color Green
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
        $snapshots = Invoke-AwsCli @(
            'ec2', 'describe-snapshots',
            '--region', $Region,
            '--owner-ids', 'self',
            '--query', 'Snapshots[].[SnapshotId,VolumeSize,StartTime,Description]',
            '--output', 'json'
        ) | ConvertFrom-Json

        if ($snapshots -and $snapshots.Count -gt 0) {
            Write-Log "Found $($snapshots.Count) snapshot(s)." -Color Cyan

            foreach ($snap in $snapshots) {
                $snapId = $snap[0]
                try {
                    if ($DeleteAMIs) {
                        $amiJson = Invoke-AwsCli @(
                            'ec2', 'describe-images',
                            '--region', $Region,
                            '--owners', 'self',
                            '--query', "Images[?BlockDeviceMappings[?Ebs.SnapshotId=='$snapId']].ImageId",
                            '--output', 'json'
                        ) | ConvertFrom-Json

                        foreach ($amiId in $amiJson) {
                            Invoke-AwsCli @('ec2', 'deregister-image', '--region', $Region, '--image-id', $amiId) | Out-Null
                            Write-Log "   ✅ Deregistered AMI: $amiId (backed by $snapId)" -Color Green
                        }
                    }

                    Invoke-AwsCli @('ec2', 'delete-snapshot', '--region', $Region, '--snapshot-id', $snapId) | Out-Null
                    Write-Log "   ✅ Deleted snapshot: $snapId ($($snap[1]) GiB)" -Color Green
                }
                catch {
                    Write-Log "   ❌ Failed to delete snapshot $($snapId): $($_.Exception.Message)" -Color Red
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
        $eips = Invoke-AwsCli @(
            'ec2', 'describe-addresses',
            '--region', $Region,
            '--query', 'Addresses[].[AllocationId,PublicIp,AssociationId]',
            '--output', 'json'
        ) | ConvertFrom-Json

        if ($eips -and $eips.Count -gt 0) {
            Write-Log "Found $($eips.Count) Elastic IP(s)." -Color Cyan
            foreach ($eip in $eips) {
                $allocId = $eip[0]
                $pubIp   = $eip[1]
                try {
                    Invoke-AwsCli @('ec2', 'release-address', '--region', $Region, '--allocation-id', $allocId) | Out-Null
                    Write-Log "   ✅ Released EIP: $pubIp ($allocId)" -Color Green
                }
                catch {
                    Write-Log "   ❌ Failed to release EIP $($allocId): $($_.Exception.Message)" -Color Red
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
        $keyPairs = Invoke-AwsCli @(
            'ec2', 'describe-key-pairs',
            '--region', $Region,
            '--query', 'KeyPairs[].[KeyName,KeyPairId]',
            '--output', 'json'
        ) | ConvertFrom-Json

        if ($keyPairs -and $keyPairs.Count -gt 0) {
            Write-Log "Found $($keyPairs.Count) key pair(s)." -Color Cyan
            foreach ($kp in $keyPairs) {
                try {
                    Invoke-AwsCli @('ec2', 'delete-key-pair', '--region', $Region, '--key-name', $kp[0]) | Out-Null
                    Write-Log "   ✅ Deleted key pair: $($kp[0]) ($($kp[1]))" -Color Green
                }
                catch {
                    Write-Log "   ❌ Failed to delete key pair $($kp[0]): $($_.Exception.Message)" -Color Red
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
        $sgs = Invoke-AwsCli @(
            'ec2', 'describe-security-groups',
            '--region', $Region,
            '--query', 'SecurityGroups[?GroupName!=`default`].[GroupId,GroupName]',
            '--output', 'json'
        ) | ConvertFrom-Json

        if ($sgs -and $sgs.Count -gt 0) {
            Write-Log "Found $($sgs.Count) non-default security group(s)." -Color Cyan
            foreach ($sg in $sgs) {
                try {
                    Invoke-AwsCli @('ec2', 'delete-security-group', '--region', $Region, '--group-id', $sg[0]) | Out-Null
                    Write-Log "   ✅ Deleted security group: $($sg[1]) ($($sg[0]))" -Color Green
                }
                catch {
                    Write-Log "   ❌ Failed to delete security group $($sg[0]): $($_.Exception.Message)" -Color Red
                }
            }
        }
        else {
            Write-Log 'ℹ️ No non-default security groups found.' -Color Yellow
        }
    }

    # Post-operation verification — confirm no running instances remain
    Write-Log '' -Color White
    Write-Log '🔎 Verifying no running instances remain...' -Color Cyan
    $remainingJson = Invoke-AwsCli @(
        'ec2', 'describe-instances',
        '--region', $Region,
        '--filters', 'Name=instance-state-name,Values=running,pending,stopping,stopped',
        '--query', 'Reservations[].Instances[].[InstanceId,State.Name]',
        '--output', 'json'
    ) | ConvertFrom-Json

    if ($remainingJson -and $remainingJson.Count -gt 0) {
        Write-Log "   ⚠️  $($remainingJson.Count) instance(s) still active after cleanup:" -Color Yellow
        foreach ($inst in $remainingJson) {
            Write-Log "      • $($inst[0]) | $($inst[1])" -Color Yellow
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
