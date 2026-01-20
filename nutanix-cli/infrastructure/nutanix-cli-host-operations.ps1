<#
.SYNOPSIS
    Manages Nutanix host operations using Nutanix PowerShell SDK.

.DESCRIPTION
    This script provides comprehensive host management including host health monitoring,
    maintenance operations, resource allocation analysis, and hardware information.
    Supports individual host or cluster-wide host operations.
    Requires Nutanix PowerShell SDK and connection to Prism Central/Element.

.PARAMETER PrismCentral
    The Prism Central FQDN or IP address to connect to.

.PARAMETER PrismElement
    The Prism Element FQDN or IP address to connect to (alternative to Prism Central).

.PARAMETER ClusterName
    Name of the cluster to target for host operations.

.PARAMETER ClusterUUID
    UUID of a specific cluster to target for host operations.

.PARAMETER HostName
    Name of a specific host to manage.

.PARAMETER HostNames
    Array of host names for batch operations.

.PARAMETER HostUUID
    UUID of a specific host to manage.

.PARAMETER HostIP
    IP address of a specific host to manage.

.PARAMETER Operation
    The operation to perform on the host(s).

.PARAMETER MaintenanceMode
    Enable or disable maintenance mode for the host.

.PARAMETER Force
    Force operations without confirmation prompts.

.PARAMETER IncludeVMs
    Include VM information in host reports.

.PARAMETER IncludeHardware
    Include detailed hardware information in host reports.

.PARAMETER IncludePerformance
    Include performance metrics in host reports.

.PARAMETER AlertThresholds
    Enable alerting with custom thresholds.

.PARAMETER CPUThreshold
    CPU usage threshold percentage for alerts.

.PARAMETER MemoryThreshold
    Memory usage threshold percentage for alerts.

.PARAMETER OutputFormat
    Output format for reports.

.PARAMETER OutputPath
    Path to save the report file.

.EXAMPLE
    .\nutanix-cli-host-operations.ps1 -PrismCentral "pc.domain.com" -Operation "Health" -ClusterName "Prod-Cluster"

.EXAMPLE
    .\nutanix-cli-host-operations.ps1 -PrismCentral "pc.domain.com" -Operation "Maintenance" -HostName "Host01" -MaintenanceMode Enable -Force

.EXAMPLE
    .\nutanix-cli-host-operations.ps1 -PrismCentral "pc.domain.com" -Operation "Report" -IncludeVMs -IncludeHardware -IncludePerformance -OutputFormat "HTML" -OutputPath "host-report.html"

.NOTES
    Author: XOAP.io
    Requires: Nutanix PowerShell SDK, AOS 6.0+

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, ParameterSetName = "PrismCentral")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismCentral,

    [Parameter(Mandatory = $false, ParameterSetName = "PrismElement")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismElement,

    [Parameter(Mandatory = $false)]
    [string]$ClusterName,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ClusterUUID,

    [Parameter(Mandatory = $false)]
    [string]$HostName,

    [Parameter(Mandatory = $false)]
    [string[]]$HostNames,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$HostUUID,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
    [string]$HostIP,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Health", "Status", "Report", "Maintenance", "Performance", "Hardware", "VMs", "Monitor")]
    [string]$Operation,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Enable", "Disable")]
    [string]$MaintenanceMode,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeVMs,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeHardware,

    [Parameter(Mandatory = $false)]
    [switch]$IncludePerformance,

    [Parameter(Mandatory = $false)]
    [switch]$AlertThresholds,

    [Parameter(Mandatory = $false)]
    [ValidateRange(50, 95)]
    [int]$CPUThreshold = 80,

    [Parameter(Mandatory = $false)]
    [ValidateRange(50, 95)]
    [int]$MemoryThreshold = 85,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "CSV", "JSON", "HTML")]
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

        # Connect to Nutanix
        $connection = Connect-NTNXCluster -Server $Server -AcceptInvalidSSLCerts
        Write-Host "Successfully connected to $ServerType`: $($connection.Server)" -ForegroundColor Green
        return $connection
    }
    catch {
        Write-Error "Failed to connect to $ServerType $Server`: $($_.Exception.Message)"
        throw
    }
}

