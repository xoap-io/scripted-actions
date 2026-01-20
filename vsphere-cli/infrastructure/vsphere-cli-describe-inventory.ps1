<#
.SYNOPSIS
    Describes vSphere infrastructure inventory and generates comprehensive reports using PowerCLI.

.DESCRIPTION
    This script provides detailed information about vSphere infrastructure including datacenters,
    clusters, hosts, VMs, datastores, networks, and resource utilization.
    Supports various output formats and filtering options.
    Requires VMware PowerCLI and connection to vCenter Server.

.PARAMETER VCenterServer
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER ReportType
    The type of report to generate.

.PARAMETER DatacenterName
    Filter results by specific datacenter (optional).

.PARAMETER ClusterName
    Filter results by specific cluster (optional).

.PARAMETER OutputFormat
    Output format for the report.

.PARAMETER OutputPath
    Path to save the report file (optional, for CSV/HTML formats).

.PARAMETER IncludeMetrics
    Include performance metrics in the report.

.PARAMETER ShowPoweredOffVMs
    Include powered-off VMs in VM reports.

.PARAMETER ShowTemplates
    Include VM templates in VM reports.

.PARAMETER SortBy
    Sort results by specified property.

.EXAMPLE
    .\vsphere-cli-describe-inventory.ps1 -VCenterServer "vcenter.domain.com" -ReportType "Overview"

.EXAMPLE
    .\vsphere-cli-describe-inventory.ps1 -VCenterServer "vcenter.domain.com" -ReportType "VMs" -ClusterName "Production" -OutputFormat "CSV" -OutputPath "C:\Reports\VMs.csv"

.EXAMPLE
    .\vsphere-cli-describe-inventory.ps1 -VCenterServer "vcenter.domain.com" -ReportType "Datastores" -IncludeMetrics -SortBy "FreeSpaceGB"

.EXAMPLE
    .\vsphere-cli-describe-inventory.ps1 -VCenterServer "vcenter.domain.com" -ReportType "Hosts" -DatacenterName "MainDC" -OutputFormat "HTML" -OutputPath "hosts-report.html"

.NOTES
    Author: XOAP.io
    Requires: VMware PowerCLI 13.x or later, vSphere 7.0 or later

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VCenterServer,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Overview", "Datacenters", "Clusters", "Hosts", "VMs", "Datastores", "Networks", "ResourcePools", "All")]
    [string]$ReportType,

    [Parameter(Mandatory = $false)]
    [string]$DatacenterName,

    [Parameter(Mandatory = $false)]
    [string]$ClusterName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "CSV", "HTML", "JSON")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeMetrics,

    [Parameter(Mandatory = $false)]
    [switch]$ShowPoweredOffVMs,

    [Parameter(Mandatory = $false)]
    [switch]$ShowTemplates,

    [Parameter(Mandatory = $false)]
    [string]$SortBy
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

# Function to get overview report
function Get-OverviewReport {
    Write-Host "Generating infrastructure overview..." -ForegroundColor Yellow

    $overview = [PSCustomObject]@{
        VCenterServer = $global:DefaultVIServers[0].Name
        VCenterVersion = $global:DefaultVIServers[0].Version
        ConnectionTime = Get-Date
        Datacenters = (Get-Datacenter).Count
        Clusters = (Get-Cluster).Count
        Hosts = (Get-VMHost).Count
        VMs = (Get-VM).Count
        PoweredOnVMs = (Get-VM | Where-Object { $_.PowerState -eq "PoweredOn" }).Count
        Templates = (Get-Template).Count
        Datastores = (Get-Datastore).Count
        TotalStorageGB = [math]::Round((Get-Datastore | Measure-Object -Property CapacityGB -Sum).Sum, 2)
        FreeStorageGB = [math]::Round((Get-Datastore | Measure-Object -Property FreeSpaceGB -Sum).Sum, 2)
        UsedStorageGB = [math]::Round((Get-Datastore | Measure-Object -Property CapacityGB -Sum).Sum - (Get-Datastore | Measure-Object -Property FreeSpaceGB -Sum).Sum, 2)
        StorageUtilizationPercent = [math]::Round(((Get-Datastore | Measure-Object -Property CapacityGB -Sum).Sum - (Get-Datastore | Measure-Object -Property FreeSpaceGB -Sum).Sum) / (Get-Datastore | Measure-Object -Property CapacityGB -Sum).Sum * 100, 1)
    }

    return $overview
}

