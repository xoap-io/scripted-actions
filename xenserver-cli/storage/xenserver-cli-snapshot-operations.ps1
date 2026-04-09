<#
.SYNOPSIS
    Create and manage VDI (virtual disk image) snapshots in a XenServer storage repository.

.DESCRIPTION
    Manages VDI snapshots within a XenServer or XCP-ng storage repository using
    XenServerPSModule. Supports listing VDIs and their snapshots with Get-XenVDI,
    creating VDI snapshots with New-XenVDISnapshot (Invoke-XenVDI -XenAction snapshot),
    and deleting snapshots with Invoke-XenVDI -XenAction destroy.

.PARAMETER XenServer
    The XenServer pool coordinator hostname or IP address.

.PARAMETER Credential
    PSCredential for XenServer authentication.

.PARAMETER SrName
    The name of the storage repository to operate on.

.PARAMETER Action
    The operation to perform: List, Snapshot, or Delete.

.PARAMETER VdiName
    The name of the VDI to snapshot. Required for Snapshot.

.PARAMETER SnapshotName
    A descriptive name for the new snapshot (Snapshot action) or the snapshot
    name to delete (Delete action).

.EXAMPLE
    .\xenserver-cli-snapshot-operations.ps1 -XenServer "xenserver.local" -Credential (Get-Credential) -SrName "NFS-Storage" -Action List

.EXAMPLE
    .\xenserver-cli-snapshot-operations.ps1 -XenServer "xenserver.local" -Credential (Get-Credential) -SrName "NFS-Storage" -Action Snapshot -VdiName "WebServer-disk" -SnapshotName "pre-upgrade"

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the storage repository to operate on.")]
    [ValidateNotNullOrEmpty()]
    [string]$SrName,

    [Parameter(Mandatory = $false, HelpMessage = "Operation to perform: List, Snapshot, or Delete.")]
    [ValidateSet('List', 'Snapshot', 'Delete')]
    [string]$Action = 'List',

    [Parameter(Mandatory = $false, HelpMessage = "Name of the VDI to snapshot. Required for Snapshot action.")]
    [string]$VdiName,

    [Parameter(Mandatory = $false, HelpMessage = "Name for the new snapshot (Snapshot) or snapshot to delete (Delete).")]
    [string]$SnapshotName
)

$ErrorActionPreference = 'Stop'

# Validate required parameters per action
if ($Action -eq 'Snapshot' -and -not $VdiName) {
    throw "VdiName is required for Action 'Snapshot'."
}
if ($Action -eq 'Delete' -and -not $SnapshotName) {
    throw "SnapshotName is required for Action 'Delete'."
}

# Check and load XenServer module
if (-not (Get-Module -ListAvailable -Name XenServerPSModule)) {
    throw "XenServerPSModule not found. Please install the XenServer PowerShell SDK."
}
Import-Module XenServerPSModule -ErrorAction Stop

$session = $null

try {
    Write-Host "🚀 Starting XenServer VDI Snapshot Operations" -ForegroundColor Green
    Write-Host "🔍 Connecting to XenServer: $XenServer" -ForegroundColor Cyan

    $url = if ($XenServer -match '^https?://') { $XenServer } else { "https://$XenServer" }
    $session = Connect-XenServer -Url $url -UserName $Credential.UserName -Password $Credential.GetNetworkCredential().Password -SetDefaultSession -PassThru
    Write-Host "✅ Connected to XenServer: $XenServer" -ForegroundColor Green

    Write-Host "🔍 Looking up storage repository: $SrName" -ForegroundColor Cyan
    $sr = Get-XenSR | Where-Object { $_.name_label -eq $SrName } | Select-Object -First 1
    if (-not $sr) {
        throw "Storage repository '$SrName' not found."
    }
    Write-Host "✅ Found SR: $($sr.name_label) (UUID: $($sr.uuid))" -ForegroundColor Green

    # Retrieve all VDIs in the SR
    $allVdis = Get-XenVDI | Where-Object { $_.SR -eq $sr.opaque_ref }

    switch ($Action) {
        'List' {
            Write-Host "🔍 Listing VDIs and snapshots in SR '$SrName'..." -ForegroundColor Cyan
            $vdis      = $allVdis | Where-Object { -not $_.is_a_snapshot }
            $snapshots = $allVdis | Where-Object { $_.is_a_snapshot }

            Write-Host "`n📊 Summary:" -ForegroundColor Blue
            Write-Host "  VDIs: $($vdis.Count)  |  Snapshots: $($snapshots.Count)" -ForegroundColor Cyan
            Write-Host "`n  VDIs:" -ForegroundColor Cyan
            foreach ($v in $vdis) {
                $sizeMB = [math]::Round($v.virtual_size / 1MB, 0)
                Write-Host ("    {0,-40} {1,8} MB  UUID: {2}" -f $v.name_label, $sizeMB, $v.uuid)
            }
            if ($snapshots) {
                Write-Host "`n  Snapshots:" -ForegroundColor Cyan
                foreach ($s in $snapshots) {
                    $sizeMB = [math]::Round($s.virtual_size / 1MB, 0)
                    Write-Host ("    {0,-40} {1,8} MB  UUID: {2}" -f $s.name_label, $sizeMB, $s.uuid)
                }
            }
        }
        'Snapshot' {
            Write-Host "🔍 Looking up VDI: $VdiName" -ForegroundColor Cyan
            $vdi = $allVdis | Where-Object { $_.name_label -eq $VdiName -and -not $_.is_a_snapshot } | Select-Object -First 1
            if (-not $vdi) {
                throw "VDI '$VdiName' not found in SR '$SrName'."
            }
            $snapLabel = if ($SnapshotName) { $SnapshotName } else { "$VdiName-snap-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
            Write-Host "🔧 Creating VDI snapshot '$snapLabel'..." -ForegroundColor Cyan
            $snapRef = Invoke-XenVDI -VDI $vdi -XenAction Snapshot -PassThru
            $snap    = Get-XenVDI -Ref $snapRef
            # Set the name label on the snapshot
            Set-XenVDI -VDI $snap -NameLabel $snapLabel
            Write-Host "✅ VDI snapshot created: $snapLabel (UUID: $($snap.uuid))" -ForegroundColor Green
        }
        'Delete' {
            Write-Host "🔧 Deleting snapshot '$SnapshotName'..." -ForegroundColor Cyan
            $snap = $allVdis | Where-Object { $_.name_label -eq $SnapshotName -and $_.is_a_snapshot } | Select-Object -First 1
            if (-not $snap) {
                throw "Snapshot '$SnapshotName' not found in SR '$SrName'."
            }
            Invoke-XenVDI -VDI $snap -XenAction Destroy
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
