<#
.SYNOPSIS
    Manages VM power operations in vSphere using PowerCLI.

.DESCRIPTION
    This script provides comprehensive VM power management including start, stop, reboot,
    suspend, and graceful shutdown operations. Supports single VMs, multiple VMs, and
    batch operations with safety checks and confirmation prompts.
    Requires VMware PowerCLI and connection to vCenter Server.

.PARAMETER VCenterServer
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER VMName
    The name of the virtual machine. Supports wildcards.

.PARAMETER VMNames
    An array of specific VM names for batch operations.

.PARAMETER ClusterName
    Target all VMs in a specific cluster.

.PARAMETER ResourcePoolName
    Target all VMs in a specific resource pool.

.PARAMETER Operation
    The power operation to perform.

.PARAMETER WaitForCompletion
    Wait for the operation to complete before continuing.

.PARAMETER TimeoutMinutes
    Timeout in minutes for operations (default: 10).

.PARAMETER Force
    Force operations without confirmation prompts.

.PARAMETER GracefulShutdown
    Use graceful shutdown instead of hard power off (requires VMware Tools).

.PARAMETER CreateSnapshot
    Create a snapshot before power operations (recommended for Stop/Reboot).

.PARAMETER SnapshotName
    Name for the snapshot (if CreateSnapshot is used).

.PARAMETER PowerOnSequence
    Power on VMs in sequence with delay between each VM.

.PARAMETER SequenceDelay
    Delay in seconds between VMs when using PowerOnSequence (default: 30).

.PARAMETER ExcludeVMs
    Array of VM names to exclude from batch operations.

.PARAMETER OutputFormat
    Output format for reports.

.PARAMETER OutputPath
    Path to save the report file (optional).

.EXAMPLE
    .\vsphere-cli-vm-power-operations.ps1 -VCenterServer "vcenter.domain.com" -VMName "WebServer01" -Operation "Start"

.EXAMPLE
    .\vsphere-cli-vm-power-operations.ps1 -VCenterServer "vcenter.domain.com" -VMNames @("Web01","Web02") -Operation "Reboot" -GracefulShutdown -CreateSnapshot -SnapshotName "BeforeReboot"

.EXAMPLE
    .\vsphere-cli-vm-power-operations.ps1 -VCenterServer "vcenter.domain.com" -ClusterName "Production" -Operation "Stop" -GracefulShutdown -Force

.EXAMPLE
    .\vsphere-cli-vm-power-operations.ps1 -VCenterServer "vcenter.domain.com" -ResourcePoolName "TestEnvironment" -Operation "Start" -PowerOnSequence -SequenceDelay 60

.EXAMPLE
    .\vsphere-cli-vm-power-operations.ps1 -VCenterServer "vcenter.domain.com" -Operation "Status" -OutputFormat "CSV" -OutputPath "vm-power-status.csv"

