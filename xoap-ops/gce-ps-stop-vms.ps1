<#
.SYNOPSIS
    Stop all running Google Cloud Compute Engine instances using Google Cloud PowerShell.

.DESCRIPTION
    This script identifies and stops all running Google Cloud Compute Engine instances
    in a specified project and zone (or region / all zones). Supports filtering by
    specific instance names, a wildcard name pattern, or a label key=value pair.
    Writes a detailed log file recording every instance that was stopped.
    Includes post-operation verification to confirm no instances remain in RUNNING state.

.PARAMETER ProjectId
    Google Cloud Project ID. If not specified, the default project from gcloud
    configuration will be used.

.PARAMETER Zone
    Google Cloud zone to target (e.g., us-central1-a). If not specified, all zones
    in the project will be checked.

.PARAMETER Region
    Google Cloud region to target (e.g., us-central1). All zones in this region
    will be checked.

.PARAMETER InstanceNames
    Specific instance names to stop, separated by commas. If not specified, all
    running instances in the target scope will be stopped.

.PARAMETER NamePattern
    Wildcard pattern to match instance names. Only matching instances are stopped.

.PARAMETER LabelFilter
    Filter instances by label in the format 'key=value'. Supports wildcards in values.

.PARAMETER WhatIf
    Show what instances would be stopped without actually stopping them.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER AllZones
    Check and stop instances across all zones in the project (or region).

.EXAMPLE
    .\gce-ps-stop-vms.ps1 -ProjectId my-project -Zone us-central1-a -WhatIf
    Shows which instances would be stopped in the specified zone.

.EXAMPLE
    .\gce-ps-stop-vms.ps1 -ProjectId my-project -AllZones -Force
    Stops all running instances in the project across all zones without confirmation.

.EXAMPLE
    .\gce-ps-stop-vms.ps1 -ProjectId my-project -Region us-central1 -NamePattern "web-*" -Force
    Stops all running instances whose names start with 'web-' in us-central1.

.EXAMPLE
    .\gce-ps-stop-vms.ps1 -ProjectId my-project -AllZones -LabelFilter "environment=dev" -Force
    Stops all running instances labeled environment=dev across all zones.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: GoogleCloud PowerShell module (Install-Module -Name GoogleCloud)

.LINK
    https://cloud.google.com/powershell/docs/reference/GoogleCloudBeta/1.0.1.0/Stop-GceInstance

