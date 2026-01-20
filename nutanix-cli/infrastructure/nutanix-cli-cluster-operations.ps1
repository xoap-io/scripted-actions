<#
.SYNOPSIS
    Manages Nutanix cluster operations using Nutanix PowerShell SDK.

.DESCRIPTION
    This script provides comprehensive cluster management including health monitoring,
    configuration management, capacity planning, and maintenance operations.
    Supports multi-cluster environments through Prism Central.
    Requires Nutanix PowerShell SDK and connection to Prism Central/Element.

.PARAMETER PrismCentral
    The Prism Central FQDN or IP address to connect to.

.PARAMETER PrismElement
    The Prism Element FQDN or IP address to connect to (alternative to Prism Central).

.PARAMETER ClusterName
    Name of the cluster to manage.

.PARAMETER ClusterNames
    Array of cluster names for batch operations.

.PARAMETER ClusterUUID
    UUID of a specific cluster to manage.

.PARAMETER Operation
    The operation to perform on the cluster(s).

.PARAMETER IncludeVMs
    Include VM information in cluster reports.

.PARAMETER IncludeHosts
    Include host information in cluster reports.

.PARAMETER IncludeStorage
    Include storage information in cluster reports.

.PARAMETER IncludeNetworking
    Include networking information in cluster reports.

.PARAMETER AlertThresholds
    Enable alerting with custom thresholds.

.PARAMETER CPUThreshold
    CPU usage threshold percentage for alerts.

.PARAMETER MemoryThreshold
    Memory usage threshold percentage for alerts.

.PARAMETER StorageThreshold
    Storage usage threshold percentage for alerts.

.PARAMETER RefreshInterval
    Refresh interval in seconds for continuous monitoring.

.PARAMETER ContinuousMonitoring
    Enable continuous monitoring mode.

.PARAMETER OutputFormat
    Output format for reports.

.PARAMETER OutputPath
    Path to save the report file.

.PARAMETER Force
    Force operations without confirmation prompts.

.EXAMPLE
    .\nutanix-cli-cluster-operations.ps1 -PrismCentral "pc.domain.com" -Operation "Health" -ClusterName "Prod-Cluster"

.EXAMPLE
    .\nutanix-cli-cluster-operations.ps1 -PrismCentral "pc.domain.com" -Operation "Monitor" -ContinuousMonitoring -RefreshInterval 60 -AlertThresholds -CPUThreshold 80 -MemoryThreshold 85

.EXAMPLE
    .\nutanix-cli-cluster-operations.ps1 -PrismCentral "pc.domain.com" -Operation "Report" -IncludeVMs -IncludeHosts -IncludeStorage -OutputFormat "HTML" -OutputPath "cluster-report.html"

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
    [string[]]$ClusterNames,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ClusterUUID,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Health", "Status", "Monitor", "Report", "Capacity", "Performance", "Alerts", "Maintenance")]
    [string]$Operation,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeVMs,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeHosts,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeStorage,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeNetworking,

    [Parameter(Mandatory = $false)]
    [switch]$AlertThresholds,

    [Parameter(Mandatory = $false)]
    [ValidateRange(50, 95)]
    [int]$CPUThreshold = 80,

    [Parameter(Mandatory = $false)]
    [ValidateRange(50, 95)]
    [int]$MemoryThreshold = 85,

    [Parameter(Mandatory = $false)]
    [ValidateRange(50, 95)]
    [int]$StorageThreshold = 90,

    [Parameter(Mandatory = $false)]
    [ValidateRange(30, 3600)]
    [int]$RefreshInterval = 300,

    [Parameter(Mandatory = $false)]
    [switch]$ContinuousMonitoring,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "CSV", "JSON", "HTML")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$Force
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

