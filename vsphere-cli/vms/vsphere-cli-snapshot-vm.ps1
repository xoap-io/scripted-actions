<#
.SYNOPSIS
    Manages VM snapshots in vSphere using PowerCLI.

.DESCRIPTION
    This script creates, lists, reverts, and deletes VM snapshots in vSphere.
    Supports single VMs or multiple VMs with various snapshot operations.
    Requires VMware PowerCLI and connection to vCenter Server.

.PARAMETER VCenterServer
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER VMName
    The name of the virtual machine. Supports wildcards.

.PARAMETER VMNames
    An array of specific VM names for batch operations.

.PARAMETER Operation
    The snapshot operation to perform.

.PARAMETER SnapshotName
    The name of the snapshot for create/revert/delete operations.

.PARAMETER SnapshotDescription
    Description for the snapshot (optional, for create operation).

.PARAMETER Memory
    Include VM memory state in snapshot (default: true for create operation).

.PARAMETER Quiesce
    Quiesce the VM file system (requires VMware Tools, default: true).

.PARAMETER RemoveChildren
    Remove child snapshots when deleting (default: false).

.PARAMETER Force
    Force the operation without confirmation prompts.

.PARAMETER MaxSnapshotsPerVM
    Maximum number of snapshots to keep per VM (for cleanup operations).

.EXAMPLE
    .\vsphere-cli-snapshot-vm.ps1 -VCenterServer "vcenter.domain.com" -VMName "WebServer01" -Operation "Create" -SnapshotName "BeforePatch" -SnapshotDescription "Before monthly patching"

.EXAMPLE
    .\vsphere-cli-snapshot-vm.ps1 -VCenterServer "vcenter.domain.com" -VMName "TestVM*" -Operation "List"

.EXAMPLE
    .\vsphere-cli-snapshot-vm.ps1 -VCenterServer "vcenter.domain.com" -VMName "WebServer01" -Operation "Revert" -SnapshotName "BeforePatch"

.EXAMPLE
    .\vsphere-cli-snapshot-vm.ps1 -VCenterServer "vcenter.domain.com" -VMNames @("VM01","VM02") -Operation "Delete" -SnapshotName "OldSnapshot" -Force

.EXAMPLE
    .\vsphere-cli-snapshot-vm.ps1 -VCenterServer "vcenter.domain.com" -VMName "TestVM01" -Operation "Cleanup" -MaxSnapshotsPerVM 3 -Force

.NOTES
    Author: XOAP.io
    Requires: VMware PowerCLI 13.x or later, vSphere 7.0 or later

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VCenterServer,

    [Parameter(Mandatory = $false, ParameterSetName = "SingleVM")]
    [ValidateNotNullOrEmpty()]
    [string]$VMName,

    [Parameter(Mandatory = $false, ParameterSetName = "MultipleVMs")]
    [ValidateNotNullOrEmpty()]
    [string[]]$VMNames,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Create", "List", "Revert", "Delete", "DeleteAll", "Cleanup")]
    [string]$Operation,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SnapshotName,

    [Parameter(Mandatory = $false)]
    [string]$SnapshotDescription,

    [Parameter(Mandatory = $false)]
    [bool]$Memory = $true,

    [Parameter(Mandatory = $false)]
    [bool]$Quiesce = $true,

    [Parameter(Mandatory = $false)]
    [switch]$RemoveChildren,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 50)]
    [int]$MaxSnapshotsPerVM = 5
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to check and install PowerCLI if needed
function Test-PowerCLIInstallation {
    Write-Host "Checking PowerCLI installation..." -ForegroundColor Yellow

    try {
        $powerCLIModule = Get-Module -Name VMware.PowerCLI -ListAvailable
        if (-not $powerCLIModule) {
            Write-Warning "VMware PowerCLI not found. Installing..."
            Install-Module -Name VMware.PowerCLI -Force -AllowClobber -Scope CurrentUser
            Write-Host "PowerCLI installed successfully." -ForegroundColor Green
        } else {
            $version = $powerCLIModule | Sort-Object Version -Descending | Select-Object -First 1
            Write-Host "PowerCLI version $($version.Version) found." -ForegroundColor Green
        }

        # Import the module
        Import-Module VMware.PowerCLI -Force

        # Disable certificate warnings for lab environments
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope User | Out-Null
        Set-PowerCLIConfiguration -ParticipateInCEIP $false -Confirm:$false -Scope User | Out-Null

        return $true
    }
    catch {
        Write-Error "Failed to install or import PowerCLI: $($_.Exception.Message)"
        return $false
    }
}