# Function to get datacenter report
function Get-DatacenterReport {
    Write-Host "Generating datacenter report..." -ForegroundColor Yellow

    $datacenters = Get-Datacenter
    if ($DatacenterName) {
        $datacenters = $datacenters | Where-Object { $_.Name -eq $DatacenterName }
    }

    $dcReport = @()
    foreach ($dc in $datacenters) {
        $clusters = Get-Cluster -Location $dc
        $hosts = Get-VMHost -Location $dc
        $vms = Get-VM -Location $dc

        $dcInfo = [PSCustomObject]@{
            Name = $dc.Name
            Clusters = $clusters.Count
            Hosts = $hosts.Count
            VMs = $vms.Count
            PoweredOnVMs = ($vms | Where-Object { $_.PowerState -eq "PoweredOn" }).Count
            TotalCPUCores = ($hosts | Measure-Object -Property NumCpu -Sum).Sum
            TotalMemoryGB = [math]::Round(($hosts | Measure-Object -Property MemoryTotalGB -Sum).Sum, 2)
            Datastores = (Get-Datastore -Location $dc).Count
        }

        $dcReport += $dcInfo
    }

    return $dcReport
}

# Function to get cluster report
function Get-ClusterReport {
    Write-Host "Generating cluster report..." -ForegroundColor Yellow

    $clusters = Get-Cluster
    if ($DatacenterName) {
        $datacenter = Get-Datacenter -Name $DatacenterName
        $clusters = Get-Cluster -Location $datacenter
    }
    if ($ClusterName) {
        $clusters = $clusters | Where-Object { $_.Name -eq $ClusterName }
    }

    $clusterReport = @()
    foreach ($cluster in $clusters) {
        $hosts = Get-VMHost -Location $cluster
        $vms = Get-VM -Location $cluster

        $clusterInfo = [PSCustomObject]@{
            Name = $cluster.Name
            Datacenter = $cluster.Parent.Name
            HAEnabled = $cluster.HAEnabled
            DrsEnabled = $cluster.DrsEnabled
            DrsAutomationLevel = $cluster.DrsAutomationLevel
            Hosts = $hosts.Count
            VMs = $vms.Count
            PoweredOnVMs = ($vms | Where-Object { $_.PowerState -eq "PoweredOn" }).Count
            TotalCPUCores = ($hosts | Measure-Object -Property NumCpu -Sum).Sum
            TotalMemoryGB = [math]::Round(($hosts | Measure-Object -Property MemoryTotalGB -Sum).Sum, 2)
            UsedCPUCores = ($vms | Where-Object { $_.PowerState -eq "PoweredOn" } | Measure-Object -Property NumCpu -Sum).Sum
            UsedMemoryGB = [math]::Round(($vms | Where-Object { $_.PowerState -eq "PoweredOn" } | Measure-Object -Property MemoryGB -Sum).Sum, 2)
        }

        if ($IncludeMetrics) {
            $cpuUsage = Get-Stat -Entity $cluster -Stat "cpu.usagemhz.average" -Realtime | Measure-Object -Property Value -Average
            $memUsage = Get-Stat -Entity $cluster -Stat "mem.usage.average" -Realtime | Measure-Object -Property Value -Average

            $clusterInfo | Add-Member -NotePropertyName "CPUUsagePercent" -NotePropertyValue ([math]::Round($cpuUsage.Average, 1))
            $clusterInfo | Add-Member -NotePropertyName "MemoryUsagePercent" -NotePropertyValue ([math]::Round($memUsage.Average, 1))
        }

        $clusterReport += $clusterInfo
    }

    return $clusterReport
}