# Function to get target hosts
function Get-TargetHosts {
    param(
        $ClusterName,
        $ClusterUUID,
        $HostName,
        $HostNames,
        $HostUUID,
        $HostIP
    )

    try {
        $hosts = @()
        $allHosts = Get-NTNXHost

        # Filter by cluster first if specified
        if ($ClusterName) {
            $cluster = Get-NTNXCluster | Where-Object { $_.name -eq $ClusterName }
            if (-not $cluster) {
                throw "Cluster '$ClusterName' not found"
            }
            $allHosts = $allHosts | Where-Object { $_.clusterUuid -eq $cluster.clusterUuid }
        }
        elseif ($ClusterUUID) {
            $allHosts = $allHosts | Where-Object { $_.clusterUuid -eq $ClusterUUID }
        }

        # Filter by specific host criteria
        if ($HostUUID) {
            $hosts = $allHosts | Where-Object { $_.uuid -eq $HostUUID }
        }
        elseif ($HostName) {
            $hosts = $allHosts | Where-Object { $_.name -eq $HostName }
        }
        elseif ($HostNames) {
            $hosts = $allHosts | Where-Object { $_.name -in $HostNames }
        }
        elseif ($HostIP) {
            $hosts = $allHosts | Where-Object { $_.managementServerIp -eq $HostIP -or $_.hypervisorAddress -eq $HostIP }
        }
        else {
            # Return all hosts (filtered by cluster if specified)
            $hosts = $allHosts
        }

        if (-not $hosts) {
            throw "No hosts found matching the specified criteria"
        }

        Write-Host "Found $($hosts.Count) host(s) for processing:" -ForegroundColor Green
        foreach ($host in $hosts) {
            Write-Host "  - $($host.name) [$($host.uuid)] - $($host.hypervisorAddress)" -ForegroundColor White
        }

        return $hosts
    }
    catch {
        Write-Error "Failed to get target hosts: $($_.Exception.Message)"
        throw
    }
}

