<#
.SYNOPSIS
    Performs power operations on vSphere virtual machines using PowerCLI.

.DESCRIPTION
    This script performs various power operations on VMs including start, stop, restart, suspend, and reset.
    Supports single VMs, multiple VMs by name pattern, or VMs in a specific folder/cluster.
    Requires VMware PowerCLI and connection to vCenter Server.

.PARAMETER VCenterServer
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER VMName
    The name of the virtual machine(s). Supports wildcards (e.g., "WebServer*").

.PARAMETER VMNames
    An array of specific VM names for batch operations.

.PARAMETER FolderName
    Target VMs in a specific folder (optional).

.PARAMETER ClusterName
    Target VMs in a specific cluster (optional).

.PARAMETER Operation
    The power operation to perform.

.PARAMETER Force
    Force the operation without confirmation prompts.

.PARAMETER WaitForCompletion
    Wait for the operation to complete before continuing.

.PARAMETER GracefulShutdown
    Use guest OS shutdown instead of hard power off (for Stop operation).

.PARAMETER TimeoutMinutes
    Timeout in minutes for operation completion (default: 10).

.EXAMPLE
    .\vsphere-cli-power-vm-operations.ps1 -VCenterServer "vcenter.domain.com" -VMName "WebServer01" -Operation "Start"

.EXAMPLE
    .\vsphere-cli-power-vm-operations.ps1 -VCenterServer "vcenter.domain.com" -VMName "TestVM*" -Operation "Stop" -GracefulShutdown -Force

.EXAMPLE
    .\vsphere-cli-power-vm-operations.ps1 -VCenterServer "vcenter.domain.com" -VMNames @("VM01","VM02","VM03") -Operation "Restart" -WaitForCompletion

.EXAMPLE
    .\vsphere-cli-power-vm-operations.ps1 -VCenterServer "vcenter.domain.com" -ClusterName "Test-Cluster" -Operation "Suspend" -Force

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: VMware PowerCLI (Install-Module -Name VMware.PowerCLI)

.LINK
    https://developer.vmware.com/docs/powercli/

