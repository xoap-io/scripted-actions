<#
.SYNOPSIS
    Manage XenServer pool operations: get pool info, join hosts, or eject hosts.

.DESCRIPTION
    Performs pool management operations on a XenServer or XCP-ng pool using the
    XenServerPSModule. Supports retrieving pool information with Get-XenPool,
    joining a new host to the pool with Invoke-XenPool -XenAction join, and
    ejecting a host from the pool with Invoke-XenPool -XenAction eject.

.PARAMETER XenServer
    The XenServer pool coordinator hostname or IP address.

.PARAMETER Credential
    PSCredential for XenServer authentication.

.PARAMETER Action
    The pool operation to perform: Get, Join, or Eject.

.PARAMETER MasterAddress
    The pool master address used when joining a new host to the pool. Required for Join.

.PARAMETER HostToEject
    The hostname or IP of the host to eject from the pool. Required for Eject.

.EXAMPLE
    .\xenserver-cli-pool-operations.ps1 -XenServer "xenserver.local" -Credential (Get-Credential) -Action Get

.EXAMPLE
    .\xenserver-cli-pool-operations.ps1 -XenServer "newhost.local" -Credential (Get-Credential) -Action Join -MasterAddress "xenmaster.local"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: XenServerPSModule (Citrix XenServer SDK)

.LINK
    https://docs.citrix.com/en-us/citrix-hypervisor/sdk/

.COMPONENT
    Citrix XenServer PowerShell
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The XenServer pool coordinator hostname or IP address.")]
    [ValidateNotNullOrEmpty()]
    [string]$XenServer,

    [Parameter(Mandatory = $true, HelpMessage = "PSCredential for XenServer authentication.")]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false, HelpMessage = "Pool operation to perform: Get, Join, or Eject.")]
    [ValidateSet('Get', 'Join', 'Eject')]
    [string]$Action = 'Get',

    [Parameter(Mandatory = $false, HelpMessage = "Pool master address. Required when Action is Join.")]
    [string]$MasterAddress,

    [Parameter(Mandatory = $false, HelpMessage = "Hostname or IP of the host to eject. Required when Action is Eject.")]
    [string]$HostToEject
)

$ErrorActionPreference = 'Stop'

# Validate required parameters per action
if ($Action -eq 'Join' -and -not $MasterAddress) {
    throw "MasterAddress is required for Action 'Join'."
}
if ($Action -eq 'Eject' -and -not $HostToEject) {
    throw "HostToEject is required for Action 'Eject'."
}

# Check and load XenServer module
if (-not (Get-Module -ListAvailable -Name XenServerPSModule)) {
    throw "XenServerPSModule not found. Please install the XenServer PowerShell SDK."
}
Import-Module XenServerPSModule -ErrorAction Stop

$session = $null

try {
    Write-Host "🚀 Starting XenServer Pool Operations" -ForegroundColor Green
    Write-Host "🔍 Connecting to XenServer: $XenServer" -ForegroundColor Cyan

    $url = if ($XenServer -match '^https?://') { $XenServer } else { "https://$XenServer" }
    $session = Connect-XenServer -Url $url -UserName $Credential.UserName -Password $Credential.GetNetworkCredential().Password -SetDefaultSession -PassThru
    Write-Host "✅ Connected to XenServer: $XenServer" -ForegroundColor Green

    switch ($Action) {
        'Get' {
            Write-Host "🔍 Retrieving pool information..." -ForegroundColor Cyan
            $pool = Get-XenPool | Select-Object -First 1
            if (-not $pool) {
                throw "No pool information found."
            }
            $master = Get-XenHost -Ref $pool.master -ErrorAction SilentlyContinue
            $hosts  = Get-XenHost

            Write-Host "`n📊 Summary:" -ForegroundColor Blue
            Write-Host "  Pool name:    $($pool.name_label)" -ForegroundColor Cyan
            Write-Host "  Pool UUID:    $($pool.uuid)" -ForegroundColor Cyan
            Write-Host "  Master:       $($master.name_label) ($($master.address))" -ForegroundColor Cyan
            Write-Host "  HA enabled:   $($pool.ha_enabled)" -ForegroundColor Cyan
            Write-Host "`n  Pool Members:" -ForegroundColor Cyan
            foreach ($h in $hosts) {
                $role = if ($h.opaque_ref -eq $pool.master) { 'Master' } else { 'Slave' }
                Write-Host "    [$role] $($h.name_label) - $($h.address) (enabled: $($h.enabled))" -ForegroundColor $(if ($role -eq 'Master') { 'Green' } else { 'White' })
            }
        }
        'Join' {
            Write-Host "🔧 Joining pool with master at $MasterAddress..." -ForegroundColor Cyan
            $pool = Get-XenPool | Select-Object -First 1
            Invoke-XenPool -Pool $pool -XenAction join -MasterAddress $MasterAddress -MasterUsername $Credential.UserName -MasterPassword $Credential.GetNetworkCredential().Password
            Write-Host "✅ Successfully joined pool. Master: $MasterAddress" -ForegroundColor Green
        }
        'Eject' {
            Write-Host "🔧 Ejecting host '$HostToEject' from pool..." -ForegroundColor Cyan
            $host2Eject = Get-XenHost | Where-Object { $_.hostname -eq $HostToEject -or $_.address -eq $HostToEject -or $_.name_label -eq $HostToEject } | Select-Object -First 1
            if (-not $host2Eject) {
                throw "Host '$HostToEject' not found in pool."
            }
            $pool = Get-XenPool | Select-Object -First 1
            Invoke-XenPool -Pool $pool -XenAction eject -Host $host2Eject
            Write-Host "✅ Host '$($host2Eject.name_label)' ejected from pool." -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($session) {
        Get-XenSession | Disconnect-XenServer -ErrorAction SilentlyContinue
    }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
