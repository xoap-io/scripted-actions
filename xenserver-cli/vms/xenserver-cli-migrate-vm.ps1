<#
.SYNOPSIS
    Live migrate a VM to another host within the same XenServer pool.

.DESCRIPTION
    Performs a live (hot) migration of a running VM to a specified destination host
    within the same XenServer pool using Invoke-XenVM -XenAction Pool_migrate.
    The VM remains running throughout the migration. Use -Force to migrate VMs that
    have local storage (not shared SRs).

.PARAMETER XenServer
    The XenServer pool coordinator hostname or IP address.

.PARAMETER Credential
    PSCredential for XenServer authentication.

.PARAMETER VmName
    The name of the VM to migrate.

.PARAMETER DestinationHost
    The hostname or IP address of the target host within the pool.

.PARAMETER Force
    Migrate the VM even if it has local (non-shared) storage. May cause downtime.

.EXAMPLE
    .\xenserver-cli-migrate-vm.ps1 -XenServer "xenserver.local" -Credential (Get-Credential) -VmName "WebServer01" -DestinationHost "xenhost02.local"

.EXAMPLE
    .\xenserver-cli-migrate-vm.ps1 -XenServer "xenserver.local" -Credential (Get-Credential) -VmName "DBServer" -DestinationHost "xenhost03.local" -Force

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the VM to migrate.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $true, HelpMessage = "The hostname or IP address of the target host within the pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationHost,

    [Parameter(Mandatory = $false, HelpMessage = "Migrate even if VM has local (non-shared) storage.")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Check and load XenServer module
if (-not (Get-Module -ListAvailable -Name XenServerPSModule)) {
    throw "XenServerPSModule not found. Please install the XenServer PowerShell SDK."
}
Import-Module XenServerPSModule -ErrorAction Stop

$session = $null

try {
    Write-Host "🚀 Starting XenServer VM Live Migration" -ForegroundColor Green
    Write-Host "🔍 Connecting to XenServer: $XenServer" -ForegroundColor Cyan

    $url = if ($XenServer -match '^https?://') { $XenServer } else { "https://$XenServer" }
    $session = Connect-XenServer -Url $url -UserName $Credential.UserName -Password $Credential.GetNetworkCredential().Password -SetDefaultSession -PassThru
    Write-Host "✅ Connected to XenServer: $XenServer" -ForegroundColor Green

    Write-Host "🔍 Looking up VM: $VmName" -ForegroundColor Cyan
    $vm = Get-XenVM -Name $VmName | Where-Object { -not $_.is_a_snapshot -and -not $_.is_a_template } | Select-Object -First 1
    if (-not $vm) {
        throw "VM '$VmName' not found."
    }
    Write-Host "✅ Found VM: $($vm.name_label) (UUID: $($vm.uuid))" -ForegroundColor Green
    Write-Host "ℹ️  Current power state: $($vm.power_state)" -ForegroundColor Yellow

    Write-Host "🔍 Looking up destination host: $DestinationHost" -ForegroundColor Cyan
    $destHost = Get-XenHost | Where-Object { $_.hostname -eq $DestinationHost -or $_.address -eq $DestinationHost -or $_.name_label -eq $DestinationHost } | Select-Object -First 1
    if (-not $destHost) {
        throw "Destination host '$DestinationHost' not found in pool."
    }
    Write-Host "✅ Found destination host: $($destHost.name_label) ($($destHost.address))" -ForegroundColor Green

    # Build migration options
    $options = @{}
    if ($Force) {
        $options['live'] = 'true'
        Write-Host "⚠️  Force flag set — migrating VM with local storage." -ForegroundColor Yellow
    }

    Write-Host "🔧 Initiating live migration of '$VmName' to '$($destHost.name_label)'..." -ForegroundColor Cyan
    Invoke-XenVM -VM $vm -XenAction Pool_migrate -Host $destHost -Options $options

    Write-Host "✅ VM '$VmName' successfully migrated to '$($destHost.name_label)'." -ForegroundColor Green

    # Confirm new host
    $migratedVM = Get-XenVM -Uuid $vm.uuid
    $residentHost = Get-XenHost -Ref $migratedVM.resident_on -ErrorAction SilentlyContinue
    if ($residentHost) {
        Write-Host "📊 Summary:" -ForegroundColor Blue
        Write-Host "  VM:              $($migratedVM.name_label)" -ForegroundColor Cyan
        Write-Host "  Resident host:   $($residentHost.name_label)" -ForegroundColor Cyan
        Write-Host "  Power state:     $($migratedVM.power_state)" -ForegroundColor Cyan
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
