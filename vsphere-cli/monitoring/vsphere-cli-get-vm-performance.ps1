<#
.SYNOPSIS
    Monitors VM performance metrics in vSphere using PowerCLI.

.DESCRIPTION
    This script collects and analyzes VM performance metrics including CPU, memory, disk, and network usage.
    Supports real-time monitoring, historical data collection, and alerting based on thresholds.
    Requires VMware PowerCLI and connection to vCenter Server.

.PARAMETER VCenterServer
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER VMName
    The name of the virtual machine(s). Supports wildcards.

.PARAMETER VMNames
    An array of specific VM names for batch monitoring.

.PARAMETER ClusterName
    Monitor all VMs in a specific cluster (optional).

.PARAMETER MetricType
    The type of metrics to collect.

.PARAMETER Duration
    Duration for performance monitoring in minutes (default: 60).

.PARAMETER SampleInterval
    Sample interval in seconds (default: 300 for 5 minutes).

.PARAMETER OutputFormat
    Output format for the results.

.PARAMETER OutputPath
    Path to save the performance report file (optional).

.PARAMETER AlertThresholds
    Enable alerting with default thresholds.

.PARAMETER CPUThreshold
    CPU usage threshold percentage for alerts (default: 80).

.PARAMETER MemoryThreshold
    Memory usage threshold percentage for alerts (default: 85).

.PARAMETER DiskLatencyThreshold
    Disk latency threshold in milliseconds for alerts (default: 20).

.PARAMETER ContinuousMonitoring
    Enable continuous monitoring mode.

.PARAMETER RefreshInterval
    Refresh interval for continuous monitoring in seconds (default: 30).

.EXAMPLE
    .\vsphere-cli-get-vm-performance.ps1 -VCenterServer "vcenter.domain.com" -VMName "WebServer01" -MetricType "All" -Duration 30

.EXAMPLE
    .\vsphere-cli-get-vm-performance.ps1 -VCenterServer "vcenter.domain.com" -ClusterName "Production" -MetricType "CPU" -AlertThresholds -CPUThreshold 70

.EXAMPLE
    .\vsphere-cli-get-vm-performance.ps1 -VCenterServer "vcenter.domain.com" -VMNames @("VM01","VM02") -MetricType "Memory" -Duration 120 -OutputFormat "CSV" -OutputPath "performance.csv"

.EXAMPLE
    .\vsphere-cli-get-vm-performance.ps1 -VCenterServer "vcenter.domain.com" -VMName "CriticalVM*" -ContinuousMonitoring -RefreshInterval 15 -AlertThresholds

.NOTES
    Author: Generated for scripted-actions
    Requires: VMware PowerCLI 13.x or later, vSphere 7.0 or later
    Version: 1.0
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

    [Parameter(Mandatory = $true)]
    [ValidateSet("CPU", "Memory", "Disk", "Network", "All")]
    [string]$MetricType,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1440)]
    [int]$Duration = 60,

    [Parameter(Mandatory = $false)]
    [ValidateRange(20, 3600)]
    [int]$SampleInterval = 300,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "CSV", "JSON")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$AlertThresholds,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$CPUThreshold = 80,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$MemoryThreshold = 85,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$DiskLatencyThreshold = 20,

    [Parameter(Mandatory = $false)]
    [switch]$ContinuousMonitoring,

    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 300)]
    [int]$RefreshInterval = 30
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Global variables for continuous monitoring
$global:MonitoringActive = $false
$global:AlertHistory = @()

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
        $ClusterName
    )
    
    Write-Host "Identifying target VMs..." -ForegroundColor Yellow
    
    try {
        $targetVMs = @()
        
        if ($VMName) {
            # Single VM or wildcard pattern
            $targetVMs = Get-VM -Name $VMName -ErrorAction SilentlyContinue | Where-Object { $_.PowerState -eq "PoweredOn" }
        }
        elseif ($VMNames) {
            # Multiple specific VMs
            foreach ($name in $VMNames) {
                $vm = Get-VM -Name $name -ErrorAction SilentlyContinue | Where-Object { $_.PowerState -eq "PoweredOn" }
                if ($vm) {
                    $targetVMs += $vm
                } else {
                    Write-Warning "VM '$name' not found or not powered on"
                }
            }
        }
        elseif ($ClusterName) {
            # All VMs in cluster
            $cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
            if (-not $cluster) {
                throw "Cluster '$ClusterName' not found"
            }
            $targetVMs = Get-VM -Location $cluster | Where-Object { $_.PowerState -eq "PoweredOn" }
        }
        else {
            throw "Must specify VMName, VMNames, or ClusterName"
        }
        
        if (-not $targetVMs) {
            throw "No powered-on VMs found matching the specified criteria"
        }
        
        Write-Host "Found $($targetVMs.Count) powered-on VM(s) for monitoring:" -ForegroundColor Green
        foreach ($vm in $targetVMs) {
            Write-Host "  - $($vm.Name)" -ForegroundColor White
        }
        
        return $targetVMs
    }
    catch {
        Write-Error "Failed to get target VMs: $($_.Exception.Message)"
        throw
    }
}

