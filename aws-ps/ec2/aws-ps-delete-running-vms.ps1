[CmdletBinding()]
param(
    [Parameter()]
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
} catch {
    Write-Error "Failed to delete running VMs: $_"
    exit 1
}