# Function to get host health information
function Get-HostHealth {
    param($Host)

    try {
        Write-Host "  Analyzing host health: $($Host.name)" -ForegroundColor Cyan

        # Get host stats
        $hostStats = Get-NTNXHostStats -HostUuid $Host.uuid

        # Calculate health metrics
        $cpuUsage = if ($hostStats.statsSpecificEntries.cpuUsagePpm) {
            [math]::Round($hostStats.statsSpecificEntries.cpuUsagePpm / 10000, 2)
        } else { 0 }

        $memoryUsage = if ($hostStats.statsSpecificEntries.memoryUsagePpm) {
            [math]::Round($hostStats.statsSpecificEntries.memoryUsagePpm / 10000, 2)
        } else { 0 }

        # Determine overall health status
        $healthStatus = "Healthy"
        $healthIssues = @()

        if ($Host.state -ne "NORMAL") {
            $healthStatus = "Critical"
            $healthIssues += "Host state is $($Host.state)"
        }

        if ($Host.inMaintenanceMode) {
            if ($healthStatus -eq "Healthy") { $healthStatus = "Warning" }
            $healthIssues += "Host is in maintenance mode"
        }

        if ($cpuUsage -gt 90) {
            $healthStatus = "Critical"
            $healthIssues += "High CPU usage: $cpuUsage%"
        } elseif ($cpuUsage -gt 80) {
            if ($healthStatus -eq "Healthy") { $healthStatus = "Warning" }
            $healthIssues += "Elevated CPU usage: $cpuUsage%"
        }

        if ($memoryUsage -gt 95) {
            $healthStatus = "Critical"
            $healthIssues += "High memory usage: $memoryUsage%"
        } elseif ($memoryUsage -gt 85) {
            if ($healthStatus -eq "Healthy") { $healthStatus = "Warning" }
            $healthIssues += "Elevated memory usage: $memoryUsage%"
        }

        Write-Host "    ✓ Health analysis completed - Status: $healthStatus" -ForegroundColor $(
            switch ($healthStatus) {
                "Healthy" { "Green" }
                "Warning" { "Yellow" }
                "Critical" { "Red" }
                default { "White" }
            }
        )

        return @{
            HostName = $Host.name
            HostUUID = $Host.uuid
            HostIP = $Host.hypervisorAddress
            HealthStatus = $healthStatus
            HealthIssues = $healthIssues
            State = $Host.state
            InMaintenanceMode = $Host.inMaintenanceMode
            CPUUsagePercent = $cpuUsage
            MemoryUsagePercent = $memoryUsage
            HypervisorType = $Host.hypervisorType
            HypervisorVersion = $Host.hypervisorFullName
            LastUpdated = Get-Date
        }
    }
    catch {
        Write-Warning "    Failed to analyze host health: $($_.Exception.Message)"
        return @{
            HostName = $Host.name
            HostUUID = $Host.uuid
            HealthStatus = "Unknown"
            HealthIssues = @("Failed to retrieve health data")
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to get detailed host status
function Get-HostStatus {
    param($Host, $IncludeVMs, $IncludeHardware, $IncludePerformance)

    try {
        Write-Host "  Getting host status: $($Host.name)" -ForegroundColor Cyan

        $status = @{
            HostName = $Host.name
            HostUUID = $Host.uuid
            HostIP = $Host.hypervisorAddress
            ManagementIP = $Host.managementServerIp
            State = $Host.state
            InMaintenanceMode = $Host.inMaintenanceMode
            HypervisorType = $Host.hypervisorType
            HypervisorVersion = $Host.hypervisorFullName
            ClusterUUID = $Host.clusterUuid
            CPUCores = $Host.numCpuCores
            CPUSockets = $Host.numCpuSockets
            MemoryCapacityGB = [math]::Round($Host.memoryCapacityBytes / 1GB, 2)
            LastUpdated = Get-Date
        }

        # Include VM information
        if ($IncludeVMs) {
            $vms = Get-NTNXVM | Where-Object { $_.hostUuid -eq $Host.uuid }
            $poweredOnVMs = $vms | Where-Object { $_.powerState -eq "ON" }

            $status.VMInfo = @{
                TotalVMs = $vms.Count
                PoweredOnVMs = $poweredOnVMs.Count
                PoweredOffVMs = ($vms | Where-Object { $_.powerState -eq "OFF" }).Count
                TotalCPUs = ($vms | Measure-Object -Property numVcpus -Sum).Sum
                TotalMemoryGB = [math]::Round(($vms | Measure-Object -Property memoryMb -Sum).Sum / 1024, 2)
                VMNames = $vms | Select-Object -ExpandProperty vmName
            }
        }

        # Include hardware information
        if ($IncludeHardware) {
            $status.HardwareInfo = @{
                Model = $Host.modelName
                SerialNumber = $Host.serialNumber
                BlockSerial = $Host.blockSerial
                Position = $Host.position
                CPUModel = $Host.cpuModel
                CPUFrequencyHz = $Host.cpuFrequencyHz
                HypervisorType = $Host.hypervisorType
                HypervisorVersion = $Host.hypervisorFullName
                BMCVersion = if ($Host.bmcVersion) { $Host.bmcVersion } else { "Not Available" }
                BIOSVersion = if ($Host.biosVersion) { $Host.biosVersion } else { "Not Available" }
            }
        }

        # Include performance information
        if ($IncludePerformance) {
            try {
                $hostStats = Get-NTNXHostStats -HostUuid $Host.uuid

                $status.PerformanceInfo = @{
                    CPUUsagePercent = if ($hostStats.statsSpecificEntries.cpuUsagePpm) {
                        [math]::Round($hostStats.statsSpecificEntries.cpuUsagePpm / 10000, 2)
                    } else { 0 }
                    MemoryUsagePercent = if ($hostStats.statsSpecificEntries.memoryUsagePpm) {
                        [math]::Round($hostStats.statsSpecificEntries.memoryUsagePpm / 10000, 2)
                    } else { 0 }
                    IOPSRead = if ($hostStats.statsSpecificEntries.readIOPS) { $hostStats.statsSpecificEntries.readIOPS } else { 0 }
                    IOPSWrite = if ($hostStats.statsSpecificEntries.writeIOPS) { $hostStats.statsSpecificEntries.writeIOPS } else { 0 }
                    ThroughputReadMBps = if ($hostStats.statsSpecificEntries.readThroughputMBps) { $hostStats.statsSpecificEntries.readThroughputMBps } else { 0 }
                    ThroughputWriteMBps = if ($hostStats.statsSpecificEntries.writeThroughputMBps) { $hostStats.statsSpecificEntries.writeThroughputMBps } else { 0 }
                }
            }
            catch {
                $status.PerformanceInfo = @{
                    Error = "Failed to retrieve performance stats: $($_.Exception.Message)"
                }
            }
        }

        Write-Host "    ✓ Status information collected" -ForegroundColor Green

        return $status
    }
    catch {
        Write-Warning "    Failed to get host status: $($_.Exception.Message)"
        return @{
            HostName = $Host.name
            HostUUID = $Host.uuid
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to manage host maintenance mode
function Set-HostMaintenanceMode {
    param($Host, $MaintenanceMode, $Force)

    try {
        Write-Host "  Managing maintenance mode for host: $($Host.name)" -ForegroundColor Cyan

        $currentMode = if ($Host.inMaintenanceMode) { "Enabled" } else { "Disabled" }
        Write-Host "    Current maintenance mode: $currentMode" -ForegroundColor White

        if ($currentMode -eq $MaintenanceMode) {
            Write-Host "    Host is already in the requested maintenance mode" -ForegroundColor Yellow
            return @{
                HostName = $Host.name
                HostUUID = $Host.uuid
                Operation = "Maintenance Mode"
                Status = "No Change Required"
                CurrentMode = $currentMode
                RequestedMode = $MaintenanceMode
                LastUpdated = Get-Date
            }
        }

        # Check for VMs if entering maintenance mode
        if ($MaintenanceMode -eq "Enable") {
            $poweredOnVMs = Get-NTNXVM | Where-Object { $_.hostUuid -eq $Host.uuid -and $_.powerState -eq "ON" }
            if ($poweredOnVMs.Count -gt 0 -and -not $Force) {
                Write-Warning "    Host has $($poweredOnVMs.Count) powered-on VMs. Use -Force to proceed with maintenance mode."
                Write-Host "    Powered-on VMs:" -ForegroundColor Yellow
                foreach ($vm in $poweredOnVMs) {
                    Write-Host "      - $($vm.vmName)" -ForegroundColor Yellow
                }
                return @{
                    HostName = $Host.name
                    HostUUID = $Host.uuid
                    Operation = "Maintenance Mode"
                    Status = "Blocked"
                    Reason = "Host has powered-on VMs"
                    PoweredOnVMs = $poweredOnVMs.Count
                    LastUpdated = Get-Date
                }
            }
        }

        # Confirm operation
        if (-not $Force) {
            $confirmation = Read-Host "Are you sure you want to $MaintenanceMode maintenance mode for host '$($Host.name)'? (y/N)"
            if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                Write-Host "    Operation cancelled by user" -ForegroundColor Yellow
                return @{
                    HostName = $Host.name
                    HostUUID = $Host.uuid
                    Operation = "Maintenance Mode"
                    Status = "Cancelled"
                    LastUpdated = Get-Date
                }
            }
        }

        # Perform maintenance mode operation
        switch ($MaintenanceMode) {
            "Enable" {
                Write-Host "    Entering maintenance mode..." -ForegroundColor Yellow
                $result = Set-NTNXHostMaintenanceMode -HostUuid $Host.uuid -InMaintenanceMode $true
                Write-Host "    ✓ Host entered maintenance mode successfully" -ForegroundColor Green
            }
            "Disable" {
                Write-Host "    Exiting maintenance mode..." -ForegroundColor Yellow
                $result = Set-NTNXHostMaintenanceMode -HostUuid $Host.uuid -InMaintenanceMode $false
                Write-Host "    ✓ Host exited maintenance mode successfully" -ForegroundColor Green
            }
        }

        return @{
            HostName = $Host.name
            HostUUID = $Host.uuid
            Operation = "Maintenance Mode"
            Status = "Success"
            PreviousMode = $currentMode
            NewMode = $MaintenanceMode
            LastUpdated = Get-Date
        }
    }
    catch {
        Write-Error "    Failed to manage maintenance mode: $($_.Exception.Message)"
        return @{
            HostName = $Host.name
            HostUUID = $Host.uuid
            Operation = "Maintenance Mode"
            Status = "Failed"
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to monitor host performance
function Monitor-HostPerformance {
    param($Host, $AlertThresholds, $CPUThreshold, $MemoryThreshold)

    try {
        Write-Host "  Monitoring host performance: $($Host.name)" -ForegroundColor Cyan

        # Get performance stats
        $stats = Get-NTNXHostStats -HostUuid $Host.uuid

        # Calculate performance metrics
        $metrics = @{
            HostName = $Host.name
            HostUUID = $Host.uuid
            HostIP = $Host.hypervisorAddress
            CPUUsagePercent = if ($stats.statsSpecificEntries.cpuUsagePpm) {
                [math]::Round($stats.statsSpecificEntries.cpuUsagePpm / 10000, 2)
            } else { 0 }
            MemoryUsagePercent = if ($stats.statsSpecificEntries.memoryUsagePpm) {
                [math]::Round($stats.statsSpecificEntries.memoryUsagePpm / 10000, 2)
            } else { 0 }
            IOPSRead = if ($stats.statsSpecificEntries.readIOPS) { $stats.statsSpecificEntries.readIOPS } else { 0 }
            IOPSWrite = if ($stats.statsSpecificEntries.writeIOPS) { $stats.statsSpecificEntries.writeIOPS } else { 0 }
            ThroughputReadMBps = if ($stats.statsSpecificEntries.readThroughputMBps) { $stats.statsSpecificEntries.readThroughputMBps } else { 0 }
            ThroughputWriteMBps = if ($stats.statsSpecificEntries.writeThroughputMBps) { $stats.statsSpecificEntries.writeThroughputMBps } else { 0 }
            State = $Host.state
            InMaintenanceMode = $Host.inMaintenanceMode
            Timestamp = Get-Date
        }

        # Check for alerts if thresholds are enabled
        if ($AlertThresholds) {
            $alerts = @()

            if ($metrics.CPUUsagePercent -gt $CPUThreshold) {
                $alerts += "CPU usage ($($metrics.CPUUsagePercent)%) exceeds threshold ($CPUThreshold%)"
                Write-Host "    ⚠ ALERT: $($alerts[-1])" -ForegroundColor Red
            }

            if ($metrics.MemoryUsagePercent -gt $MemoryThreshold) {
                $alerts += "Memory usage ($($metrics.MemoryUsagePercent)%) exceeds threshold ($MemoryThreshold%)"
                Write-Host "    ⚠ ALERT: $($alerts[-1])" -ForegroundColor Red
            }

            if ($Host.state -ne "NORMAL") {
                $alerts += "Host state is $($Host.state)"
                Write-Host "    ⚠ ALERT: $($alerts[-1])" -ForegroundColor Red
            }

            $metrics.Alerts = $alerts
            $metrics.AlertCount = $alerts.Count
        }

        Write-Host "    ✓ Performance metrics collected - CPU: $($metrics.CPUUsagePercent)%, Memory: $($metrics.MemoryUsagePercent)%" -ForegroundColor Green

        return $metrics
    }
    catch {
        Write-Warning "    Failed to monitor host performance: $($_.Exception.Message)"
        return @{
            HostName = $Host.name
            HostUUID = $Host.uuid
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }
    }
}

# Function to get host hardware information
function Get-HostHardware {
    param($Host)

    try {
        Write-Host "  Getting hardware information: $($Host.name)" -ForegroundColor Cyan

        $hardware = @{
            HostName = $Host.name
            HostUUID = $Host.uuid
            HostIP = $Host.hypervisorAddress
            Model = $Host.modelName
            SerialNumber = $Host.serialNumber
            BlockSerial = $Host.blockSerial
            Position = $Host.position
            CPUModel = $Host.cpuModel
            CPUCores = $Host.numCpuCores
            CPUSockets = $Host.numCpuSockets
            CPUFrequencyHz = $Host.cpuFrequencyHz
            MemoryCapacityGB = [math]::Round($Host.memoryCapacityBytes / 1GB, 2)
            HypervisorType = $Host.hypervisorType
            HypervisorVersion = $Host.hypervisorFullName
            BMCVersion = if ($Host.bmcVersion) { $Host.bmcVersion } else { "Not Available" }
            BIOSVersion = if ($Host.biosVersion) { $Host.biosVersion } else { "Not Available" }
            LastBootTime = if ($Host.bootTimeUsecs) {
                [DateTimeOffset]::FromUnixTimeMilliseconds($Host.bootTimeUsecs / 1000).DateTime
            } else { "Not Available" }
            LastUpdated = Get-Date
        }

        Write-Host "    ✓ Hardware information collected" -ForegroundColor Green

        return $hardware
    }
    catch {
        Write-Warning "    Failed to get hardware information: $($_.Exception.Message)"
        return @{
            HostName = $Host.name
            HostUUID = $Host.uuid
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to get host VMs
function Get-HostVMs {
    param($Host)

    try {
        Write-Host "  Getting VMs for host: $($Host.name)" -ForegroundColor Cyan

        $vms = Get-NTNXVM | Where-Object { $_.hostUuid -eq $Host.uuid }

        $vmInfo = @{
            HostName = $Host.name
            HostUUID = $Host.uuid
            TotalVMs = $vms.Count
            PoweredOnVMs = ($vms | Where-Object { $_.powerState -eq "ON" }).Count
            PoweredOffVMs = ($vms | Where-Object { $_.powerState -eq "OFF" }).Count
            TotalCPUs = ($vms | Measure-Object -Property numVcpus -Sum).Sum
            TotalMemoryGB = [math]::Round(($vms | Measure-Object -Property memoryMb -Sum).Sum / 1024, 2)
            VMs = $vms | Select-Object vmName, powerState, numVcpus, @{Name="MemoryGB";Expression={[math]::Round($_.memoryMb/1024,2)}}, description
            LastUpdated = Get-Date
        }

        Write-Host "    ✓ VM information collected - $($vmInfo.TotalVMs) VMs ($($vmInfo.PoweredOnVMs) powered on)" -ForegroundColor Green

        return $vmInfo
    }
    catch {
        Write-Warning "    Failed to get VM information: $($_.Exception.Message)"
        return @{
            HostName = $Host.name
            HostUUID = $Host.uuid
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to display results
function Show-HostResults {
    param($Results, $Operation, $OutputFormat, $OutputPath)

    Write-Host "`n=== Host $Operation Results ===" -ForegroundColor Cyan

    switch ($Operation) {
        "Health" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nHost Health Summary:" -ForegroundColor Green
                foreach ($result in $Results) {
                    $statusColor = switch ($result.HealthStatus) {
                        "Healthy" { "Green" }
                        "Warning" { "Yellow" }
                        "Critical" { "Red" }
                        default { "White" }
                    }
                    Write-Host "$($result.HostName): $($result.HealthStatus)" -ForegroundColor $statusColor
                    if ($result.HealthIssues -and $result.HealthIssues.Count -gt 0) {
                        foreach ($issue in $result.HealthIssues) {
                            Write-Host "  - $issue" -ForegroundColor Yellow
                        }
                    }
                }
            }
        }
        "Monitor" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nHost Performance Monitoring:" -ForegroundColor Green
                $Results | Format-Table HostName, CPUUsagePercent, MemoryUsagePercent, State, InMaintenanceMode, IOPSRead, IOPSWrite -AutoSize

                # Show alerts if any
                $alertResults = $Results | Where-Object { $_.AlertCount -gt 0 }
                if ($alertResults) {
                    Write-Host "`nActive Alerts:" -ForegroundColor Red
                    foreach ($result in $alertResults) {
                        Write-Host "$($result.HostName):" -ForegroundColor Yellow
                        foreach ($alert in $result.Alerts) {
                            Write-Host "  ⚠ $alert" -ForegroundColor Red
                        }
                    }
                }
            }
        }
        "Hardware" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nHost Hardware Information:" -ForegroundColor Green
                foreach ($result in $Results) {
                    Write-Host "`nHost: $($result.HostName)" -ForegroundColor White
                    Write-Host "  Model: $($result.Model)" -ForegroundColor White
                    Write-Host "  Serial: $($result.SerialNumber)" -ForegroundColor White
                    Write-Host "  CPU: $($result.CPUCores) cores, $($result.CPUSockets) sockets ($($result.CPUModel))" -ForegroundColor White
                    Write-Host "  Memory: $($result.MemoryCapacityGB) GB" -ForegroundColor White
                    Write-Host "  Hypervisor: $($result.HypervisorType) $($result.HypervisorVersion)" -ForegroundColor White
                }
            }
        }
        "VMs" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nHost VM Information:" -ForegroundColor Green
                foreach ($result in $Results) {
                    Write-Host "`nHost: $($result.HostName)" -ForegroundColor White
                    Write-Host "  Total VMs: $($result.TotalVMs) ($($result.PoweredOnVMs) powered on)" -ForegroundColor White
                    Write-Host "  Total Resources: $($result.TotalCPUs) vCPUs, $($result.TotalMemoryGB) GB RAM" -ForegroundColor White
                    if ($result.VMs -and $result.VMs.Count -gt 0) {
                        Write-Host "  VM List:" -ForegroundColor White
                        $result.VMs | Format-Table vmName, powerState, numVcpus, MemoryGB -AutoSize
                    }
                }
            }
        }
        default {
            if ($OutputFormat -eq "Console") {
                $Results | Format-Table -AutoSize
            }
        }
    }

    # Export results if requested
    if ($OutputFormat -ne "Console") {
        switch ($OutputFormat) {
            "CSV" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_Host_$Operation`_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                }
                $Results | Export-Csv -Path $OutputPath -NoTypeInformation
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
            "JSON" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_Host_$Operation`_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                }
                $Results | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
            "HTML" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_Host_$Operation`_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
                }
                $htmlContent = $Results | ConvertTo-Html -Title "Nutanix Host $Operation Report" -Head "<style>table{border-collapse:collapse;width:100%;}th,td{border:1px solid #ddd;padding:8px;text-align:left;}th{background-color:#f2f2f2;}</style>"
                $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "`nHTML report generated: $OutputPath" -ForegroundColor Green
            }
        }
    }
}

# Main execution
try {
    Write-Host "=== Nutanix Host Operations ===" -ForegroundColor Cyan

    # Determine target server
    $targetServer = if ($PrismCentral) { $PrismCentral } else { $PrismElement }
    $serverType = if ($PrismCentral) { "Prism Central" } else { "Prism Element" }

    if (-not $targetServer) {
        throw "Either PrismCentral or PrismElement parameter must be specified"
    }

    Write-Host "Target $serverType`: $targetServer" -ForegroundColor White
    Write-Host "Operation: $Operation" -ForegroundColor White
    Write-Host ""

    # Check and install Nutanix PowerShell SDK
    if (-not (Test-NutanixSDKInstallation)) {
        throw "Nutanix PowerShell SDK installation failed"
    }

    # Connect to Nutanix
    $connection = Connect-ToNutanix -Server $targetServer -ServerType $serverType

    # Get target hosts
    $targetHosts = Get-TargetHosts -ClusterName $ClusterName -ClusterUUID $ClusterUUID -HostName $HostName -HostNames $HostNames -HostUUID $HostUUID -HostIP $HostIP

    # Perform operations
    $results = @()

    foreach ($host in $targetHosts) {
        switch ($Operation) {
            "Health" {
                $result = Get-HostHealth -Host $host
                $results += $result
            }
            "Status" {
                $result = Get-HostStatus -Host $host -IncludeVMs:$IncludeVMs -IncludeHardware:$IncludeHardware -IncludePerformance:$IncludePerformance
                $results += $result
            }
            "Report" {
                $result = Get-HostStatus -Host $host -IncludeVMs:$IncludeVMs -IncludeHardware:$IncludeHardware -IncludePerformance:$IncludePerformance
                $results += $result
            }
            "Maintenance" {
                if (-not $MaintenanceMode) {
                    throw "MaintenanceMode parameter is required for Maintenance operation"
                }
                $result = Set-HostMaintenanceMode -Host $host -MaintenanceMode $MaintenanceMode -Force:$Force
                $results += $result
            }
            "Performance" {
                $result = Monitor-HostPerformance -Host $host -AlertThresholds:$AlertThresholds -CPUThreshold $CPUThreshold -MemoryThreshold $MemoryThreshold
                $results += $result
            }
            "Monitor" {
                $result = Monitor-HostPerformance -Host $host -AlertThresholds:$AlertThresholds -CPUThreshold $CPUThreshold -MemoryThreshold $MemoryThreshold
                $results += $result
            }
            "Hardware" {
                $result = Get-HostHardware -Host $host
                $results += $result
            }
            "VMs" {
                $result = Get-HostVMs -Host $host
                $results += $result
            }
        }
    }

    # Display results
    Show-HostResults -Results $results -Operation $Operation -OutputFormat $OutputFormat -OutputPath $OutputPath

    Write-Host "`n=== Host Operations Completed ===" -ForegroundColor Green
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