# Function to get CPU metrics
function Get-CPUMetrics {
    param($VMs, $Duration, $SampleInterval)
    
    Write-Host "Collecting CPU metrics..." -ForegroundColor Yellow
    
    $cpuMetrics = @()
    $endTime = Get-Date
    $startTime = $endTime.AddMinutes(-$Duration)
    
    foreach ($vm in $VMs) {
        try {
            # Get CPU usage statistics
            $cpuStats = Get-Stat -Entity $vm -Stat @("cpu.usage.average", "cpu.usagemhz.average", "cpu.ready.summation") -Start $startTime -Finish $endTime -IntervalMins ($SampleInterval / 60)
            
            $cpuUsage = $cpuStats | Where-Object { $_.MetricId -eq "cpu.usage.average" }
            $cpuMhz = $cpuStats | Where-Object { $_.MetricId -eq "cpu.usagemhz.average" }
            $cpuReady = $cpuStats | Where-Object { $_.MetricId -eq "cpu.ready.summation" }
            
            $avgCpuUsage = if ($cpuUsage) { [math]::Round(($cpuUsage | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            $maxCpuUsage = if ($cpuUsage) { [math]::Round(($cpuUsage | Measure-Object -Property Value -Maximum).Maximum, 2) } else { 0 }
            $avgCpuMhz = if ($cpuMhz) { [math]::Round(($cpuMhz | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            $avgCpuReady = if ($cpuReady) { [math]::Round(($cpuReady | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            
            $cpuMetric = [PSCustomObject]@{
                VM = $vm.Name
                MetricType = "CPU"
                AvgUsagePercent = $avgCpuUsage
                MaxUsagePercent = $maxCpuUsage
                AvgUsageMHz = $avgCpuMhz
                AvgReadyTime = $avgCpuReady
                AllocatedCPUs = $vm.NumCpu
                Timestamp = Get-Date
            }
            
            $cpuMetrics += $cpuMetric
        }
        catch {
            Write-Warning "Failed to get CPU metrics for VM '$($vm.Name)': $($_.Exception.Message)"
        }
    }
    
    return $cpuMetrics
}

# Function to get Memory metrics
function Get-MemoryMetrics {
    param($VMs, $Duration, $SampleInterval)
    
    Write-Host "Collecting Memory metrics..." -ForegroundColor Yellow
    
    $memoryMetrics = @()
    $endTime = Get-Date
    $startTime = $endTime.AddMinutes(-$Duration)
    
    foreach ($vm in $VMs) {
        try {
            # Get memory usage statistics
            $memStats = Get-Stat -Entity $vm -Stat @("mem.usage.average", "mem.active.average", "mem.consumed.average", "mem.swapused.average") -Start $startTime -Finish $endTime -IntervalMins ($SampleInterval / 60)
            
            $memUsage = $memStats | Where-Object { $_.MetricId -eq "mem.usage.average" }
            $memActive = $memStats | Where-Object { $_.MetricId -eq "mem.active.average" }
            $memConsumed = $memStats | Where-Object { $_.MetricId -eq "mem.consumed.average" }
            $memSwap = $memStats | Where-Object { $_.MetricId -eq "mem.swapused.average" }
            
            $avgMemUsage = if ($memUsage) { [math]::Round(($memUsage | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            $maxMemUsage = if ($memUsage) { [math]::Round(($memUsage | Measure-Object -Property Value -Maximum).Maximum, 2) } else { 0 }
            $avgMemActive = if ($memActive) { [math]::Round(($memActive | Measure-Object -Property Value -Average).Average / 1024, 2) } else { 0 }
            $avgMemConsumed = if ($memConsumed) { [math]::Round(($memConsumed | Measure-Object -Property Value -Average).Average / 1024, 2) } else { 0 }
            $avgMemSwap = if ($memSwap) { [math]::Round(($memSwap | Measure-Object -Property Value -Average).Average / 1024, 2) } else { 0 }
            
            $memoryMetric = [PSCustomObject]@{
                VM = $vm.Name
                MetricType = "Memory"
                AvgUsagePercent = $avgMemUsage
                MaxUsagePercent = $maxMemUsage
                AvgActiveMB = $avgMemActive
                AvgConsumedMB = $avgMemConsumed
                AvgSwapUsedMB = $avgMemSwap
                AllocatedMemoryGB = $vm.MemoryGB
                Timestamp = Get-Date
            }
            
            $memoryMetrics += $memoryMetric
        }
        catch {
            Write-Warning "Failed to get memory metrics for VM '$($vm.Name)': $($_.Exception.Message)"
        }
    }
    
    return $memoryMetrics
}

# Function to get Disk metrics
function Get-DiskMetrics {
    param($VMs, $Duration, $SampleInterval)
    
    Write-Host "Collecting Disk metrics..." -ForegroundColor Yellow
    
    $diskMetrics = @()
    $endTime = Get-Date
    $startTime = $endTime.AddMinutes(-$Duration)
    
    foreach ($vm in $VMs) {
        try {
            # Get disk statistics
            $diskStats = Get-Stat -Entity $vm -Stat @("disk.usage.average", "disk.read.average", "disk.write.average", "disk.totalLatency.average") -Start $startTime -Finish $endTime -IntervalMins ($SampleInterval / 60)
            
            $diskUsage = $diskStats | Where-Object { $_.MetricId -eq "disk.usage.average" }
            $diskRead = $diskStats | Where-Object { $_.MetricId -eq "disk.read.average" }
            $diskWrite = $diskStats | Where-Object { $_.MetricId -eq "disk.write.average" }
            $diskLatency = $diskStats | Where-Object { $_.MetricId -eq "disk.totalLatency.average" }
            
            $avgDiskUsage = if ($diskUsage) { [math]::Round(($diskUsage | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            $avgDiskRead = if ($diskRead) { [math]::Round(($diskRead | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            $avgDiskWrite = if ($diskWrite) { [math]::Round(($diskWrite | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            $avgDiskLatency = if ($diskLatency) { [math]::Round(($diskLatency | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            $maxDiskLatency = if ($diskLatency) { [math]::Round(($diskLatency | Measure-Object -Property Value -Maximum).Maximum, 2) } else { 0 }
            
            $diskMetric = [PSCustomObject]@{
                VM = $vm.Name
                MetricType = "Disk"
                AvgUsageKBps = $avgDiskUsage
                AvgReadKBps = $avgDiskRead
                AvgWriteKBps = $avgDiskWrite
                AvgLatencyMs = $avgDiskLatency
                MaxLatencyMs = $maxDiskLatency
                TotalDiskGB = [math]::Round($vm.ProvisionedSpaceGB, 2)
                Timestamp = Get-Date
            }
            
            $diskMetrics += $diskMetric
        }
        catch {
            Write-Warning "Failed to get disk metrics for VM '$($vm.Name)': $($_.Exception.Message)"
        }
    }
    
    return $diskMetrics
}

# Function to get Network metrics
function Get-NetworkMetrics {
    param($VMs, $Duration, $SampleInterval)
    
    Write-Host "Collecting Network metrics..." -ForegroundColor Yellow
    
    $networkMetrics = @()
    $endTime = Get-Date
    $startTime = $endTime.AddMinutes(-$Duration)
    
    foreach ($vm in $VMs) {
        try {
            # Get network statistics
            $netStats = Get-Stat -Entity $vm -Stat @("net.usage.average", "net.received.average", "net.transmitted.average", "net.packetsRx.summation", "net.packetsTx.summation") -Start $startTime -Finish $endTime -IntervalMins ($SampleInterval / 60)
            
            $netUsage = $netStats | Where-Object { $_.MetricId -eq "net.usage.average" }
            $netReceived = $netStats | Where-Object { $_.MetricId -eq "net.received.average" }
            $netTransmitted = $netStats | Where-Object { $_.MetricId -eq "net.transmitted.average" }
            $packetsRx = $netStats | Where-Object { $_.MetricId -eq "net.packetsRx.summation" }
            $packetsTx = $netStats | Where-Object { $_.MetricId -eq "net.packetsTx.summation" }
            
            $avgNetUsage = if ($netUsage) { [math]::Round(($netUsage | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            $avgNetReceived = if ($netReceived) { [math]::Round(($netReceived | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            $avgNetTransmitted = if ($netTransmitted) { [math]::Round(($netTransmitted | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            $avgPacketsRx = if ($packetsRx) { [math]::Round(($packetsRx | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            $avgPacketsTx = if ($packetsTx) { [math]::Round(($packetsTx | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            
            $networkMetric = [PSCustomObject]@{
                VM = $vm.Name
                MetricType = "Network"
                AvgUsageKBps = $avgNetUsage
                AvgReceivedKBps = $avgNetReceived
                AvgTransmittedKBps = $avgNetTransmitted
                AvgPacketsRx = $avgPacketsRx
                AvgPacketsTx = $avgPacketsTx
                NetworkAdapters = ($vm | Get-NetworkAdapter).Count
                Timestamp = Get-Date
            }
            
            $networkMetrics += $networkMetric
        }
        catch {
            Write-Warning "Failed to get network metrics for VM '$($vm.Name)': $($_.Exception.Message)"
        }
    }
    
    return $networkMetrics
}

# Function to check alert thresholds
function Test-AlertThresholds {
    param(
        $Metrics,
        $CPUThreshold,
        $MemoryThreshold,
        $DiskLatencyThreshold
    )
    
    $alerts = @()
    
    foreach ($metric in $Metrics) {
        switch ($metric.MetricType) {
            "CPU" {
                if ($metric.AvgUsagePercent -gt $CPUThreshold) {
                    $alerts += [PSCustomObject]@{
                        VM = $metric.VM
                        AlertType = "CPU High Usage"
                        CurrentValue = "$($metric.AvgUsagePercent)%"
                        Threshold = "$CPUThreshold%"
                        Severity = if ($metric.AvgUsagePercent -gt 90) { "Critical" } else { "Warning" }
                        Timestamp = $metric.Timestamp
                    }
                }
            }
            "Memory" {
                if ($metric.AvgUsagePercent -gt $MemoryThreshold) {
                    $alerts += [PSCustomObject]@{
                        VM = $metric.VM
                        AlertType = "Memory High Usage"
                        CurrentValue = "$($metric.AvgUsagePercent)%"
                        Threshold = "$MemoryThreshold%"
                        Severity = if ($metric.AvgUsagePercent -gt 95) { "Critical" } else { "Warning" }
                        Timestamp = $metric.Timestamp
                    }
                }
            }
            "Disk" {
                if ($metric.AvgLatencyMs -gt $DiskLatencyThreshold) {
                    $alerts += [PSCustomObject]@{
                        VM = $metric.VM
                        AlertType = "Disk High Latency"
                        CurrentValue = "$($metric.AvgLatencyMs)ms"
                        Threshold = "${DiskLatencyThreshold}ms"
                        Severity = if ($metric.AvgLatencyMs -gt 50) { "Critical" } else { "Warning" }
                        Timestamp = $metric.Timestamp
                    }
                }
            }
        }
    }
    
    return $alerts
}

# Function to display alerts
function Show-Alerts {
    param($Alerts)
    
    if ($Alerts.Count -gt 0) {
        Write-Host "`n=== PERFORMANCE ALERTS ===" -ForegroundColor Red
        foreach ($alert in $Alerts) {
            $color = switch ($alert.Severity) {
                "Critical" { "Red" }
                "Warning" { "Yellow" }
                default { "White" }
            }
            Write-Host "[$($alert.Severity)] $($alert.VM): $($alert.AlertType)" -ForegroundColor $color
            Write-Host "  Current: $($alert.CurrentValue) | Threshold: $($alert.Threshold)" -ForegroundColor White
        }
        
        # Add to global alert history
        $global:AlertHistory += $Alerts
    }
}

# Function to export metrics
function Export-Metrics {
    param(
        $Metrics,
        $OutputFormat,
        $OutputPath
    )
    
    switch ($OutputFormat) {
        "Console" {
            if ($Metrics.Count -gt 0) {
                Write-Host "`n=== Performance Metrics ===" -ForegroundColor Cyan
                $Metrics | Format-Table -AutoSize
            }
        }
        "CSV" {
            if (-not $OutputPath) {
                $OutputPath = "VM_Performance_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            }
            $Metrics | Export-Csv -Path $OutputPath -NoTypeInformation
            Write-Host "Metrics exported to: $OutputPath" -ForegroundColor Green
        }
        "JSON" {
            if (-not $OutputPath) {
                $OutputPath = "VM_Performance_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            }
            $Metrics | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "Metrics exported to: $OutputPath" -ForegroundColor Green
        }
    }
}

# Function for continuous monitoring
function Start-ContinuousMonitoring {
    param(
        $VMs,
        $MetricType,
        $RefreshInterval,
        $AlertThresholds,
        $CPUThreshold,
        $MemoryThreshold,
        $DiskLatencyThreshold
    )
    
    Write-Host "`n=== Starting Continuous Monitoring ===" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
    Write-Host "Refresh interval: $RefreshInterval seconds" -ForegroundColor White
    Write-Host ""
    
    $global:MonitoringActive = $true
    
    # Register event handler for Ctrl+C
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        $global:MonitoringActive = $false
    }
    
    try {
        while ($global:MonitoringActive) {
            $timestamp = Get-Date
            Write-Host "[$($timestamp.ToString('yyyy-MM-dd HH:mm:ss'))] Collecting metrics..." -ForegroundColor Green
            
            # Collect real-time metrics (short duration, small interval)
            $allMetrics = @()
            
            if ($MetricType -eq "All" -or $MetricType -eq "CPU") {
                $cpuMetrics = Get-CPUMetrics -VMs $VMs -Duration 5 -SampleInterval 20
                $allMetrics += $cpuMetrics
            }
            
            if ($MetricType -eq "All" -or $MetricType -eq "Memory") {
                $memoryMetrics = Get-MemoryMetrics -VMs $VMs -Duration 5 -SampleInterval 20
                $allMetrics += $memoryMetrics
            }
            
            if ($MetricType -eq "All" -or $MetricType -eq "Disk") {
                $diskMetrics = Get-DiskMetrics -VMs $VMs -Duration 5 -SampleInterval 20
                $allMetrics += $diskMetrics
            }
            
            if ($MetricType -eq "All" -or $MetricType -eq "Network") {
                $networkMetrics = Get-NetworkMetrics -VMs $VMs -Duration 5 -SampleInterval 20
                $allMetrics += $networkMetrics
            }
            
            # Display current metrics summary
            foreach ($vm in $VMs) {
                $vmMetrics = $allMetrics | Where-Object { $_.VM -eq $vm.Name }
                Write-Host "  VM: $($vm.Name)" -ForegroundColor Cyan
                
                foreach ($metric in $vmMetrics) {
                    switch ($metric.MetricType) {
                        "CPU" { Write-Host "    CPU: $($metric.AvgUsagePercent)% (Ready: $($metric.AvgReadyTime)ms)" -ForegroundColor White }
                        "Memory" { Write-Host "    Memory: $($metric.AvgUsagePercent)% (Swap: $($metric.AvgSwapUsedMB)MB)" -ForegroundColor White }
                        "Disk" { Write-Host "    Disk: $($metric.AvgLatencyMs)ms latency ($($metric.AvgUsageKBps) KBps)" -ForegroundColor White }
                        "Network" { Write-Host "    Network: $($metric.AvgUsageKBps) KBps (Rx: $($metric.AvgReceivedKBps), Tx: $($metric.AvgTransmittedKBps))" -ForegroundColor White }
                    }
                }
            }
            
            # Check alerts if enabled
            if ($AlertThresholds) {
                $alerts = Test-AlertThresholds -Metrics $allMetrics -CPUThreshold $CPUThreshold -MemoryThreshold $MemoryThreshold -DiskLatencyThreshold $DiskLatencyThreshold
                Show-Alerts -Alerts $alerts
            }
            
            Write-Host ""
            
            # Wait for next refresh
            Start-Sleep -Seconds $RefreshInterval
        }
    }
    catch {
        if ($_.Exception.Message -notmatch "pipeline.*stopped") {
            Write-Error "Monitoring error: $($_.Exception.Message)"
        }
    }
    finally {
        Write-Host "`nContinuous monitoring stopped." -ForegroundColor Yellow
        if ($global:AlertHistory.Count -gt 0) {
            Write-Host "Total alerts generated: $($global:AlertHistory.Count)" -ForegroundColor Cyan
        }
    }
}

# Main execution
try {
    Write-Host "=== vSphere VM Performance Monitoring ===" -ForegroundColor Cyan
    Write-Host "Target vCenter: $VCenterServer" -ForegroundColor White
    Write-Host "Metric Type: $MetricType" -ForegroundColor White
    
    if (-not $ContinuousMonitoring) {
        Write-Host "Duration: $Duration minutes" -ForegroundColor White
        Write-Host "Sample Interval: $SampleInterval seconds" -ForegroundColor White
    }
    Write-Host ""
    
    # Check and install PowerCLI
    if (-not (Test-PowerCLIInstallation)) {
        throw "PowerCLI installation failed"
    }
    
    # Connect to vCenter
    $connection = Connect-ToVCenter -Server $VCenterServer
    
    # Get target VMs
    $targetVMs = Get-TargetVMs -VMName $VMName -VMNames $VMNames -ClusterName $ClusterName
    
    if ($ContinuousMonitoring) {
        # Start continuous monitoring
        Start-ContinuousMonitoring -VMs $targetVMs -MetricType $MetricType -RefreshInterval $RefreshInterval -AlertThresholds:$AlertThresholds -CPUThreshold $CPUThreshold -MemoryThreshold $MemoryThreshold -DiskLatencyThreshold $DiskLatencyThreshold
    }
    else {
        # Single-run monitoring
        $allMetrics = @()
        
        if ($MetricType -eq "All" -or $MetricType -eq "CPU") {
            $cpuMetrics = Get-CPUMetrics -VMs $targetVMs -Duration $Duration -SampleInterval $SampleInterval
            $allMetrics += $cpuMetrics
        }
        
        if ($MetricType -eq "All" -or $MetricType -eq "Memory") {
            $memoryMetrics = Get-MemoryMetrics -VMs $targetVMs -Duration $Duration -SampleInterval $SampleInterval
            $allMetrics += $memoryMetrics
        }
        
        if ($MetricType -eq "All" -or $MetricType -eq "Disk") {
            $diskMetrics = Get-DiskMetrics -VMs $targetVMs -Duration $Duration -SampleInterval $SampleInterval
            $allMetrics += $diskMetrics
        }
        
        if ($MetricType -eq "All" -or $MetricType -eq "Network") {
            $networkMetrics = Get-NetworkMetrics -VMs $targetVMs -Duration $Duration -SampleInterval $SampleInterval
            $allMetrics += $networkMetrics
        }
        
        # Check alerts if enabled
        if ($AlertThresholds) {
            $alerts = Test-AlertThresholds -Metrics $allMetrics -CPUThreshold $CPUThreshold -MemoryThreshold $MemoryThreshold -DiskLatencyThreshold $DiskLatencyThreshold
            Show-Alerts -Alerts $alerts
        }
        
        # Export metrics
        Export-Metrics -Metrics $allMetrics -OutputFormat $OutputFormat -OutputPath $OutputPath
    }
    
    Write-Host "`n=== Performance Monitoring Completed ===" -ForegroundColor Green
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Cleanup
    $global:MonitoringActive = $false
    
    # Disconnect from vCenter if connected
    if ($global:DefaultVIServers) {
        Write-Host "`nDisconnecting from vCenter..." -ForegroundColor Yellow
        Disconnect-VIServer -Server * -Confirm:$false -Force
    }
}
