<#
.SYNOPSIS
    Perform bulk power or snapshot operations on multiple vSphere VMs using PowerCLI.

.DESCRIPTION
    This script applies power operations (Start, Stop, Suspend, Restart) or snapshot
    operations (Snapshot, RemoveSnapshot) to multiple virtual machines that match a
    wildcard name pattern or a specific tag. At least one of VmNamePattern or TagName
    must be provided. The -WhatIf switch previews the operation without executing it.
    The -Force switch skips confirmation prompts for destructive operations.

.PARAMETER Server
    The vCenter Server FQDN or IP address.

.PARAMETER Credential
    PSCredential object for authenticating to vCenter.

.PARAMETER VmNamePattern
    A wildcard pattern to match VM names (e.g., "Web*" or "Prod-App-?").
    At least one of VmNamePattern or TagName must be specified.

.PARAMETER TagName
    A tag name to filter VMs. Only VMs that have this tag will be included.
    At least one of VmNamePattern or TagName must be specified.

.PARAMETER Action
    The bulk operation to perform. Valid values: Start, Stop, Suspend, Restart, Snapshot, RemoveSnapshot.
    Default: Stop

.PARAMETER SnapshotName
    The name to use when creating or removing snapshots. Required for Snapshot and RemoveSnapshot actions.

.PARAMETER Force
    Skip confirmation prompts for Stop, Suspend, and Restart operations.

.PARAMETER WhatIf
    Preview the operation without actually performing it.

.EXAMPLE
    $cred = Get-Credential
    .\vsphere-cli-bulk-vm-operations.ps1 -Server "vcenter.domain.com" -Credential $cred -VmNamePattern "Dev-*" -Action Stop -Force

    Stop all VMs whose names start with Dev- without confirmation.

.EXAMPLE
    $cred = Get-Credential
    .\vsphere-cli-bulk-vm-operations.ps1 -Server "vcenter.domain.com" -Credential $cred -TagName "PrePatch" -Action Snapshot -SnapshotName "PrePatch-20260408"

    Create a snapshot named PrePatch-20260408 on all VMs tagged with PrePatch.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: VMware.PowerCLI (Install-Module -Name VMware.PowerCLI)

.LINK
    https://developer.vmware.com/docs/powercli/

