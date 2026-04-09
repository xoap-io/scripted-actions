<#
.SYNOPSIS
    Create, revert, list, or delete VM snapshots in XenServer/XCP-ng.

.DESCRIPTION
    Manages VM snapshots in a XenServer or XCP-ng pool using the XenServerPSModule.
    Supports creating new snapshots with New-XenVMSnapshot, reverting to a snapshot
    with Restore-XenVM (Invoke-XenVM -XenAction revert), listing existing snapshots,
    and deleting named snapshots.

.PARAMETER XenServer
    The XenServer pool coordinator hostname or IP address.

.PARAMETER Credential
    PSCredential for XenServer authentication.

.PARAMETER VmName
    The name of the VM to snapshot.

.PARAMETER Action
    The snapshot action to perform: Create, Revert, List, or Delete.

.PARAMETER SnapshotName
    Name for the snapshot. Auto-generated from timestamp if omitted on Create.
    Required for Revert and Delete actions.

.EXAMPLE
    .\xenserver-cli-snapshot-vm.ps1 -XenServer "xenserver.local" -Credential (Get-Credential) -VmName "WebServer01" -Action Create -SnapshotName "pre-patching-2026"

.EXAMPLE
    .\xenserver-cli-snapshot-vm.ps1 -XenServer "xenserver.local" -Credential (Get-Credential) -VmName "WebServer01" -Action Revert -SnapshotName "pre-patching-2026"

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the VM to snapshot.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $false, HelpMessage = "The snapshot action to perform: Create, Revert, List, or Delete.")]
    [ValidateSet('Create', 'Revert', 'List', 'Delete')]
    [string]$Action = 'Create',

    [Parameter(Mandatory = $false, HelpMessage = "Snapshot name. Auto-generated if omitted for Create; required for Revert and Delete.")]
    [string]$SnapshotName
)

$ErrorActionPreference = 'Stop'

# Validate required parameters per action
if ($Action -in @('Revert', 'Delete') -and -not $SnapshotName) {
    throw "SnapshotName is required for Action '$Action'."
}

# Check and load XenServer module
if (-not (Get-Module -ListAvailable -Name XenServerPSModule)) {
    throw "XenServerPSModule not found. Please install the XenServer PowerShell SDK."
}
Import-Module XenServerPSModule -ErrorAction Stop

$session = $null

try {
    Write-Host "🚀 Starting XenServer VM Snapshot Manager" -ForegroundColor Green
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

    switch ($Action) {
        'Create' {
            if (-not $SnapshotName) {
                $SnapshotName = "$VmName-snap-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            }
            Write-Host "🔧 Creating snapshot '$SnapshotName' for VM '$VmName'..." -ForegroundColor Cyan
            $snapRef = Invoke-XenVM -VM $vm -XenAction Snapshot -NewNameLabel $SnapshotName -PassThru
            $snap = Get-XenVM -Ref $snapRef
            Write-Host "✅ Snapshot created: $($snap.name_label) (UUID: $($snap.uuid))" -ForegroundColor Green
        }
        'Revert' {
            Write-Host "🔧 Reverting VM '$VmName' to snapshot '$SnapshotName'..." -ForegroundColor Cyan
            $snap = Get-XenVM -Name $SnapshotName | Where-Object { $_.is_a_snapshot } | Select-Object -First 1
            if (-not $snap) {
                throw "Snapshot '$SnapshotName' not found."
            }
            Invoke-XenVM -VM $snap -XenAction Revert
            Write-Host "✅ VM '$VmName' reverted to snapshot '$SnapshotName'." -ForegroundColor Green
        }
        'List' {
            Write-Host "🔍 Listing snapshots for VM '$VmName'..." -ForegroundColor Cyan
            $snapshots = Get-XenVM | Where-Object { $_.is_a_snapshot -and $_.snapshot_of -eq $vm.opaque_ref }
            if ($snapshots) {
                Write-Host "`n📊 Summary:" -ForegroundColor Blue
                Write-Host ("  {0,-40} {1,-30} {2}" -f "Name", "UUID", "Created") -ForegroundColor Cyan
                Write-Host ("  {0,-40} {1,-30} {2}" -f "----", "----", "-------") -ForegroundColor Cyan
                foreach ($s in $snapshots) {
                    Write-Host ("  {0,-40} {1,-30} {2}" -f $s.name_label, $s.uuid, $s.snapshot_time)
                }
            } else {
                Write-Host "ℹ️  No snapshots found for VM '$VmName'." -ForegroundColor Yellow
            }
        }
        'Delete' {
            Write-Host "🔧 Deleting snapshot '$SnapshotName'..." -ForegroundColor Cyan
            $snap = Get-XenVM -Name $SnapshotName | Where-Object { $_.is_a_snapshot } | Select-Object -First 1
            if (-not $snap) {
                throw "Snapshot '$SnapshotName' not found."
            }
            # Destroy the snapshot VDIs first, then the snapshot VM record
            foreach ($vbdRef in $snap.VBDs) {
                $vbd = Get-XenVBD -Ref $vbdRef -ErrorAction SilentlyContinue
                if ($vbd -and $vbd.type -eq 'Disk') {
                    $vdi = Get-XenVDI -Ref $vbd.VDI -ErrorAction SilentlyContinue
                    if ($vdi -and $vdi.is_a_snapshot) {
                        Invoke-XenVDI -VDI $vdi -XenAction Destroy -ErrorAction SilentlyContinue
                    }
                }
            }
            Invoke-XenVM -VM $snap -XenAction Destroy
            Write-Host "✅ Snapshot '$SnapshotName' deleted." -ForegroundColor Green
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
