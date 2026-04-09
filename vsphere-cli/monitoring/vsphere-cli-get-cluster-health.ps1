<#
.SYNOPSIS
    Report vSphere cluster health including host state, CPU/memory usage, datastore capacity, and VM count.

.DESCRIPTION
    This script generates a cluster health report for one or all vSphere clusters using PowerCLI.
    For each cluster it collects:
      - Host connection state and CPU/memory utilization (Get-VMHost)
      - Datastore capacity and free space (Get-Datastore)
      - Total VM count (Get-VM)
    Results can be output as a formatted table or JSON.

.PARAMETER Server
    The vCenter Server FQDN or IP address.

.PARAMETER Credential
    PSCredential object for authenticating to vCenter.

.PARAMETER ClusterName
    The name of the cluster to report on. If omitted, all clusters are included.

.PARAMETER OutputFormat
    Output format for the results. Valid values: Table, JSON.
    Default: Table

.EXAMPLE
    $cred = Get-Credential
    .\vsphere-cli-get-cluster-health.ps1 -Server "vcenter.domain.com" -Credential $cred

    Report health for all clusters as a table.

.EXAMPLE
    $cred = Get-Credential
    .\vsphere-cli-get-cluster-health.ps1 -Server "vcenter.domain.com" -Credential $cred -ClusterName "Production" -OutputFormat JSON

    Report health for the Production cluster as JSON.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: VMware.PowerCLI (Install-Module -Name VMware.PowerCLI)

.LINK
    https://developer.vmware.com/docs/powercli/

.COMPONENT
    VMware vSphere PowerCLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The vCenter Server FQDN or IP address.")]
    [ValidateNotNullOrEmpty()]
    [string]$Server,

    [Parameter(Mandatory = $true, HelpMessage = "PSCredential object for authenticating to vCenter.")]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false, HelpMessage = "The cluster name to report on. If omitted, all clusters are included.")]
    [string]$ClusterName,

    [Parameter(Mandatory = $false, HelpMessage = "Output format for the results. Valid values: Table, JSON.")]
    [ValidateSet('Table', 'JSON')]
    [string]$OutputFormat = 'Table'
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting vSphere cluster health report..." -ForegroundColor Green

    # Import PowerCLI
    Write-Host "🔍 Loading VMware.PowerCLI module..." -ForegroundColor Cyan
    if (-not (Get-Module -Name VMware.PowerCLI -ListAvailable)) {
        throw "VMware.PowerCLI module is not installed. Install it with: Install-Module -Name VMware.PowerCLI"
    }
    Import-Module VMware.PowerCLI -ErrorAction Stop
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope User | Out-Null
    Set-PowerCLIConfiguration -ParticipateInCEIP $false -Confirm:$false -Scope User | Out-Null

    # Connect
    Write-Host "🔍 Connecting to vCenter Server '$Server'..." -ForegroundColor Cyan
    $connection = Connect-VIServer -Server $Server -Credential $Credential -Force
    Write-Host "✅ Connected to: $($connection.Name)" -ForegroundColor Green

    # Get clusters
    if ($ClusterName) {
        $clusters = Get-Cluster -Name $ClusterName -ErrorAction Stop
    }
    else {
        $clusters = Get-Cluster
    }

    if (-not $clusters) {
        throw "No clusters found."
    }

    Write-Host "ℹ️  Processing $($clusters.Count) cluster(s)..." -ForegroundColor Yellow

    $report = @()

    foreach ($cluster in $clusters) {
        Write-Host "🔍 Collecting data for cluster '$($cluster.Name)'..." -ForegroundColor Cyan

        # Hosts
        $hosts = Get-VMHost -Location $cluster
        $hostCount = $hosts.Count
        $connectedHosts = ($hosts | Where-Object { $_.ConnectionState -eq 'Connected' }).Count

        $totalCpuMhz = ($hosts | Measure-Object -Property CpuTotalMhz -Sum).Sum
        $usedCpuMhz  = ($hosts | Measure-Object -Property CpuUsageMhz -Sum).Sum
        $cpuUsagePct = if ($totalCpuMhz -gt 0) { [math]::Round($usedCpuMhz / $totalCpuMhz * 100, 1) } else { 0 }

        $totalMemGB  = [math]::Round(($hosts | Measure-Object -Property MemoryTotalGB -Sum).Sum, 2)
        $usedMemGB   = [math]::Round(($hosts | Measure-Object -Property MemoryUsageGB -Sum).Sum, 2)
        $memUsagePct = if ($totalMemGB -gt 0) { [math]::Round($usedMemGB / $totalMemGB * 100, 1) } else { 0 }

        # VMs
        $vmCount = (Get-VM -Location $cluster -ErrorAction SilentlyContinue).Count

        # Datastores
        $datastores = Get-Datastore -RelatedObject $cluster -ErrorAction SilentlyContinue
        $totalDsCapGB = [math]::Round(($datastores | Measure-Object -Property CapacityGB -Sum).Sum, 2)
        $totalDsFreeGB = [math]::Round(($datastores | Measure-Object -Property FreeSpaceGB -Sum).Sum, 2)
        $dsUsagePct = if ($totalDsCapGB -gt 0) { [math]::Round(($totalDsCapGB - $totalDsFreeGB) / $totalDsCapGB * 100, 1) } else { 0 }

        $report += [PSCustomObject]@{
            ClusterName      = $cluster.Name
            HAEnabled        = $cluster.HAEnabled
            DrsEnabled       = $cluster.DrsEnabled
            TotalHosts       = $hostCount
            ConnectedHosts   = $connectedHosts
            VMCount          = $vmCount
            'CPU_Total_MHz'  = $totalCpuMhz
            'CPU_Used_MHz'   = $usedCpuMhz
            'CPU_Usage_%'    = $cpuUsagePct
            'Mem_Total_GB'   = $totalMemGB
            'Mem_Used_GB'    = $usedMemGB
            'Mem_Usage_%'    = $memUsagePct
            'DS_Total_GB'    = $totalDsCapGB
            'DS_Free_GB'     = $totalDsFreeGB
            'DS_Usage_%'     = $dsUsagePct
        }
    }

    Write-Host "✅ Health report complete." -ForegroundColor Green

    if ($OutputFormat -eq 'JSON') {
        $report | ConvertTo-Json -Depth 5
    }
    else {
        $report | Format-Table -AutoSize
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($global:DefaultVIServers) {
        Disconnect-VIServer -Server * -Confirm:$false -Force -ErrorAction SilentlyContinue
    }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
