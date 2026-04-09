<#
.SYNOPSIS
    Create, configure, get, or remove a vSphere cluster with DRS and HA settings using PowerCLI.

.DESCRIPTION
    This script manages vSphere cluster lifecycle operations using VMware PowerCLI cmdlets:
      Get    - Retrieve and display cluster details
      Create - Create a new cluster in the specified datacenter
      Configure - Update DRS and HA settings on an existing cluster
      Remove - Remove a cluster from vCenter (requires -Force)

    DRS automation level and HA failover level can be configured during Create or Configure actions.

.PARAMETER Server
    The vCenter Server FQDN or IP address.

.PARAMETER Credential
    PSCredential object for authenticating to vCenter.

.PARAMETER DatacenterName
    The name of the datacenter where the cluster resides or will be created.

.PARAMETER ClusterName
    The name of the cluster to manage.

.PARAMETER Action
    The operation to perform. Valid values: Create, Configure, Remove, Get.
    Default: Get

.PARAMETER EnableDrs
    Enable vSphere DRS on the cluster (for Create and Configure actions).

.PARAMETER DrsAutomationLevel
    The DRS automation level. Valid values: FullyAutomated, Manual, PartiallyAutomated.
    Default: FullyAutomated

.PARAMETER EnableHA
    Enable vSphere HA on the cluster (for Create and Configure actions).

.PARAMETER HaFailoverLevel
    Number of host failures the cluster can tolerate (1-4). Default: 1

.PARAMETER Force
    Required to confirm cluster removal. Also skips confirmation prompts.

.EXAMPLE
    $cred = Get-Credential
    .\vsphere-cli-manage-clusters.ps1 -Server "vcenter.domain.com" -Credential $cred -DatacenterName "Production" -ClusterName "ProdCluster01" -Action Create -EnableDrs -EnableHA

    Create a new cluster with DRS and HA enabled.

