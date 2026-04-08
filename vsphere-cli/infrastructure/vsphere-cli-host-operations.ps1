<#
.SYNOPSIS
    Manages ESXi host operations in vSphere using PowerCLI.

.DESCRIPTION
    This script provides comprehensive ESXi host management including maintenance mode,
    power operations, configuration management, and health monitoring.
    Supports single host and cluster-wide operations with safety checks.
    Requires VMware PowerCLI and connection to vCenter Server.

.PARAMETER VCenterServer
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER HostName
    The name of the ESXi host to manage. Supports wildcards.

.PARAMETER HostNames
    An array of specific host names for batch operations.

.PARAMETER ClusterName
    Target all hosts in a specific cluster.

.PARAMETER Operation
    The host operation to perform.

.PARAMETER MaintenanceMode
    Enter or exit maintenance mode.

.PARAMETER EvacuateVMs
    Evacuate VMs when entering maintenance mode (uses vMotion).

.PARAMETER PowerOperation
    Power operation for host management.

.PARAMETER ShutdownTimeout
    Timeout in minutes for host shutdown operations (default: 10).

.PARAMETER Force
    Force operations without confirmation prompts.

.PARAMETER WaitForCompletion
    Wait for operations to complete before continuing.

.PARAMETER OutputFormat
    Output format for reports.

.PARAMETER OutputPath
    Path to save the report file (optional).

.EXAMPLE
    .\vsphere-cli-host-operations.ps1 -VCenterServer "vcenter.domain.com" -HostName "esx01.domain.com" -Operation "EnterMaintenance" -EvacuateVMs

.EXAMPLE
    .\vsphere-cli-host-operations.ps1 -VCenterServer "vcenter.domain.com" -ClusterName "Production" -Operation "HealthCheck"

.EXAMPLE
    .\vsphere-cli-host-operations.ps1 -VCenterServer "vcenter.domain.com" -HostName "esx02.domain.com" -Operation "Power" -PowerOperation "Shutdown" -Force