# Function to get target clusters
function Get-TargetClusters {
    param(
        $ClusterName,
        $ClusterNames,
        $ClusterUUID
    )

    try {
        $clusters = @()

        if ($ClusterUUID) {
            # Get cluster by UUID
            $clusters = Get-NTNXCluster | Where-Object { $_.clusterUuid -eq $ClusterUUID }
        }
        elseif ($ClusterName) {
            # Get cluster by name
            $clusters = Get-NTNXCluster | Where-Object { $_.name -eq $ClusterName }
        }
        elseif ($ClusterNames) {
            # Get multiple clusters by name
            $clusters = Get-NTNXCluster | Where-Object { $_.name -in $ClusterNames }
        }
        else {
            # Get all clusters
            $clusters = Get-NTNXCluster
        }

        if (-not $clusters) {
            throw "No clusters found matching the specified criteria"
        }

        Write-Host "Found $($clusters.Count) cluster(s) for processing:" -ForegroundColor Green
        foreach ($cluster in $clusters) {
            Write-Host "  - $($cluster.name) [$($cluster.clusterUuid)]" -ForegroundColor White
        }

        return $clusters
    }
    catch {
        Write-Error "Failed to get target clusters: $($_.Exception.Message)"
        throw
    }
}

# Function to get cluster health information
function Get-ClusterHealth {
    param($Cluster)

    try {
        Write-Host "  Analyzing cluster health: $($Cluster.name)" -ForegroundColor Cyan

        # Get cluster stats
        $clusterStats = Get-NTNXClusterStats -ClusterUuid $Cluster.clusterUuid

        # Get host information
        $hosts = Get-NTNXHost | Where-Object { $_.clusterUuid -eq $Cluster.clusterUuid }
        $hostsOnline = $hosts | Where-Object { $_.state -eq "NORMAL" }

        # Get storage information
        $storageContainers = Get-NTNXStorageContainer | Where-Object { $_.clusterUuid -eq $Cluster.clusterUuid }

        # Calculate health metrics
        $cpuUsage = if ($clusterStats.statsSpecificEntries.cpuUsagePpm) {
            [math]::Round($clusterStats.statsSpecificEntries.cpuUsagePpm / 10000, 2)
        } else { 0 }

        $memoryUsage = if ($clusterStats.statsSpecificEntries.memoryUsagePpm) {
            [math]::Round($clusterStats.statsSpecificEntries.memoryUsagePpm / 10000, 2)
        } else { 0 }

        $storageUsage = if ($clusterStats.statsSpecificEntries.storageUsageBytes -and $Cluster.storageCapacityBytes) {
            [math]::Round(($clusterStats.statsSpecificEntries.storageUsageBytes / $Cluster.storageCapacityBytes) * 100, 2)
        } else { 0 }

        # Determine overall health status
        $healthStatus = "Healthy"
        $healthIssues = @()

        if ($hostsOnline.Count -ne $hosts.Count) {
            $healthStatus = "Warning"
            $healthIssues += "Some hosts are not in NORMAL state"
        }

        if ($cpuUsage -gt 85) {
            $healthStatus = "Critical"
            $healthIssues += "High CPU usage: $cpuUsage%"
        } elseif ($cpuUsage -gt 75) {
            if ($healthStatus -eq "Healthy") { $healthStatus = "Warning" }
            $healthIssues += "Elevated CPU usage: $cpuUsage%"
        }

        if ($memoryUsage -gt 90) {
            $healthStatus = "Critical"
            $healthIssues += "High memory usage: $memoryUsage%"
        } elseif ($memoryUsage -gt 80) {
            if ($healthStatus -eq "Healthy") { $healthStatus = "Warning" }
            $healthIssues += "Elevated memory usage: $memoryUsage%"
        }

        if ($storageUsage -gt 90) {
            $healthStatus = "Critical"
            $healthIssues += "High storage usage: $storageUsage%"
        } elseif ($storageUsage -gt 80) {
            if ($healthStatus -eq "Healthy") { $healthStatus = "Warning" }
            $healthIssues += "Elevated storage usage: $storageUsage%"
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
            ClusterName = $Cluster.name
            ClusterUUID = $Cluster.clusterUuid
            HealthStatus = $healthStatus
            HealthIssues = $healthIssues
            CPUUsagePercent = $cpuUsage
            MemoryUsagePercent = $memoryUsage
            StorageUsagePercent = $storageUsage
            TotalHosts = $hosts.Count
            HealthyHosts = $hostsOnline.Count
            TotalContainers = $storageContainers.Count
            ClusterVersion = $Cluster.version
            HypervisorTypes = ($hosts | Select-Object -ExpandProperty hypervisorType -Unique) -join ", "
            LastUpdated = Get-Date
        }
    }
    catch {
        Write-Warning "    Failed to analyze cluster health: $($_.Exception.Message)"
        return @{
            ClusterName = $Cluster.name
            ClusterUUID = $Cluster.clusterUuid
            HealthStatus = "Unknown"
            HealthIssues = @("Failed to retrieve health data")
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to get detailed cluster status
function Get-ClusterStatus {
    param($Cluster, $IncludeVMs, $IncludeHosts, $IncludeStorage, $IncludeNetworking)

    try {
        Write-Host "  Getting cluster status: $($Cluster.name)" -ForegroundColor Cyan

        $status = @{
            ClusterName = $Cluster.name
            ClusterUUID = $Cluster.clusterUuid
            Version = $Cluster.version
            NumberOfNodes = $Cluster.numberOfNodes
            ExternalDataServicesIP = $Cluster.externalDataServicesIP
            ExternalIP = $Cluster.externalIP
            LastUpdated = Get-Date
        }

        # Include VM information
        if ($IncludeVMs) {
            $vms = Get-NTNXVM | Where-Object { $_.clusterUuid -eq $Cluster.clusterUuid }
            $poweredOnVMs = $vms | Where-Object { $_.powerState -eq "ON" }

            $status.VMInfo = @{
                TotalVMs = $vms.Count
                PoweredOnVMs = $poweredOnVMs.Count
                PoweredOffVMs = ($vms | Where-Object { $_.powerState -eq "OFF" }).Count
                TotalCPUs = ($vms | Measure-Object -Property numVcpus -Sum).Sum
                TotalMemoryGB = [math]::Round(($vms | Measure-Object -Property memoryMb -Sum).Sum / 1024, 2)
            }
        }

        # Include host information
        if ($IncludeHosts) {
            $hosts = Get-NTNXHost | Where-Object { $_.clusterUuid -eq $Cluster.clusterUuid }

            $status.HostInfo = @{
                TotalHosts = $hosts.Count
                HealthyHosts = ($hosts | Where-Object { $_.state -eq "NORMAL" }).Count
                HypervisorTypes = ($hosts | Select-Object -ExpandProperty hypervisorType -Unique) -join ", "
                TotalCPUCores = ($hosts | Measure-Object -Property numCpuCores -Sum).Sum
                TotalMemoryGB = [math]::Round(($hosts | Measure-Object -Property memoryCapacityBytes -Sum).Sum / 1GB, 2)
            }
        }

        # Include storage information
        if ($IncludeStorage) {
            $containers = Get-NTNXStorageContainer | Where-Object { $_.clusterUuid -eq $Cluster.clusterUuid }

            $status.StorageInfo = @{
                TotalContainers = $containers.Count
                TotalCapacityGB = [math]::Round($Cluster.storageCapacityBytes / 1GB, 2)
                UsedCapacityGB = [math]::Round(($containers | Measure-Object -Property usageStats.storageUsageBytes -Sum).Sum / 1GB, 2)
                CompressionEnabled = ($containers | Where-Object { $_.compressionEnabled }).Count
                DeduplicationEnabled = ($containers | Where-Object { $_.fingerPrintOnWrite -eq "ON" }).Count
            }
        }

        # Include networking information
        if ($IncludeNetworking) {
            $networks = Get-NTNXNetwork

            $status.NetworkInfo = @{
                TotalNetworks = $networks.Count
                VLANNetworks = ($networks | Where-Object { $_.vlanId }).Count
                NetworkNames = ($networks | Select-Object -ExpandProperty name) -join ", "
            }
        }

        Write-Host "    ✓ Status information collected" -ForegroundColor Green

        return $status
    }
    catch {
        Write-Warning "    Failed to get cluster status: $($_.Exception.Message)"
        return @{
            ClusterName = $Cluster.name
            ClusterUUID = $Cluster.clusterUuid
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to monitor cluster performance
function Monitor-ClusterPerformance {
    param($Cluster, $AlertThresholds, $CPUThreshold, $MemoryThreshold, $StorageThreshold)

    try {
        Write-Host "  Monitoring cluster performance: $($Cluster.name)" -ForegroundColor Cyan

        # Get performance stats
        $stats = Get-NTNXClusterStats -ClusterUuid $Cluster.clusterUuid

        # Calculate performance metrics
        $metrics = @{
            ClusterName = $Cluster.name
            ClusterUUID = $Cluster.clusterUuid
            CPUUsagePercent = if ($stats.statsSpecificEntries.cpuUsagePpm) {
                [math]::Round($stats.statsSpecificEntries.cpuUsagePpm / 10000, 2)
            } else { 0 }
            MemoryUsagePercent = if ($stats.statsSpecificEntries.memoryUsagePpm) {
                [math]::Round($stats.statsSpecificEntries.memoryUsagePpm / 10000, 2)
            } else { 0 }
            StorageUsagePercent = if ($stats.statsSpecificEntries.storageUsageBytes -and $Cluster.storageCapacityBytes) {
                [math]::Round(($stats.statsSpecificEntries.storageUsageBytes / $Cluster.storageCapacityBytes) * 100, 2)
            } else { 0 }
            IOPSRead = if ($stats.statsSpecificEntries.readIOPS) { $stats.statsSpecificEntries.readIOPS } else { 0 }
            IOPSWrite = if ($stats.statsSpecificEntries.writeIOPS) { $stats.statsSpecificEntries.writeIOPS } else { 0 }
            ThroughputReadMBps = if ($stats.statsSpecificEntries.readThroughputMBps) { $stats.statsSpecificEntries.readThroughputMBps } else { 0 }
            ThroughputWriteMBps = if ($stats.statsSpecificEntries.writeThroughputMBps) { $stats.statsSpecificEntries.writeThroughputMBps } else { 0 }
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

            if ($metrics.StorageUsagePercent -gt $StorageThreshold) {
                $alerts += "Storage usage ($($metrics.StorageUsagePercent)%) exceeds threshold ($StorageThreshold%)"
                Write-Host "    ⚠ ALERT: $($alerts[-1])" -ForegroundColor Red
            }

            $metrics.Alerts = $alerts
            $metrics.AlertCount = $alerts.Count
        }

        Write-Host "    ✓ Performance metrics collected - CPU: $($metrics.CPUUsagePercent)%, Memory: $($metrics.MemoryUsagePercent)%, Storage: $($metrics.StorageUsagePercent)%" -ForegroundColor Green

        return $metrics
    }
    catch {
        Write-Warning "    Failed to monitor cluster performance: $($_.Exception.Message)"
        return @{
            ClusterName = $Cluster.name
            ClusterUUID = $Cluster.clusterUuid
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }
    }
}

# Function to get cluster capacity information
function Get-ClusterCapacity {
    param($Cluster)

    try {
        Write-Host "  Analyzing cluster capacity: $($Cluster.name)" -ForegroundColor Cyan

        # Get hosts for capacity calculation
        $hosts = Get-NTNXHost | Where-Object { $_.clusterUuid -eq $Cluster.clusterUuid }
        $containers = Get-NTNXStorageContainer | Where-Object { $_.clusterUuid -eq $Cluster.clusterUuid }
        $vms = Get-NTNXVM | Where-Object { $_.clusterUuid -eq $Cluster.clusterUuid }

        # Calculate CPU capacity
        $totalCPUCores = ($hosts | Measure-Object -Property numCpuCores -Sum).Sum
        $allocatedCPUs = ($vms | Measure-Object -Property numVcpus -Sum).Sum
        $cpuOvercommitRatio = if ($totalCPUCores -gt 0) {
            [math]::Round($allocatedCPUs / $totalCPUCores, 2)
        } else { 0 }

        # Calculate memory capacity
        $totalMemoryGB = [math]::Round(($hosts | Measure-Object -Property memoryCapacityBytes -Sum).Sum / 1GB, 2)
        $allocatedMemoryGB = [math]::Round(($vms | Measure-Object -Property memoryMb -Sum).Sum / 1024, 2)
        $memoryUtilizationPercent = if ($totalMemoryGB -gt 0) {
            [math]::Round(($allocatedMemoryGB / $totalMemoryGB) * 100, 2)
        } else { 0 }

        # Calculate storage capacity
        $totalStorageGB = [math]::Round($Cluster.storageCapacityBytes / 1GB, 2)
        $usedStorageGB = [math]::Round(($containers | Measure-Object -Property usageStats.storageUsageBytes -Sum).Sum / 1GB, 2)
        $storageUtilizationPercent = if ($totalStorageGB -gt 0) {
            [math]::Round(($usedStorageGB / $totalStorageGB) * 100, 2)
        } else { 0 }

        # Calculate growth projections (basic linear projection)
        $growthDays = 30  # Project for 30 days
        $dailyGrowthGB = 1.0  # Assume 1GB daily growth if no historical data

        $projectedStorageGB = $usedStorageGB + ($dailyGrowthGB * $growthDays)
        $projectedUtilization = if ($totalStorageGB -gt 0) {
            [math]::Round(($projectedStorageGB / $totalStorageGB) * 100, 2)
        } else { 0 }

        $capacity = @{
            ClusterName = $Cluster.name
            ClusterUUID = $Cluster.clusterUuid
            CPUInfo = @{
                TotalCores = $totalCPUCores
                AllocatedCores = $allocatedCPUs
                OvercommitRatio = $cpuOvercommitRatio
                AvailableCores = $totalCPUCores - $allocatedCPUs
            }
            MemoryInfo = @{
                TotalGB = $totalMemoryGB
                AllocatedGB = $allocatedMemoryGB
                UtilizationPercent = $memoryUtilizationPercent
                AvailableGB = $totalMemoryGB - $allocatedMemoryGB
            }
            StorageInfo = @{
                TotalGB = $totalStorageGB
                UsedGB = $usedStorageGB
                UtilizationPercent = $storageUtilizationPercent
                AvailableGB = $totalStorageGB - $usedStorageGB
                ProjectedUsageGB = $projectedStorageGB
                ProjectedUtilizationPercent = $projectedUtilization
                DaysToFull = if ($dailyGrowthGB -gt 0) {
                    [math]::Floor(($totalStorageGB - $usedStorageGB) / $dailyGrowthGB)
                } else { "N/A" }
            }
            VMInfo = @{
                TotalVMs = $vms.Count
                PoweredOnVMs = ($vms | Where-Object { $_.powerState -eq "ON" }).Count
            }
            LastUpdated = Get-Date
        }

        Write-Host "    ✓ Capacity analysis completed" -ForegroundColor Green

        return $capacity
    }
    catch {
        Write-Warning "    Failed to analyze cluster capacity: $($_.Exception.Message)"
        return @{
            ClusterName = $Cluster.name
            ClusterUUID = $Cluster.clusterUuid
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to display results
function Show-ClusterResults {
    param($Results, $Operation, $OutputFormat, $OutputPath)

    Write-Host "`n=== Cluster $Operation Results ===" -ForegroundColor Cyan

    switch ($Operation) {
        "Health" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nCluster Health Summary:" -ForegroundColor Green
                foreach ($result in $Results) {
                    $statusColor = switch ($result.HealthStatus) {
                        "Healthy" { "Green" }
                        "Warning" { "Yellow" }
                        "Critical" { "Red" }
                        default { "White" }
                    }
                    Write-Host "$($result.ClusterName): $($result.HealthStatus)" -ForegroundColor $statusColor
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
                Write-Host "`nCluster Performance Monitoring:" -ForegroundColor Green
                $Results | Format-Table ClusterName, CPUUsagePercent, MemoryUsagePercent, StorageUsagePercent, IOPSRead, IOPSWrite -AutoSize

                # Show alerts if any
                $alertResults = $Results | Where-Object { $_.AlertCount -gt 0 }
                if ($alertResults) {
                    Write-Host "`nActive Alerts:" -ForegroundColor Red
                    foreach ($result in $alertResults) {
                        Write-Host "$($result.ClusterName):" -ForegroundColor Yellow
                        foreach ($alert in $result.Alerts) {
                            Write-Host "  ⚠ $alert" -ForegroundColor Red
                        }
                    }
                }
            }
        }
        "Capacity" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nCluster Capacity Analysis:" -ForegroundColor Green
                foreach ($result in $Results) {
                    Write-Host "`nCluster: $($result.ClusterName)" -ForegroundColor White
                    Write-Host "  CPU: $($result.CPUInfo.AllocatedCores)/$($result.CPUInfo.TotalCores) cores (ratio: $($result.CPUInfo.OvercommitRatio))" -ForegroundColor White
                    Write-Host "  Memory: $($result.MemoryInfo.AllocatedGB)/$($result.MemoryInfo.TotalGB) GB ($($result.MemoryInfo.UtilizationPercent)%)" -ForegroundColor White
                    Write-Host "  Storage: $($result.StorageInfo.UsedGB)/$($result.StorageInfo.TotalGB) GB ($($result.StorageInfo.UtilizationPercent)%)" -ForegroundColor White
                    if ($result.StorageInfo.DaysToFull -ne "N/A") {
                        Write-Host "  Projected full in: $($result.StorageInfo.DaysToFull) days" -ForegroundColor Yellow
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
                    $OutputPath = "Nutanix_Cluster_$Operation`_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                }
                $Results | Export-Csv -Path $OutputPath -NoTypeInformation
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
            "JSON" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_Cluster_$Operation`_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                }
                $Results | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
            "HTML" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_Cluster_$Operation`_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
                }
                $htmlContent = $Results | ConvertTo-Html -Title "Nutanix Cluster $Operation Report" -Head "<style>table{border-collapse:collapse;width:100%;}th,td{border:1px solid #ddd;padding:8px;text-align:left;}th{background-color:#f2f2f2;}</style>"
                $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "`nHTML report generated: $OutputPath" -ForegroundColor Green
            }
        }
    }
}

# Function for continuous monitoring
function Start-ContinuousMonitoring {
    param($Clusters, $AlertThresholds, $CPUThreshold, $MemoryThreshold, $StorageThreshold, $RefreshInterval)

    Write-Host "`n=== Starting Continuous Monitoring ===" -ForegroundColor Cyan
    Write-Host "Monitoring $($Clusters.Count) cluster(s) with $RefreshInterval second refresh interval" -ForegroundColor White
    Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
    Write-Host ""

    try {
        while ($true) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Host "[$timestamp] Collecting performance metrics..." -ForegroundColor Gray

            $results = @()
            foreach ($cluster in $Clusters) {
                $metrics = Monitor-ClusterPerformance -Cluster $cluster -AlertThresholds:$AlertThresholds -CPUThreshold $CPUThreshold -MemoryThreshold $MemoryThreshold -StorageThreshold $StorageThreshold
                $results += $metrics
            }

            # Display current status
            Clear-Host
            Write-Host "=== Nutanix Cluster Continuous Monitoring ===" -ForegroundColor Cyan
            Write-Host "Last Update: $timestamp" -ForegroundColor White
            Write-Host "Refresh Interval: $RefreshInterval seconds" -ForegroundColor White
            Write-Host ""

            Show-ClusterResults -Results $results -Operation "Monitor" -OutputFormat "Console"

            Start-Sleep -Seconds $RefreshInterval
        }
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        Write-Host "`n`nContinuous monitoring stopped by user." -ForegroundColor Yellow
    }
}

# Main execution
try {
    Write-Host "=== Nutanix Cluster Operations ===" -ForegroundColor Cyan

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

    # Get target clusters
    $targetClusters = Get-TargetClusters -ClusterName $ClusterName -ClusterNames $ClusterNames -ClusterUUID $ClusterUUID

    # Perform operations
    $results = @()

    foreach ($cluster in $targetClusters) {
        switch ($Operation) {
            "Health" {
                $result = Get-ClusterHealth -Cluster $cluster
                $results += $result
            }
            "Status" {
                $result = Get-ClusterStatus -Cluster $cluster -IncludeVMs:$IncludeVMs -IncludeHosts:$IncludeHosts -IncludeStorage:$IncludeStorage -IncludeNetworking:$IncludeNetworking
                $results += $result
            }
            "Monitor" {
                if ($ContinuousMonitoring) {
                    Start-ContinuousMonitoring -Clusters $targetClusters -AlertThresholds:$AlertThresholds -CPUThreshold $CPUThreshold -MemoryThreshold $MemoryThreshold -StorageThreshold $StorageThreshold -RefreshInterval $RefreshInterval
                    return
                } else {
                    $result = Monitor-ClusterPerformance -Cluster $cluster -AlertThresholds:$AlertThresholds -CPUThreshold $CPUThreshold -MemoryThreshold $MemoryThreshold -StorageThreshold $StorageThreshold
                    $results += $result
                }
            }
            "Capacity" {
                $result = Get-ClusterCapacity -Cluster $cluster
                $results += $result
            }
            "Report" {
                $result = Get-ClusterStatus -Cluster $cluster -IncludeVMs:$IncludeVMs -IncludeHosts:$IncludeHosts -IncludeStorage:$IncludeStorage -IncludeNetworking:$IncludeNetworking
                $results += $result
            }
            "Performance" {
                $result = Monitor-ClusterPerformance -Cluster $cluster -AlertThresholds:$AlertThresholds -CPUThreshold $CPUThreshold -MemoryThreshold $MemoryThreshold -StorageThreshold $StorageThreshold
                $results += $result
            }
            "Alerts" {
                $result = Monitor-ClusterPerformance -Cluster $cluster -AlertThresholds:$true -CPUThreshold $CPUThreshold -MemoryThreshold $MemoryThreshold -StorageThreshold $StorageThreshold
                $results += $result
            }
            "Maintenance" {
                Write-Host "  Maintenance operations for: $($cluster.name)" -ForegroundColor Cyan
                Write-Host "    ⚠ Maintenance mode operations would be implemented here" -ForegroundColor Yellow
                $results += @{
                    ClusterName = $cluster.name
                    ClusterUUID = $cluster.clusterUuid
                    Operation = "Maintenance"
                    Status = "Not Implemented"
                    Message = "Maintenance operations require specific implementation"
                }
            }
        }
    }

    # Display results
    if (-not $ContinuousMonitoring) {
        Show-ClusterResults -Results $results -Operation $Operation -OutputFormat $OutputFormat -OutputPath $OutputPath
    }

    Write-Host "`n=== Cluster Operations Completed ===" -ForegroundColor Green
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
