<#
.SYNOPSIS
    Delete running EC2 instances and clean up associated resources.

.DESCRIPTION
    This script stops and terminates EC2 instances using Get-EC2Instance, Stop-EC2Instance, and Remove-EC2Instance from AWS.Tools.EC2.
    It also releases associated Elastic IPs, deletes attached EBS volumes, and removes related snapshots.
    If no InstanceIds are specified, all running instances are targeted.

.PARAMETER InstanceIds
    (Optional) Array of EC2 instance IDs to delete. If omitted, all running instances are targeted.

.EXAMPLE
    .\aws-ps-delete-running-vms.ps1 -InstanceIds i-12345678,i-87654321

.EXAMPLE
    .\aws-ps-delete-running-vms.ps1

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.EC2

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/

.COMPONENT
    AWS PowerShell EC2
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Optional array of EC2 instance IDs to delete. If omitted, all running instances are targeted.")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string[]]$InstanceIds
)

$ErrorActionPreference = 'Stop'
$deletedVMs = @()

try {
    if ($InstanceIds) {
        $instances = Get-EC2Instance -InstanceId $InstanceIds | Select-Object -ExpandProperty Instances
    } else {
        $instances = Get-EC2Instance | Select-Object -ExpandProperty Instances | Where-Object { $_.State.Name -eq 'running' }
    }
    if (-not $instances) {
        Write-Host "No running EC2 instances found to delete." -ForegroundColor Yellow
        return
    }
    foreach ($instance in $instances) {
        $instanceId = $instance.InstanceId
        $name = ($instance.Tags | Where-Object { $_.Key -eq 'Name' }).Value
        $volumes = $instance.BlockDeviceMappings | ForEach-Object { $_.Ebs.VolumeId }

        Write-Host "Stopping instance $instanceId ($name)..." -ForegroundColor Cyan
        Stop-EC2Instance -InstanceId $instanceId -Force
        Wait-EC2InstanceStopped -InstanceId $instanceId

        Write-Host "Terminating instance $instanceId..." -ForegroundColor Cyan
        Remove-EC2Instance -InstanceId $instanceId -Force
        Wait-EC2InstanceTerminated -InstanceId $instanceId

        # Release Elastic IPs
        $eip = Get-EC2Address | Where-Object { $_.InstanceId -eq $instanceId }
        if ($eip) {
            Write-Host "Releasing Elastic IP: $($eip.PublicIp)" -ForegroundColor Cyan
            Remove-EC2Address -PublicIp $eip.PublicIp -Force
        }

        # Delete attached volumes
        foreach ($volumeId in $volumes) {
            Write-Host "Deleting volume $volumeId..." -ForegroundColor Cyan
            Remove-EC2Volume -VolumeId $volumeId -Force
        }

        # Delete related snapshots (if tagged with instance ID)
        $snapshots = Get-EC2Snapshot | Where-Object {
            $_.Description -like "*$instanceId*" -or ($_.Tags | Where-Object { $_.Key -eq 'InstanceId' -and $_.Value -eq $instanceId })
        }

        foreach ($snap in $snapshots) {
            Write-Host "Deleting snapshot: $($snap.SnapshotId)" -ForegroundColor Cyan
            Remove-EC2Snapshot -SnapshotId $snap.SnapshotId -Force
        }

        $deletedVMs += "$instanceId ($name)"
    }
    Write-Host "`nDeleted AWS Instances:" -ForegroundColor Green
    $deletedVMs | ForEach-Object { Write-Host "- $_" }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