.EXAMPLE
    .\vsphere-cli-host-operations.ps1 -VCenterServer "vcenter.domain.com" -Operation "Report" -OutputFormat "CSV" -OutputPath "host-report.csv"

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

    [Parameter(Mandatory = $false, ParameterSetName = "SingleHost", HelpMessage = "The name of the ESXi host to manage. Supports wildcards.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostName,

    [Parameter(Mandatory = $false, ParameterSetName = "MultipleHosts", HelpMessage = "An array of specific host names for batch operations.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$HostNames,

    [Parameter(Mandatory = $false, HelpMessage = "Target all hosts in a specific cluster.")]
    [string]$ClusterName,

    [Parameter(Mandatory = $true, HelpMessage = "The host operation to perform (e.g. EnterMaintenance, ExitMaintenance, Power, HealthCheck).")]
    [ValidateSet("EnterMaintenance", "ExitMaintenance", "Power", "HealthCheck", "Configuration", "Report")]
    [string]$Operation,

    [Parameter(Mandatory = $false, HelpMessage = "Evacuate VMs when entering maintenance mode using vMotion.")]
    [switch]$EvacuateVMs,

    [Parameter(Mandatory = $false, HelpMessage = "Power operation to perform on the host (Shutdown, Reboot, or PowerOn).")]
    [ValidateSet("Shutdown", "Reboot", "PowerOn")]
    [string]$PowerOperation,

    [Parameter(Mandatory = $false, HelpMessage = "Timeout in minutes for host shutdown operations (default: 10).")]
    [ValidateRange(5, 60)]
    [int]$ShutdownTimeout = 10,

    [Parameter(Mandatory = $false, HelpMessage = "Force operations without confirmation prompts.")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Wait for operations to complete before continuing.")]
    [switch]$WaitForCompletion,

    [Parameter(Mandatory = $false, HelpMessage = "Output format for reports (Console, CSV, or JSON).")]
    [ValidateSet("Console", "CSV", "JSON")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false, HelpMessage = "Path to save the report file.")]
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

# Function to get target hosts
function Get-TargetHosts {
    param(
        $HostName,
        $HostNames,
        $ClusterName
    )

    Write-Host "Identifying target hosts..." -ForegroundColor Yellow

    try {
        $targetHosts = @()

        if ($HostName) {
            # Single host or wildcard pattern
            $targetHosts = Get-VMHost -Name $HostName -ErrorAction SilentlyContinue
        }
        elseif ($HostNames) {
            # Multiple specific hosts
            foreach ($name in $HostNames) {
                $vmHost = Get-VMHost -Name $name -ErrorAction SilentlyContinue
                if ($vmHost) {
                    $targetHosts += $vmHost
                } else {
                    Write-Warning "Host '$name' not found"
                }
            }
        }
        elseif ($ClusterName) {
            # All hosts in cluster
            $cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
            if (-not $cluster) {
                throw "Cluster '$ClusterName' not found"
            }
            $targetHosts = Get-VMHost -Location $cluster
        }
        else {
            # All hosts
            $targetHosts = Get-VMHost
        }

        if (-not $targetHosts) {
            throw "No hosts found matching the specified criteria"
        }

        Write-Host "Found $($targetHosts.Count) host(s):" -ForegroundColor Green
        foreach ($vmHost in $targetHosts) {
            $vmCount = (Get-VM -Location $vmHost | Where-Object { $_.PowerState -eq "PoweredOn" }).Count
            Write-Host "  - $($vmHost.Name): $($vmHost.ConnectionState), $vmCount powered-on VMs" -ForegroundColor White
        }

        return $targetHosts
    }
    catch {
        Write-Error "Failed to get target hosts: $($_.Exception.Message)"
        throw
    }
}

# Function to enter maintenance mode
function Enter-HostMaintenanceMode {
    param(
        $VMHost,
        $EvacuateVMs,
        $WaitForCompletion
    )

    try {
        Write-Host "  Entering maintenance mode for host '$($VMHost.Name)'..." -ForegroundColor Yellow

        # Check if already in maintenance mode
        if ($VMHost.State -eq "Maintenance") {
            Write-Host "    Host is already in maintenance mode" -ForegroundColor Yellow
            return @{
                Host = $VMHost.Name
                Operation = "EnterMaintenance"
                Status = "AlreadyInMaintenance"
                Message = "Host was already in maintenance mode"
            }
        }

        # Check for powered-on VMs
        $poweredOnVMs = Get-VM -Location $VMHost | Where-Object { $_.PowerState -eq "PoweredOn" }

        if ($poweredOnVMs.Count -gt 0) {
            Write-Host "    Found $($poweredOnVMs.Count) powered-on VMs" -ForegroundColor Cyan

            if ($EvacuateVMs) {
                Write-Host "    Evacuating VMs using vMotion..." -ForegroundColor Yellow

                # Get cluster to find destination hosts
                $cluster = $VMHost.Parent
                $destinationHosts = Get-VMHost -Location $cluster | Where-Object {
                    $_.Name -ne $VMHost.Name -and
                    $_.State -eq "Connected" -and
                    $_.ConnectionState -eq "Connected"
                }

                if ($destinationHosts.Count -eq 0) {
                    throw "No available destination hosts for VM evacuation"
                }

                $evacuationTasks = @()
                foreach ($vm in $poweredOnVMs) {
                    # Let DRS choose the best destination host
                    $moveTask = Move-VM -VM $vm -Destination $cluster -RunAsync
                    $evacuationTasks += $moveTask
                    Write-Host "      Migrating VM '$($vm.Name)'..." -ForegroundColor Gray
                }

                # Wait for all migrations to complete
                if ($WaitForCompletion) {
                    Write-Host "    Waiting for VM migrations to complete..." -ForegroundColor Yellow
                    foreach ($task in $evacuationTasks) {
                        Wait-Task -Task $task | Out-Null
                    }
                    Write-Host "    ✓ All VMs evacuated successfully" -ForegroundColor Green
                }
            } else {
                throw "Host has $($poweredOnVMs.Count) powered-on VMs. Use -EvacuateVMs to automatically migrate them."
            }
        }

        # Enter maintenance mode
        $maintenanceTask = Set-VMHost -VMHost $VMHost -State "Maintenance" -RunAsync

        if ($WaitForCompletion) {
            Write-Host "    Waiting for maintenance mode to complete..." -ForegroundColor Yellow
            Wait-Task -Task $maintenanceTask | Out-Null

            # Refresh host state
            $updatedHost = Get-VMHost -Name $VMHost.Name
            if ($updatedHost.State -eq "Maintenance") {
                Write-Host "    ✓ Host successfully entered maintenance mode" -ForegroundColor Green
                return @{
                    Host = $VMHost.Name
                    Operation = "EnterMaintenance"
                    Status = "Success"
                    Message = "Successfully entered maintenance mode"
                    VMsEvacuated = $poweredOnVMs.Count
                }
            } else {
                throw "Failed to enter maintenance mode. Current state: $($updatedHost.State)"
            }
        } else {
            Write-Host "    ✓ Maintenance mode task initiated" -ForegroundColor Green
            return @{
                Host = $VMHost.Name
                Operation = "EnterMaintenance"
                Status = "InProgress"
                Message = "Maintenance mode task initiated"
                Task = $maintenanceTask
            }
        }
    }
    catch {
        return @{
            Host = $VMHost.Name
            Operation = "EnterMaintenance"
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to exit maintenance mode
function Exit-HostMaintenanceMode {
    param(
        $VMHost,
        $WaitForCompletion
    )

    try {
        Write-Host "  Exiting maintenance mode for host '$($VMHost.Name)'..." -ForegroundColor Yellow

        # Check if in maintenance mode
        if ($VMHost.State -ne "Maintenance") {
            Write-Host "    Host is not in maintenance mode (Current state: $($VMHost.State))" -ForegroundColor Yellow
            return @{
                Host = $VMHost.Name
                Operation = "ExitMaintenance"
                Status = "NotInMaintenance"
                Message = "Host was not in maintenance mode"
            }
        }

        # Exit maintenance mode
        $exitTask = Set-VMHost -VMHost $VMHost -State "Connected" -RunAsync

        if ($WaitForCompletion) {
            Write-Host "    Waiting for exit maintenance mode to complete..." -ForegroundColor Yellow
            Wait-Task -Task $exitTask | Out-Null

            # Refresh host state
            $updatedHost = Get-VMHost -Name $VMHost.Name
            if ($updatedHost.State -eq "Connected") {
                Write-Host "    ✓ Host successfully exited maintenance mode" -ForegroundColor Green
                return @{
                    Host = $VMHost.Name
                    Operation = "ExitMaintenance"
                    Status = "Success"
                    Message = "Successfully exited maintenance mode"
                }
            } else {
                throw "Failed to exit maintenance mode. Current state: $($updatedHost.State)"
            }
        } else {
            Write-Host "    ✓ Exit maintenance mode task initiated" -ForegroundColor Green
            return @{
                Host = $VMHost.Name
                Operation = "ExitMaintenance"
                Status = "InProgress"
                Message = "Exit maintenance mode task initiated"
                Task = $exitTask
            }
        }
    }
    catch {
        return @{
            Host = $VMHost.Name
            Operation = "ExitMaintenance"
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to perform host power operations
function Invoke-HostPowerOperation {
    param(
        $VMHost,
        $PowerOperation,
        $ShutdownTimeout,
        $WaitForCompletion
    )

    try {
        Write-Host "  Performing $PowerOperation on host '$($VMHost.Name)'..." -ForegroundColor Yellow

        # Check for powered-on VMs
        $poweredOnVMs = Get-VM -Location $VMHost | Where-Object { $_.PowerState -eq "PoweredOn" }

        if ($poweredOnVMs.Count -gt 0 -and $PowerOperation -in @("Shutdown", "Reboot")) {
            throw "Host has $($poweredOnVMs.Count) powered-on VMs. Evacuate VMs before power operation."
        }

        switch ($PowerOperation) {
            "Shutdown" {
                $powerTask = Stop-VMHost -VMHost $VMHost -RunAsync -Confirm:$false
                Write-Host "    Initiating graceful shutdown..." -ForegroundColor Gray
            }
            "Reboot" {
                $powerTask = Restart-VMHost -VMHost $VMHost -RunAsync -Confirm:$false
                Write-Host "    Initiating reboot..." -ForegroundColor Gray
            }
            "PowerOn" {
                # Note: PowerOn typically requires out-of-band management (iLO, iDRAC, etc.)
                Write-Host "    PowerOn operation requires out-of-band management interface" -ForegroundColor Yellow
                return @{
                    Host = $VMHost.Name
                    Operation = "Power-$PowerOperation"
                    Status = "NotSupported"
                    Message = "PowerOn requires out-of-band management (iLO, iDRAC, etc.)"
                }
            }
        }

        if ($WaitForCompletion -and $PowerOperation -ne "PowerOn") {
            Write-Host "    Waiting for power operation to complete (timeout: $ShutdownTimeout minutes)..." -ForegroundColor Yellow

            try {
                Wait-Task -Task $powerTask -TimeoutSeconds ($ShutdownTimeout * 60)
                Write-Host "    ✓ Power operation completed successfully" -ForegroundColor Green

                return @{
                    Host = $VMHost.Name
                    Operation = "Power-$PowerOperation"
                    Status = "Success"
                    Message = "Power operation completed successfully"
                }
            }
            catch {
                return @{
                    Host = $VMHost.Name
                    Operation = "Power-$PowerOperation"
                    Status = "Timeout"
                    Message = "Power operation timed out after $ShutdownTimeout minutes"
                }
            }
        } else {
            Write-Host "    ✓ Power operation task initiated" -ForegroundColor Green
            return @{
                Host = $VMHost.Name
                Operation = "Power-$PowerOperation"
                Status = "InProgress"
                Message = "Power operation task initiated"
                Task = $powerTask
            }
        }
    }
    catch {
        return @{
            Host = $VMHost.Name
            Operation = "Power-$PowerOperation"
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to perform host health check
function Get-HostHealthCheck {
    param($VMHost)

    Write-Host "  Performing health check for host '$($VMHost.Name)'..." -ForegroundColor Yellow

    $healthIssues = @()
    $healthStatus = "Healthy"

    try {
        # Check connection state
        if ($VMHost.ConnectionState -ne "Connected") {
            $healthIssues += "Connection state is $($VMHost.ConnectionState)"
            $healthStatus = "Warning"
        }

        # Check overall status
        if ($VMHost.State -eq "NotResponding") {
            $healthIssues += "Host is not responding"
            $healthStatus = "Critical"
        }

        # Check CPU usage
        $cpuUsage = $VMHost.CpuUsageMhz / $VMHost.CpuTotalMhz * 100
        if ($cpuUsage -gt 90) {
            $healthIssues += "High CPU usage: $([math]::Round($cpuUsage, 1))%"
            $healthStatus = "Warning"
        }

        # Check memory usage
        $memUsage = $VMHost.MemoryUsageGB / $VMHost.MemoryTotalGB * 100
        if ($memUsage -gt 90) {
            $healthIssues += "High memory usage: $([math]::Round($memUsage, 1))%"
            $healthStatus = "Warning"
        }

        # Check datastore accessibility
        $datastores = Get-Datastore -VMHost $VMHost
        $inaccessibleDatastores = $datastores | Where-Object { -not $_.Accessible }
        if ($inaccessibleDatastores) {
            $healthIssues += "Inaccessible datastores: $($inaccessibleDatastores.Name -join ', ')"
            $healthStatus = "Critical"
        }

        # Check for alarms
        $alarms = Get-AlarmDefinition | Where-Object { $_.Enabled } | ForEach-Object {
            Get-AlarmStatus -Entity $VMHost -AlarmDefinition $_
        } | Where-Object { $_.Status -ne "Green" }

        if ($alarms) {
            $healthIssues += "Active alarms: $($alarms.Count)"
            if ($alarms | Where-Object { $_.Status -eq "Red" }) {
                $healthStatus = "Critical"
            } elseif ($healthStatus -ne "Critical") {
                $healthStatus = "Warning"
            }
        }

        # Uptime check
        $uptimeDays = [math]::Round($VMHost.ExtensionData.Summary.QuickStats.Uptime / 86400, 1)
        if ($uptimeDays -gt 365) {
            $healthIssues += "Host uptime is very high: $uptimeDays days"
            if ($healthStatus -eq "Healthy") {
                $healthStatus = "Warning"
            }
        }

        $result = @{
            Host = $VMHost.Name
            Operation = "HealthCheck"
            Status = $healthStatus
            Issues = $healthIssues
            ConnectionState = $VMHost.ConnectionState
            PowerState = $VMHost.PowerState
            CPUUsagePercent = [math]::Round($cpuUsage, 1)
            MemoryUsagePercent = [math]::Round($memUsage, 1)
            UptimeDays = $uptimeDays
            Version = $VMHost.Version
            Build = $VMHost.Build
        }

        $statusColor = switch ($healthStatus) {
            "Healthy" { "Green" }
            "Warning" { "Yellow" }
            "Critical" { "Red" }
            default { "White" }
        }

        Write-Host "    Status: $healthStatus" -ForegroundColor $statusColor
        if ($healthIssues.Count -gt 0) {
            foreach ($issue in $healthIssues) {
                Write-Host "      - $issue" -ForegroundColor Gray
            }
        }

        return $result
    }
    catch {
        return @{
            Host = $VMHost.Name
            Operation = "HealthCheck"
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to generate host configuration report
function Get-HostConfigurationReport {
    param(
        $Hosts,
        $OutputFormat,
        $OutputPath
    )

    Write-Host "Generating host configuration report..." -ForegroundColor Yellow

    $reportData = @()

    foreach ($vmHost in $Hosts) {
        try {
            $vmsOnHost = Get-VM -Location $vmHost
            $poweredOnVMs = $vmsOnHost | Where-Object { $_.PowerState -eq "PoweredOn" }
            $datastores = Get-Datastore -VMHost $vmHost

            $reportItem = [PSCustomObject]@{
                Name = $vmHost.Name
                Cluster = $vmHost.Parent.Name
                ConnectionState = $vmHost.ConnectionState
                PowerState = $vmHost.PowerState
                State = $vmHost.State
                Version = $vmHost.Version
                Build = $vmHost.Build
                Manufacturer = $vmHost.Manufacturer
                Model = $vmHost.Model
                ProcessorType = $vmHost.ProcessorType
                CPUCores = $vmHost.NumCpu
                CPUTotalMHz = $vmHost.CpuTotalMhz
                CPUUsageMHz = $vmHost.CpuUsageMhz
                CPUUsagePercent = [math]::Round($vmHost.CpuUsageMhz / $vmHost.CpuTotalMhz * 100, 1)
                MemoryTotalGB = [math]::Round($vmHost.MemoryTotalGB, 2)
                MemoryUsageGB = [math]::Round($vmHost.MemoryUsageGB, 2)
                MemoryUsagePercent = [math]::Round($vmHost.MemoryUsageGB / $vmHost.MemoryTotalGB * 100, 1)
                UptimeDays = [math]::Round($vmHost.ExtensionData.Summary.QuickStats.Uptime / 86400, 1)
                VMs = $vmsOnHost.Count
                PoweredOnVMs = $poweredOnVMs.Count
                Datastores = $datastores.Count
                DatastoreList = ($datastores.Name -join ";")
                VMKernelNICs = ($vmHost | Get-VMHostNetworkAdapter -VMKernel).Count
                PhysicalNICs = ($vmHost | Get-VMHostNetworkAdapter -Physical).Count
                HyperThreading = $vmHost.HyperthreadingActive
                Timestamp = Get-Date
            }

            $reportData += $reportItem
        }
        catch {
            Write-Warning "Failed to get configuration data for host '$($vmHost.Name)': $($_.Exception.Message)"
        }
    }

    # Export report
    switch ($OutputFormat) {
        "Console" {
            Write-Host "`n=== Host Configuration Report ===" -ForegroundColor Cyan
            $reportData | Format-Table Name, ConnectionState, Version, CPUCores, MemoryTotalGB, VMs, PoweredOnVMs -AutoSize
        }
        "CSV" {
            if (-not $OutputPath) {
                $OutputPath = "Host_Configuration_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            }
            $reportData | Export-Csv -Path $OutputPath -NoTypeInformation
            Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
        }
        "JSON" {
            if (-not $OutputPath) {
                $OutputPath = "Host_Configuration_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            }
            $reportData | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
        }
    }

    return $reportData
}

# Function to display operation summary
function Show-HostOperationSummary {
    param(
        $Results,
        $Operation
    )

    Write-Host "`n=== Host $Operation Summary ===" -ForegroundColor Cyan

    $successful = $Results | Where-Object { $_.Status -eq "Success" }
    $failed = $Results | Where-Object { $_.Status -eq "Failed" }
    $inProgress = $Results | Where-Object { $_.Status -eq "InProgress" }
    $warnings = $Results | Where-Object { $_.Status -in @("Warning", "AlreadyInMaintenance", "NotInMaintenance") }

    Write-Host "Total Hosts: $($Results.Count)" -ForegroundColor White
    Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    Write-Host "In Progress: $($inProgress.Count)" -ForegroundColor Yellow
    Write-Host "Warnings: $($warnings.Count)" -ForegroundColor Yellow

    if ($failed.Count -gt 0) {
        Write-Host "`nFailed Operations:" -ForegroundColor Red
        foreach ($result in $failed) {
            Write-Host "  - $($result.Host): $($result.Message)" -ForegroundColor White
        }
    }

    if ($warnings.Count -gt 0) {
        Write-Host "`nWarnings/Info:" -ForegroundColor Yellow
        foreach ($result in $warnings) {
            Write-Host "  - $($result.Host): $($result.Message)" -ForegroundColor White
        }
    }
}

# Main execution
try {
    Write-Host "=== vSphere Host Operations ===" -ForegroundColor Cyan
    Write-Host "Target vCenter: $VCenterServer" -ForegroundColor White
    Write-Host "Operation: $Operation" -ForegroundColor White

    if ($HostName) { Write-Host "Target Host: $HostName" -ForegroundColor White }
    if ($HostNames) { Write-Host "Target Hosts: $($HostNames -join ', ')" -ForegroundColor White }
    if ($ClusterName) { Write-Host "Target Cluster: $ClusterName" -ForegroundColor White }
    Write-Host ""

    # Check and install PowerCLI
    if (-not (Test-PowerCLIInstallation)) {
        throw "PowerCLI installation failed"
    }

    # Connect to vCenter
    $connection = Connect-ToVCenter -Server $VCenterServer

    # Get target hosts
    $targetHosts = Get-TargetHosts -HostName $HostName -HostNames $HostNames -ClusterName $ClusterName

    # Confirm operation if not using Force and operation is potentially disruptive
    if (-not $Force -and $Operation -in @("EnterMaintenance", "Power")) {
        $confirmation = Read-Host "`nProceed with $Operation operation on $($targetHosts.Count) host(s)? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Perform the requested operation
    $results = @()

    switch ($Operation) {
        "EnterMaintenance" {
            foreach ($vmHost in $targetHosts) {
                $result = Enter-HostMaintenanceMode -VMHost $vmHost -EvacuateVMs:$EvacuateVMs -WaitForCompletion:$WaitForCompletion
                $results += $result
            }
        }

        "ExitMaintenance" {
            foreach ($vmHost in $targetHosts) {
                $result = Exit-HostMaintenanceMode -VMHost $vmHost -WaitForCompletion:$WaitForCompletion
                $results += $result
            }
        }

        "Power" {
            if (-not $PowerOperation) {
                throw "PowerOperation parameter is required for Power operation"
            }

            foreach ($vmHost in $targetHosts) {
                $result = Invoke-HostPowerOperation -VMHost $vmHost -PowerOperation $PowerOperation -ShutdownTimeout $ShutdownTimeout -WaitForCompletion:$WaitForCompletion
                $results += $result
            }
        }

        "HealthCheck" {
            foreach ($vmHost in $targetHosts) {
                $result = Get-HostHealthCheck -VMHost $vmHost
                $results += $result
            }

            # Display health summary
            $healthy = $results | Where-Object { $_.Status -eq "Healthy" }
            $warning = $results | Where-Object { $_.Status -eq "Warning" }
            $critical = $results | Where-Object { $_.Status -eq "Critical" }

            Write-Host "`n=== Health Check Summary ===" -ForegroundColor Cyan
            Write-Host "Healthy: $($healthy.Count)" -ForegroundColor Green
            Write-Host "Warning: $($warning.Count)" -ForegroundColor Yellow
            Write-Host "Critical: $($critical.Count)" -ForegroundColor Red
        }

        "Configuration" {
            $results = Get-HostConfigurationReport -Hosts $targetHosts -OutputFormat $OutputFormat -OutputPath $OutputPath
        }

        "Report" {
            $results = Get-HostConfigurationReport -Hosts $targetHosts -OutputFormat $OutputFormat -OutputPath $OutputPath
        }
    }

    # Display summary (except for Report operation which already displays results)
    if ($Operation -notin @("Report", "Configuration", "HealthCheck")) {
        Show-HostOperationSummary -Results $results -Operation $Operation
    }

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