# Function to connect to vCenter
function Connect-ToVCenter {
    param($Server)

    try {
        Write-Host "Connecting to vCenter Server: $Server" -ForegroundColor Yellow

        # Check if already connected
        $connection = $global:DefaultVIServers | Where-Object { $_.Name -eq $Server -and $_.IsConnected }
        if ($connection) {
            Write-Host "Already connected to $Server" -ForegroundColor Green
            return $connection
        }

        # Connect to vCenter (will prompt for credentials if not cached)
        $connection = Connect-VIServer -Server $Server -Force
        Write-Host "Successfully connected to vCenter: $($connection.Name)" -ForegroundColor Green
        return $connection
    }
    catch {
        Write-Error "Failed to connect to vCenter Server $Server`: $($_.Exception.Message)"
        throw
    }
}

# Function to get target VMs
function Get-TargetVMs {
    param(
        $VMName,
        $VMNames
    )

    Write-Host "Identifying target VMs..." -ForegroundColor Yellow

    try {
        $targetVMs = @()

        if ($VMName) {
            # Single VM or wildcard pattern
            $targetVMs = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        }
        elseif ($VMNames) {
            # Multiple specific VMs
            foreach ($name in $VMNames) {
                $vm = Get-VM -Name $name -ErrorAction SilentlyContinue
                if ($vm) {
                    $targetVMs += $vm
                } else {
                    Write-Warning "VM '$name' not found"
                }
            }
        }

        if (-not $targetVMs) {
            throw "No VMs found matching the specified criteria"
        }

        Write-Host "Found $($targetVMs.Count) VM(s) matching criteria:" -ForegroundColor Green
        foreach ($vm in $targetVMs) {
            Write-Host "  - $($vm.Name) [$($vm.PowerState)]" -ForegroundColor White
        }

        return $targetVMs
    }
    catch {
        Write-Error "Failed to get target VMs: $($_.Exception.Message)"
        throw
    }
}

