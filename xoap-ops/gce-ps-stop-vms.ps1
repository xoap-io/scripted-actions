<#
.SYNOPSIS
    Stop all running Google Cloud Compute Engine instances using Google Cloud PowerShell.

.DESCRIPTION
    This script identifies and stops all running Google Cloud Compute Engine instances in a specified project and zone.
    Provides detailed output for each stopped instance including machine type, zone, labels, and cost information.
    Supports dry-run mode for validation and selective stopping by instance name or label patterns.

.PARAMETER ProjectId
    Google Cloud Project ID. If not specified, the default project from gcloud configuration will be used.

.PARAMETER Zone
    Google Cloud zone to target (e.g., 'us-central1-a'). If not specified, all zones in the project will be checked.

.PARAMETER Region
    Google Cloud region to target (e.g., 'us-central1'). If specified, all zones in this region will be checked.

.PARAMETER InstanceNames
    Specific instance names to stop (comma-separated). If not specified, all running instances will be targeted.

.PARAMETER NamePattern
    Pattern to match instance names (supports wildcards). Only instances matching this pattern will be stopped.

.PARAMETER LabelFilter
    Filter instances by label in format 'key=value'. Supports wildcards in values.

.PARAMETER WhatIf
    Show what instances would be stopped without actually stopping them (dry-run mode).

.PARAMETER Force
    Skip confirmation prompts and stop instances immediately.

.PARAMETER AllZones
    Check and stop instances across all zones in the project or region.

.PARAMETER IncludeTerminated
    Also show terminated instances in the output for comparison.

.EXAMPLE
    .\gcp-ps-stop-running-instances.ps1
    
    Stops all running instances in the default project and zone with confirmation prompts.

.EXAMPLE
    .\gcp-ps-stop-running-instances.ps1 -ProjectId "my-project" -Zone "us-central1-a" -WhatIf
    
    Shows what instances would be stopped in the specified project and zone.

.EXAMPLE
    .\gcp-ps-stop-running-instances.ps1 -NamePattern "web-*" -Force -AllZones
    
    Stops all running instances with names starting with 'web-' across all zones without confirmation.

.EXAMPLE
    .\gcp-ps-stop-running-instances.ps1 -LabelFilter "environment=dev" -Region "us-central1"
    
    Stops all running instances labeled with environment=dev in the us-central1 region.

.EXAMPLE
    .\gcp-ps-stop-running-instances.ps1 -InstanceNames "instance-1,instance-2" -Zone "us-west1-a"
    
    Stops specific instances by their names in the specified zone.

.NOTES
    Author: Google Cloud PowerShell Script
    Version: 1.0.0
    Requires: Google Cloud PowerShell module (Install-Module -Name GoogleCloud)
    Requires: Google Cloud authentication (gcloud auth login or service account)

.LINK
    https://cloud.google.com/powershell/docs/reference/GoogleCloudBeta/1.0.1.0/Stop-GceInstance
    
.COMPONENT
    Google Cloud PowerShell Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Google Cloud Project ID")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z][a-z0-9-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(HelpMessage = "Google Cloud zone (e.g., 'us-central1-a')")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]
    [string]$Zone,

    [Parameter(HelpMessage = "Google Cloud region (e.g., 'us-central1')")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z]+-[a-z]+\d+$')]
    [string]$Region,

    [Parameter(HelpMessage = "Specific instance names to stop (comma-separated)")]
    [ValidateNotNullOrEmpty()]
    [string]$InstanceNames,

    [Parameter(HelpMessage = "Pattern to match instance names (supports wildcards)")]
    [ValidateNotNullOrEmpty()]
    [string]$NamePattern = "*",

    [Parameter(HelpMessage = "Filter instances by label in format 'key=value'")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z][a-z0-9_-]*=[^=]*$')]
    [string]$LabelFilter,

    [Parameter(HelpMessage = "Show what instances would be stopped without actually stopping them")]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Skip confirmation prompts and stop instances immediately")]
    [switch]$Force,

    [Parameter(HelpMessage = "Check and stop instances across all zones")]
    [switch]$AllZones,

    [Parameter(HelpMessage = "Also show terminated instances in the output for comparison")]
    [switch]$IncludeTerminated
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