# Function to get host report
function Get-HostReport {
    Write-Host "Generating host report..." -ForegroundColor Yellow

    $hosts = Get-VMHost
    if ($DatacenterName) {
        $datacenter = Get-Datacenter -Name $DatacenterName
        $hosts = Get-VMHost -Location $datacenter
    }
    if ($ClusterName) {
        $cluster = Get-Cluster -Name $ClusterName
        $hosts = Get-VMHost -Location $cluster
    }

    $hostReport = @()
    foreach ($vmHost in $hosts) {
        $vms = Get-VM -Location $vmHost

        $hostInfo = [PSCustomObject]@{
            Name = $vmHost.Name
            Cluster = $vmHost.Parent.Name
            ConnectionState = $vmHost.ConnectionState
            PowerState = $vmHost.PowerState
            Version = $vmHost.Version
            Build = $vmHost.Build
            Manufacturer = $vmHost.Manufacturer
            Model = $vmHost.Model
            ProcessorType = $vmHost.ProcessorType
            CPUCores = $vmHost.NumCpu
            MemoryGB = [math]::Round($vmHost.MemoryTotalGB, 2)
            VMs = $vms.Count
            PoweredOnVMs = ($vms | Where-Object { $_.PowerState -eq "PoweredOn" }).Count
            UptimeDays = [math]::Round($vmHost.ExtensionData.Summary.QuickStats.Uptime / 86400, 1)
        }

        if ($IncludeMetrics) {
            $cpuUsage = Get-Stat -Entity $vmHost -Stat "cpu.usage.average" -Realtime | Measure-Object -Property Value -Average
            $memUsage = Get-Stat -Entity $vmHost -Stat "mem.usage.average" -Realtime | Measure-Object -Property Value -Average

            $hostInfo | Add-Member -NotePropertyName "CPUUsagePercent" -NotePropertyValue ([math]::Round($cpuUsage.Average, 1))
            $hostInfo | Add-Member -NotePropertyName "MemoryUsagePercent" -NotePropertyValue ([math]::Round($memUsage.Average, 1))
        }

        $hostReport += $hostInfo
    }

    return $hostReport
}

# Function to get VM report
function Get-VMReport {
    Write-Host "Generating VM report..." -ForegroundColor Yellow

    $vms = Get-VM
    if ($DatacenterName) {
        $datacenter = Get-Datacenter -Name $DatacenterName
        $vms = Get-VM -Location $datacenter
    }
    if ($ClusterName) {
        $cluster = Get-Cluster -Name $ClusterName
        $vms = Get-VM -Location $cluster
    }

    # Filter by power state
    if (-not $ShowPoweredOffVMs) {
        $vms = $vms | Where-Object { $_.PowerState -eq "PoweredOn" }
    }

    $vmReport = @()
    foreach ($vm in $vms) {
        $vmInfo = [PSCustomObject]@{
            Name = $vm.Name
            PowerState = $vm.PowerState
            Host = $vm.VMHost.Name
            Cluster = $vm.VMHost.Parent.Name
            Folder = $vm.Folder.Name
            GuestOS = $vm.Guest.OSFullName
            GuestId = $vm.GuestId
            CPUs = $vm.NumCpu
            MemoryGB = $vm.MemoryGB
            ProvisionedSpaceGB = [math]::Round($vm.ProvisionedSpaceGB, 2)
            UsedSpaceGB = [math]::Round($vm.UsedSpaceGB, 2)
            NumDisks = ($vm | Get-HardDisk).Count
            VMwareToolsStatus = $vm.ExtensionData.Guest.ToolsStatus
            VMwareToolsVersion = $vm.ExtensionData.Guest.ToolsVersion
            HardwareVersion = $vm.HardwareVersion
            CreateDate = $vm.CreateDate
            UptimeDays = if ($vm.PowerState -eq "PoweredOn") { [math]::Round((Get-Date).Subtract($vm.ExtensionData.Runtime.BootTime).TotalDays, 1) } else { 0 }
        }

        if ($IncludeMetrics -and $vm.PowerState -eq "PoweredOn") {
            $cpuUsage = Get-Stat -Entity $vm -Stat "cpu.usage.average" -Realtime | Measure-Object -Property Value -Average
            $memUsage = Get-Stat -Entity $vm -Stat "mem.usage.average" -Realtime | Measure-Object -Property Value -Average

            $vmInfo | Add-Member -NotePropertyName "CPUUsagePercent" -NotePropertyValue ([math]::Round($cpuUsage.Average, 1))
            $vmInfo | Add-Member -NotePropertyName "MemoryUsagePercent" -NotePropertyValue ([math]::Round($memUsage.Average, 1))
        }

        $vmReport += $vmInfo
    }

    # Include templates if requested
    if ($ShowTemplates) {
        $templates = Get-Template
        if ($DatacenterName) {
            $datacenter = Get-Datacenter -Name $DatacenterName
            $templates = Get-Template -Location $datacenter
        }

        foreach ($template in $templates) {
            $templateInfo = [PSCustomObject]@{
                Name = $template.Name
                PowerState = "Template"
                Host = ""
                Cluster = ""
                Folder = $template.Folder.Name
                GuestOS = $template.ExtensionData.Guest.GuestFullName
                GuestId = $template.ExtensionData.Config.GuestId
                CPUs = $template.NumCpu
                MemoryGB = $template.MemoryGB
                ProvisionedSpaceGB = [math]::Round(($template | Get-HardDisk | Measure-Object -Property CapacityGB -Sum).Sum, 2)
                UsedSpaceGB = 0
                NumDisks = ($template | Get-HardDisk).Count
                VMwareToolsStatus = ""
                VMwareToolsVersion = ""
                HardwareVersion = $template.HardwareVersion
                CreateDate = $template.ExtensionData.Config.CreateDate
                UptimeDays = 0
            }

            $vmReport += $templateInfo
        }
    }

    return $vmReport
}

