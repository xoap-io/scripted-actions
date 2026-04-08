<#
.SYNOPSIS
    Manages XenServer storage repositories using XenServerPSModule.

.DESCRIPTION
    Creates, destroys, and manages storage repositories (SRs) in XenServer.
    Supports various SR types including NFS, iSCSI, Local VHD, and more.

.PARAMETER Server
    The XenServer pool coordinator hostname or IP address.

.PARAMETER Username
    Username for authentication (default: root).

.PARAMETER Password
    Password for authentication.

.PARAMETER Operation
    The SR operation: Create, Destroy, Scan, List, Probe.

.PARAMETER SRName
    The name of the storage repository.

.PARAMETER SRUUID
    The UUID of the storage repository.

.PARAMETER SRType
    The type of SR: nfs, lvmoiscsi, lvmohba, lvm, ext, iso.

.PARAMETER ServerPath
    For NFS: server:/path format (e.g., nfs-server.local:/exports/xen).

.PARAMETER TargetIQN
    For iSCSI: target IQN.

.PARAMETER TargetIP
    For iSCSI: target IP address.

.PARAMETER SCSIid
    For iSCSI/HBA: SCSI device identifier.

.PARAMETER DevicePath
    For local storage: device path (e.g., /dev/sdb1).

.PARAMETER Shared
    Whether the SR is shared across multiple hosts.

.EXAMPLE
    .\xenserver-cli-sr-operations.ps1 -Server "xenserver.local" -Operation "Create" -SRName "NFS-Storage" -SRType "nfs" -ServerPath "nfs-server.local:/exports/xen" -Shared

.EXAMPLE
    .\xenserver-cli-sr-operations.ps1 -Server "xenserver.local" -Operation "List"

.EXAMPLE
    .\xenserver-cli-sr-operations.ps1 -Server "xenserver.local" -Operation "Scan" -SRUUID "12345678-abcd-1234-abcd-123456789012"

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
    https://docs.xenserver.com/en-us/xenserver/current-release/storage.html

.COMPONENT
    Citrix XenServer PowerShell
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The XenServer pool coordinator hostname or IP address.")]
    [string]$Server,

    [Parameter(Mandatory = $false, HelpMessage = "Username for authentication (default: root).")]
    [string]$Username = "root",

    [Parameter(Mandatory = $false, HelpMessage = "Password for authentication.")]
    [string]$Password,

    [Parameter(Mandatory = $true, HelpMessage = "The SR operation: Create, Destroy, Scan, List, Probe, Forget.")]
    [ValidateSet("Create", "Destroy", "Scan", "List", "Probe", "Forget")]
    [string]$Operation,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the storage repository.")]
    [string]$SRName,

    [Parameter(Mandatory = $false, HelpMessage = "The UUID of the storage repository.")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$SRUUID,

    [Parameter(Mandatory = $false, HelpMessage = "The type of SR: nfs, lvmoiscsi, lvmohba, lvm, ext, iso.")]
    [ValidateSet("nfs", "lvmoiscsi", "lvmohba", "lvm", "ext", "iso")]
    [string]$SRType,

    [Parameter(Mandatory = $false, HelpMessage = "For NFS: server:/path format (e.g., nfs-server.local:/exports/xen).")]
    [string]$ServerPath,

    [Parameter(Mandatory = $false, HelpMessage = "For iSCSI: target IQN.")]
    [string]$TargetIQN,

    [Parameter(Mandatory = $false, HelpMessage = "For iSCSI: target IP address.")]
    [string]$TargetIP,

    [Parameter(Mandatory = $false, HelpMessage = "For iSCSI/HBA: SCSI device identifier.")]
    [string]$SCSIid,

    [Parameter(Mandatory = $false, HelpMessage = "For local storage: device path (e.g., /dev/sdb1).")]
    [string]$DevicePath,

    [Parameter(Mandatory = $false, HelpMessage = "Whether the SR is shared across multiple hosts.")]
    [switch]$Shared
)

$ErrorActionPreference = 'Stop'

