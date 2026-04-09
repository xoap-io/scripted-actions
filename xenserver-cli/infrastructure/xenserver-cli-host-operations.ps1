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
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: XenServerPSModule (Citrix XenServer SDK)

.LINK
    https://docs.xenserver.com/en-us/xenserver/current-release/hosts-and-resource-pools.html

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

    [Parameter(Mandatory = $false, ParameterSetName = "ByName", HelpMessage = "The hostname of the XenServer host.")]
    [string]$HostName,

    [Parameter(Mandatory = $false, ParameterSetName = "ByUUID", HelpMessage = "The UUID of the XenServer host.")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$HostUUID,

    [Parameter(Mandatory = $true, HelpMessage = "The operation to perform: Enable, Disable, Evacuate, Reboot, Shutdown, HealthCheck.")]
    [ValidateSet("Enable", "Disable", "Evacuate", "Reboot", "Shutdown", "HealthCheck")]
    [string]$Operation,

    [Parameter(Mandatory = $false, HelpMessage = "Evacuate VMs when disabling host (live migration to other hosts).")]
    [switch]$EvacuateVMs,

    [Parameter(Mandatory = $false, HelpMessage = "Force operations without confirmation.")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Check and load XenServer module
if (-not (Get-Module -ListAvailable -Name XenServerPSModule)) {
    throw "XenServerPSModule not found. Please install the XenServer PowerShell SDK."
}
Import-Module XenServerPSModule -ErrorAction Stop

function Invoke-HostOperation {
    param([object]$hostObj, [string]$Op, [bool]$Evacuate, [bool]$ForceOp)

    Write-Host "Performing $Op on host $($hostObj.name_label)..." -ForegroundColor Cyan

    try {
        switch ($Op) {
            "Enable" {
                Set-XenHost -Host $hostObj -Enabled $true
            }
            "Disable" {
                Set-XenHost -Host $hostObj -Enabled $false
            }
            "Evacuate" {
                Invoke-XenHost -Host $hostObj -XenAction Evacuate
            }
            "Reboot" {
                Invoke-XenHost -Host $hostObj -XenAction Reboot
            }
            "Shutdown" {
                Invoke-XenHost -Host $hostObj -XenAction Shutdown
            }
            "HealthCheck" {
                # Display host details
                Write-Host "`nHost Information:" -ForegroundColor Cyan
                Write-Host "  Name: $($hostObj.name_label)"
                Write-Host "  UUID: $($hostObj.uuid)"
                Write-Host "  Enabled: $($hostObj.enabled)"
                Write-Host "  Address: $($hostObj.address)"
                Write-Host "  Memory Total: $([math]::Round($hostObj.memory_total / 1GB, 2)) GB"
                Write-Host "  Memory Free: $([math]::Round($hostObj.memory_free / 1GB, 2)) GB"
                Write-Host "  Software Version: $($hostObj.software_version['product_version'])"
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