# Function to create snapshots
function New-VMSnapshot {
    param(
        $VMs,
        $SnapshotName,
        $SnapshotDescription,
        $Memory,
        $Quiesce
    )

    Write-Host "Creating snapshots for $($VMs.Count) VM(s)..." -ForegroundColor Yellow

    $results = @()

    foreach ($vm in $VMs) {
        try {
            Write-Host "  Processing VM: $($vm.Name)" -ForegroundColor Cyan

            # Check if snapshot with same name already exists
            $existingSnapshot = Get-Snapshot -VM $vm -Name $SnapshotName -ErrorAction SilentlyContinue
            if ($existingSnapshot) {
                Write-Warning "    Snapshot '$SnapshotName' already exists for VM '$($vm.Name)'"
                $results += @{
                    VM = $vm.Name
                    Operation = "Create"
                    Status = "Skipped"
                    Message = "Snapshot already exists"
                    Snapshot = $existingSnapshot.Name
                }
                continue
            }

            # Create snapshot
            $snapshotParams = @{
                VM = $vm
                Name = $SnapshotName
                Memory = $Memory
                Quiesce = $Quiesce
            }

            if ($SnapshotDescription) {
                $snapshotParams.Description = $SnapshotDescription
            }

            $snapshot = New-Snapshot @snapshotParams

            $results += @{
                VM = $vm.Name
                Operation = "Create"
                Status = "Success"
                Message = "Snapshot created successfully"
                Snapshot = $snapshot.Name
                Created = $snapshot.Created
                SizeGB = [math]::Round($snapshot.SizeGB, 2)
            }

            Write-Host "    ✓ Snapshot '$SnapshotName' created" -ForegroundColor Green
        }
        catch {
            $results += @{
                VM = $vm.Name
                Operation = "Create"
                Status = "Failed"
                Message = $_.Exception.Message
                Snapshot = $SnapshotName
            }
            Write-Host "    ✗ Failed to create snapshot: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    return $results
}

# Function to list snapshots
function Get-VMSnapshotList {
    param($VMs)

    Write-Host "Listing snapshots for $($VMs.Count) VM(s)..." -ForegroundColor Yellow

    $results = @()

    foreach ($vm in $VMs) {
        Write-Host "`nVM: $($vm.Name)" -ForegroundColor Cyan

        $snapshots = Get-Snapshot -VM $vm -ErrorAction SilentlyContinue

        if ($snapshots) {
            Write-Host "  Found $($snapshots.Count) snapshot(s):" -ForegroundColor Green

            foreach ($snapshot in $snapshots) {
                $snapshotInfo = @{
                    VM = $vm.Name
                    Name = $snapshot.Name
                    Description = $snapshot.Description
                    Created = $snapshot.Created
                    SizeGB = [math]::Round($snapshot.SizeGB, 2)
                    PowerState = $snapshot.PowerState
                    IsCurrent = $snapshot.IsCurrent
                    Parent = if ($snapshot.Parent) { $snapshot.Parent.Name } else { "Root" }
                    Children = $snapshot.Children.Count
                }

                $results += $snapshotInfo

                $ageInDays = [math]::Round((Get-Date).Subtract($snapshot.Created).TotalDays, 1)
                $currentMarker = if ($snapshot.IsCurrent) { " [CURRENT]" } else { "" }

                Write-Host "    - $($snapshot.Name)$currentMarker" -ForegroundColor White
                Write-Host "      Created: $($snapshot.Created) ($ageInDays days ago)" -ForegroundColor Gray
                Write-Host "      Size: $([math]::Round($snapshot.SizeGB, 2)) GB" -ForegroundColor Gray
                if ($snapshot.Description) {
                    Write-Host "      Description: $($snapshot.Description)" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "  No snapshots found" -ForegroundColor Yellow
        }
    }

    return $results
}

# Function to revert to snapshot
function Restore-VMSnapshot {
    param(
        $VMs,
        $SnapshotName
    )

    Write-Host "Reverting VMs to snapshot '$SnapshotName'..." -ForegroundColor Yellow

    $results = @()

    foreach ($vm in $VMs) {
        try {
            Write-Host "  Processing VM: $($vm.Name)" -ForegroundColor Cyan

            # Find the snapshot
            $snapshot = Get-Snapshot -VM $vm -Name $SnapshotName -ErrorAction SilentlyContinue
            if (-not $snapshot) {
                Write-Warning "    Snapshot '$SnapshotName' not found for VM '$($vm.Name)'"
                $results += @{
                    VM = $vm.Name
                    Operation = "Revert"
                    Status = "Failed"
                    Message = "Snapshot not found"
                    Snapshot = $SnapshotName
                }
                continue
            }

            # Revert to snapshot
            Set-VM -VM $vm -Snapshot $snapshot -Confirm:$false

            $results += @{
                VM = $vm.Name
                Operation = "Revert"
                Status = "Success"
                Message = "Reverted successfully"
                Snapshot = $snapshot.Name
                SnapshotDate = $snapshot.Created
            }

            Write-Host "    ✓ Reverted to snapshot '$SnapshotName'" -ForegroundColor Green
        }
        catch {
            $results += @{
                VM = $vm.Name
                Operation = "Revert"
                Status = "Failed"
                Message = $_.Exception.Message
                Snapshot = $SnapshotName
            }
            Write-Host "    ✗ Failed to revert: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    return $results
}

# Function to delete snapshots
function Remove-VMSnapshot {
    param(
        $VMs,
        $SnapshotName,
        $RemoveChildren,
        $DeleteAll = $false
    )

    $operation = if ($DeleteAll) { "DeleteAll" } else { "Delete" }
    Write-Host "Deleting snapshots from $($VMs.Count) VM(s)..." -ForegroundColor Yellow

    $results = @()

    foreach ($vm in $VMs) {
        try {
            Write-Host "  Processing VM: $($vm.Name)" -ForegroundColor Cyan

            if ($DeleteAll) {
                # Delete all snapshots
                $snapshots = Get-Snapshot -VM $vm -ErrorAction SilentlyContinue
                if ($snapshots) {
                    foreach ($snapshot in $snapshots) {
                        Remove-Snapshot -Snapshot $snapshot -Confirm:$false -RemoveChildren:$RemoveChildren
                    }

                    $results += @{
                        VM = $vm.Name
                        Operation = $operation
                        Status = "Success"
                        Message = "All snapshots deleted"
                        Count = $snapshots.Count
                    }

                    Write-Host "    ✓ Deleted $($snapshots.Count) snapshot(s)" -ForegroundColor Green
                } else {
                    $results += @{
                        VM = $vm.Name
                        Operation = $operation
                        Status = "Skipped"
                        Message = "No snapshots found"
                        Count = 0
                    }
                    Write-Host "    - No snapshots to delete" -ForegroundColor Yellow
                }
            } else {
                # Delete specific snapshot
                $snapshot = Get-Snapshot -VM $vm -Name $SnapshotName -ErrorAction SilentlyContinue
                if (-not $snapshot) {
                    Write-Warning "    Snapshot '$SnapshotName' not found for VM '$($vm.Name)'"
                    $results += @{
                        VM = $vm.Name
                        Operation = $operation
                        Status = "Failed"
                        Message = "Snapshot not found"
                        Snapshot = $SnapshotName
                    }
                    continue
                }

                Remove-Snapshot -Snapshot $snapshot -Confirm:$false -RemoveChildren:$RemoveChildren

                $results += @{
                    VM = $vm.Name
                    Operation = $operation
                    Status = "Success"
                    Message = "Snapshot deleted successfully"
                    Snapshot = $snapshot.Name
                }

                Write-Host "    ✓ Deleted snapshot '$SnapshotName'" -ForegroundColor Green
            }
        }
        catch {
            $results += @{
                VM = $vm.Name
                Operation = $operation
                Status = "Failed"
                Message = $_.Exception.Message
                Snapshot = if ($DeleteAll) { "All" } else { $SnapshotName }
            }
            Write-Host "    ✗ Failed to delete: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    return $results
}

# Function to cleanup old snapshots
function Invoke-SnapshotCleanup {
    param(
        $VMs,
        $MaxSnapshotsPerVM
    )

    Write-Host "Cleaning up old snapshots (keeping max $MaxSnapshotsPerVM per VM)..." -ForegroundColor Yellow

    $results = @()

    foreach ($vm in $VMs) {
        try {
            Write-Host "  Processing VM: $($vm.Name)" -ForegroundColor Cyan

            $snapshots = Get-Snapshot -VM $vm -ErrorAction SilentlyContinue | Sort-Object Created -Descending

            if ($snapshots.Count -le $MaxSnapshotsPerVM) {
                $results += @{
                    VM = $vm.Name
                    Operation = "Cleanup"
                    Status = "Skipped"
                    Message = "Within limit ($($snapshots.Count)/$MaxSnapshotsPerVM)"
                    Deleted = 0
                }
                Write-Host "    - Within limit ($($snapshots.Count)/$MaxSnapshotsPerVM snapshots)" -ForegroundColor Yellow
                continue
            }

            # Delete oldest snapshots
            $snapshotsToDelete = $snapshots | Select-Object -Skip $MaxSnapshotsPerVM
            $deletedCount = 0

            foreach ($snapshot in $snapshotsToDelete) {
                # Don't delete current snapshot
                if (-not $snapshot.IsCurrent) {
                    Remove-Snapshot -Snapshot $snapshot -Confirm:$false
                    $deletedCount++
                    Write-Host "    ✓ Deleted old snapshot: $($snapshot.Name) ($($snapshot.Created))" -ForegroundColor Green
                }
            }

            $results += @{
                VM = $vm.Name
                Operation = "Cleanup"
                Status = "Success"
                Message = "Cleaned up successfully"
                Deleted = $deletedCount
                Remaining = $snapshots.Count - $deletedCount
            }

            Write-Host "    ✓ Deleted $deletedCount old snapshot(s)" -ForegroundColor Green
        }
        catch {
            $results += @{
                VM = $vm.Name
                Operation = "Cleanup"
                Status = "Failed"
                Message = $_.Exception.Message
                Deleted = 0
            }
            Write-Host "    ✗ Failed cleanup: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    return $results
}

# Function to display operation summary
function Show-SnapshotSummary {
    param(
        $Results,
        $Operation
    )

    Write-Host "`n=== $Operation Operation Summary ===" -ForegroundColor Cyan

    $successful = $Results | Where-Object { $_.Status -eq "Success" }
    $failed = $Results | Where-Object { $_.Status -eq "Failed" }
    $skipped = $Results | Where-Object { $_.Status -eq "Skipped" }

    Write-Host "Total VMs: $($Results.Count)" -ForegroundColor White
    Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    Write-Host "Skipped: $($skipped.Count)" -ForegroundColor Yellow

    if ($failed.Count -gt 0) {
        Write-Host "`nFailed Operations:" -ForegroundColor Red
        foreach ($result in $failed) {
            Write-Host "  - $($result.VM): $($result.Message)" -ForegroundColor White
        }
    }

    # Operation-specific summaries
    switch ($Operation) {
        "Create" {
            $totalSize = ($successful | Where-Object { $_.SizeGB } | Measure-Object -Property SizeGB -Sum).Sum
            if ($totalSize -gt 0) {
                Write-Host "`nTotal snapshot size: $([math]::Round($totalSize, 2)) GB" -ForegroundColor Cyan
            }
        }
        "Cleanup" {
            $totalDeleted = ($successful | Measure-Object -Property Deleted -Sum).Sum
            Write-Host "`nTotal snapshots deleted: $totalDeleted" -ForegroundColor Cyan
        }
    }
}

# Main execution
try {
    Write-Host "=== vSphere VM Snapshot Management ===" -ForegroundColor Cyan
    Write-Host "Target vCenter: $VCenterServer" -ForegroundColor White
    Write-Host "Operation: $Operation" -ForegroundColor White

    if ($VMName) { Write-Host "Target VM Pattern: $VMName" -ForegroundColor White }
    if ($VMNames) { Write-Host "Target VMs: $($VMNames -join ', ')" -ForegroundColor White }
    if ($SnapshotName) { Write-Host "Snapshot Name: $SnapshotName" -ForegroundColor White }
    Write-Host ""

    # Validate required parameters
    if ($Operation -in @("Create", "Revert", "Delete") -and -not $SnapshotName) {
        throw "SnapshotName parameter is required for $Operation operation"
    }

    # Check and install PowerCLI
    if (-not (Test-PowerCLIInstallation)) {
        throw "PowerCLI installation failed"
    }

    # Connect to vCenter
    $connection = Connect-ToVCenter -Server $VCenterServer

    # Get target VMs
    $targetVMs = Get-TargetVMs -VMName $VMName -VMNames $VMNames

    # Confirm operation if not using Force and operation is destructive
    if (-not $Force -and $Operation -in @("Delete", "DeleteAll", "Cleanup", "Revert")) {
        $confirmation = Read-Host "`nProceed with $Operation operation on $($targetVMs.Count) VM(s)? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Perform the snapshot operation
    $results = @()
    switch ($Operation) {
        "Create" {
            $results = New-VMSnapshot -VMs $targetVMs -SnapshotName $SnapshotName -SnapshotDescription $SnapshotDescription -Memory $Memory -Quiesce $Quiesce
        }
        "List" {
            $results = Get-VMSnapshotList -VMs $targetVMs
        }
        "Revert" {
            $results = Restore-VMSnapshot -VMs $targetVMs -SnapshotName $SnapshotName
        }
        "Delete" {
            $results = Remove-VMSnapshot -VMs $targetVMs -SnapshotName $SnapshotName -RemoveChildren:$RemoveChildren
        }
        "DeleteAll" {
            $results = Remove-VMSnapshot -VMs $targetVMs -RemoveChildren:$RemoveChildren -DeleteAll $true
        }
        "Cleanup" {
            $results = Invoke-SnapshotCleanup -VMs $targetVMs -MaxSnapshotsPerVM $MaxSnapshotsPerVM
        }
    }

    # Display summary (except for List operation which already displays results)
    if ($Operation -ne "List") {
        Show-SnapshotSummary -Results $results -Operation $Operation
    }

    Write-Host "`n=== Operation Completed ===" -ForegroundColor Green
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Disconnect from vCenter if connected
    if ($global:DefaultVIServers) {
        Write-Host "`nDisconnecting from vCenter..." -ForegroundColor Yellow
        Disconnect-VIServer -Server * -Confirm:$false -Force
    }
}