# Check and load XenServer module
if (-not (Get-Module -ListAvailable -Name XenServerPSModule)) {
    throw "XenServerPSModule not found. Please install the XenServer PowerShell SDK."
}
Import-Module XenServerPSModule -ErrorAction Stop

# Main execution
try {
    Write-Host "XenServer Storage Repository Operations" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan

    # Connect to XenServer
    $url = if ($Server -match '^https?://') { $Server } else { "https://$Server" }
    $session = Connect-XenServer -Url $url -UserName $Username -Password $Password -SetDefaultSession -PassThru
    Write-Host "✓ Connected to XenServer: $Server" -ForegroundColor Green

    switch ($Operation) {
        "Create" {
            if (-not $SRName -or -not $SRType) {
                throw "SRName and SRType are required for Create operation"
            }

            Write-Host "`nCreating SR: $SRName (Type: $SRType)..." -ForegroundColor Cyan

            $deviceConfig = @{}

            # Build device-config based on SR type
            switch ($SRType) {
                "nfs" {
                    if (-not $ServerPath) { throw "ServerPath required for NFS SR" }
                    $parts = $ServerPath -split ':'
                    $deviceConfig['server'] = $parts[0]
                    $deviceConfig['serverpath'] = $parts[1]
                }
                "lvmoiscsi" {
                    if (-not $TargetIP -or -not $TargetIQN) { throw "TargetIP and TargetIQN required for iSCSI SR" }
                    $deviceConfig['target'] = $TargetIP
                    $deviceConfig['targetIQN'] = $TargetIQN
                    if ($SCSIid) { $deviceConfig['SCSIid'] = $SCSIid }
                }
                "lvm" {
                    if (-not $DevicePath) { throw "DevicePath required for local LVM SR" }
                    $deviceConfig['device'] = $DevicePath
                }
            }

            # Get a host for SR creation
            $host = Get-XenHost | Select-Object -First 1

            # Create SR
            $sr = New-XenSR -XenHost $host -NameLabel $SRName -Type $SRType -DeviceConfig $deviceConfig -Shared $Shared.IsPresent
            Write-Host "✓ SR created successfully: $SRName (UUID: $($sr.uuid))" -ForegroundColor Green
        }

        "List" {
            Write-Host "`nListing all storage repositories..." -ForegroundColor Cyan
            $srs = Get-XenSR
            foreach ($sr in $srs) {
                Write-Host "`n  Name: $($sr.name_label)"
                Write-Host "  UUID: $($sr.uuid)"
                Write-Host "  Type: $($sr.type)"
                Write-Host "  Size: $([math]::Round($sr.physical_size / 1GB, 2)) GB"
                Write-Host "  Used: $([math]::Round($sr.physical_utilisation / 1GB, 2)) GB"
                Write-Host "  Shared: $($sr.shared)"
            }
        }

        "Scan" {
            if (-not $SRUUID) { throw "SRUUID required for Scan operation" }
            Write-Host "`nScanning SR: $SRUUID..." -ForegroundColor Cyan
            $sr = Get-XenSR -Uuid $SRUUID
            Invoke-XenSR -SR $sr -XenAction Scan
            Write-Host "✓ SR scan completed successfully" -ForegroundColor Green
        }

        "Destroy" {
            if (-not $SRUUID) { throw "SRUUID required for Destroy operation" }
            Write-Host "`nDestroying SR: $SRUUID..." -ForegroundColor Cyan
            $sr = Get-XenSR -Uuid $SRUUID
            Remove-XenSR -SR $sr
            Write-Host "✓ SR destroyed successfully" -ForegroundColor Green
        }

        "Forget" {
            if (-not $SRUUID) { throw "SRUUID required for Forget operation" }
            Write-Host "`nForgetting SR: $SRUUID..." -ForegroundColor Cyan
            $sr = Get-XenSR -Uuid $SRUUID
            Invoke-XenSR -SR $sr -XenAction Forget
            Write-Host "✓ SR forgotten successfully" -ForegroundColor Green
        }
    }

    Write-Host "`n✓ Operation completed successfully" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    # Disconnect
    if ($session) {
        Get-XenSession | Disconnect-XenServer
    }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
