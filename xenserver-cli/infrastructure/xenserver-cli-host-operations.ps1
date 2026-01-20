<#
.SYNOPSIS
    Manages XenServer host operations using XenServerPSModule.

.DESCRIPTION
    Provides comprehensive host management including maintenance mode,
    power operations, evacuation, and health monitoring.

.PARAMETER Server
    The XenServer pool coordinator hostname or IP address.

.PARAMETER Username
    Username for authentication (default: root).

.PARAMETER Password
    Password for authentication.

.PARAMETER HostName
    The hostname of the XenServer host.

.PARAMETER HostUUID
    The UUID of the XenServer host.

.PARAMETER Operation
    The operation to perform: Enable, Disable, Evacuate, Reboot, Shutdown, HealthCheck.

.PARAMETER EvacuateVMs
    Evacuate VMs when disabling host (live migration to other hosts).

.PARAMETER Force
    Force operations without confirmation.

.EXAMPLE
    .\xenserver-cli-host-operations.ps1 -Server "xenserver.local" -HostName "xenhost01.local" -Operation "Disable" -EvacuateVMs

.EXAMPLE
    .\xenserver-cli-host-operations.ps1 -Server "xenserver.local" -HostUUID "12345678-abcd-1234-abcd-123456789012" -Operation "Reboot" -Force

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

    [Parameter(Mandatory = $false, ParameterSetName = "ByName")]
    [string]$HostName,

    [Parameter(Mandatory = $false, ParameterSetName = "ByUUID")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$HostUUID,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Enable", "Disable", "Evacuate", "Reboot", "Shutdown", "HealthCheck")]
    [string]$Operation,

    [Parameter(Mandatory = $false)]
    [switch]$EvacuateVMs,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Check and load XenServer module
if (-not (Get-Module -ListAvailable -Name XenServerPSModule)) {
    throw "XenServerPSModule not found. Please install the XenServer PowerShell SDK."
}
Import-Module XenServerPSModule -ErrorAction Stop

function Invoke-HostOperation {
    param([object]$Host, [string]$Op, [bool]$Evacuate, [bool]$ForceOp)

    Write-Host "Performing $Op on host $($Host.name_label)..." -ForegroundColor Cyan

    try {
        switch ($Op) {
            "Enable" {
                Set-XenHost -Host $Host -Enabled $true
            }
            "Disable" {
                Set-XenHost -Host $Host -Enabled $false
            }
            "Evacuate" {
                Invoke-XenHost -Host $Host -XenAction Evacuate
            }
            "Reboot" {
                Invoke-XenHost -Host $Host -XenAction Reboot
            }
            "Shutdown" {
                Invoke-XenHost -Host $Host -XenAction Shutdown
            }
            "HealthCheck" {
                # Display host details
                Write-Host "`nHost Information:" -ForegroundColor Cyan
                Write-Host "  Name: $($Host.name_label)"
                Write-Host "  UUID: $($Host.uuid)"
                Write-Host "  Enabled: $($Host.enabled)"
                Write-Host "  Address: $($Host.address)"
                Write-Host "  Memory Total: $([math]::Round($Host.memory_total / 1GB, 2)) GB"
                Write-Host "  Memory Free: $([math]::Round($Host.memory_free / 1GB, 2)) GB"
                Write-Host "  Software Version: $($Host.software_version['product_version'])"
                return $true
            }
        }
        Write-Host "✓ Operation completed successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed: $_"
        return $false
    }
}

# Main execution
try {
    Write-Host "XenServer Host Operations Script" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan

    # Connect to XenServer
    $url = if ($Server -match '^https?://') { $Server } else { "https://$Server" }
    $session = Connect-XenServer -Url $url -UserName $Username -Password $Password -SetDefaultSession -PassThru
    Write-Host "✓ Connected to XenServer: $Server" -ForegroundColor Green

    # Get host
    $targetHost = if ($HostUUID) {
        Get-XenHost -Uuid $HostUUID
    }
    elseif ($HostName) {
        Get-XenHost -Name $HostName
    }
    else {
        throw "Specify -HostName or -HostUUID"
    }

    if (-not $targetHost) {
        throw "Host not found"
    }

    Write-Host "`nTarget Host: $($targetHost.name_label) ($($targetHost.uuid))" -ForegroundColor Yellow

    # Evacuate VMs first if requested
    if ($EvacuateVMs -and ($Operation -in @("Disable", "Reboot", "Shutdown"))) {
        Write-Host "`nEvacuating VMs from host..." -ForegroundColor Yellow
        Invoke-HostOperation -Host $targetHost -Op "Evacuate" -Evacuate $true -ForceOp $false
    }

    # Perform main operation
    $success = Invoke-HostOperation -Host $targetHost -Op $Operation -Evacuate $EvacuateVMs.IsPresent -ForceOp $Force.IsPresent

    if ($success) {
        Write-Host "`n✓ Host operation completed successfully" -ForegroundColor Green
    }
    else {
        Write-Error "Host operation failed"
        exit 1
    }
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
