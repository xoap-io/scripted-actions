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
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: XenServerPSModule (Citrix XenServer SDK)

.LINK
    https://docs.xenserver.com/en-us/xenserver/current-release/networking.html

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

    [Parameter(Mandatory = $true, HelpMessage = "Network operation: CreateNetwork, CreateVLAN, CreateBond, List, Destroy.")]
    [ValidateSet("CreateNetwork", "CreateVLAN", "CreateBond", "List", "Destroy")]
    [string]$Operation,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the network.")]
    [string]$NetworkName,

    [Parameter(Mandatory = $false, HelpMessage = "The UUID of the network.")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$NetworkUUID,

    [Parameter(Mandatory = $false, HelpMessage = "VLAN tag number (1-4094).")]
    [ValidateRange(1, 4094)]
    [int]$VLANTag,

    [Parameter(Mandatory = $false, HelpMessage = "Physical interface UUID for VLAN creation.")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$PIFUUID,

    [Parameter(Mandatory = $false, HelpMessage = "Array of PIF UUIDs for bond creation.")]
    [string[]]$PIFUUIDs,

    [Parameter(Mandatory = $false, HelpMessage = "Bond mode: active-backup, lacp, balance-slb.")]
    [ValidateSet("active-backup", "lacp", "balance-slb")]
    [string]$BondMode = "active-backup",

    [Parameter(Mandatory = $false, HelpMessage = "Optional description for the network.")]
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
            $null = New-XenVLAN -Network $network -PIF $pif -Tag $VLANTag
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
            $null = New-XenBond -Network $network -PIFs $pifs -Mode $BondMode
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
