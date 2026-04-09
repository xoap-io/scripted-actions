<#
.SYNOPSIS
    Bulk stop all running Google Cloud Compute Engine VMs in a project using gcloud CLI.

.DESCRIPTION
    This script discovers all RUNNING Compute Engine instances in a GCP project using
    `gcloud compute instances list --filter="status=RUNNING" --format json`, then stops
    them using `gcloud compute instances stop`. It supports per-zone filtering, WhatIf
    mode, and requires explicit 'YES' confirmation unless -Force is specified.

    After stopping, the script re-queries the API to verify no RUNNING instances remain
    and writes a timestamped log file (gce-cli-stop-vms-YYYYMMDD-HHmmss.log).

.PARAMETER ProjectId
    Optional GCP project ID. If omitted, the active project from `gcloud config` is used.

.PARAMETER Zone
    Optional zone filter (e.g. us-central1-a). If omitted, all zones are searched.

.PARAMETER WhatIf
    Show which instances would be stopped without making any changes.

.PARAMETER Force
    Skip the 'YES' confirmation prompt and stop instances immediately.

.EXAMPLE
    .\gce-cli-stop-vms.ps1 -ProjectId my-gcp-project -WhatIf
    Shows all running GCE instances that would be stopped without making changes.

.EXAMPLE
    .\gce-cli-stop-vms.ps1 -ProjectId my-gcp-project -Force
    Stops all running GCE instances in the project without a confirmation prompt.

.EXAMPLE
    .\gce-cli-stop-vms.ps1 -ProjectId my-gcp-project -Zone us-central1-a
    Stops all running GCE instances in the specified zone, with confirmation.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: gcloud CLI

.LINK
    https://cloud.google.com/sdk/gcloud/reference/compute/instances/stop

.COMPONENT
    Google Cloud CLI
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Optional GCP project ID. If omitted, uses the active project from gcloud config.")]
    [string]$ProjectId,

    [Parameter(HelpMessage = "Optional zone filter (e.g. us-central1-a). If omitted, all zones are searched.")]
    [string]$Zone,

    [Parameter(HelpMessage = "Show which instances would be stopped without making any changes.")]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Skip the 'YES' confirmation prompt and stop instances immediately.")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$LogFile = "gce-cli-stop-vms-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $LogFile -Value "[$timestamp] $Message"
    Write-Host $Message -ForegroundColor $Color
}

try {
    Write-Log '===== GCE CLI Bulk VM Stop Script Started =====' -Color Blue
    Write-Log "Log file: $LogFile" -Color Cyan

    # Verify gcloud is available
    $null = Get-Command gcloud -ErrorAction Stop

    # Resolve project
    if (-not $ProjectId) {
        $ProjectId = (gcloud config get-value project 2>$null).Trim()
        if (-not $ProjectId) {
            throw "No project specified and no active project found in gcloud config. Use -ProjectId to specify a project."
        }
    }
    Write-Log "Project: $ProjectId" -Color Cyan

    # Build gcloud list arguments
    $listArgs = @(
        'compute', 'instances', 'list',
        '--project', $ProjectId,
        '--filter', 'status=RUNNING',
        '--format', 'json'
    )
    if ($Zone) {
        $listArgs += @('--zones', $Zone)
        Write-Log "Zone filter: $Zone" -Color Cyan
    }

    # Discover running instances
    Write-Log '🔍 Discovering running GCE instances...' -Color Cyan
    $jsonOutput = & gcloud @listArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "gcloud instances list failed: $jsonOutput"
    }

    $instances = $jsonOutput | ConvertFrom-Json
    if (-not $instances -or $instances.Count -eq 0) {
        Write-Log 'ℹ️  No RUNNING GCE instances found.' -Color Yellow
        exit 0
    }

    Write-Log "Found $($instances.Count) RUNNING instance(s):" -Color Cyan
    foreach ($inst in $instances) {
        $zone = $inst.zone -replace '.*/zones/', ''
        Write-Log "   • $($inst.name) | Zone: $zone | MachineType: $($inst.machineType -replace '.*/machineTypes/', '')" -Color White
    }

    if ($WhatIf) {
        Write-Log '🔍 WhatIf mode — no instances will be stopped.' -Color Cyan
        exit 0
    }

    # Confirmation prompt
    if (-not $Force) {
        Write-Log '' -Color White
        Write-Log "⚠️  About to stop $($instances.Count) RUNNING instance(s) in project '$ProjectId'." -Color Yellow
        $confirmation = Read-Host "Type 'YES' to confirm"
        if ($confirmation -ne 'YES') {
            Write-Log 'Operation cancelled by user.' -Color Yellow
            exit 0
        }
    }

    # Stop each instance
    Write-Log '🛑 Stopping instances...' -Color Cyan
    foreach ($inst in $instances) {
        $instZone = $inst.zone -replace '.*/zones/', ''
        Write-Log "   Stopping: $($inst.name) in zone $instZone..." -Color Cyan
        try {
            $stopArgs = @(
                'compute', 'instances', 'stop',
                $inst.name,
                '--project', $ProjectId,
                '--zone', $instZone,
                '--quiet'
            )
            & gcloud @stopArgs 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "   ✅ Stop initiated: $($inst.name)" -Color Green
            }
            else {
                Write-Log "   ⚠️  Stop command returned non-zero for: $($inst.name)" -Color Yellow
            }
        }
        catch {
            Write-Log "   ❌ Failed to stop $($inst.name): $($_.Exception.Message)" -Color Red
        }
    }

    # Post-verification: wait for instances to reach TERMINATED/STOPPED state
    Write-Log '' -Color White
    Write-Log '🔎 Verifying instances have stopped...' -Color Cyan
    $maxWait = 300
    $waited  = 0
    $interval = 15

    do {
        Start-Sleep -Seconds $interval
        $waited += $interval

        $verifyArgs = @(
            'compute', 'instances', 'list',
            '--project', $ProjectId,
            '--filter', 'status=RUNNING',
            '--format', 'json'
        )
        if ($Zone) {
            $verifyArgs += @('--zones', $Zone)
        }

        $stillRunning = & gcloud @verifyArgs 2>&1 | ConvertFrom-Json
        $runningCount = if ($stillRunning) { @($stillRunning).Count } else { 0 }
        Write-Log "   Waiting... $runningCount instance(s) still RUNNING ($waited/$maxWait s)" -Color Gray
    } while ($runningCount -gt 0 -and $waited -lt $maxWait)

    if ($runningCount -gt 0) {
        Write-Log "   ⚠️  $runningCount instance(s) are still RUNNING after $maxWait seconds." -Color Yellow
        foreach ($r in @($stillRunning)) {
            $rZone = $r.zone -replace '.*/zones/', ''
            Write-Log "      • $($r.name) | Zone: $rZone" -Color Yellow
        }
    }
    else {
        Write-Log '   ✅ Verified: no RUNNING instances remain.' -Color Green
    }

    Write-Log '' -Color White
    Write-Log '===== Operation Complete =====' -Color White
    Write-Log "Project:  $ProjectId" -Color White
    Write-Log "Log file: $LogFile" -Color Gray
    Write-Log '==============================' -Color White
}
catch {
    Write-Log "❌ Script failed: $($_.Exception.Message)" -Color Red
    exit 1
}
finally {
    Write-Log '' -Color White
    Write-Log '🏁 Script execution completed' -Color Green
}