.NOTES
    Author: XOAP.io
    Requires: VMware PowerCLI 13.x or later, vSphere 7.0 or later, VMware Tools (for graceful operations)

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

    [Parameter(Mandatory = $false)]
    [string]$ClusterName,

    [Parameter(Mandatory = $false)]
    [string]$ResourcePoolName,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Start", "Stop", "Reboot", "Suspend", "Reset", "Status", "GracefulShutdown", "PowerOnSequence")]
    [string]$Operation,

    [Parameter(Mandatory = $false)]
    [switch]$WaitForCompletion,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 60)]
    [int]$TimeoutMinutes = 10,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$GracefulShutdown,

    [Parameter(Mandatory = $false)]
    [switch]$CreateSnapshot,

    [Parameter(Mandatory = $false)]
    [string]$SnapshotName,

    [Parameter(Mandatory = $false)]
    [switch]$PowerOnSequence,

    [Parameter(Mandatory = $false)]
    [ValidateRange(10, 300)]
    [int]$SequenceDelay = 30,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeVMs,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "CSV", "JSON")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
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
        $VMNames,
        $ClusterName,
        $ResourcePoolName,
        $ExcludeVMs
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
        elseif ($ClusterName) {
            # All VMs in cluster
            $cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
            if (-not $cluster) {
                throw "Cluster '$ClusterName' not found"
            }
            $targetVMs = Get-VM -Location $cluster
        }
        elseif ($ResourcePoolName) {
            # All VMs in resource pool
            $resourcePool = Get-ResourcePool -Name $ResourcePoolName -ErrorAction SilentlyContinue
            if (-not $resourcePool) {
                throw "Resource pool '$ResourcePoolName' not found"
            }
            $targetVMs = Get-VM -Location $resourcePool
        }
        else {
            # All VMs (use with caution)
            $targetVMs = Get-VM
        }

        # Exclude specified VMs
        if ($ExcludeVMs) {
            $targetVMs = $targetVMs | Where-Object { $_.Name -notin $ExcludeVMs }
            Write-Host "Excluded $($ExcludeVMs.Count) VM(s) from operation" -ForegroundColor Gray
        }

        if (-not $targetVMs) {
            throw "No VMs found matching the specified criteria"
        }

        Write-Host "Found $($targetVMs.Count) VM(s) matching criteria:" -ForegroundColor Green
        foreach ($vm in $targetVMs) {
            $toolsStatus = if ($vm.ExtensionData.Guest.ToolsStatus) { $vm.ExtensionData.Guest.ToolsStatus } else { "Unknown" }
            Write-Host "  - $($vm.Name) [$($vm.PowerState)] [Tools: $toolsStatus]" -ForegroundColor White
        }

        return $targetVMs
    }
    catch {
        Write-Error "Failed to get target VMs: $($_.Exception.Message)"
        throw
    }
}

# Function to check VMware Tools status
function Test-VMwareToolsStatus {
    param($VM)

    $toolsStatus = $VM.ExtensionData.Guest.ToolsStatus
    $toolsRunning = $VM.ExtensionData.Guest.ToolsRunningStatus

    return @{
        Status = $toolsStatus
        Running = $toolsRunning
        IsInstalled = $toolsStatus -in @("toolsOk", "toolsOld", "toolsNotRunning")
        IsRunning = $toolsRunning -eq "guestToolsRunning"
    }
}

