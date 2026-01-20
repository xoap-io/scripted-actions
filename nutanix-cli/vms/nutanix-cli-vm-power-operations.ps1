<#
.SYNOPSIS
    Manages VM power operations in Nutanix AHV using Nutanix PowerShell SDK.

.DESCRIPTION
    This script provides comprehensive VM power management including start, stop, reboot,
    suspend, and graceful shutdown operations. Supports single VMs, multiple VMs, and
    batch operations with safety checks and confirmation prompts.
    Requires Nutanix PowerShell SDK and connection to Prism Central/Element.

.PARAMETER PrismCentral
    The Prism Central FQDN or IP address to connect to.

.PARAMETER PrismElement
    The Prism Element FQDN or IP address to connect to (alternative to Prism Central).

.PARAMETER VMName
    The name of the virtual machine. Supports wildcards.

.PARAMETER VMNames
    An array of specific VM names for batch operations.

.PARAMETER VMUUID
    The UUID of a specific VM (alternative to name).

.PARAMETER VMUUIDs
    An array of VM UUIDs for batch operations.

.PARAMETER ClusterName
    Target all VMs in a specific cluster.

.PARAMETER ClusterUUID
    Target all VMs in a specific cluster by UUID.

.PARAMETER Operation
    The power operation to perform.

.PARAMETER WaitForCompletion
    Wait for the operation to complete before continuing.

.PARAMETER TimeoutMinutes
    Timeout in minutes for operations (default: 10).

.PARAMETER Force
    Force operations without confirmation prompts.

.PARAMETER GracefulShutdown
    Use graceful shutdown instead of hard power off (requires NGT).

.PARAMETER CreateSnapshot
    Create a snapshot before power operations (recommended for Stop/Reboot).

.PARAMETER SnapshotName
    Name for the snapshot (if CreateSnapshot is used).

.PARAMETER SequentialStartup
    Power on VMs in sequence with delay between each VM.

.PARAMETER StartupDelay
    Delay in seconds between VMs when using SequentialStartup (default: 30).

.PARAMETER ExcludeVMs
    Array of VM names to exclude from batch operations.

.PARAMETER OutputFormat
    Output format for reports.

.PARAMETER OutputPath
    Path to save the report file (optional).

.EXAMPLE
    .\nutanix-cli-vm-power-operations.ps1 -PrismCentral "pc.domain.com" -VMName "WebServer01" -Operation "Start"

.EXAMPLE
    .\nutanix-cli-vm-power-operations.ps1 -PrismCentral "pc.domain.com" -VMNames @("Web01","Web02") -Operation "Reboot" -GracefulShutdown -CreateSnapshot -SnapshotName "BeforeReboot"

.EXAMPLE
    .\nutanix-cli-vm-power-operations.ps1 -PrismCentral "pc.domain.com" -ClusterName "Production" -Operation "Stop" -GracefulShutdown -Force

.EXAMPLE
    .\nutanix-cli-vm-power-operations.ps1 -PrismCentral "pc.domain.com" -VMNames @("app01", "app02") -Operation "Start" -SequentialStartup -StartupDelay 60

.EXAMPLE
    .\nutanix-cli-vm-power-operations.ps1 -PrismCentral "pc.domain.com" -Operation "Status" -OutputFormat "CSV" -OutputPath "vm-power-status.csv"