# Function to get datastore report
function Get-DatastoreReport {
    Write-Host "Generating datastore report..." -ForegroundColor Yellow

    $datastores = Get-Datastore
    if ($DatacenterName) {
        $datacenter = Get-Datacenter -Name $DatacenterName
        $datastores = Get-Datastore -Location $datacenter
    }

    $datastoreReport = @()
    foreach ($datastore in $datastores) {
        $vms = Get-VM -Datastore $datastore

        $datastoreInfo = [PSCustomObject]@{
            Name = $datastore.Name
            Type = $datastore.Type
            FileSystemVersion = $datastore.FileSystemVersion
            CapacityGB = [math]::Round($datastore.CapacityGB, 2)
            FreeSpaceGB = [math]::Round($datastore.FreeSpaceGB, 2)
            UsedSpaceGB = [math]::Round($datastore.CapacityGB - $datastore.FreeSpaceGB, 2)
            UsagePercent = [math]::Round(($datastore.CapacityGB - $datastore.FreeSpaceGB) / $datastore.CapacityGB * 100, 1)
            VMs = $vms.Count
            State = $datastore.State
            Accessible = $datastore.Accessible
            MultiplePaths = $datastore.ExtensionData.Summary.MultipleHostAccess
        }

        $datastoreReport += $datastoreInfo
    }

    return $datastoreReport
}

# Function to get network report
function Get-NetworkReport {
    Write-Host "Generating network report..." -ForegroundColor Yellow

    $networks = Get-VirtualPortGroup
    if ($DatacenterName) {
        $datacenter = Get-Datacenter -Name $DatacenterName
        $networks = Get-VirtualPortGroup -Location $datacenter
    }

    $networkReport = @()
    foreach ($network in $networks) {
        $vms = Get-VM | Where-Object { ($_ | Get-NetworkAdapter).NetworkName -contains $network.Name }

        $networkInfo = [PSCustomObject]@{
            Name = $network.Name
            VLanId = $network.VLanId
            Type = $network.GetType().Name
            ConnectedVMs = $vms.Count
            Switch = if ($network.VirtualSwitch) { $network.VirtualSwitch.Name } else { "N/A" }
        }

        $networkReport += $networkInfo
    }

    return $networkReport
}