# Function to create snapshot before power operation
function New-PowerOperationSnapshot {
    param(
        $VM,
        $SnapshotName,
        $Operation
    )

    try {
        if (-not $SnapshotName) {
            $SnapshotName = "Before$Operation-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        }

        Write-Host "      Creating snapshot '$SnapshotName'..." -ForegroundColor Gray

        # Check if snapshot already exists
        $existingSnapshot = Get-Snapshot -VM $VM -Name $SnapshotName -ErrorAction SilentlyContinue
        if ($existingSnapshot) {
            Write-Warning "      Snapshot '$SnapshotName' already exists"
            return $existingSnapshot
        }

        $snapshot = New-Snapshot -VM $VM -Name $SnapshotName -Description "Auto-created before $Operation operation" -Memory:$true -Quiesce:$true
        Write-Host "      ✓ Snapshot created: $($snapshot.Name)" -ForegroundColor Green
        return $snapshot
    }
    catch {
        Write-Warning "      Failed to create snapshot: $($_.Exception.Message)"
        return $null
    }
}

# Function to start VMs
function Start-VMPowerOperation {
    param(
        $VMs,
        $WaitForCompletion,
        $TimeoutMinutes,
        $PowerOnSequence,
        $SequenceDelay,
        $CreateSnapshot,
        $SnapshotName
    )

    Write-Host "Starting $($VMs.Count) VM(s)..." -ForegroundColor Yellow

    $results = @()
    $startTasks = @()

    foreach ($vm in $VMs) {
        try {
            Write-Host "  Processing VM: $($vm.Name)" -ForegroundColor Cyan

            # Check current power state
            if ($vm.PowerState -eq "PoweredOn") {
                Write-Host "    VM is already powered on" -ForegroundColor Yellow
                $results += @{
                    VM = $vm.Name
                    Operation = "Start"
                    Status = "AlreadyRunning"
                    Message = "VM is already powered on"
                    PowerState = $vm.PowerState
                }
                continue
            }

            # Create snapshot if requested
            if ($CreateSnapshot) {
                New-PowerOperationSnapshot -VM $vm -SnapshotName $SnapshotName -Operation "Start" | Out-Null
            }

            # Start the VM
            $startTask = Start-VM -VM $vm -RunAsync
            $startTasks += @{
                Task = $startTask
                VM = $vm
                StartTime = Get-Date
            }

            Write-Host "    ✓ Start task initiated" -ForegroundColor Green

            # Sequential startup with delay
            if ($PowerOnSequence -and $vm -ne $VMs[-1]) {
                Write-Host "    Waiting $SequenceDelay seconds before next VM..." -ForegroundColor Gray
                Start-Sleep -Seconds $SequenceDelay
            }
        }
        catch {
            $results += @{
                VM = $vm.Name
                Operation = "Start"
                Status = "Failed"
                Message = $_.Exception.Message
                PowerState = $vm.PowerState
            }
            Write-Host "    ✗ Failed to start: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Wait for completion if requested
    if ($WaitForCompletion -and $startTasks.Count -gt 0) {
        Write-Host "`nWaiting for VM start operations to complete..." -ForegroundColor Yellow

        foreach ($taskInfo in $startTasks) {
            try {
                $timeoutSeconds = $TimeoutMinutes * 60
                Wait-Task -Task $taskInfo.Task -TimeoutSeconds $timeoutSeconds | Out-Null

                # Refresh VM state
                $vm = Get-VM -Name $taskInfo.VM.Name
                $duration = [math]::Round((Get-Date).Subtract($taskInfo.StartTime).TotalSeconds, 1)

                $results += @{
                    VM = $vm.Name
                    Operation = "Start"
                    Status = "Success"
                    Message = "VM started successfully"
                    PowerState = $vm.PowerState
                    Duration = "$duration seconds"
                }

                Write-Host "  ✓ $($vm.Name) started successfully ($duration seconds)" -ForegroundColor Green
            }
            catch {
                $results += @{
                    VM = $taskInfo.VM.Name
                    Operation = "Start"
                    Status = "Timeout"
                    Message = "Operation timed out after $TimeoutMinutes minutes"
                    PowerState = "Unknown"
                }
                Write-Host "  ✗ $($taskInfo.VM.Name) timed out" -ForegroundColor Red
            }
        }
    } else {
        # Add async results
        foreach ($taskInfo in $startTasks) {
            $results += @{
                VM = $taskInfo.VM.Name
                Operation = "Start"
                Status = "InProgress"
                Message = "Start task initiated"
                PowerState = "Starting"
                TaskId = $taskInfo.Task.Id
            }
        }
    }

    return $results
}

# Function to stop VMs
function Stop-VMPowerOperation {
    param(
        $VMs,
        $WaitForCompletion,
        $TimeoutMinutes,
        $GracefulShutdown,
        $CreateSnapshot,
        $SnapshotName
    )

    $operation = if ($GracefulShutdown) { "GracefulShutdown" } else { "Stop" }
    Write-Host "Stopping $($VMs.Count) VM(s) [Method: $operation]..." -ForegroundColor Yellow

    $results = @()
    $stopTasks = @()

    foreach ($vm in $VMs) {
        try {
            Write-Host "  Processing VM: $($vm.Name)" -ForegroundColor Cyan

            # Check current power state
            if ($vm.PowerState -eq "PoweredOff") {
                Write-Host "    VM is already powered off" -ForegroundColor Yellow
                $results += @{
                    VM = $vm.Name
                    Operation = $operation
                    Status = "AlreadyStopped"
                    Message = "VM is already powered off"
                    PowerState = $vm.PowerState
                }
                continue
            }

            # Create snapshot if requested
            if ($CreateSnapshot) {
                New-PowerOperationSnapshot -VM $vm -SnapshotName $SnapshotName -Operation $operation | Out-Null
            }

            # Check VMware Tools for graceful shutdown
            if ($GracefulShutdown) {
                $toolsStatus = Test-VMwareToolsStatus -VM $vm
                if (-not $toolsStatus.IsRunning) {
                    Write-Warning "    VMware Tools not running, falling back to hard power off"
                    $stopTask = Stop-VM -VM $vm -Kill -RunAsync
                } else {
                    Write-Host "    Initiating graceful shutdown..." -ForegroundColor Gray
                    $stopTask = Stop-VM -VM $vm -RunAsync
                }
            } else {
                $stopTask = Stop-VM -VM $vm -Kill -RunAsync
            }

            $stopTasks += @{
                Task = $stopTask
                VM = $vm
                StartTime = Get-Date
                Method = if ($GracefulShutdown -and (Test-VMwareToolsStatus -VM $vm).IsRunning) { "Graceful" } else { "Hard" }
            }

            Write-Host "    ✓ Stop task initiated" -ForegroundColor Green
        }
        catch {
            $results += @{
                VM = $vm.Name
                Operation = $operation
                Status = "Failed"
                Message = $_.Exception.Message
                PowerState = $vm.PowerState
            }
            Write-Host "    ✗ Failed to stop: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Wait for completion if requested
    if ($WaitForCompletion -and $stopTasks.Count -gt 0) {
        Write-Host "`nWaiting for VM stop operations to complete..." -ForegroundColor Yellow

        foreach ($taskInfo in $stopTasks) {
            try {
                $timeoutSeconds = $TimeoutMinutes * 60
                Wait-Task -Task $taskInfo.Task -TimeoutSeconds $timeoutSeconds | Out-Null

                # Refresh VM state
                $vm = Get-VM -Name $taskInfo.VM.Name
                $duration = [math]::Round((Get-Date).Subtract($taskInfo.StartTime).TotalSeconds, 1)

                $results += @{
                    VM = $vm.Name
                    Operation = $operation
                    Status = "Success"
                    Message = "VM stopped successfully"
                    PowerState = $vm.PowerState
                    Duration = "$duration seconds"
                    Method = $taskInfo.Method
                }

                Write-Host "  ✓ $($vm.Name) stopped successfully [$($taskInfo.Method), $duration seconds]" -ForegroundColor Green
            }
            catch {
                $results += @{
                    VM = $taskInfo.VM.Name
                    Operation = $operation
                    Status = "Timeout"
                    Message = "Operation timed out after $TimeoutMinutes minutes"
                    PowerState = "Unknown"
                    Method = $taskInfo.Method
                }
                Write-Host "  ✗ $($taskInfo.VM.Name) timed out" -ForegroundColor Red
            }
        }
    } else {
        # Add async results
        foreach ($taskInfo in $stopTasks) {
            $results += @{
                VM = $taskInfo.VM.Name
                Operation = $operation
                Status = "InProgress"
                Message = "Stop task initiated"
                PowerState = "Stopping"
                TaskId = $taskInfo.Task.Id
                Method = $taskInfo.Method
            }
        }
    }

    return $results
}

# Function to reboot VMs
function Restart-VMPowerOperation {
    param(
        $VMs,
        $WaitForCompletion,
        $TimeoutMinutes,
        $GracefulShutdown,
        $CreateSnapshot,
        $SnapshotName
    )

    Write-Host "Rebooting $($VMs.Count) VM(s)..." -ForegroundColor Yellow

    $results = @()
    $rebootTasks = @()

    foreach ($vm in $VMs) {
        try {
            Write-Host "  Processing VM: $($vm.Name)" -ForegroundColor Cyan

            # Check current power state
            if ($vm.PowerState -eq "PoweredOff") {
                Write-Host "    VM is powered off, starting instead of rebooting" -ForegroundColor Yellow
                $startTask = Start-VM -VM $vm -RunAsync
                $rebootTasks += @{
                    Task = $startTask
                    VM = $vm
                    StartTime = Get-Date
                    Operation = "Start"
                }
                continue
            }

            # Create snapshot if requested
            if ($CreateSnapshot) {
                New-PowerOperationSnapshot -VM $vm -SnapshotName $SnapshotName -Operation "Reboot" | Out-Null
            }

            # Check VMware Tools for graceful reboot
            if ($GracefulShutdown) {
                $toolsStatus = Test-VMwareToolsStatus -VM $vm
                if (-not $toolsStatus.IsRunning) {
                    Write-Warning "    VMware Tools not running, falling back to hard reboot"
                    $rebootTask = Restart-VM -VM $vm -RunAsync
                } else {
                    Write-Host "    Initiating graceful reboot..." -ForegroundColor Gray
                    $rebootTask = Restart-VMGuest -VM $vm -Confirm:$false
                    # Note: Restart-VMGuest doesn't return a task, so we'll track differently
                    $rebootTasks += @{
                        Task = $null
                        VM = $vm
                        StartTime = Get-Date
                        Operation = "GracefulReboot"
                    }
                    continue
                }
            } else {
                $rebootTask = Restart-VM -VM $vm -RunAsync
            }

            $rebootTasks += @{
                Task = $rebootTask
                VM = $vm
                StartTime = Get-Date
                Operation = "Reboot"
            }

            Write-Host "    ✓ Reboot task initiated" -ForegroundColor Green
        }
        catch {
            $results += @{
                VM = $vm.Name
                Operation = "Reboot"
                Status = "Failed"
                Message = $_.Exception.Message
                PowerState = $vm.PowerState
            }
            Write-Host "    ✗ Failed to reboot: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Wait for completion if requested
    if ($WaitForCompletion -and $rebootTasks.Count -gt 0) {
        Write-Host "`nWaiting for VM reboot operations to complete..." -ForegroundColor Yellow

        foreach ($taskInfo in $rebootTasks) {
            try {
                if ($taskInfo.Task) {
                    $timeoutSeconds = $TimeoutMinutes * 60
                    Wait-Task -Task $taskInfo.Task -TimeoutSeconds $timeoutSeconds | Out-Null
                } else {
                    # For graceful reboots, wait and monitor VM state
                    $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
                    while ((Get-Date) -lt $timeout) {
                        Start-Sleep -Seconds 10
                        $vm = Get-VM -Name $taskInfo.VM.Name
                        if ($vm.PowerState -eq "PoweredOn") {
                            break
                        }
                    }
                }

                # Refresh VM state
                $vm = Get-VM -Name $taskInfo.VM.Name
                $duration = [math]::Round((Get-Date).Subtract($taskInfo.StartTime).TotalSeconds, 1)

                $results += @{
                    VM = $vm.Name
                    Operation = $taskInfo.Operation
                    Status = "Success"
                    Message = "VM rebooted successfully"
                    PowerState = $vm.PowerState
                    Duration = "$duration seconds"
                }

                Write-Host "  ✓ $($vm.Name) rebooted successfully ($duration seconds)" -ForegroundColor Green
            }
            catch {
                $results += @{
                    VM = $taskInfo.VM.Name
                    Operation = $taskInfo.Operation
                    Status = "Timeout"
                    Message = "Operation timed out after $TimeoutMinutes minutes"
                    PowerState = "Unknown"
                }
                Write-Host "  ✗ $($taskInfo.VM.Name) timed out" -ForegroundColor Red
            }
        }
    } else {
        # Add async results
        foreach ($taskInfo in $rebootTasks) {
            $results += @{
                VM = $taskInfo.VM.Name
                Operation = $taskInfo.Operation
                Status = "InProgress"
                Message = "Reboot task initiated"
                PowerState = "Rebooting"
                TaskId = if ($taskInfo.Task) { $taskInfo.Task.Id } else { "N/A" }
            }
        }
    }

    return $results
}

# Function to suspend VMs
function Suspend-VMPowerOperation {
    param(
        $VMs,
        $WaitForCompletion,
        $TimeoutMinutes,
        $CreateSnapshot,
        $SnapshotName
    )

    Write-Host "Suspending $($VMs.Count) VM(s)..." -ForegroundColor Yellow

    $results = @()
    $suspendTasks = @()

    foreach ($vm in $VMs) {
        try {
            Write-Host "  Processing VM: $($vm.Name)" -ForegroundColor Cyan

            # Check current power state
            if ($vm.PowerState -eq "Suspended") {
                Write-Host "    VM is already suspended" -ForegroundColor Yellow
                $results += @{
                    VM = $vm.Name
                    Operation = "Suspend"
                    Status = "AlreadySuspended"
                    Message = "VM is already suspended"
                    PowerState = $vm.PowerState
                }
                continue
            }

            if ($vm.PowerState -eq "PoweredOff") {
                Write-Host "    VM is powered off, cannot suspend" -ForegroundColor Yellow
                $results += @{
                    VM = $vm.Name
                    Operation = "Suspend"
                    Status = "InvalidState"
                    Message = "Cannot suspend a powered off VM"
                    PowerState = $vm.PowerState
                }
                continue
            }

            # Create snapshot if requested
            if ($CreateSnapshot) {
                New-PowerOperationSnapshot -VM $vm -SnapshotName $SnapshotName -Operation "Suspend" | Out-Null
            }

            # Suspend the VM
            $suspendTask = Suspend-VM -VM $vm -RunAsync
            $suspendTasks += @{
                Task = $suspendTask
                VM = $vm
                StartTime = Get-Date
            }

            Write-Host "    ✓ Suspend task initiated" -ForegroundColor Green
        }
        catch {
            $results += @{
                VM = $vm.Name
                Operation = "Suspend"
                Status = "Failed"
                Message = $_.Exception.Message
                PowerState = $vm.PowerState
            }
            Write-Host "    ✗ Failed to suspend: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Wait for completion if requested
    if ($WaitForCompletion -and $suspendTasks.Count -gt 0) {
        Write-Host "`nWaiting for VM suspend operations to complete..." -ForegroundColor Yellow

        foreach ($taskInfo in $suspendTasks) {
            try {
                $timeoutSeconds = $TimeoutMinutes * 60
                Wait-Task -Task $taskInfo.Task -TimeoutSeconds $timeoutSeconds | Out-Null

                # Refresh VM state
                $vm = Get-VM -Name $taskInfo.VM.Name
                $duration = [math]::Round((Get-Date).Subtract($taskInfo.StartTime).TotalSeconds, 1)

                $results += @{
                    VM = $vm.Name
                    Operation = "Suspend"
                    Status = "Success"
                    Message = "VM suspended successfully"
                    PowerState = $vm.PowerState
                    Duration = "$duration seconds"
                }

                Write-Host "  ✓ $($vm.Name) suspended successfully ($duration seconds)" -ForegroundColor Green
            }
            catch {
                $results += @{
                    VM = $taskInfo.VM.Name
                    Operation = "Suspend"
                    Status = "Timeout"
                    Message = "Operation timed out after $TimeoutMinutes minutes"
                    PowerState = "Unknown"
                }
                Write-Host "  ✗ $($taskInfo.VM.Name) timed out" -ForegroundColor Red
            }
        }
    } else {
        # Add async results
        foreach ($taskInfo in $suspendTasks) {
            $results += @{
                VM = $taskInfo.VM.Name
                Operation = "Suspend"
                Status = "InProgress"
                Message = "Suspend task initiated"
                PowerState = "Suspending"
                TaskId = $taskInfo.Task.Id
            }
        }
    }

    return $results
}

# Function to get VM power status
function Get-VMPowerStatus {
    param(
        $VMs,
        $OutputFormat,
        $OutputPath
    )

    Write-Host "Getting power status for $($VMs.Count) VM(s)..." -ForegroundColor Yellow

    $statusData = @()

    foreach ($vm in $VMs) {
        try {
            $toolsStatus = Test-VMwareToolsStatus -VM $vm
            $uptime = "N/A"

            if ($vm.PowerState -eq "PoweredOn" -and $vm.ExtensionData.Guest.BootTime) {
                $bootTime = $vm.ExtensionData.Guest.BootTime
                $uptimeSpan = (Get-Date).Subtract($bootTime)
                $uptime = "$([math]::Floor($uptimeSpan.TotalDays))d $($uptimeSpan.Hours)h $($uptimeSpan.Minutes)m"
            }

            $statusItem = [PSCustomObject]@{
                VMName = $vm.Name
                PowerState = $vm.PowerState
                ToolsStatus = $toolsStatus.Status
                ToolsRunning = $toolsStatus.IsRunning
                GuestOS = $vm.Guest.OSFullName
                Host = $vm.VMHost.Name
                Cluster = $vm.VMHost.Parent.Name
                ResourcePool = $vm.ResourcePool.Name
                CPUs = $vm.NumCpu
                MemoryGB = $vm.MemoryGB
                UsedSpaceGB = [math]::Round($vm.UsedSpaceGB, 2)
                ProvisionedSpaceGB = [math]::Round($vm.ProvisionedSpaceGB, 2)
                Uptime = $uptime
                LastBootTime = if ($vm.ExtensionData.Guest.BootTime) { $vm.ExtensionData.Guest.BootTime } else { "N/A" }
                Timestamp = Get-Date
            }

            $statusData += $statusItem
        }
        catch {
            Write-Warning "Failed to get status for VM '$($vm.Name)': $($_.Exception.Message)"
        }
    }

    # Export status
    switch ($OutputFormat) {
        "Console" {
            Write-Host "`n=== VM Power Status Report ===" -ForegroundColor Cyan
            $statusData | Format-Table VMName, PowerState, ToolsRunning, GuestOS, Host, Uptime -AutoSize
        }
        "CSV" {
            if (-not $OutputPath) {
                $OutputPath = "VM_Power_Status_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            }
            $statusData | Export-Csv -Path $OutputPath -NoTypeInformation
            Write-Host "Status report exported to: $OutputPath" -ForegroundColor Green
        }
        "JSON" {
            if (-not $OutputPath) {
                $OutputPath = "VM_Power_Status_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            }
            $statusData | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "Status report exported to: $OutputPath" -ForegroundColor Green
        }
    }

    return $statusData
}

# Function to display operation summary
function Show-PowerOperationSummary {
    param(
        $Results,
        $Operation
    )

    Write-Host "`n=== Power $Operation Summary ===" -ForegroundColor Cyan

    $successful = $Results | Where-Object { $_.Status -eq "Success" }
    $failed = $Results | Where-Object { $_.Status -eq "Failed" }
    $inProgress = $Results | Where-Object { $_.Status -eq "InProgress" }
    $skipped = $Results | Where-Object { $_.Status -in @("AlreadyRunning", "AlreadyStopped", "AlreadySuspended", "InvalidState") }
    $timeout = $Results | Where-Object { $_.Status -eq "Timeout" }

    Write-Host "Total VMs: $($Results.Count)" -ForegroundColor White
    Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    Write-Host "In Progress: $($inProgress.Count)" -ForegroundColor Yellow
    Write-Host "Skipped: $($skipped.Count)" -ForegroundColor Yellow
    Write-Host "Timed Out: $($timeout.Count)" -ForegroundColor Red

    if ($failed.Count -gt 0) {
        Write-Host "`nFailed Operations:" -ForegroundColor Red
        foreach ($result in $failed) {
            Write-Host "  - $($result.VM): $($result.Message)" -ForegroundColor White
        }
    }

    if ($timeout.Count -gt 0) {
        Write-Host "`nTimed Out Operations:" -ForegroundColor Red
        foreach ($result in $timeout) {
            Write-Host "  - $($result.VM): $($result.Message)" -ForegroundColor White
        }
    }

    # Show average duration if available
    $withDuration = $successful | Where-Object { $_.Duration }
    if ($withDuration.Count -gt 0) {
        $avgDuration = ($withDuration | ForEach-Object {
            [double]($_.Duration -replace ' seconds', '')
        } | Measure-Object -Average).Average
        Write-Host "`nAverage operation time: $([math]::Round($avgDuration, 1)) seconds" -ForegroundColor Cyan
    }
}

# Main execution
try {
    Write-Host "=== vSphere VM Power Operations ===" -ForegroundColor Cyan
    Write-Host "Target vCenter: $VCenterServer" -ForegroundColor White
    Write-Host "Operation: $Operation" -ForegroundColor White

    if ($VMName) { Write-Host "Target VM Pattern: $VMName" -ForegroundColor White }
    if ($VMNames) { Write-Host "Target VMs: $($VMNames -join ', ')" -ForegroundColor White }
    if ($ClusterName) { Write-Host "Target Cluster: $ClusterName" -ForegroundColor White }
    if ($ResourcePoolName) { Write-Host "Target Resource Pool: $ResourcePoolName" -ForegroundColor White }
    if ($GracefulShutdown) { Write-Host "Using graceful shutdown/reboot" -ForegroundColor White }
    if ($CreateSnapshot) { Write-Host "Creating snapshots before operations" -ForegroundColor White }
    Write-Host ""

    # Check and install PowerCLI
    if (-not (Test-PowerCLIInstallation)) {
        throw "PowerCLI installation failed"
    }

    # Connect to vCenter
    $connection = Connect-ToVCenter -Server $VCenterServer

    # Get target VMs
    $targetVMs = Get-TargetVMs -VMName $VMName -VMNames $VMNames -ClusterName $ClusterName -ResourcePoolName $ResourcePoolName -ExcludeVMs $ExcludeVMs

    # Confirm operation if not using Force and operation is potentially disruptive
    if (-not $Force -and $Operation -in @("Stop", "Reboot", "Suspend", "Reset", "GracefulShutdown") -and $targetVMs.Count -gt 1) {
        $confirmation = Read-Host "`nProceed with $Operation operation on $($targetVMs.Count) VM(s)? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Perform the power operation
    $results = @()
    switch ($Operation) {
        "Start" {
            $results = Start-VMPowerOperation -VMs $targetVMs -WaitForCompletion:$WaitForCompletion -TimeoutMinutes $TimeoutMinutes -PowerOnSequence:$PowerOnSequence -SequenceDelay $SequenceDelay -CreateSnapshot:$CreateSnapshot -SnapshotName $SnapshotName
        }
        "PowerOnSequence" {
            $results = Start-VMPowerOperation -VMs $targetVMs -WaitForCompletion:$true -TimeoutMinutes $TimeoutMinutes -PowerOnSequence:$true -SequenceDelay $SequenceDelay -CreateSnapshot:$CreateSnapshot -SnapshotName $SnapshotName
        }
        "Stop" {
            $results = Stop-VMPowerOperation -VMs $targetVMs -WaitForCompletion:$WaitForCompletion -TimeoutMinutes $TimeoutMinutes -GracefulShutdown:$false -CreateSnapshot:$CreateSnapshot -SnapshotName $SnapshotName
        }
        "GracefulShutdown" {
            $results = Stop-VMPowerOperation -VMs $targetVMs -WaitForCompletion:$WaitForCompletion -TimeoutMinutes $TimeoutMinutes -GracefulShutdown:$true -CreateSnapshot:$CreateSnapshot -SnapshotName $SnapshotName
        }
        "Reboot" {
            $results = Restart-VMPowerOperation -VMs $targetVMs -WaitForCompletion:$WaitForCompletion -TimeoutMinutes $TimeoutMinutes -GracefulShutdown:$GracefulShutdown -CreateSnapshot:$CreateSnapshot -SnapshotName $SnapshotName
        }
        "Suspend" {
            $results = Suspend-VMPowerOperation -VMs $targetVMs -WaitForCompletion:$WaitForCompletion -TimeoutMinutes $TimeoutMinutes -CreateSnapshot:$CreateSnapshot -SnapshotName $SnapshotName
        }
        "Reset" {
            Write-Host "Performing hard reset on $($targetVMs.Count) VM(s)..." -ForegroundColor Yellow
            foreach ($vm in $targetVMs) {
                try {
                    Write-Host "  Resetting VM: $($vm.Name)" -ForegroundColor Cyan
                    if ($CreateSnapshot) {
                        New-PowerOperationSnapshot -VM $vm -SnapshotName $SnapshotName -Operation "Reset" | Out-Null
                    }
                    Reset-VM -VM $vm -Confirm:$false
                    $results += @{
                        VM = $vm.Name
                        Operation = "Reset"
                        Status = "Success"
                        Message = "VM reset successfully"
                        PowerState = $vm.PowerState
                    }
                    Write-Host "    ✓ VM reset successfully" -ForegroundColor Green
                }
                catch {
                    $results += @{
                        VM = $vm.Name
                        Operation = "Reset"
                        Status = "Failed"
                        Message = $_.Exception.Message
                        PowerState = $vm.PowerState
                    }
                    Write-Host "    ✗ Failed to reset: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        "Status" {
            $results = Get-VMPowerStatus -VMs $targetVMs -OutputFormat $OutputFormat -OutputPath $OutputPath
        }
    }

    # Display summary (except for Status operation which already displays results)
    if ($Operation -ne "Status") {
        Show-PowerOperationSummary -Results $results -Operation $Operation
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
