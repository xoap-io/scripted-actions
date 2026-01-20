<#
.SYNOPSIS
    Manages XenServer virtual networks using XenServerPSModule.

.DESCRIPTION
    Creates, destroys, and manages virtual networks, VLANs, and network bonds in XenServer.
    Supports network configuration, VLAN tagging, and NIC bonding for high availability.

.PARAMETER Server
    The XenServer pool coordinator hostname or IP address.

.PARAMETER Username
    Username for authentication (default: root).

.PARAMETER Password
    Password for authentication.

.PARAMETER Operation
    Network operation: CreateNetwork, CreateVLAN, CreateBond, List, Destroy.

.PARAMETER NetworkName
    The name of the network.

.PARAMETER NetworkUUID
    The UUID of the network.

.PARAMETER VLANTag
    VLAN tag number (1-4094).

.PARAMETER PIFUUID
    Physical interface UUID for VLAN creation.

.PARAMETER PIFUUIDs
    Array of PIF UUIDs for bond creation.

.PARAMETER BondMode
    Bond mode: active-backup, lacp, balance-slb.

.PARAMETER NetworkDescription
    Optional description for the network.

.EXAMPLE
    .\xenserver-cli-network-operations.ps1 -Server "xenserver.local" -Operation "CreateNetwork" -NetworkName "VM-Network"

.EXAMPLE
    .\xenserver-cli-network-operations.ps1 -Server "xenserver.local" -Operation "CreateVLAN" -NetworkName "VLAN-100" -VLANTag 100 -PIFUUID "87654321-4321-4321-4321-210987654321"

.EXAMPLE
    .\xenserver-cli-network-operations.ps1 -Server "xenserver.local" -Operation "CreateBond" -NetworkName "bond0" -PIFUUIDs @("uuid1","uuid2") -BondMode "active-backup"

.NOTES
    Author: XOAP.io
    Requires: XenServerPSModule (PowerShell SDK)
    Version: 2.0
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [Parameter(Mandatory = $false)]
    [string]$Username = "root",

    [Parameter(Mandatory = $false)]
    [string]$Password,

    [Parameter(Mandatory = $true)]
    [ValidateSet("CreateNetwork", "CreateVLAN", "CreateBond", "List", "Destroy")]
    [string]$Operation,

    [Parameter(Mandatory = $false)]
    [string]$NetworkName,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$NetworkUUID,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 4094)]
    [int]$VLANTag,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$PIFUUID,

    [Parameter(Mandatory = $false)]
    [string[]]$PIFUUIDs,

    [Parameter(Mandatory = $false)]
    [ValidateSet("active-backup", "lacp", "balance-slb")]
    [string]$BondMode = "active-backup",

    [Parameter(Mandatory = $false)]
    [string]$NetworkDescription = ""
)

$ErrorActionPreference = 'Stop'

# Check and load XenServer module
if (-not (Get-Module -ListAvailable -Name XenServerPSModule)) {
    throw "XenServerPSModule not found. Please install the XenServer PowerShell SDK."
}
Import-Module XenServerPSModule -ErrorAction Stop

# Main execution
try {
    Write-Host "XenServer Network Operations" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan

    # Connect to XenServer
    $url = if ($Server -match '^https?://') { $Server } else { "https://$Server" }
    $session = Connect-XenServer -Url $url -UserName $Username -Password $Password -SetDefaultSession -PassThru
    Write-Host "✓ Connected to XenServer: $Server" -ForegroundColor Green

    switch ($Operation) {
        "CreateNetwork" {
            if (-not $NetworkName) { throw "NetworkName required" }
            Write-Host "`nCreating network: $NetworkName..." -ForegroundColor Cyan

            $network = New-XenNetwork -NameLabel $NetworkName -NameDescription $NetworkDescription
            Write-Host "✓ Network created: $NetworkName (UUID: $($network.uuid))" -ForegroundColor Green
        }

        "CreateVLAN" {
            if (-not $NetworkName -or -not $VLANTag -or -not $PIFUUID) {
                throw "NetworkName, VLANTag, and PIFUUID required"
            }
            Write-Host "`nCreating VLAN $VLANTag on PIF $PIFUUID..." -ForegroundColor Cyan

            # First create the network
            $network = New-XenNetwork -NameLabel $NetworkName -NameDescription "VLAN $VLANTag"

            # Get the PIF
            $pif = Get-XenPIF -Uuid $PIFUUID

            # Create VLAN
            $vlan = New-XenVLAN -Network $network -PIF $pif -Tag $VLANTag
            Write-Host "✓ VLAN created successfully" -ForegroundColor Green
        }

        "CreateBond" {
            if (-not $NetworkName -or -not $PIFUUIDs -or $PIFUUIDs.Count -lt 2) {
                throw "NetworkName and at least 2 PIFUUIDs required"
            }
            Write-Host "`nCreating bond with PIFs: $($PIFUUIDs -join ', ')..." -ForegroundColor Cyan

            # Create network for bond
            $network = New-XenNetwork -NameLabel $NetworkName -NameDescription "Bonded Network"

            # Get PIFs
            $pifs = @()
            foreach ($pifUUID in $PIFUUIDs) {
                $pifs += Get-XenPIF -Uuid $pifUUID
            }

            # Create bond
            $bond = New-XenBond -Network $network -PIFs $pifs -Mode $BondMode
            Write-Host "✓ Bond created successfully (Mode: $BondMode)" -ForegroundColor Green
        }

        "List" {
            Write-Host "`nListing networks..." -ForegroundColor Cyan
            $networks = Get-XenNetwork
            foreach ($net in $networks) {
                Write-Host "`n  Name: $($net.name_label)"
                Write-Host "  UUID: $($net.uuid)"
                Write-Host "  Bridge: $($net.bridge)"
                Write-Host "  PIFs: $($net.PIFs.Count)"
                Write-Host "  VIFs: $($net.VIFs.Count)"
            }
        }

        "Destroy" {
            if (-not $NetworkUUID) { throw "NetworkUUID required" }
            Write-Host "`nDestroying network: $NetworkUUID..." -ForegroundColor Cyan
            $network = Get-XenNetwork -Uuid $NetworkUUID
            Remove-XenNetwork -Network $network
            Write-Host "✓ Network destroyed successfully" -ForegroundColor Green
        }
    }

    Write-Host "`n✓ Operation completed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Script failed: $_"
    exit 1
}
finally {
    # Disconnect
    if ($session) {
        Get-XenSession | Disconnect-XenServer
    }
}
