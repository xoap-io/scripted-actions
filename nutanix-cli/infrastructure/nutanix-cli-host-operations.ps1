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
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: PowerShell with REST API capabilities (Nutanix Prism REST API v3)

.LINK
    https://www.nutanix.dev/reference/prism_central/v3/

.COMPONENT
    Nutanix REST API PowerShell
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, ParameterSetName = "PrismCentral", HelpMessage = "The Prism Central FQDN or IP address to connect to.")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismCentral,

    [Parameter(Mandatory = $false, ParameterSetName = "PrismElement", HelpMessage = "The Prism Element FQDN or IP address to connect to.")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismElement,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the cluster to target for host operations.")]
    [string]$ClusterName,

    [Parameter(Mandatory = $false, HelpMessage = "UUID of a specific cluster to target for host operations.")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ClusterUUID,

    [Parameter(Mandatory = $false, HelpMessage = "Name of a specific host to manage.")]
    [string]$HostName,

    [Parameter(Mandatory = $false, HelpMessage = "Array of host names for batch operations.")]
    [string[]]$HostNames,

    [Parameter(Mandatory = $false, HelpMessage = "UUID of a specific host to manage.")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$HostUUID,

    [Parameter(Mandatory = $false, HelpMessage = "IP address of a specific host to manage.")]
    [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
    [string]$HostIP,

    [Parameter(Mandatory = $true, HelpMessage = "The operation to perform on the host(s). Valid values: Health, Status, Report, Maintenance, Performance, Hardware, VMs, Monitor.")]
    [ValidateSet("Health", "Status", "Report", "Maintenance", "Performance", "Hardware", "VMs", "Monitor")]
    [string]$Operation,

    [Parameter(Mandatory = $false, HelpMessage = "Enable or disable maintenance mode for the host. Valid values: Enable, Disable.")]
    [ValidateSet("Enable", "Disable")]
    [string]$MaintenanceMode,

    [Parameter(Mandatory = $false, HelpMessage = "Force operations without confirmation prompts.")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Include VM information in host reports.")]
    [switch]$IncludeVMs,

    [Parameter(Mandatory = $false, HelpMessage = "Include detailed hardware information in host reports.")]
    [switch]$IncludeHardware,

    [Parameter(Mandatory = $false, HelpMessage = "Include performance metrics in host reports.")]
    [switch]$IncludePerformance,

    [Parameter(Mandatory = $false, HelpMessage = "Enable alerting with custom thresholds.")]
    [switch]$AlertThresholds,

    [Parameter(Mandatory = $false, HelpMessage = "CPU usage threshold percentage for alerts (50-95).")]
    [ValidateRange(50, 95)]
    [int]$CPUThreshold = 80,

    [Parameter(Mandatory = $false, HelpMessage = "Memory usage threshold percentage for alerts (50-95).")]
    [ValidateRange(50, 95)]
    [int]$MemoryThreshold = 85,

    [Parameter(Mandatory = $false, HelpMessage = "Output format for reports. Valid values: Console, CSV, JSON, HTML.")]
    [ValidateSet("Console", "CSV", "JSON", "HTML")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false, HelpMessage = "Path to save the report file.")]
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
        foreach ($hostObj in $hosts) {
            Write-Host "  - $($hostObj.name) [$($hostObj.uuid)] - $($hostObj.hypervisorAddress)" -ForegroundColor White
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
    param($hostObj)

    try {
        Write-Host "  Analyzing host health: $($hostObj.name)" -ForegroundColor Cyan

        # Get host stats
        $hostStats = Get-NTNXHostStats -HostUuid $hostObj.uuid

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

        if ($hostObj.state -ne "NORMAL") {
            $healthStatus = "Critical"
            $healthIssues += "Host state is $($hostObj.state)"
        }

        if ($hostObj.inMaintenanceMode) {
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
            HostName = $hostObj.name
            HostUUID = $hostObj.uuid
            HostIP = $hostObj.hypervisorAddress
            HealthStatus = $healthStatus
            HealthIssues = $healthIssues
            State = $hostObj.state
            InMaintenanceMode = $hostObj.inMaintenanceMode
            CPUUsagePercent = $cpuUsage
            MemoryUsagePercent = $memoryUsage
            HypervisorType = $hostObj.hypervisorType
            HypervisorVersion = $hostObj.hypervisorFullName
            LastUpdated = Get-Date
        }
    }
    catch {
        Write-Warning "    Failed to analyze host health: $($_.Exception.Message)"
        return @{
            HostName = $hostObj.name
            HostUUID = $hostObj.uuid
            HealthStatus = "Unknown"
            HealthIssues = @("Failed to retrieve health data")
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to get detailed host status
function Get-HostStatus {
    param($hostObj, $IncludeVMs, $IncludeHardware, $IncludePerformance)

    try {
        Write-Host "  Getting host status: $($hostObj.name)" -ForegroundColor Cyan

        $status = @{
            HostName = $hostObj.name
            HostUUID = $hostObj.uuid
            HostIP = $hostObj.hypervisorAddress
            ManagementIP = $hostObj.managementServerIp
            State = $hostObj.state
            InMaintenanceMode = $hostObj.inMaintenanceMode
            HypervisorType = $hostObj.hypervisorType
            HypervisorVersion = $hostObj.hypervisorFullName
            ClusterUUID = $hostObj.clusterUuid
            CPUCores = $hostObj.numCpuCores
            CPUSockets = $hostObj.numCpuSockets
            MemoryCapacityGB = [math]::Round($hostObj.memoryCapacityBytes / 1GB, 2)
            LastUpdated = Get-Date
        }

        # Include VM information
        if ($IncludeVMs) {
            $vms = Get-NTNXVM | Where-Object { $_.hostUuid -eq $hostObj.uuid }
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
                Model = $hostObj.modelName
                SerialNumber = $hostObj.serialNumber
                BlockSerial = $hostObj.blockSerial
                Position = $hostObj.position
                CPUModel = $hostObj.cpuModel
                CPUFrequencyHz = $hostObj.cpuFrequencyHz
                HypervisorType = $hostObj.hypervisorType
                HypervisorVersion = $hostObj.hypervisorFullName
                BMCVersion = if ($hostObj.bmcVersion) { $hostObj.bmcVersion } else { "Not Available" }
                BIOSVersion = if ($hostObj.biosVersion) { $hostObj.biosVersion } else { "Not Available" }
            }
        }

        # Include performance information
        if ($IncludePerformance) {
            try {
                $hostStats = Get-NTNXHostStats -HostUuid $hostObj.uuid

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
            HostName = $hostObj.name
            HostUUID = $hostObj.uuid
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to manage host maintenance mode
function Set-HostMaintenanceMode {
    param($hostObj, $MaintenanceMode, $Force)

    try {
        Write-Host "  Managing maintenance mode for host: $($hostObj.name)" -ForegroundColor Cyan

        $currentMode = if ($hostObj.inMaintenanceMode) { "Enabled" } else { "Disabled" }
        Write-Host "    Current maintenance mode: $currentMode" -ForegroundColor White

        if ($currentMode -eq $MaintenanceMode) {
            Write-Host "    Host is already in the requested maintenance mode" -ForegroundColor Yellow
            return @{
                HostName = $hostObj.name
                HostUUID = $hostObj.uuid
                Operation = "Maintenance Mode"
                Status = "No Change Required"
                CurrentMode = $currentMode
                RequestedMode = $MaintenanceMode
                LastUpdated = Get-Date
            }
        }

        # Check for VMs if entering maintenance mode
        if ($MaintenanceMode -eq "Enable") {
            $poweredOnVMs = Get-NTNXVM | Where-Object { $_.hostUuid -eq $hostObj.uuid -and $_.powerState -eq "ON" }
            if ($poweredOnVMs.Count -gt 0 -and -not $Force) {
                Write-Warning "    Host has $($poweredOnVMs.Count) powered-on VMs. Use -Force to proceed with maintenance mode."
                Write-Host "    Powered-on VMs:" -ForegroundColor Yellow
                foreach ($vm in $poweredOnVMs) {
                    Write-Host "      - $($vm.vmName)" -ForegroundColor Yellow
                }
                return @{
                    HostName = $hostObj.name
                    HostUUID = $hostObj.uuid
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
            $confirmation = Read-Host "Are you sure you want to $MaintenanceMode maintenance mode for host '$($hostObj.name)'? (y/N)"
            if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                Write-Host "    Operation cancelled by user" -ForegroundColor Yellow
                return @{
                    HostName = $hostObj.name
                    HostUUID = $hostObj.uuid
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
                $null = Set-NTNXHostMaintenanceMode -HostUuid $hostObj.uuid -InMaintenanceMode $true
                Write-Host "    ✓ Host entered maintenance mode successfully" -ForegroundColor Green
            }
            "Disable" {
                Write-Host "    Exiting maintenance mode..." -ForegroundColor Yellow
                $null = Set-NTNXHostMaintenanceMode -HostUuid $hostObj.uuid -InMaintenanceMode $false
                Write-Host "    ✓ Host exited maintenance mode successfully" -ForegroundColor Green
            }
        }

        return @{
            HostName = $hostObj.name
            HostUUID = $hostObj.uuid
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
            HostName = $hostObj.name
            HostUUID = $hostObj.uuid
            Operation = "Maintenance Mode"
            Status = "Failed"
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to monitor host performance
function Monitor-HostPerformance {
    param($hostObj, $AlertThresholds, $CPUThreshold, $MemoryThreshold)

    try {
        Write-Host "  Monitoring host performance: $($hostObj.name)" -ForegroundColor Cyan

        # Get performance stats
        $stats = Get-NTNXHostStats -HostUuid $hostObj.uuid

        # Calculate performance metrics
        $metrics = @{
            HostName = $hostObj.name
            HostUUID = $hostObj.uuid
            HostIP = $hostObj.hypervisorAddress
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
            State = $hostObj.state
            InMaintenanceMode = $hostObj.inMaintenanceMode
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

            if ($hostObj.state -ne "NORMAL") {
                $alerts += "Host state is $($hostObj.state)"
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
            HostName = $hostObj.name
            HostUUID = $hostObj.uuid
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }
    }
}

# Function to get host hardware information
function Get-HostHardware {
    param($hostObj)

    try {
        Write-Host "  Getting hardware information: $($hostObj.name)" -ForegroundColor Cyan

        $hardware = @{
            HostName = $hostObj.name
            HostUUID = $hostObj.uuid
            HostIP = $hostObj.hypervisorAddress
            Model = $hostObj.modelName
            SerialNumber = $hostObj.serialNumber
            BlockSerial = $hostObj.blockSerial
            Position = $hostObj.position
            CPUModel = $hostObj.cpuModel
            CPUCores = $hostObj.numCpuCores
            CPUSockets = $hostObj.numCpuSockets
            CPUFrequencyHz = $hostObj.cpuFrequencyHz
            MemoryCapacityGB = [math]::Round($hostObj.memoryCapacityBytes / 1GB, 2)
            HypervisorType = $hostObj.hypervisorType
            HypervisorVersion = $hostObj.hypervisorFullName
            BMCVersion = if ($hostObj.bmcVersion) { $hostObj.bmcVersion } else { "Not Available" }
            BIOSVersion = if ($hostObj.biosVersion) { $hostObj.biosVersion } else { "Not Available" }
            LastBootTime = if ($hostObj.bootTimeUsecs) {
                [DateTimeOffset]::FromUnixTimeMilliseconds($hostObj.bootTimeUsecs / 1000).DateTime
            } else { "Not Available" }
            LastUpdated = Get-Date
        }

        Write-Host "    ✓ Hardware information collected" -ForegroundColor Green

        return $hardware
    }
    catch {
        Write-Warning "    Failed to get hardware information: $($_.Exception.Message)"
        return @{
            HostName = $hostObj.name
            HostUUID = $hostObj.uuid
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to get host VMs
function Get-HostVMs {
    param($hostObj)

    try {
        Write-Host "  Getting VMs for host: $($hostObj.name)" -ForegroundColor Cyan

        $vms = Get-NTNXVM | Where-Object { $_.hostUuid -eq $hostObj.uuid }

        $vmInfo = @{
            HostName = $hostObj.name
            HostUUID = $hostObj.uuid
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
            HostName = $hostObj.name
            HostUUID = $hostObj.uuid
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

    foreach ($hostObj in $targetHosts) {
        switch ($Operation) {
            "Health" {
                $result = Get-HostHealth -Host $hostObj
                $results += $result
            }
            "Status" {
                $result = Get-HostStatus -Host $hostObj -IncludeVMs:$IncludeVMs -IncludeHardware:$IncludeHardware -IncludePerformance:$IncludePerformance
                $results += $result
            }
            "Report" {
                $result = Get-HostStatus -Host $hostObj -IncludeVMs:$IncludeVMs -IncludeHardware:$IncludeHardware -IncludePerformance:$IncludePerformance
                $results += $result
            }
            "Maintenance" {
                if (-not $MaintenanceMode) {
                    throw "MaintenanceMode parameter is required for Maintenance operation"
                }
                $result = Set-HostMaintenanceMode -Host $hostObj -MaintenanceMode $MaintenanceMode -Force:$Force
                $results += $result
            }
            "Performance" {
                $result = Monitor-HostPerformance -Host $hostObj -AlertThresholds:$AlertThresholds -CPUThreshold $CPUThreshold -MemoryThreshold $MemoryThreshold
                $results += $result
            }
            "Monitor" {
                $result = Monitor-HostPerformance -Host $hostObj -AlertThresholds:$AlertThresholds -CPUThreshold $CPUThreshold -MemoryThreshold $MemoryThreshold
                $results += $result
            }
            "Hardware" {
                $result = Get-HostHardware -Host $hostObj
                $results += $result
            }
            "VMs" {
                $result = Get-HostVMs -Host $hostObj
                $results += $result
            }
        }
    }

    # Display results
    Show-HostResults -Results $results -Operation $Operation -OutputFormat $OutputFormat -OutputPath $OutputPath

    Write-Host "`n=== Host Operations Completed ===" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    # Disconnect from Nutanix if connected
    if ($global:DefaultNTNXConnection) {
        Write-Host "`nDisconnecting from Nutanix..." -ForegroundColor Yellow
        Disconnect-NTNXCluster
    }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