.NOTES
    Author: XOAP.io
    Requires: Nutanix PowerShell SDK, AOS 6.0+, NGT (for graceful operations)

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, ParameterSetName = "PrismCentral")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismCentral,

    [Parameter(Mandatory = $false, ParameterSetName = "PrismElement")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismElement,

    [Parameter(Mandatory = $false, ParameterSetName = "SingleVM")]
    [ValidateNotNullOrEmpty()]
    [string]$VMName,

    [Parameter(Mandatory = $false, ParameterSetName = "MultipleVMs")]
    [ValidateNotNullOrEmpty()]
    [string[]]$VMNames,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$VMUUID,

    [Parameter(Mandatory = $false)]
    [ValidateScript({
        foreach ($uuid in $_) {
            if ($uuid -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                throw "Invalid UUID format: $uuid"
            }
        }
        return $true
    })]
    [string[]]$VMUUIDs,

    [Parameter(Mandatory = $false)]
    [string]$ClusterName,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ClusterUUID,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Start", "Stop", "Reboot", "Suspend", "Reset", "Status", "GracefulShutdown")]
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
    [switch]$SequentialStartup,

    [Parameter(Mandatory = $false)]
    [ValidateRange(10, 300)]
    [int]$StartupDelay = 30,

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

# Function to check and install Nutanix PowerShell SDK if needed
function Test-NutanixSDKInstallation {
    Write-Host "Checking Nutanix PowerShell SDK installation..." -ForegroundColor Yellow

    try {
        $nutanixModule = Get-Module -Name Nutanix.PowerShell.SDK -ListAvailable
        if (-not $nutanixModule) {
            Write-Warning "Nutanix PowerShell SDK not found. Installing..."
            Install-Module -Name Nutanix.PowerShell.SDK -Force -AllowClobber -Scope CurrentUser
            Write-Host "Nutanix PowerShell SDK installed successfully." -ForegroundColor Green
        } else {
            $version = $nutanixModule | Sort-Object Version -Descending | Select-Object -First 1
            Write-Host "Nutanix PowerShell SDK version $($version.Version) found." -ForegroundColor Green
        }

        # Import the module
        Import-Module Nutanix.PowerShell.SDK -Force

        return $true
    }
    catch {
        Write-Error "Failed to install or import Nutanix PowerShell SDK: $($_.Exception.Message)"
        return $false
    }
}

# Function to connect to Prism Central or Element
function Connect-ToNutanix {
    param($Server, $ServerType)

    try {
        Write-Host "Connecting to $ServerType`: $Server" -ForegroundColor Yellow

        # Check if already connected
        if ($global:DefaultNTNXConnection -and $global:DefaultNTNXConnection.Server -eq $Server) {
            Write-Host "Already connected to $Server" -ForegroundColor Green
            return $global:DefaultNTNXConnection
        }

        # Connect to Nutanix (will prompt for credentials if not provided)
        $connection = Connect-NTNXCluster -Server $Server -AcceptInvalidSSLCerts
        Write-Host "Successfully connected to $ServerType`: $($connection.Server)" -ForegroundColor Green
        return $connection
    }
    catch {
        Write-Error "Failed to connect to $ServerType $Server`: $($_.Exception.Message)"
        throw
    }
}

# Function to get target VMs
function Get-TargetVMs {
    param(
        $VMName,
        $VMNames,
        $VMUUID,
        $VMUUIDs,
        $ClusterName,
        $ClusterUUID,
        $ExcludeVMs
    )

    Write-Host "Identifying target VMs..." -ForegroundColor Yellow

    try {
        $targetVMs = @()

        if ($VMUUID) {
            # Single VM by UUID
            $targetVMs = Get-NTNXVM | Where-Object { $_.uuid -eq $VMUUID }
        }
        elseif ($VMUUIDs) {
            # Multiple VMs by UUID
            $targetVMs = Get-NTNXVM | Where-Object { $_.uuid -in $VMUUIDs }
        }
        elseif ($VMName) {
            # Single VM or wildcard pattern by name
            if ($VMName -contains "*" -or $VMName -contains "?") {
                $targetVMs = Get-NTNXVM | Where-Object { $_.vmName -like $VMName }
            } else {
                $targetVMs = Get-NTNXVM | Where-Object { $_.vmName -eq $VMName }
            }
        }
        elseif ($VMNames) {
            # Multiple specific VMs by name
            $targetVMs = Get-NTNXVM | Where-Object { $_.vmName -in $VMNames }
        }
        elseif ($ClusterUUID) {
            # All VMs in cluster by UUID
            $targetVMs = Get-NTNXVM | Where-Object { $_.clusterUuid -eq $ClusterUUID }
        }
        elseif ($ClusterName) {
            # All VMs in cluster by name
            $clusters = Get-NTNXCluster | Where-Object { $_.name -eq $ClusterName }
            if (-not $clusters) {
                throw "Cluster '$ClusterName' not found"
            }
            $clusterUuid = $clusters[0].clusterUuid
            $targetVMs = Get-NTNXVM | Where-Object { $_.clusterUuid -eq $clusterUuid }
        }
        else {
            # All VMs (use with caution)
            Write-Warning "No specific VM criteria provided. Getting all VMs..."
            $targetVMs = Get-NTNXVM
        }

        # Exclude specified VMs
        if ($ExcludeVMs) {
            $targetVMs = $targetVMs | Where-Object { $_.vmName -notin $ExcludeVMs }
            Write-Host "Excluded $($ExcludeVMs.Count) VM(s) from operation" -ForegroundColor Gray
        }

        if (-not $targetVMs) {
            throw "No VMs found matching the specified criteria"
        }

        Write-Host "Found $($targetVMs.Count) VM(s) matching criteria:" -ForegroundColor Green
        foreach ($vm in $targetVMs) {
            $ngtStatus = if ($vm.nutanixGuestTools.toolsInstalled) { "Installed" } else { "Not Installed" }
            Write-Host "  - $($vm.vmName) [$($vm.powerState)] [NGT: $ngtStatus]" -ForegroundColor White
        }

        return $targetVMs
    }
    catch {
        Write-Error "Failed to get target VMs: $($_.Exception.Message)"
        throw
    }
}

# Function to check Nutanix Guest Tools status
function Test-NGTStatus {
    param($VM)

    $ngtInstalled = $VM.nutanixGuestTools.toolsInstalled
    $ngtEnabled = $VM.nutanixGuestTools.enabled

    return @{
        IsInstalled = $ngtInstalled
        IsEnabled = $ngtEnabled
        IsReady = $ngtInstalled -and $ngtEnabled
        Version = $VM.nutanixGuestTools.toolsVersion
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
        $existingSnapshots = Get-NTNXSnapshot | Where-Object {
            $_.vmUuid -eq $VM.uuid -and $_.snapshotName -eq $SnapshotName
        }
        if ($existingSnapshots) {
            Write-Warning "      Snapshot '$SnapshotName' already exists"
            return $existingSnapshots[0]
        }

        # Create snapshot
        $snapshotSpec = New-Object Nutanix.Prism.Model.SnapshotSpec
        $snapshotSpec.snapshotName = $SnapshotName
        $snapshotSpec.vmUuid = $VM.uuid

        $snapshot = New-NTNXSnapshot -SnapshotSpecs $snapshotSpec
        Write-Host "      ✓ Snapshot created: $($snapshot.snapshotName)" -ForegroundColor Green
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
        $SequentialStartup,
        $StartupDelay,
        $CreateSnapshot,
        $SnapshotName
    )

    Write-Host "Starting $($VMs.Count) VM(s)..." -ForegroundColor Yellow

    $results = @()
    $startTasks = @()

    foreach ($vm in $VMs) {
        try {
            Write-Host "  Processing VM: $($vm.vmName)" -ForegroundColor Cyan

            # Check current power state
            if ($vm.powerState -eq "ON") {
                Write-Host "    VM is already powered on" -ForegroundColor Yellow
                $results += @{
                    VM = $vm.vmName
                    UUID = $vm.uuid
                    Operation = "Start"
                    Status = "AlreadyRunning"
                    Message = "VM is already powered on"
                    PowerState = $vm.powerState
                }
                continue
            }

            # Create snapshot if requested
            if ($CreateSnapshot) {
                New-PowerOperationSnapshot -VM $vm -SnapshotName $SnapshotName -Operation "Start" | Out-Null
            }

            # Start the VM
            $task = Set-NTNXVMPowerState -Vmid $vm.uuid -Transition "ON"
            $startTasks += @{
                Task = $task
                VM = $vm
                StartTime = Get-Date
            }

            Write-Host "    ✓ Start task initiated" -ForegroundColor Green

            # Sequential startup with delay
            if ($SequentialStartup -and $vm -ne $VMs[-1]) {
                Write-Host "    Waiting $StartupDelay seconds before next VM..." -ForegroundColor Gray
                Start-Sleep -Seconds $StartupDelay
            }
        }
        catch {
            $results += @{
                VM = $vm.vmName
                UUID = $vm.uuid
                Operation = "Start"
                Status = "Failed"
                Message = $_.Exception.Message
                PowerState = $vm.powerState
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
                $startTime = Get-Date
                $taskCompleted = $false

                while ((Get-Date).Subtract($startTime).TotalSeconds -lt $timeoutSeconds -and -not $taskCompleted) {
                    Start-Sleep -Seconds 5
                    $vm = Get-NTNXVM | Where-Object { $_.uuid -eq $taskInfo.VM.uuid }
                    if ($vm.powerState -eq "ON") {
                        $taskCompleted = $true
                    }
                }

                if ($taskCompleted) {
                    $duration = [math]::Round((Get-Date).Subtract($taskInfo.StartTime).TotalSeconds, 1)

                    $results += @{
                        VM = $vm.vmName
                        UUID = $vm.uuid
                        Operation = "Start"
                        Status = "Success"
                        Message = "VM started successfully"
                        PowerState = $vm.powerState
                        Duration = "$duration seconds"
                    }

                    Write-Host "  ✓ $($vm.vmName) started successfully ($duration seconds)" -ForegroundColor Green
                } else {
                    $results += @{
                        VM = $taskInfo.VM.vmName
                        UUID = $taskInfo.VM.uuid
                        Operation = "Start"
                        Status = "Timeout"
                        Message = "Operation timed out after $TimeoutMinutes minutes"
                        PowerState = "Unknown"
                    }
                    Write-Host "  ✗ $($taskInfo.VM.vmName) timed out" -ForegroundColor Red
                }
            }
            catch {
                $results += @{
                    VM = $taskInfo.VM.vmName
                    UUID = $taskInfo.VM.uuid
                    Operation = "Start"
                    Status = "Timeout"
                    Message = "Operation timed out after $TimeoutMinutes minutes"
                    PowerState = "Unknown"
                }
                Write-Host "  ✗ $($taskInfo.VM.vmName) timed out" -ForegroundColor Red
            }
        }
    } else {
        # Add async results
        foreach ($taskInfo in $startTasks) {
            $results += @{
                VM = $taskInfo.VM.vmName
                UUID = $taskInfo.VM.uuid
                Operation = "Start"
                Status = "InProgress"
                Message = "Start task initiated"
                PowerState = "Starting"
                TaskId = if ($taskInfo.Task.taskUuid) { $taskInfo.Task.taskUuid } else { "N/A" }
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
            Write-Host "  Processing VM: $($vm.vmName)" -ForegroundColor Cyan

            # Check current power state
            if ($vm.powerState -eq "OFF") {
                Write-Host "    VM is already powered off" -ForegroundColor Yellow
                $results += @{
                    VM = $vm.vmName
                    UUID = $vm.uuid
                    Operation = $operation
                    Status = "AlreadyStopped"
                    Message = "VM is already powered off"
                    PowerState = $vm.powerState
                }
                continue
            }

            # Create snapshot if requested
            if ($CreateSnapshot) {
                New-PowerOperationSnapshot -VM $vm -SnapshotName $SnapshotName -Operation $operation | Out-Null
            }

            # Check NGT for graceful shutdown
            $transition = "OFF"
            $method = "Hard"

            if ($GracefulShutdown) {
                $ngtStatus = Test-NGTStatus -VM $vm
                if ($ngtStatus.IsReady) {
                    $transition = "ACPI_SHUTDOWN"
                    $method = "Graceful"
                    Write-Host "    Initiating graceful shutdown..." -ForegroundColor Gray
                } else {
                    Write-Warning "    NGT not ready, falling back to hard power off"
                }
            }

            $task = Set-NTNXVMPowerState -Vmid $vm.uuid -Transition $transition
            $stopTasks += @{
                Task = $task
                VM = $vm
                StartTime = Get-Date
                Method = $method
            }

            Write-Host "    ✓ Stop task initiated" -ForegroundColor Green
        }
        catch {
            $results += @{
                VM = $vm.vmName
                UUID = $vm.uuid
                Operation = $operation
                Status = "Failed"
                Message = $_.Exception.Message
                PowerState = $vm.powerState
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
                $startTime = Get-Date
                $taskCompleted = $false

                while ((Get-Date).Subtract($startTime).TotalSeconds -lt $timeoutSeconds -and -not $taskCompleted) {
                    Start-Sleep -Seconds 5
                    $vm = Get-NTNXVM | Where-Object { $_.uuid -eq $taskInfo.VM.uuid }
                    if ($vm.powerState -eq "OFF") {
                        $taskCompleted = $true
                    }
                }

                if ($taskCompleted) {
                    $duration = [math]::Round((Get-Date).Subtract($taskInfo.StartTime).TotalSeconds, 1)

                    $results += @{
                        VM = $vm.vmName
                        UUID = $vm.uuid
                        Operation = $operation
                        Status = "Success"
                        Message = "VM stopped successfully"
                        PowerState = $vm.powerState
                        Duration = "$duration seconds"
                        Method = $taskInfo.Method
                    }

                    Write-Host "  ✓ $($vm.vmName) stopped successfully [$($taskInfo.Method), $duration seconds]" -ForegroundColor Green
                } else {
                    $results += @{
                        VM = $taskInfo.VM.vmName
                        UUID = $taskInfo.VM.uuid
                        Operation = $operation
                        Status = "Timeout"
                        Message = "Operation timed out after $TimeoutMinutes minutes"
                        PowerState = "Unknown"
                        Method = $taskInfo.Method
                    }
                    Write-Host "  ✗ $($taskInfo.VM.vmName) timed out" -ForegroundColor Red
                }
            }
            catch {
                $results += @{
                    VM = $taskInfo.VM.vmName
                    UUID = $taskInfo.VM.uuid
                    Operation = $operation
                    Status = "Timeout"
                    Message = "Operation timed out after $TimeoutMinutes minutes"
                    PowerState = "Unknown"
                    Method = $taskInfo.Method
                }
                Write-Host "  ✗ $($taskInfo.VM.vmName) timed out" -ForegroundColor Red
            }
        }
    } else {
        # Add async results
        foreach ($taskInfo in $stopTasks) {
            $results += @{
                VM = $taskInfo.VM.vmName
                UUID = $taskInfo.VM.uuid
                Operation = $operation
                Status = "InProgress"
                Message = "Stop task initiated"
                PowerState = "Stopping"
                TaskId = if ($taskInfo.Task.taskUuid) { $taskInfo.Task.taskUuid } else { "N/A" }
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
            Write-Host "  Processing VM: $($vm.vmName)" -ForegroundColor Cyan

            # Check current power state
            if ($vm.powerState -eq "OFF") {
                Write-Host "    VM is powered off, starting instead of rebooting" -ForegroundColor Yellow
                $task = Set-NTNXVMPowerState -Vmid $vm.uuid -Transition "ON"
                $rebootTasks += @{
                    Task = $task
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

            # Check NGT for graceful reboot
            $transition = "RESET"
            $operation = "Reboot"

            if ($GracefulShutdown) {
                $ngtStatus = Test-NGTStatus -VM $vm
                if ($ngtStatus.IsReady) {
                    $transition = "ACPI_REBOOT"
                    $operation = "GracefulReboot"
                    Write-Host "    Initiating graceful reboot..." -ForegroundColor Gray
                } else {
                    Write-Warning "    NGT not ready, falling back to hard reboot"
                }
            }

            $task = Set-NTNXVMPowerState -Vmid $vm.uuid -Transition $transition
            $rebootTasks += @{
                Task = $task
                VM = $vm
                StartTime = Get-Date
                Operation = $operation
            }

            Write-Host "    ✓ Reboot task initiated" -ForegroundColor Green
        }
        catch {
            $results += @{
                VM = $vm.vmName
                UUID = $vm.uuid
                Operation = "Reboot"
                Status = "Failed"
                Message = $_.Exception.Message
                PowerState = $vm.powerState
            }
            Write-Host "    ✗ Failed to reboot: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Wait for completion if requested
    if ($WaitForCompletion -and $rebootTasks.Count -gt 0) {
        Write-Host "`nWaiting for VM reboot operations to complete..." -ForegroundColor Yellow

        foreach ($taskInfo in $rebootTasks) {
            try {
                $timeoutSeconds = $TimeoutMinutes * 60
                $startTime = Get-Date
                $taskCompleted = $false

                # For reboot operations, we need to wait for the VM to be back online
                while ((Get-Date).Subtract($startTime).TotalSeconds -lt $timeoutSeconds -and -not $taskCompleted) {
                    Start-Sleep -Seconds 10
                    $vm = Get-NTNXVM | Where-Object { $_.uuid -eq $taskInfo.VM.uuid }
                    if ($vm.powerState -eq "ON") {
                        $taskCompleted = $true
                    }
                }

                if ($taskCompleted) {
                    $duration = [math]::Round((Get-Date).Subtract($taskInfo.StartTime).TotalSeconds, 1)

                    $results += @{
                        VM = $vm.vmName
                        UUID = $vm.uuid
                        Operation = $taskInfo.Operation
                        Status = "Success"
                        Message = "VM rebooted successfully"
                        PowerState = $vm.powerState
                        Duration = "$duration seconds"
                    }

                    Write-Host "  ✓ $($vm.vmName) rebooted successfully ($duration seconds)" -ForegroundColor Green
                } else {
                    $results += @{
                        VM = $taskInfo.VM.vmName
                        UUID = $taskInfo.VM.uuid
                        Operation = $taskInfo.Operation
                        Status = "Timeout"
                        Message = "Operation timed out after $TimeoutMinutes minutes"
                        PowerState = "Unknown"
                    }
                    Write-Host "  ✗ $($taskInfo.VM.vmName) timed out" -ForegroundColor Red
                }
            }
            catch {
                $results += @{
                    VM = $taskInfo.VM.vmName
                    UUID = $taskInfo.VM.uuid
                    Operation = $taskInfo.Operation
                    Status = "Timeout"
                    Message = "Operation timed out after $TimeoutMinutes minutes"
                    PowerState = "Unknown"
                }
                Write-Host "  ✗ $($taskInfo.VM.vmName) timed out" -ForegroundColor Red
            }
        }
    } else {
        # Add async results
        foreach ($taskInfo in $rebootTasks) {
            $results += @{
                VM = $taskInfo.VM.vmName
                UUID = $taskInfo.VM.uuid
                Operation = $taskInfo.Operation
                Status = "InProgress"
                Message = "Reboot task initiated"
                PowerState = "Rebooting"
                TaskId = if ($taskInfo.Task.taskUuid) { $taskInfo.Task.taskUuid } else { "N/A" }
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
            $ngtStatus = Test-NGTStatus -VM $vm
            $uptime = "N/A"

            # Calculate uptime if VM is running
            if ($vm.powerState -eq "ON" -and $vm.vmLogicalTimestamp) {
                # Note: Nutanix doesn't directly provide boot time, using logical timestamp as approximation
                $uptimeSpan = New-TimeSpan -Seconds ([int64]$vm.vmLogicalTimestamp / 1000000)
                $uptime = "$([math]::Floor($uptimeSpan.TotalDays))d $($uptimeSpan.Hours)h $($uptimeSpan.Minutes)m"
            }

            $cluster = Get-NTNXCluster | Where-Object { $_.clusterUuid -eq $vm.clusterUuid }
            $clusterName = if ($cluster) { $cluster.name } else { "Unknown" }

            $statusItem = [PSCustomObject]@{
                VMName = $vm.vmName
                UUID = $vm.uuid
                PowerState = $vm.powerState
                NGTInstalled = $ngtStatus.IsInstalled
                NGTEnabled = $ngtStatus.IsEnabled
                NGTVersion = $ngtStatus.Version
                ClusterName = $clusterName
                ClusterUUID = $vm.clusterUuid
                CPUCores = $vm.numVcpus
                CPUSockets = $vm.numCoresPerVcpu
                MemoryMB = $vm.memoryMb
                MemoryGB = [math]::Round($vm.memoryMb / 1024, 2)
                DiskCount = $vm.vmDiskInfo.Count
                Uptime = $uptime
                HypervisorType = $vm.hypervisorType
                HostUUID = $vm.hostUuid
                Timestamp = Get-Date
            }

            $statusData += $statusItem
        }
        catch {
            Write-Warning "Failed to get status for VM '$($vm.vmName)': $($_.Exception.Message)"
        }
    }

    # Export status
    switch ($OutputFormat) {
        "Console" {
            Write-Host "`n=== VM Power Status Report ===" -ForegroundColor Cyan
            $statusData | Format-Table VMName, PowerState, NGTInstalled, ClusterName, MemoryGB, CPUCores, Uptime -AutoSize
        }
        "CSV" {
            if (-not $OutputPath) {
                $OutputPath = "Nutanix_VM_Power_Status_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            }
            $statusData | Export-Csv -Path $OutputPath -NoTypeInformation
            Write-Host "Status report exported to: $OutputPath" -ForegroundColor Green
        }
        "JSON" {
            if (-not $OutputPath) {
                $OutputPath = "Nutanix_VM_Power_Status_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
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
    $skipped = $Results | Where-Object { $_.Status -in @("AlreadyRunning", "AlreadyStopped", "InvalidState") }
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
    Write-Host "=== Nutanix AHV VM Power Operations ===" -ForegroundColor Cyan

    # Determine target server
    $targetServer = if ($PrismCentral) { $PrismCentral } else { $PrismElement }
    $serverType = if ($PrismCentral) { "Prism Central" } else { "Prism Element" }

    if (-not $targetServer) {
        throw "Either PrismCentral or PrismElement parameter must be specified"
    }

    Write-Host "Target $serverType`: $targetServer" -ForegroundColor White
    Write-Host "Operation: $Operation" -ForegroundColor White

    if ($VMName) { Write-Host "Target VM Pattern: $VMName" -ForegroundColor White }
    if ($VMNames) { Write-Host "Target VMs: $($VMNames -join ', ')" -ForegroundColor White }
    if ($VMUUID) { Write-Host "Target VM UUID: $VMUUID" -ForegroundColor White }
    if ($VMUUIDs) { Write-Host "Target VM UUIDs: $($VMUUIDs.Count) specified" -ForegroundColor White }
    if ($ClusterName) { Write-Host "Target Cluster: $ClusterName" -ForegroundColor White }
    if ($ClusterUUID) { Write-Host "Target Cluster UUID: $ClusterUUID" -ForegroundColor White }
    if ($GracefulShutdown) { Write-Host "Using graceful shutdown/reboot" -ForegroundColor White }
    if ($CreateSnapshot) { Write-Host "Creating snapshots before operations" -ForegroundColor White }
    Write-Host ""

    # Check and install Nutanix PowerShell SDK
    if (-not (Test-NutanixSDKInstallation)) {
        throw "Nutanix PowerShell SDK installation failed"
    }

    # Connect to Nutanix
    $connection = Connect-ToNutanix -Server $targetServer -ServerType $serverType

    # Get target VMs
    $targetVMs = Get-TargetVMs -VMName $VMName -VMNames $VMNames -VMUUID $VMUUID -VMUUIDs $VMUUIDs -ClusterName $ClusterName -ClusterUUID $ClusterUUID -ExcludeVMs $ExcludeVMs

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
            $results = Start-VMPowerOperation -VMs $targetVMs -WaitForCompletion:$WaitForCompletion -TimeoutMinutes $TimeoutMinutes -SequentialStartup:$SequentialStartup -StartupDelay $StartupDelay -CreateSnapshot:$CreateSnapshot -SnapshotName $SnapshotName
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
        "Reset" {
            Write-Host "Performing hard reset on $($targetVMs.Count) VM(s)..." -ForegroundColor Yellow
            foreach ($vm in $targetVMs) {
                try {
                    Write-Host "  Resetting VM: $($vm.vmName)" -ForegroundColor Cyan
                    if ($CreateSnapshot) {
                        New-PowerOperationSnapshot -VM $vm -SnapshotName $SnapshotName -Operation "Reset" | Out-Null
                    }
                    $task = Set-NTNXVMPowerState -Vmid $vm.uuid -Transition "RESET"
                    $results += @{
                        VM = $vm.vmName
                        UUID = $vm.uuid
                        Operation = "Reset"
                        Status = "Success"
                        Message = "VM reset successfully"
                        PowerState = $vm.powerState
                        TaskId = if ($task.taskUuid) { $task.taskUuid } else { "N/A" }
                    }
                    Write-Host "    ✓ VM reset successfully" -ForegroundColor Green
                }
                catch {
                    $results += @{
                        VM = $vm.vmName
                        UUID = $vm.uuid
                        Operation = "Reset"
                        Status = "Failed"
                        Message = $_.Exception.Message
                        PowerState = $vm.powerState
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
    # Disconnect from Nutanix if connected
    if ($global:DefaultNTNXConnection) {
        Write-Host "`nDisconnecting from Nutanix..." -ForegroundColor Yellow
        Disconnect-NTNXCluster
    }
}
