<#
.SYNOPSIS
    Create a vCenter alarm definition using VMware PowerCLI.

.DESCRIPTION
    This script creates an alarm definition in vCenter Server using the New-AlarmDefinition
    PowerCLI cmdlet. Alarms can be scoped to VirtualMachine, HostSystem, Datastore, or Cluster
    entity types. Optional warning and critical thresholds can be configured for a metric-based
    alarm trigger.

.PARAMETER Server
    The vCenter Server FQDN or IP address.

.PARAMETER Credential
    PSCredential object for authenticating to vCenter.

.PARAMETER AlarmName
    The name for the new alarm definition.

.PARAMETER Description
    An optional description for the alarm.

.PARAMETER Entity
    The entity type the alarm will apply to. Valid values: VirtualMachine, HostSystem, Datastore, Cluster.
    Default: VirtualMachine

.PARAMETER MetricId
    The metric identifier for a metric-based alarm trigger (e.g., cpu.usage.average).
    Optional - if omitted, a basic alarm definition without metric trigger is created.

.PARAMETER WarningThreshold
    The warning threshold value for the metric (used if MetricId is specified).

.PARAMETER CriticalThreshold
    The critical threshold value for the metric (used if MetricId is specified).

.EXAMPLE
    $cred = Get-Credential
    .\vsphere-cli-create-alarm.ps1 -Server "vcenter.domain.com" -Credential $cred -AlarmName "High CPU Alert" -Entity VirtualMachine -MetricId "cpu.usage.average" -WarningThreshold 70 -CriticalThreshold 90

    Create a VM CPU usage alarm with warning at 70% and critical at 90%.

.EXAMPLE
    $cred = Get-Credential
    .\vsphere-cli-create-alarm.ps1 -Server "vcenter.domain.com" -Credential $cred -AlarmName "Host Disconnected" -Description "Alert when a host disconnects" -Entity HostSystem

    Create a basic host alarm definition without a metric trigger.

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

    [Parameter(Mandatory = $true, HelpMessage = "The name for the new alarm definition.")]
    [ValidateNotNullOrEmpty()]
    [string]$AlarmName,

    [Parameter(Mandatory = $false, HelpMessage = "An optional description for the alarm.")]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "The entity type the alarm applies to. Valid values: VirtualMachine, HostSystem, Datastore, Cluster.")]
    [ValidateSet('VirtualMachine', 'HostSystem', 'Datastore', 'Cluster')]
    [string]$Entity = 'VirtualMachine',

    [Parameter(Mandatory = $false, HelpMessage = "The metric identifier for a metric-based alarm trigger (e.g., cpu.usage.average).")]
    [string]$MetricId,

    [Parameter(Mandatory = $false, HelpMessage = "The warning threshold value for the metric.")]
    [double]$WarningThreshold,

    [Parameter(Mandatory = $false, HelpMessage = "The critical threshold value for the metric.")]
    [double]$CriticalThreshold
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting vCenter alarm creation..." -ForegroundColor Green

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

    # Map entity string to SDK type
    $entityTypeMap = @{
        VirtualMachine = 'VirtualMachine'
        HostSystem     = 'HostSystem'
        Datastore      = 'Datastore'
        Cluster        = 'ClusterComputeResource'
    }
    $sdkEntityType = $entityTypeMap[$Entity]

    Write-Host "ℹ️  Alarm Name  : $AlarmName" -ForegroundColor Yellow
    Write-Host "ℹ️  Entity Type : $Entity" -ForegroundColor Yellow
    if ($MetricId) {
        Write-Host "ℹ️  Metric ID   : $MetricId" -ForegroundColor Yellow
        if ($WarningThreshold)  { Write-Host "ℹ️  Warning     : $WarningThreshold" -ForegroundColor Yellow }
        if ($CriticalThreshold) { Write-Host "ℹ️  Critical    : $CriticalThreshold" -ForegroundColor Yellow }
    }

    # Build alarm params
    $alarmParams = @{
        Name       = $AlarmName
        EntityType = $sdkEntityType
    }
    if ($Description) { $alarmParams.Description = $Description }

    Write-Host "🔧 Creating alarm definition '$AlarmName'..." -ForegroundColor Cyan
    $alarm = New-AlarmDefinition @alarmParams

    Write-Host "✅ Alarm definition '$AlarmName' created successfully." -ForegroundColor Green

    # Add metric trigger if MetricId provided
    if ($MetricId -and ($PSBoundParameters.ContainsKey('WarningThreshold') -or $PSBoundParameters.ContainsKey('CriticalThreshold'))) {
        Write-Host "🔧 Adding metric trigger for '$MetricId'..." -ForegroundColor Cyan

        $triggerParams = @{
            Alarm    = $alarm
            Metric   = $MetricId
            Operator = 'IsAbove'
        }
        if ($PSBoundParameters.ContainsKey('WarningThreshold'))  { $triggerParams.Yellow = $WarningThreshold }
        if ($PSBoundParameters.ContainsKey('CriticalThreshold')) { $triggerParams.Red    = $CriticalThreshold }

        New-AlarmTrigger @triggerParams | Out-Null
        Write-Host "✅ Metric trigger configured for alarm '$AlarmName'." -ForegroundColor Green
    }

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  Alarm Name : $($alarm.Name)" -ForegroundColor White
    Write-Host "  Entity Type: $Entity" -ForegroundColor White
    Write-Host "  Enabled    : $($alarm.Enabled)" -ForegroundColor White
    if ($Description) { Write-Host "  Description: $Description" -ForegroundColor White }
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