.COMPONENT
    VMware vSphere PowerCLI
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The vCenter Server FQDN or IP address.")]
    [ValidateNotNullOrEmpty()]
    [string]$Server,

    [Parameter(Mandatory = $true, HelpMessage = "PSCredential object for authenticating to vCenter.")]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false, HelpMessage = "A wildcard pattern to match VM names (e.g., 'Web*').")]
    [string]$VmNamePattern,

    [Parameter(Mandatory = $false, HelpMessage = "A tag name to filter VMs. VMs with this tag will be included.")]
    [string]$TagName,

    [Parameter(Mandatory = $false, HelpMessage = "The bulk operation to perform. Valid values: Start, Stop, Suspend, Restart, Snapshot, RemoveSnapshot.")]
    [ValidateSet('Start', 'Stop', 'Suspend', 'Restart', 'Snapshot', 'RemoveSnapshot')]
    [string]$Action = 'Stop',

    [Parameter(Mandatory = $false, HelpMessage = "The snapshot name for Snapshot or RemoveSnapshot actions.")]
    [string]$SnapshotName,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts for destructive operations.")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Preview the operation without actually performing it.")]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting vSphere bulk VM operation: $Action" -ForegroundColor Green

    # Validate at least one selector provided
    if (-not $VmNamePattern -and -not $TagName) {
        throw "At least one of VmNamePattern or TagName must be specified."
    }

    # Validate snapshot name for snapshot actions
    if ($Action -in 'Snapshot', 'RemoveSnapshot' -and -not $SnapshotName) {
        throw "SnapshotName is required when Action is '$Action'."
    }

    # Import PowerCLI
    Write-Host "🔍 Loading VMware.PowerCLI module..." -ForegroundColor Cyan
    if (-not (Get-Module -Name VMware.PowerCLI -ListAvailable)) {
        throw "VMware.PowerCLI module is not installed. Install it with: Install-Module -Name VMware.PowerCLI"
    }
    Import-Module VMware.PowerCLI -ErrorAction Stop
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope User | Out-Null
    Set-PowerCLIConfiguration -ParticipateInCEIP $false -Confirm:$false -Scope User | Out-Null

    # Connect
    Write-Host "🔍 Connecting to vCenter Server '$Server'..." -ForegroundColor Cyan
    $connection = Connect-VIServer -Server $Server -Credential $Credential -Force
    Write-Host "✅ Connected to: $($connection.Name)" -ForegroundColor Green

    # Collect target VMs
    $targetVMs = @()

    if ($VmNamePattern) {
        Write-Host "🔍 Collecting VMs matching pattern '$VmNamePattern'..." -ForegroundColor Cyan
        $targetVMs += Get-VM -Name $VmNamePattern -ErrorAction SilentlyContinue
    }

    if ($TagName) {
        Write-Host "🔍 Collecting VMs with tag '$TagName'..." -ForegroundColor Cyan
        $tag = Get-Tag -Name $TagName -ErrorAction SilentlyContinue
        if ($tag) {
            $taggedVMs = Get-TagAssignment -Tag $tag | ForEach-Object { $_.Entity } | Where-Object { $_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl] }
            $targetVMs += $taggedVMs
        }
        else {
            Write-Host "⚠️  Tag '$TagName' not found." -ForegroundColor Yellow
        }
    }

    # Remove duplicates
    $targetVMs = $targetVMs | Sort-Object -Property Id -Unique

    if ($targetVMs.Count -eq 0) {
        Write-Host "⚠️  No VMs found matching the specified criteria. No action taken." -ForegroundColor Yellow
        return
    }

    Write-Host "ℹ️  Found $($targetVMs.Count) VM(s) to process:" -ForegroundColor Yellow
    $targetVMs | ForEach-Object { Write-Host "   - $($_.Name) ($($_.PowerState))" -ForegroundColor White }

    if ($WhatIf) {
        Write-Host "`n⚠️  WhatIf: Would perform '$Action' on the $($targetVMs.Count) VM(s) listed above." -ForegroundColor Yellow
        return
    }

    # Confirmation for destructive actions
    if (-not $Force -and $Action -in 'Stop', 'Suspend', 'Restart', 'RemoveSnapshot') {
        $confirm = Read-Host "`nProceed with '$Action' on $($targetVMs.Count) VM(s)? (y/N)"
        if ($confirm -notmatch '^[Yy]$') {
            Write-Host "⚠️  Operation cancelled by user." -ForegroundColor Yellow
            return
        }
    }

    # Execute operation
    $successCount = 0
    $failCount = 0

    foreach ($vm in $targetVMs) {
        try {
            Write-Host "🔧 [$($vm.Name)] Performing '$Action'..." -ForegroundColor Cyan
            switch ($Action) {
                'Start'           { Start-VM -VM $vm -Confirm:$false | Out-Null }
                'Stop'            { Stop-VM -VM $vm -Confirm:$false | Out-Null }
                'Suspend'         { Suspend-VM -VM $vm -Confirm:$false | Out-Null }
                'Restart'         { Restart-VM -VM $vm -Confirm:$false | Out-Null }
                'Snapshot'        { New-Snapshot -VM $vm -Name $SnapshotName -Confirm:$false | Out-Null }
                'RemoveSnapshot'  {
                    $snap = Get-Snapshot -VM $vm -Name $SnapshotName -ErrorAction SilentlyContinue
                    if ($snap) { Remove-Snapshot -Snapshot $snap -Confirm:$false }
                    else { Write-Host "⚠️  [$($vm.Name)] Snapshot '$SnapshotName' not found." -ForegroundColor Yellow }
                }
            }
            Write-Host "✅ [$($vm.Name)] $Action completed." -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host "❌ [$($vm.Name)] Failed: $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  Total VMs : $($targetVMs.Count)" -ForegroundColor White
    Write-Host "  Succeeded : $successCount" -ForegroundColor Green
    Write-Host "  Failed    : $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'White' })
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($global:DefaultVIServers) {
        Disconnect-VIServer -Server * -Confirm:$false -Force -ErrorAction SilentlyContinue
    }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