# Function to get resource pool report
function Get-ResourcePoolReport {
    Write-Host "Generating resource pool report..." -ForegroundColor Yellow

    $resourcePools = Get-ResourcePool
    if ($DatacenterName) {
        $datacenter = Get-Datacenter -Name $DatacenterName
        $resourcePools = Get-ResourcePool -Location $datacenter
    }
    if ($ClusterName) {
        $cluster = Get-Cluster -Name $ClusterName
        $resourcePools = Get-ResourcePool -Location $cluster
    }

    $rpReport = @()
    foreach ($rp in $resourcePools) {
        $vms = Get-VM -Location $rp

        $rpInfo = [PSCustomObject]@{
            Name = $rp.Name
            Parent = $rp.Parent.Name
            VMs = $vms.Count
            CPUSharesLevel = $rp.CpuSharesLevel
            CPUReservationMHz = $rp.CpuReservationMHz
            CPULimitMHz = $rp.CpuLimitMHz
            MemSharesLevel = $rp.MemSharesLevel
            MemReservationGB = [math]::Round($rp.MemReservationMB / 1024, 2)
            MemLimitGB = if ($rp.MemLimitMB -ne -1) { [math]::Round($rp.MemLimitMB / 1024, 2) } else { "Unlimited" }
        }

        $rpReport += $rpInfo
    }

    return $rpReport
}

# Function to format and output results
function Export-Report {
    param(
        $Data,
        $ReportType,
        $OutputFormat,
        $OutputPath,
        $SortBy
    )

    # Sort data if requested
    if ($SortBy -and $Data[0].PSObject.Properties.Name -contains $SortBy) {
        $Data = $Data | Sort-Object $SortBy
    }

    switch ($OutputFormat) {
        "Console" {
            Write-Host "`n=== $ReportType Report ===" -ForegroundColor Cyan
            $Data | Format-Table -AutoSize
        }
        "CSV" {
            if (-not $OutputPath) {
                $OutputPath = "${ReportType}_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            }
            $Data | Export-Csv -Path $OutputPath -NoTypeInformation
            Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
        }
        "HTML" {
            if (-not $OutputPath) {
                $OutputPath = "${ReportType}_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
            }

            $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>vSphere $ReportType Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
</head>
<body>
    <h1>vSphere $ReportType Report</h1>
    <p>Generated: $(Get-Date)</p>
    $($Data | ConvertTo-Html -Fragment)
</body>
</html>
"@

            $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
        }
        "JSON" {
            if (-not $OutputPath) {
                $OutputPath = "${ReportType}_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            }
            $Data | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
        }
    }
}

# Main execution
try {
    Write-Host "=== vSphere Infrastructure Inventory Report ===" -ForegroundColor Cyan
    Write-Host "Target vCenter: $VCenterServer" -ForegroundColor White
    Write-Host "Report Type: $ReportType" -ForegroundColor White
    Write-Host "Output Format: $OutputFormat" -ForegroundColor White
    Write-Host ""

    # Check and install PowerCLI
    if (-not (Test-PowerCLIInstallation)) {
        throw "PowerCLI installation failed"
    }

    # Connect to vCenter
    $connection = Connect-ToVCenter -Server $VCenterServer

    # Generate reports based on type
    $reportData = @()
    $reportsToGenerate = if ($ReportType -eq "All") {
        @("Overview", "Datacenters", "Clusters", "Hosts", "VMs", "Datastores", "Networks", "ResourcePools")
    } else {
        @($ReportType)
    }

    foreach ($report in $reportsToGenerate) {
        Write-Host "Generating $report report..." -ForegroundColor Yellow

        $data = switch ($report) {
            "Overview" { Get-OverviewReport }
            "Datacenters" { Get-DatacenterReport }
            "Clusters" { Get-ClusterReport }
            "Hosts" { Get-HostReport }
            "VMs" { Get-VMReport }
            "Datastores" { Get-DatastoreReport }
            "Networks" { Get-NetworkReport }
            "ResourcePools" { Get-ResourcePoolReport }
        }

        if ($ReportType -eq "All") {
            # For "All" reports, display each section
            Export-Report -Data $data -ReportType $report -OutputFormat "Console" -SortBy $SortBy
        } else {
            # For single report type, store data for final output
            $reportData = $data
        }
    }

    # Export single report type if not "All"
    if ($ReportType -ne "All") {
        Export-Report -Data $reportData -ReportType $ReportType -OutputFormat $OutputFormat -OutputPath $OutputPath -SortBy $SortBy
    }

    Write-Host "`n=== Report Generation Completed ===" -ForegroundColor Green
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
