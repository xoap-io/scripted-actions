<#
.SYNOPSIS
    Apply patches and updates to XenServer hosts.

.DESCRIPTION
    Manages patch/update operations on XenServer or XCP-ng hosts using XenServerPSModule.
    Supports listing available patches with Get-XenPoolPatch, applying a specific patch
    with Invoke-XenPoolPatch -XenAction apply, and applying all available patches with
    Invoke-XenHost -XenAction apply_patches.

.PARAMETER XenServer
    The XenServer pool coordinator hostname or IP address.

.PARAMETER Credential
    PSCredential for XenServer authentication.

.PARAMETER Action
    The patch management action to perform: List or Apply.

.PARAMETER PatchUuid
    UUID of a specific patch to apply. Required for Apply when ApplyAll is not set.

.PARAMETER ApplyAll
    Apply all available patches to all hosts in the pool.

.EXAMPLE
    .\xenserver-cli-patch-management.ps1 -XenServer "xenserver.local" -Credential (Get-Credential) -Action List

.EXAMPLE
    .\xenserver-cli-patch-management.ps1 -XenServer "xenserver.local" -Credential (Get-Credential) -Action Apply -ApplyAll

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

    [Parameter(Mandatory = $false, HelpMessage = "Patch management action to perform: List or Apply.")]
    [ValidateSet('List', 'Apply')]
    [string]$Action = 'List',

    [Parameter(Mandatory = $false, HelpMessage = "UUID of a specific patch to apply.")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$PatchUuid,

    [Parameter(Mandatory = $false, HelpMessage = "Apply all available patches to all hosts in the pool.")]
    [switch]$ApplyAll
)

$ErrorActionPreference = 'Stop'

# Validate required parameters per action
if ($Action -eq 'Apply' -and -not $PatchUuid -and -not $ApplyAll) {
    throw "Either PatchUuid or -ApplyAll must be specified for Action 'Apply'."
}

# Check and load XenServer module
if (-not (Get-Module -ListAvailable -Name XenServerPSModule)) {
    throw "XenServerPSModule not found. Please install the XenServer PowerShell SDK."
}
Import-Module XenServerPSModule -ErrorAction Stop

$session = $null

try {
    Write-Host "🚀 Starting XenServer Patch Management" -ForegroundColor Green
    Write-Host "🔍 Connecting to XenServer: $XenServer" -ForegroundColor Cyan

    $url = if ($XenServer -match '^https?://') { $XenServer } else { "https://$XenServer" }
    $session = Connect-XenServer -Url $url -UserName $Credential.UserName -Password $Credential.GetNetworkCredential().Password -SetDefaultSession -PassThru
    Write-Host "✅ Connected to XenServer: $XenServer" -ForegroundColor Green

    $hosts = Get-XenHost

    switch ($Action) {
        'List' {
            Write-Host "🔍 Listing available pool patches..." -ForegroundColor Cyan
            $patches = Get-XenPoolPatch
            if ($patches) {
                Write-Host "`n📊 Summary: $($patches.Count) patch(es) found" -ForegroundColor Blue
                Write-Host ("  {0,-40} {1,-38} {2}" -f "Name", "UUID", "Applied") -ForegroundColor Cyan
                Write-Host ("  {0,-40} {1,-38} {2}" -f "----", "----", "-------") -ForegroundColor Cyan
                foreach ($p in $patches) {
                    $appliedCount = $p.host_patches.Count
                    Write-Host ("  {0,-40} {1,-38} {2} host(s)" -f $p.name_label, $p.uuid, $appliedCount)
                }
            } else {
                Write-Host "ℹ️  No patches found. Host may be up to date or patches not yet uploaded." -ForegroundColor Yellow
            }
        }
        'Apply' {
            if ($ApplyAll) {
                Write-Host "🔧 Applying all available patches to all pool hosts..." -ForegroundColor Cyan
                foreach ($h in $hosts) {
                    Write-Host "  🔧 Applying patches to host: $($h.name_label)" -ForegroundColor Cyan
                    try {
                        Invoke-XenHost -Host $h -XenAction ApplyUpdates
                        Write-Host "  ✅ Patches applied to $($h.name_label)." -ForegroundColor Green
                    } catch {
                        Write-Host "  ⚠️  Failed to apply patches to $($h.name_label): $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
                Write-Host "✅ Patch apply operation completed for all hosts." -ForegroundColor Green
            } else {
                Write-Host "🔍 Looking up patch UUID: $PatchUuid" -ForegroundColor Cyan
                $patch = Get-XenPoolPatch -Uuid $PatchUuid
                if (-not $patch) {
                    throw "Patch with UUID '$PatchUuid' not found."
                }
                Write-Host "✅ Found patch: $($patch.name_label)" -ForegroundColor Green
                Write-Host "🔧 Applying patch '$($patch.name_label)' to all pool hosts..." -ForegroundColor Cyan
                foreach ($h in $hosts) {
                    Write-Host "  🔧 Applying to host: $($h.name_label)" -ForegroundColor Cyan
                    try {
                        Invoke-XenPoolPatch -PoolPatch $patch -XenAction Apply -Host $h
                        Write-Host "  ✅ Patch applied to $($h.name_label)." -ForegroundColor Green
                    } catch {
                        Write-Host "  ⚠️  Failed on $($h.name_label): $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
                Write-Host "✅ Patch '$($patch.name_label)' applied." -ForegroundColor Green
            }
            Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
            Write-Host "  - Review host status and evacuate VMs before rebooting hosts if required." -ForegroundColor Yellow
            Write-Host "  - Use xenserver-cli-host-operations.ps1 to place hosts into maintenance mode." -ForegroundColor Yellow
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