.COMPONENT
    VMware vSphere PowerCLI
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The vCenter Server FQDN or IP address to connect to.")]
    [ValidateNotNullOrEmpty()]
    [string]$VCenterServer,

    [Parameter(Mandatory = $false, ParameterSetName = "SingleVM", HelpMessage = "The name of the virtual machine(s). Supports wildcards.")]
    [ValidateNotNullOrEmpty()]
    [string]$VMName,

    [Parameter(Mandatory = $false, ParameterSetName = "MultipleVMs", HelpMessage = "An array of specific VM names for batch operations.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$VMNames,

    [Parameter(Mandatory = $false, HelpMessage = "Target VMs in a specific folder.")]
    [string]$FolderName,

    [Parameter(Mandatory = $false, HelpMessage = "Target VMs in a specific cluster.")]
    [string]$ClusterName,

    [Parameter(Mandatory = $true, HelpMessage = "The power operation to perform (Start, Stop, Restart, Suspend, or Reset).")]
    [ValidateSet("Start", "Stop", "Restart", "Suspend", "Reset")]
    [string]$Operation,

    [Parameter(Mandatory = $false, HelpMessage = "Force the operation without confirmation prompts.")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Wait for the operation to complete before continuing.")]
    [switch]$WaitForCompletion,

    [Parameter(Mandatory = $false, HelpMessage = "Use guest OS shutdown instead of hard power off (for Stop operation).")]
    [switch]$GracefulShutdown,

    [Parameter(Mandatory = $false, HelpMessage = "Timeout in minutes for operation completion (default: 10).")]
    [ValidateRange(1, 60)]
    [int]$TimeoutMinutes = 10
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

# Function to get target VMs based on parameters
function Get-TargetVMs {
    param(
        $VMName,
        $VMNames,
        $FolderName,
        $ClusterName
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
        else {
            # Get all VMs, then filter by folder/cluster if specified
            $targetVMs = Get-VM
        }

        # Filter by folder if specified
        if ($FolderName -and $targetVMs) {
            $folder = Get-Folder -Name $FolderName -Type VM -ErrorAction SilentlyContinue
            if (-not $folder) {
                throw "Folder '$FolderName' not found"
            }
            $targetVMs = $targetVMs | Where-Object { $_.Folder.Name -eq $FolderName }
        }

        # Filter by cluster if specified
        if ($ClusterName -and $targetVMs) {
            $cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
            if (-not $cluster) {
                throw "Cluster '$ClusterName' not found"
            }
            $targetVMs = $targetVMs | Where-Object { $_.VMHost.Parent.Name -eq $ClusterName }
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

# Function to validate VMs for the operation
function Test-VMOperationPrerequisites {
    param(
        $VMs,
        $Operation
    )

    Write-Host "Validating VMs for $Operation operation..." -ForegroundColor Yellow

    $validVMs = @()
    $invalidVMs = @()

    foreach ($vm in $VMs) {
        $isValid = $true
        $reason = ""

        switch ($Operation) {
            "Start" {
                if ($vm.PowerState -eq "PoweredOn") {
                    $isValid = $false
                    $reason = "Already powered on"
                }
            }
            "Stop" {
                if ($vm.PowerState -eq "PoweredOff") {
                    $isValid = $false
                    $reason = "Already powered off"
                }
            }
            "Restart" {
                if ($vm.PowerState -ne "PoweredOn") {
                    $isValid = $false
                    $reason = "Must be powered on to restart"
                }
            }
            "Suspend" {
                if ($vm.PowerState -ne "PoweredOn") {
                    $isValid = $false
                    $reason = "Must be powered on to suspend"
                }
            }
            "Reset" {
                if ($vm.PowerState -ne "PoweredOn") {
                    $isValid = $false
                    $reason = "Must be powered on to reset"
                }
            }
        }

        if ($isValid) {
            $validVMs += $vm
        } else {
            $invalidVMs += @{ VM = $vm; Reason = $reason }
            Write-Warning "VM '$($vm.Name)' skipped: $reason"
        }
    }

    if ($validVMs.Count -eq 0) {
        throw "No VMs are valid for the $Operation operation"
    }

    Write-Host "$($validVMs.Count) VM(s) validated for $Operation operation" -ForegroundColor Green
    return $validVMs
}

# Function to perform power operation on VMs
function Invoke-VMPowerOperation {
    param(
        $VMs,
        $Operation,
        $GracefulShutdown,
        $WaitForCompletion,
        $TimeoutMinutes
    )

    Write-Host "Performing $Operation operation on $($VMs.Count) VM(s)..." -ForegroundColor Yellow

    $tasks = @()
    $results = @()

    try {
        foreach ($vm in $VMs) {
            Write-Host "  Processing VM: $($vm.Name)" -ForegroundColor Cyan

            $task = $null
            switch ($Operation) {
                "Start" {
                    $task = $vm | Start-VM -RunAsync -ErrorAction Stop
                }
                "Stop" {
                    if ($GracefulShutdown) {
                        $task = $vm | Shutdown-VMGuest -Confirm:$false -RunAsync -ErrorAction Stop
                    } else {
                        $task = $vm | Stop-VM -Confirm:$false -RunAsync -ErrorAction Stop
                    }
                }
                "Restart" {
                    if ($GracefulShutdown) {
                        $task = $vm | Restart-VMGuest -Confirm:$false -RunAsync -ErrorAction Stop
                    } else {
                        $task = $vm | Restart-VM -Confirm:$false -RunAsync -ErrorAction Stop
                    }
                }
                "Suspend" {
                    $task = $vm | Suspend-VM -Confirm:$false -RunAsync -ErrorAction Stop
                }
                "Reset" {
                    $task = $vm | Restart-VM -Confirm:$false -RunAsync -ErrorAction Stop
                }
            }

            if ($task) {
                $tasks += $task
                $results += @{
                    VM = $vm.Name
                    Task = $task
                    Status = "Started"
                    StartTime = Get-Date
                }
                Write-Host "    ✓ $Operation task initiated" -ForegroundColor Green
            }
        }

        # Wait for completion if requested
        if ($WaitForCompletion -and $tasks.Count -gt 0) {
            Write-Host "`nWaiting for operations to complete (timeout: $TimeoutMinutes minutes)..." -ForegroundColor Yellow

            foreach ($result in $results) {
                $task = $result.Task
                $vmName = $result.VM

                Write-Host "  Waiting for VM '$vmName'..." -ForegroundColor Cyan

                try {
                    # Wait for task with timeout
                    $taskResult = Wait-Task -Task $task -TimeoutSeconds ($TimeoutMinutes * 60)

                    if ($taskResult.State -eq "Success") {
                        $result.Status = "Completed"
                        $result.EndTime = Get-Date
                        $duration = ($result.EndTime - $result.StartTime).TotalSeconds
                        Write-Host "    ✓ Completed successfully (${duration}s)" -ForegroundColor Green
                    } else {
                        $result.Status = "Failed"
                        $result.Error = $taskResult.Result
                        Write-Host "    ✗ Failed: $($taskResult.Result)" -ForegroundColor Red
                    }
                }
                catch {
                    $result.Status = "Timeout"
                    $result.Error = "Operation timed out after $TimeoutMinutes minutes"
                    Write-Host "    ⚠ Timed out after $TimeoutMinutes minutes" -ForegroundColor Yellow
                }
            }
        }

        return $results
    }
    catch {
        Write-Error "Failed to perform power operation: $($_.Exception.Message)"
        throw
    }
}

# Function to display operation summary
function Show-OperationSummary {
    param(
        $Results,
        $Operation
    )

    Write-Host "`n=== $Operation Operation Summary ===" -ForegroundColor Cyan

    $successful = $Results | Where-Object { $_.Status -eq "Completed" }
    $failed = $Results | Where-Object { $_.Status -eq "Failed" }
    $timeout = $Results | Where-Object { $_.Status -eq "Timeout" }
    $started = $Results | Where-Object { $_.Status -eq "Started" }

    Write-Host "Total VMs: $($Results.Count)" -ForegroundColor White
    Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    Write-Host "Timed out: $($timeout.Count)" -ForegroundColor Yellow
    Write-Host "In progress: $($started.Count)" -ForegroundColor Cyan

    if ($failed.Count -gt 0) {
        Write-Host "`nFailed Operations:" -ForegroundColor Red
        foreach ($result in $failed) {
            Write-Host "  - $($result.VM): $($result.Error)" -ForegroundColor White
        }
    }

    if ($timeout.Count -gt 0) {
        Write-Host "`nTimed Out Operations:" -ForegroundColor Yellow
        foreach ($result in $timeout) {
            Write-Host "  - $($result.VM): $($result.Error)" -ForegroundColor White
        }
    }

    # Show current power states
    Write-Host "`nCurrent VM Power States:" -ForegroundColor Cyan
    foreach ($result in $Results) {
        $vm = Get-VM -Name $result.VM -ErrorAction SilentlyContinue
        if ($vm) {
            $stateColor = switch ($vm.PowerState) {
                "PoweredOn" { "Green" }
                "PoweredOff" { "Red" }
                "Suspended" { "Yellow" }
                default { "White" }
            }
            Write-Host "  $($vm.Name): $($vm.PowerState)" -ForegroundColor $stateColor
        }
    }
}

# Main execution
try {
    Write-Host "=== vSphere VM Power Operations ===" -ForegroundColor Cyan
    Write-Host "Target vCenter: $VCenterServer" -ForegroundColor White
    Write-Host "Operation: $Operation" -ForegroundColor White

    if ($VMName) { Write-Host "Target VM Pattern: $VMName" -ForegroundColor White }
    if ($VMNames) { Write-Host "Target VMs: $($VMNames -join ', ')" -ForegroundColor White }
    if ($FolderName) { Write-Host "Target Folder: $FolderName" -ForegroundColor White }
    if ($ClusterName) { Write-Host "Target Cluster: $ClusterName" -ForegroundColor White }
    if ($GracefulShutdown) { Write-Host "Using graceful shutdown/restart" -ForegroundColor White }
    Write-Host ""

    # Check and install PowerCLI
    if (-not (Test-PowerCLIInstallation)) {
        throw "PowerCLI installation failed"
    }

    # Connect to vCenter
    $connection = Connect-ToVCenter -Server $VCenterServer

    # Get target VMs
    $targetVMs = Get-TargetVMs -VMName $VMName -VMNames $VMNames -FolderName $FolderName -ClusterName $ClusterName

    # Validate VMs for the operation
    $validVMs = Test-VMOperationPrerequisites -VMs $targetVMs -Operation $Operation

    # Confirm operation if not using Force
    if (-not $Force) {
        $confirmation = Read-Host "`nProceed with $Operation operation on $($validVMs.Count) VM(s)? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Perform the power operation
    $results = Invoke-VMPowerOperation -VMs $validVMs -Operation $Operation -GracefulShutdown:$GracefulShutdown -WaitForCompletion:$WaitForCompletion -TimeoutMinutes $TimeoutMinutes

    # Display summary
    Show-OperationSummary -Results $results -Operation $Operation

    Write-Host "`n=== Operation Completed ===" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
    # Disconnect from vCenter if connected
    if ($global:DefaultVIServers) {
        Write-Host "`nDisconnecting from vCenter..." -ForegroundColor Yellow
        Disconnect-VIServer -Server * -Confirm:$false -Force
    }
}