try {
    Write-Host "🔍 Checking Google Cloud PowerShell module..." -ForegroundColor Cyan
    
    # Check if GoogleCloud module is available
    if (-not (Get-Module -ListAvailable -Name GoogleCloud)) {
        throw "Google Cloud PowerShell module is not installed. Please run: Install-Module -Name GoogleCloud"
    }

    # Import the module
    Import-Module GoogleCloud -Force

    Write-Host "✅ Google Cloud PowerShell module available" -ForegroundColor Green

    # Check authentication and get default project
    try {
        if (-not $ProjectId) {
            # Try to get default project from gcloud config
            $gcloudProject = & gcloud config get-value project 2>$null
            if ($gcloudProject -and $gcloudProject -ne "(unset)") {
                $ProjectId = $gcloudProject
                Write-Host "Using default project from gcloud config: $ProjectId" -ForegroundColor Yellow
            } else {
                throw "No project specified and no default project found in gcloud config"
            }
        }
        
        # Test authentication by listing projects
        $null = Get-GcpProject -ProjectId $ProjectId
        Write-Host "✅ Authentication successful for project: $ProjectId" -ForegroundColor Green
    } catch {
        throw "Google Cloud authentication failed or project not accessible. Please run 'gcloud auth login' or configure service account authentication"
    }

    # Determine zones to check
    $zonesToCheck = @()
    
    if ($AllZones) {
        Write-Host "🌍 Getting all zones in project..." -ForegroundColor Cyan
        if ($Region) {
            $zonesToCheck = (Get-GceZone | Where-Object { $_.Name -like "$Region-*" }).Name
            Write-Host "   Found $($zonesToCheck.Count) zones in region $Region" -ForegroundColor Gray
        } else {
            $zonesToCheck = (Get-GceZone).Name
            Write-Host "   Found $($zonesToCheck.Count) zones in project" -ForegroundColor Gray
        }
    } elseif ($Region) {
        $zonesToCheck = (Get-GceZone | Where-Object { $_.Name -like "$Region-*" }).Name
        Write-Host "📍 Checking all zones in region: $Region" -ForegroundColor Yellow
    } elseif ($Zone) {
        $zonesToCheck = @($Zone)
    } else {
        # Get default zone from gcloud config
        $defaultZone = & gcloud config get-value compute/zone 2>$null
        if ($defaultZone -and $defaultZone -ne "(unset)") {
            $zonesToCheck = @($defaultZone)
            Write-Host "Using default zone from gcloud config: $defaultZone" -ForegroundColor Yellow
        } else {
            throw "No zone specified and no default zone found in gcloud config. Please specify -Zone, -Region, or -AllZones"
        }
    }

    Write-Host "📍 Target zones: $($zonesToCheck -join ', ')" -ForegroundColor Yellow

    # Parse instance names if provided
    $targetInstanceNames = @()
    if ($InstanceNames) {
        $targetInstanceNames = $InstanceNames -split ',' | ForEach-Object { $_.Trim() }
        Write-Host "🎯 Targeting specific instances: $($targetInstanceNames -join ', ')" -ForegroundColor Yellow
    }

    # Parse label filter if provided
    $labelKey = $null
    $labelValue = $null
    if ($LabelFilter) {
        $labelParts = $LabelFilter -split '=', 2
        $labelKey = $labelParts[0]
        $labelValue = $labelParts[1]
        Write-Host "🏷️ Label filter: $labelKey = $labelValue" -ForegroundColor Yellow
    }

    # Collect all instances across zones
    $allInstances = @()
    $runningInstances = @()

    foreach ($currentZone in $zonesToCheck) {
        Write-Host "🔍 Discovering instances in zone: $currentZone" -ForegroundColor Cyan
        
        try {
            $zoneInstances = Get-GceInstance -Zone $currentZone -Project $ProjectId
            
            foreach ($instance in $zoneInstances) {
                # Add zone info to instance object
                $instance | Add-Member -NotePropertyName ZoneName -NotePropertyValue $currentZone -Force
                
                $allInstances += $instance
                
                # Filter running instances
                if ($instance.Status -eq "RUNNING") {
                    $runningInstances += $instance
                }
            }
            
            Write-Host "   Found $($zoneInstances.Count) instances" -ForegroundColor Gray
        } catch {
            Write-Host "   ⚠️ Unable to access zone $currentZone : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    if ($allInstances.Count -eq 0) {
        Write-Host "ℹ️ No instances found in the specified zones" -ForegroundColor Yellow
        return
    }

    # Apply filters
    $filteredRunningInstances = $runningInstances

    # Filter by specific instance names
    if ($targetInstanceNames.Count -gt 0) {
        $filteredRunningInstances = $filteredRunningInstances | Where-Object { $_.Name -in $targetInstanceNames }
    }

    # Filter by name pattern
    if ($NamePattern -ne "*") {
        $filteredRunningInstances = $filteredRunningInstances | Where-Object { $_.Name -like $NamePattern }
    }

    # Filter by label
    if ($LabelFilter) {
        $filteredRunningInstances = $filteredRunningInstances | Where-Object {
            $instance = $_
            if ($instance.Labels -and $instance.Labels.ContainsKey($labelKey)) {
                return $instance.Labels[$labelKey] -like $labelValue
            }
            return $false
        }
    }

    # Categorize instances by status
    $stoppedInstances = $allInstances | Where-Object { $_.Status -eq "TERMINATED" }
    $otherStatusInstances = $allInstances | Where-Object { $_.Status -notin @("RUNNING", "TERMINATED") }

    Write-Host "`n📊 Instance Status Summary:" -ForegroundColor White
    Write-Host "   🟢 Running Instances: $($filteredRunningInstances.Count) (of $($runningInstances.Count) total)" -ForegroundColor Green
    Write-Host "   🔴 Terminated Instances: $($stoppedInstances.Count)" -ForegroundColor Red
    Write-Host "   🟡 Other Status: $($otherStatusInstances.Count)" -ForegroundColor Yellow
    Write-Host "   📦 Total Instances: $($allInstances.Count)" -ForegroundColor Cyan

    # Show terminated instances if requested
    if ($IncludeTerminated -and $stoppedInstances.Count -gt 0) {
        Write-Host "`n🔴 Terminated Instances (for reference):" -ForegroundColor Red
        $stoppedInstances | ForEach-Object {
            Write-Host "   • $($_.Name) [$($_.MachineType.Split('/')[-1])] in $($_.ZoneName)" -ForegroundColor Gray
        }
    }

    # Show other status instances
    if ($otherStatusInstances.Count -gt 0) {
        Write-Host "`n🟡 Instances in other status:" -ForegroundColor Yellow
        $otherStatusInstances | ForEach-Object {
            Write-Host "   • $($_.Name) [$($_.Status)] in $($_.ZoneName)" -ForegroundColor Gray
        }
    }

    if ($filteredRunningInstances.Count -eq 0) {
        Write-Host "`nℹ️ No running instances found matching the specified criteria" -ForegroundColor Yellow
        return
    }

    # Display running instances that will be stopped
    Write-Host "`n🟢 Running instances that will be stopped:" -ForegroundColor Green
    $filteredRunningInstances | ForEach-Object {
        Write-Host "   • $($_.Name)" -ForegroundColor White
        Write-Host "     └─ Machine Type: $($_.MachineType.Split('/')[-1])" -ForegroundColor Gray
        Write-Host "     └─ Zone: $($_.ZoneName)" -ForegroundColor Gray
        Write-Host "     └─ Created: $($_.CreationTimestamp)" -ForegroundColor Gray
        Write-Host "     └─ Status: $($_.Status)" -ForegroundColor Gray
        if ($_.Labels -and $_.Labels.Count -gt 0) {
            $labelString = ($_.Labels.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "
            Write-Host "     └─ Labels: $labelString" -ForegroundColor Gray
        }
    }

    # WhatIf mode - exit without stopping
    if ($WhatIf) {
        Write-Host "`n🔍 WhatIf mode: No instances will be stopped" -ForegroundColor Cyan
        Write-Host "   $($filteredRunningInstances.Count) instances would be stopped" -ForegroundColor Yellow
        return
    }

    # Confirmation prompt (unless Force is specified)
    if (-not $Force) {
        Write-Host "`n⚠️ Warning: This will stop $($filteredRunningInstances.Count) running instance(s)" -ForegroundColor Yellow
        $confirmation = Read-Host "Continue? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "❌ Operation cancelled by user" -ForegroundColor Red
            return
        }
    }

    # Stop instances by zone
    Write-Host "`n🛑 Stopping instances..." -ForegroundColor Cyan
    $stopResults = @()

    $instancesByZone = $filteredRunningInstances | Group-Object -Property ZoneName

    foreach ($zoneGroup in $instancesByZone) {
        $currentZone = $zoneGroup.Name
        $zoneInstances = $zoneGroup.Group
        
        Write-Host "   Stopping $($zoneInstances.Count) instances in zone: $currentZone" -ForegroundColor Yellow
        
        foreach ($instance in $zoneInstances) {
            try {
                Write-Host "     Stopping: $($instance.Name)" -ForegroundColor Gray
                $stopResult = Stop-GceInstance -Project $ProjectId -Zone $currentZone -Name $instance.Name
                
                $stopResults += @{
                    InstanceName = $instance.Name
                    MachineType = $instance.MachineType.Split('/')[-1]
                    Zone = $currentZone
                    Success = $true
                    Status = "Stopping"
                    Error = $null
                }
                
                Write-Host "     ✅ Successfully initiated stop for: $($instance.Name)" -ForegroundColor Green
            } catch {
                $stopResults += @{
                    InstanceName = $instance.Name
                    MachineType = $instance.MachineType.Split('/')[-1]
                    Zone = $currentZone
                    Success = $false
                    Status = "Failed"
                    Error = $_.Exception.Message
                }
                
                Write-Host "     ❌ Failed to stop: $($instance.Name) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    # Display detailed results
    Write-Host "`n📋 Detailed Stop Results:" -ForegroundColor White
    $successfulStops = $stopResults | Where-Object { $_.Success }
    $failedStops = $stopResults | Where-Object { -not $_.Success }

    if ($successfulStops.Count -gt 0) {
        Write-Host "`n✅ Successfully Initiated Stop for Instances ($($successfulStops.Count)):" -ForegroundColor Green
        foreach ($result in $successfulStops) {
            Write-Host "   • $($result.InstanceName)" -ForegroundColor White
            Write-Host "     └─ Machine Type: $($result.MachineType)" -ForegroundColor Gray
            Write-Host "     └─ Zone: $($result.Zone)" -ForegroundColor Gray
            Write-Host "     └─ Status: Running → Stopping → Terminated" -ForegroundColor Gray
        }
    }

    if ($failedStops.Count -gt 0) {
        Write-Host "`n❌ Failed to Stop Instances ($($failedStops.Count)):" -ForegroundColor Red
        foreach ($result in $failedStops) {
            Write-Host "   • $($result.InstanceName)" -ForegroundColor White
            Write-Host "     └─ Zone: $($result.Zone)" -ForegroundColor Gray
            Write-Host "     └─ Error: $($result.Error)" -ForegroundColor Red
        }
    }

    # Summary
    Write-Host "`n📊 Operation Summary:" -ForegroundColor White
    Write-Host "   🎯 Target Instances: $($filteredRunningInstances.Count)" -ForegroundColor Cyan
    Write-Host "   ✅ Successfully Stopped: $($successfulStops.Count)" -ForegroundColor Green
    Write-Host "   ❌ Failed: $($failedStops.Count)" -ForegroundColor Red
    
    if ($successfulStops.Count -gt 0) {
        Write-Host "`n💰 Cost Savings: Instances are now stopping/terminated and will not incur compute charges" -ForegroundColor Green
        Write-Host "   (Persistent disks may still incur storage charges)" -ForegroundColor Gray
    }

} catch {
    Write-Host "`n❌ Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    exit 1
}