.EXAMPLE
    $cred = Get-Credential
    .\vsphere-cli-manage-clusters.ps1 -Server "vcenter.domain.com" -Credential $cred -DatacenterName "Production" -ClusterName "ProdCluster01" -Action Configure -DrsAutomationLevel PartiallyAutomated -HaFailoverLevel 2

    Update an existing cluster DRS and HA settings.

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the datacenter where the cluster resides or will be created.")]
    [ValidateNotNullOrEmpty()]
    [string]$DatacenterName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the cluster to manage.")]
    [ValidateNotNullOrEmpty()]
    [string]$ClusterName,

    [Parameter(Mandatory = $false, HelpMessage = "The operation to perform. Valid values: Create, Configure, Remove, Get.")]
    [ValidateSet('Create', 'Configure', 'Remove', 'Get')]
    [string]$Action = 'Get',

    [Parameter(Mandatory = $false, HelpMessage = "Enable vSphere DRS on the cluster.")]
    [switch]$EnableDrs,

    [Parameter(Mandatory = $false, HelpMessage = "The DRS automation level. Valid values: FullyAutomated, Manual, PartiallyAutomated.")]
    [ValidateSet('FullyAutomated', 'Manual', 'PartiallyAutomated')]
    [string]$DrsAutomationLevel = 'FullyAutomated',

    [Parameter(Mandatory = $false, HelpMessage = "Enable vSphere HA on the cluster.")]
    [switch]$EnableHA,

    [Parameter(Mandatory = $false, HelpMessage = "Number of host failures the cluster can tolerate (1-4).")]
    [ValidateRange(1, 4)]
    [int]$HaFailoverLevel = 1,

    [Parameter(Mandatory = $false, HelpMessage = "Required to confirm cluster removal. Also skips confirmation prompts.")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting vSphere cluster management (Action: $Action)..." -ForegroundColor Green

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

    # Get datacenter
    Write-Host "🔍 Locating datacenter '$DatacenterName'..." -ForegroundColor Cyan
    $datacenter = Get-Datacenter -Name $DatacenterName -ErrorAction Stop
    if (-not $datacenter) { throw "Datacenter '$DatacenterName' not found." }

    switch ($Action) {
        'Get' {
            Write-Host "🔍 Retrieving cluster '$ClusterName'..." -ForegroundColor Cyan
            $cluster = Get-Cluster -Name $ClusterName -Location $datacenter -ErrorAction Stop

            Write-Host "✅ Cluster found." -ForegroundColor Green
            Write-Host "`n📊 Cluster Details:" -ForegroundColor Blue
            $cluster | Select-Object Name, HAEnabled, HAFailoverLevel, DrsEnabled, DrsAutomationLevel,
                @{N='VMCount'; E={(Get-VM -Location $_ -ErrorAction SilentlyContinue).Count}},
                @{N='HostCount'; E={(Get-VMHost -Location $_ -ErrorAction SilentlyContinue).Count}} |
                Format-List
        }

        'Create' {
            Write-Host "🔧 Creating cluster '$ClusterName' in datacenter '$DatacenterName'..." -ForegroundColor Cyan

            $createParams = @{
                Name     = $ClusterName
                Location = $datacenter
            }
            if ($EnableDrs) {
                $createParams.DrsEnabled          = $true
                $createParams.DrsAutomationLevel  = $DrsAutomationLevel
            }
            if ($EnableHA) {
                $createParams.HAEnabled      = $true
                $createParams.HAFailoverLevel = $HaFailoverLevel
            }

            $cluster = New-Cluster @createParams
            Write-Host "✅ Cluster '$ClusterName' created successfully." -ForegroundColor Green
            Write-Host "ℹ️  DRS Enabled: $($cluster.DrsEnabled) | HA Enabled: $($cluster.HAEnabled)" -ForegroundColor Yellow
        }

        'Configure' {
            Write-Host "🔍 Retrieving cluster '$ClusterName' for configuration..." -ForegroundColor Cyan
            $cluster = Get-Cluster -Name $ClusterName -Location $datacenter -ErrorAction Stop

            $configParams = @{ Cluster = $cluster }
            if ($PSBoundParameters.ContainsKey('EnableDrs')) {
                $configParams.DrsEnabled         = $EnableDrs.IsPresent
                $configParams.DrsAutomationLevel = $DrsAutomationLevel
            }
            if ($PSBoundParameters.ContainsKey('EnableHA')) {
                $configParams.HAEnabled      = $EnableHA.IsPresent
                $configParams.HAFailoverLevel = $HaFailoverLevel
            }

            Write-Host "🔧 Updating cluster '$ClusterName' configuration..." -ForegroundColor Cyan
            $cluster = Set-Cluster @configParams -Confirm:$false
            Write-Host "✅ Cluster '$ClusterName' configured successfully." -ForegroundColor Green
            Write-Host "ℹ️  DRS: $($cluster.DrsEnabled) ($($cluster.DrsAutomationLevel)) | HA: $($cluster.HAEnabled) (Failover: $($cluster.HAFailoverLevel))" -ForegroundColor Yellow
        }

        'Remove' {
            if (-not $Force) {
                throw "Use -Force to confirm cluster removal. This operation cannot be undone."
            }

            Write-Host "🔍 Retrieving cluster '$ClusterName' for removal..." -ForegroundColor Cyan
            $cluster = Get-Cluster -Name $ClusterName -Location $datacenter -ErrorAction Stop

            $vmCount = (Get-VM -Location $cluster -ErrorAction SilentlyContinue).Count
            if ($vmCount -gt 0 -and -not $Force) {
                throw "Cluster '$ClusterName' contains $vmCount VM(s). Remove VMs before deleting the cluster, or use -Force."
            }

            Write-Host "🔧 Removing cluster '$ClusterName'..." -ForegroundColor Cyan
            Remove-Cluster -Cluster $cluster -Confirm:$false
            Write-Host "✅ Cluster '$ClusterName' removed successfully." -ForegroundColor Green
        }
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