.COMPONENT
    Google Cloud PowerShell Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Google Cloud Project ID")]
    [ValidatePattern('^[a-z][a-z0-9-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(HelpMessage = "Google Cloud zone (e.g., us-central1-a)")]
    [ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]
    [string]$Zone,

    [Parameter(HelpMessage = "Google Cloud region (e.g., us-central1)")]
    [ValidatePattern('^[a-z]+-[a-z]+\d+$')]
    [string]$Region,

    [Parameter(HelpMessage = "Specific instance names to stop (comma-separated)")]
    [ValidateNotNullOrEmpty()]
    [string]$InstanceNames,

    [Parameter(HelpMessage = "Wildcard pattern to match instance names")]
    [ValidateNotNullOrEmpty()]
    [string]$NamePattern,

    [Parameter(HelpMessage = "Filter instances by label in format 'key=value'")]
    [ValidatePattern('^[a-z][a-z0-9_-]*=[^=]*$')]
    [string]$LabelFilter,

    [Parameter(HelpMessage = "Show what instances would be stopped without actually stopping them")]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Skip confirmation prompts")]
    [switch]$Force,

    [Parameter(HelpMessage = "Check and stop instances across all zones")]
    [switch]$AllZones
)

$ErrorActionPreference = 'Stop'

$LogFile = "gce-ps-stop-vms-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

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
    Write-Log '===== GCE PowerShell Stop Instances Script Started =====' -Color Blue
    Write-Log "Log file: $LogFile" -Color Cyan

    # Verify module
    if (-not (Get-Module -ListAvailable -Name GoogleCloud)) {
        throw "GoogleCloud module not found. Install with: Install-Module -Name GoogleCloud"
    }
    Import-Module GoogleCloud -ErrorAction Stop

    # Resolve project
    if (-not $ProjectId) {
        $gcloudProject = & gcloud config get-value project 2>$null
        if ($gcloudProject -and $gcloudProject -ne '(unset)') {
            $ProjectId = $gcloudProject
            Write-Log "Project: $ProjectId (from gcloud config)" -Color Cyan
        }
        else {
            throw "No project specified and no default project found in gcloud config."
        }
    }
    else {
        Write-Log "Project: $ProjectId" -Color Cyan
    }

    # Verify authentication
    $null = Get-GcpProject -ProjectId $ProjectId
    Write-Log "Authentication confirmed for project: $ProjectId" -Color Cyan

    # Resolve zones to check
    $zonesToCheck = @()

    if ($AllZones -or $Region) {
        Write-Log '🔍 Discovering zones...' -Color Cyan
        $allGceZones = (Get-GceZone -Project $ProjectId).Name
        if ($Region) {
            $zonesToCheck = @($allGceZones | Where-Object { $_ -like "$Region-*" })
            Write-Log "Found $($zonesToCheck.Count) zone(s) in region $Region" -Color Cyan
        }
        else {
            $zonesToCheck = @($allGceZones)
            Write-Log "Found $($zonesToCheck.Count) zone(s) in project" -Color Cyan
        }
    }
    elseif ($Zone) {
        $zonesToCheck = @($Zone)
    }
    else {
        $defaultZone = & gcloud config get-value compute/zone 2>$null
        if ($defaultZone -and $defaultZone -ne '(unset)') {
            $zonesToCheck = @($defaultZone)
            Write-Log "Zone: $defaultZone (from gcloud config)" -Color Cyan
        }
        else {
            throw "No zone specified and no default zone in gcloud config. Use -Zone, -Region, or -AllZones."
        }
    }

    Write-Log "Target zones: $($zonesToCheck -join ', ')" -Color Cyan

    # Parse filters
    $targetInstanceNames = @()
    if ($InstanceNames) {
        $targetInstanceNames = @($InstanceNames -split ',' | ForEach-Object { $_.Trim() })
        Write-Log "Instance filter: $($targetInstanceNames -join ', ')" -Color Cyan
    }

    $labelKey   = $null
    $labelValue = $null
    if ($LabelFilter) {
        $parts      = $LabelFilter -split '=', 2
        $labelKey   = $parts[0]
        $labelValue = $parts[1]
        Write-Log "Label filter: $labelKey = $labelValue" -Color Cyan
    }

    # Discover instances
    Write-Log '🔍 Discovering running instances...' -Color Cyan
    $runningInstances = @()

    foreach ($z in $zonesToCheck) {
        try {
            $zoneInstances = @(Get-GceInstance -Zone $z -Project $ProjectId |
                Where-Object { $_.Status -eq 'RUNNING' })

            foreach ($inst in $zoneInstances) {
                $inst | Add-Member -NotePropertyName ZoneName -NotePropertyValue $z -Force
                $runningInstances += $inst
            }

            Write-Log "   $z — $($zoneInstances.Count) running" -Color Gray
        }
        catch {
            Write-Log "   ⚠️ Cannot access zone $($z): $($_.Exception.Message)" -Color Yellow
        }
    }

    # Apply filters
    $filtered = $runningInstances

    if ($targetInstanceNames.Count -gt 0) {
        $filtered = @($filtered | Where-Object { $_.Name -in $targetInstanceNames })
    }

    if ($NamePattern) {
        $filtered = @($filtered | Where-Object { $_.Name -like $NamePattern })
    }

    if ($LabelFilter) {
        $filtered = @($filtered | Where-Object {
            $inst = $_
            $inst.Labels -and $inst.Labels.ContainsKey($labelKey) -and
                ($inst.Labels[$labelKey] -like $labelValue)
        })
    }

    if ($filtered.Count -eq 0) {
        Write-Log 'ℹ️ No running instances found matching the specified criteria.' -Color Yellow
        exit 0
    }

    Write-Log "Found $($filtered.Count) running instance(s) to stop:" -Color Cyan
    foreach ($inst in $filtered) {
        $machineType = $inst.MachineType.Split('/')[-1]
        Write-Log "   • $($inst.Name) | $machineType | $($inst.ZoneName)" -Color White
    }

    if ($WhatIf) {
        Write-Log '🔍 WhatIf mode — no changes will be made.' -Color Cyan
        Write-Log "Would stop $($filtered.Count) instance(s)." -Color Yellow
        exit 0
    }

    if (-not $Force) {
        Write-Log '' -Color White
        Write-Log "⚠️  About to stop $($filtered.Count) instance(s) in project '$ProjectId'" -Color Yellow
        $confirmation = Read-Host "Type 'YES' to confirm"
        if ($confirmation -ne 'YES') {
            Write-Log 'Operation cancelled by user.' -Color Yellow
            exit 0
        }
    }

    # Stop instances
    Write-Log '🛑 Stopping instances...' -Color Cyan
    $succeeded = 0
    $failed    = 0

    foreach ($inst in $filtered) {
        try {
            Stop-GceInstance -Project $ProjectId -Zone $inst.ZoneName -Name $inst.Name | Out-Null
            Write-Log "   ✅ Stopped: $($inst.Name) (zone: $($inst.ZoneName))" -Color Green
            $succeeded++
        }
        catch {
            Write-Log "   ❌ Failed to stop $($inst.Name): $($_.Exception.Message)" -Color Red
            $failed++
        }
    }

    # Post-operation verification
    Write-Log '' -Color White
    Write-Log '🔎 Verifying no running instances remain...' -Color Cyan
    $stillRunning = @()

    foreach ($z in $zonesToCheck) {
        try {
            $remaining = @(Get-GceInstance -Zone $z -Project $ProjectId |
                Where-Object { $_.Status -eq 'RUNNING' })

            if ($LabelFilter) {
                $remaining = @($remaining | Where-Object {
                    $inst = $_
                    $inst.Labels -and $inst.Labels.ContainsKey($labelKey) -and
                        ($inst.Labels[$labelKey] -like $labelValue)
                })
            }
            if ($NamePattern) {
                $remaining = @($remaining | Where-Object { $_.Name -like $NamePattern })
            }
            if ($targetInstanceNames.Count -gt 0) {
                $remaining = @($remaining | Where-Object { $_.Name -in $targetInstanceNames })
            }

            $stillRunning += $remaining
        }
        catch {
            Write-Log "   ⚠️ Cannot verify zone $($z): $($_.Exception.Message)" -Color Yellow
        }
    }

    if ($stillRunning.Count -gt 0) {
        Write-Log "   ⚠️  $($stillRunning.Count) instance(s) still RUNNING after stop operation:" -Color Yellow
        foreach ($inst in $stillRunning) {
            Write-Log "      • $($inst.Name) | $($inst.ZoneName)" -Color Yellow
        }
    }
    else {
        Write-Log '   ✅ Verified: no targeted instances remain in RUNNING state.' -Color Green
    }

    Write-Log '' -Color White
    Write-Log '===== Operation Complete =====' -Color White
    Write-Log "Project:          $ProjectId" -Color White
    Write-Log "Zones checked:    $($zonesToCheck.Count)" -Color White
    Write-Log "Instances found:  $($filtered.Count)" -Color White
    Write-Log "Successfully stopped: $succeeded" -Color White
    Write-Log "Failed:           $failed" -Color White
    Write-Log "Log file: $LogFile" -Color Gray
    Write-Log '=============================' -Color White
}
catch {
    Write-Log "❌ Script failed: $($_.Exception.Message)" -Color Red
    exit 1
}
finally {
    Write-Log '' -Color White
    Write-Log '🏁 Script execution completed' -Color Green
}
