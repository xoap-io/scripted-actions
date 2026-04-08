<#
.SYNOPSIS
    Delete all running Google Cloud VM instances and their associated resources in specified zones.

.DESCRIPTION
    This script safely deletes all running Google Cloud VM instances in the specified project and zones,
    along with their associated resources including disks, static IP addresses, and snapshots.
    Includes safety checks, confirmation prompts, and comprehensive error handling.

.PARAMETER Project
    The Google Cloud project ID from which to delete VM instances.

.PARAMETER Zone
    The zone(s) where the virtual machines are located. Can be a single zone or comma-separated list.
    Examples: "us-central1-a" or "us-central1-a,us-west1-b"

.PARAMETER DeleteDisks
    Delete attached disks along with the VM instances (default: $true).
    Boot disks are typically auto-deleted, but additional disks may remain.

.PARAMETER DeleteSnapshots
    Delete snapshots associated with the VM instances (default: $false).
    Only deletes snapshots that match the VM instance names.

.PARAMETER DeleteStaticIPs
    Delete static IP addresses associated with the VM instances (default: $false).

.PARAMETER Filter
    Optional filter to apply when listing instances. Uses gcloud compute instances list filter syntax.
    Example: "status=RUNNING" or "labels.environment=dev"

.PARAMETER Force
    Skip confirmation prompts and proceed with deletion immediately.

.PARAMETER WhatIf
    Show what would be deleted without actually performing the deletion.

.EXAMPLE
    .\gce-cli-delete-running-vms.ps1 -Project "my-project-123" -Zone "us-central1-a"

    Delete all running VMs in the specified zone with confirmation prompts.

.EXAMPLE
    .\gce-cli-delete-running-vms.ps1 -Project "my-project-123" -Zone "us-central1-a,us-west1-b" -Force

    Delete all running VMs in multiple zones without confirmation prompts.

.EXAMPLE
    .\gce-cli-delete-running-vms.ps1 -Project "my-project-123" -Zone "us-central1-a" -Filter "labels.environment=dev" -WhatIf

    Show what dev environment VMs would be deleted without actually deleting them.

.EXAMPLE
    .\gce-cli-delete-running-vms.ps1 -Project "my-project-123" -Zone "us-central1-a" -DeleteSnapshots -DeleteStaticIPs -Force

    Delete VMs and all associated resources including snapshots and static IPs.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Google Cloud SDK

.COMPONENT
    Google Cloud CLI Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The Google Cloud project ID from which to delete VM instances.")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$Project,

    [Parameter(Mandatory = $true, HelpMessage = "The zone(s) where the virtual machines are located. Can be a single zone or comma-separated list.")]
    [ValidateNotNullOrEmpty()]
    [string]$Zone,

    [Parameter(Mandatory = $false, HelpMessage = "Delete attached disks along with the VM instances.")]
    [bool]$DeleteDisks = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Delete snapshots associated with the VM instances.")]
    [bool]$DeleteSnapshots = $false,

    [Parameter(Mandatory = $false, HelpMessage = "Delete static IP addresses associated with the VM instances.")]
    [bool]$DeleteStaticIPs = $false,

    [Parameter(Mandatory = $false, HelpMessage = "Optional filter to apply when listing instances. Uses gcloud compute instances list filter syntax.")]
    [string]$Filter,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts and proceed with deletion immediately.")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Show what would be deleted without actually performing the deletion.")]
    [switch]$WhatIf
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to test gcloud authentication and availability
function Test-GCloudAuth {
    try {
        $authResult = & gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null
        if (-not $authResult) {
            throw "No active gcloud authentication found. Please run 'gcloud auth login' first."
        }
        Write-Output "Authenticated as: $authResult"
        return $true
    }
    catch {
        throw "gcloud CLI is not available or not authenticated. Please install gcloud and authenticate."
    }
}

# Function to get VM instances in specified zones
function Get-VMInstances {
    param(
        [string]$ProjectId,
        [string[]]$Zones,
        [string]$FilterExpression
    )

    $allInstances = @()

    foreach ($currentZone in $Zones) {
        try {
            Write-Output "Scanning zone: $currentZone"

            $arguments = @(
                'compute', 'instances', 'list',
                '--project', $ProjectId,
                '--zones', $currentZone,
                '--format', 'csv(name,zone,status,machineType)'
            )

            if ($FilterExpression) {
                $arguments += '--filter', $FilterExpression
            }

            $result = & gcloud @arguments 2>&1

            if ($LASTEXITCODE -eq 0 -and $result.Count -gt 1) {
                # Skip header row
                $instances = $result | Select-Object -Skip 1 | ForEach-Object {
                    $parts = $_ -split ','
                    if ($parts.Count -ge 4) {
                        @{
                            Name = $parts[0]
                            Zone = $parts[1].Split('/')[-1]  # Extract zone name from full path
                            Status = $parts[2]
                            MachineType = $parts[3].Split('/')[-1]  # Extract machine type name
                        }
                    }
                }
                $allInstances += $instances
            }
        }
        catch {
            Write-Warning "Failed to list instances in zone $currentZone : $($_.Exception.Message)"
        }
    }

    return $allInstances
}

# Function to get attached disks for an instance
function Get-InstanceDisks {
    param(
        [string]$ProjectId,
        [string]$Zone,
        [string]$InstanceName
    )

    try {
        $result = & gcloud compute instances describe $InstanceName --project $ProjectId --zone $Zone --format="value(disks[].source)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            return $result | ForEach-Object { $_.Split('/')[-1] }  # Extract disk name from full path
        }
    }
    catch {
        Write-Warning "Failed to get disks for instance $InstanceName : $($_.Exception.Message)"
    }

    return @()
}

# Function to get static IP addresses for an instance
function Get-InstanceStaticIPs {
    param(
        [string]$ProjectId,
        [string]$InstancePattern
    )

    try {
        $result = & gcloud compute addresses list --project $ProjectId --filter="name~$InstancePattern" --format="csv(name,region)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $result.Count -gt 1) {
            return $result | Select-Object -Skip 1 | ForEach-Object {
                $parts = $_ -split ','
                if ($parts.Count -ge 2) {
                    @{
                        Name = $parts[0]
                        Region = $parts[1].Split('/')[-1]  # Extract region name
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to get static IPs for pattern $InstancePattern : $($_.Exception.Message)"
    }

    return @()
}

# Function to get snapshots for an instance
function Get-InstanceSnapshots {
    param(
        [string]$ProjectId,
        [string]$InstancePattern
    )

    try {
        $result = & gcloud compute snapshots list --project $ProjectId --filter="name~$InstancePattern" --format="value(name)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            return $result
        }
    }
    catch {
        Write-Warning "Failed to get snapshots for pattern $InstancePattern : $($_.Exception.Message)"
    }

    return @()
}

# Function to delete resources
function Remove-GCPResources {
    param(
        [object[]]$Instances,
        [string]$ProjectId,
        [bool]$RemoveDisks,
        [bool]$RemoveSnapshots,
        [bool]$RemoveStaticIPs,
        [bool]$WhatIfMode
    )

    $deletionSummary = @{
        DeletedInstances = @()
        DeletedDisks = @()
        DeletedSnapshots = @()
        DeletedStaticIPs = @()
        Errors = @()
    }

    foreach ($instance in $Instances) {
        $instanceName = $instance.Name
        $instanceZone = $instance.Zone

        try {
            if ($WhatIfMode) {
                Write-Output "WHATIF: Would delete VM instance: $instanceName in zone $instanceZone"
            } else {
                Write-Output "Deleting VM instance: $instanceName in zone $instanceZone"
                $result = & gcloud compute instances delete $instanceName --project $ProjectId --zone $instanceZone --quiet 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $deletionSummary.DeletedInstances += "$instanceName ($instanceZone)"
                    Write-Output "Successfully deleted instance: $instanceName"
                } else {
                    throw "Failed to delete instance. Error: $($result -join '; ')"
                }
            }

            # Handle attached disks
            if ($RemoveDisks) {
                $disks = Get-InstanceDisks -ProjectId $ProjectId -Zone $instanceZone -InstanceName $instanceName
                foreach ($disk in $disks) {
                    try {
                        if ($WhatIfMode) {
                            Write-Output "WHATIF: Would delete disk: $disk"
                        } else {
                            Write-Output "Deleting disk: $disk"
                            $result = & gcloud compute disks delete $disk --project $ProjectId --zone $instanceZone --quiet 2>&1

                            if ($LASTEXITCODE -eq 0) {
                                $deletionSummary.DeletedDisks += "$disk ($instanceZone)"
                                Write-Output "Successfully deleted disk: $disk"
                            } else {
                                Write-Warning "Failed to delete disk $disk : $($result -join '; ')"
                            }
                        }
                    }
                    catch {
                        $deletionSummary.Errors += "Disk deletion failed for $disk : $($_.Exception.Message)"
                        Write-Warning "Failed to delete disk $disk : $($_.Exception.Message)"
                    }
                }
            }

            # Handle static IP addresses
            if ($RemoveStaticIPs) {
                $staticIPs = Get-InstanceStaticIPs -ProjectId $ProjectId -InstancePattern $instanceName
                foreach ($ip in $staticIPs) {
                    try {
                        if ($WhatIfMode) {
                            Write-Output "WHATIF: Would release static IP: $($ip.Name) in region $($ip.Region)"
                        } else {
                            Write-Output "Releasing static IP: $($ip.Name) in region $($ip.Region)"
                            $result = & gcloud compute addresses delete $ip.Name --region $ip.Region --project $ProjectId --quiet 2>&1

                            if ($LASTEXITCODE -eq 0) {
                                $deletionSummary.DeletedStaticIPs += "$($ip.Name) ($($ip.Region))"
                                Write-Output "Successfully released static IP: $($ip.Name)"
                            } else {
                                Write-Warning "Failed to release static IP $($ip.Name) : $($result -join '; ')"
                            }
                        }
                    }
                    catch {
                        $deletionSummary.Errors += "Static IP deletion failed for $($ip.Name) : $($_.Exception.Message)"
                        Write-Warning "Failed to release static IP $($ip.Name) : $($_.Exception.Message)"
                    }
                }
            }

            # Handle snapshots
            if ($RemoveSnapshots) {
                $snapshots = Get-InstanceSnapshots -ProjectId $ProjectId -InstancePattern $instanceName
                foreach ($snapshot in $snapshots) {
                    try {
                        if ($WhatIfMode) {
                            Write-Output "WHATIF: Would delete snapshot: $snapshot"
                        } else {
                            Write-Output "Deleting snapshot: $snapshot"
                            $result = & gcloud compute snapshots delete $snapshot --project $ProjectId --quiet 2>&1

                            if ($LASTEXITCODE -eq 0) {
                                $deletionSummary.DeletedSnapshots += $snapshot
                                Write-Output "Successfully deleted snapshot: $snapshot"
                            } else {
                                Write-Warning "Failed to delete snapshot $snapshot : $($result -join '; ')"
                            }
                        }
                    }
                    catch {
                        $deletionSummary.Errors += "Snapshot deletion failed for $snapshot : $($_.Exception.Message)"
                        Write-Warning "Failed to delete snapshot $snapshot : $($_.Exception.Message)"
                    }
                }
            }
        }
        catch {
            $deletionSummary.Errors += "Instance deletion failed for $instanceName : $($_.Exception.Message)"
            Write-Error "Failed to delete instance $instanceName : $($_.Exception.Message)"
        }
    }

    return $deletionSummary
}

try {
    Write-Output "Starting Google Cloud VM deletion process..."

    # Test gcloud authentication
    Test-GCloudAuth

    # Set the active project
    Write-Output "Setting active project to: $Project"
    $setProjectResult = & gcloud config set project $Project 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set project '$Project'. Error: $setProjectResult"
    }

    # Parse zones
    $zones = $Zone -split ',' | ForEach-Object { $_.Trim() }
    Write-Output "Target zones: $($zones -join ', ')"

    # Get list of VM instances
    Write-Output "Scanning for VM instances..."
    $instances = Get-VMInstances -ProjectId $Project -Zones $zones -FilterExpression $Filter

    if (-not $instances -or $instances.Count -eq 0) {
        Write-Output "No VM instances found matching the criteria."
        exit 0
    }

    # Display what will be affected
    Write-Output "Found $($instances.Count) VM instance(s) to process:"
    $instances | ForEach-Object {
        Write-Output "  • $($_.Name) ($($_.Zone)) - $($_.Status) - $($_.MachineType)"
    }

    # Configuration summary
    Write-Output "Configuration:"
    Write-Output "  • Delete attached disks: $DeleteDisks"
    Write-Output "  • Delete snapshots: $DeleteSnapshots"
    Write-Output "  • Delete static IPs: $DeleteStaticIPs"
    if ($Filter) { Write-Output "  • Filter applied: $Filter" }

    # Confirmation (unless Force or WhatIf)
    if (-not $Force -and -not $WhatIf) {
        Write-Output "WARNING: This operation is DESTRUCTIVE and cannot be undone!"
        $confirmation = Read-Host "Are you sure you want to proceed? (yes/no)"
        if ($confirmation -ne 'yes') {
            Write-Output "Operation cancelled by user."
            exit 0
        }
    }

    # Perform deletion
    $summary = Remove-GCPResources -Instances $instances -ProjectId $Project -RemoveDisks $DeleteDisks -RemoveSnapshots $DeleteSnapshots -RemoveStaticIPs $DeleteStaticIPs -WhatIfMode $WhatIf.IsPresent

    # Display summary
    Write-Output "Operation Summary:"

    if ($summary.DeletedInstances.Count -gt 0) {
        Write-Output "Deleted VM Instances ($($summary.DeletedInstances.Count)):"
        $summary.DeletedInstances | ForEach-Object { Write-Output "  • $_" }
    }

    if ($summary.DeletedDisks.Count -gt 0) {
        Write-Output "Deleted Disks ($($summary.DeletedDisks.Count)):"
        $summary.DeletedDisks | ForEach-Object { Write-Output "  • $_" }
    }

    if ($summary.DeletedStaticIPs.Count -gt 0) {
        Write-Output "Released Static IPs ($($summary.DeletedStaticIPs.Count)):"
        $summary.DeletedStaticIPs | ForEach-Object { Write-Output "  • $_" }
    }

    if ($summary.DeletedSnapshots.Count -gt 0) {
        Write-Output "Deleted Snapshots ($($summary.DeletedSnapshots.Count)):"
        $summary.DeletedSnapshots | ForEach-Object { Write-Output "  • $_" }
    }

    if ($summary.Errors.Count -gt 0) {
        Write-Output "Errors encountered ($($summary.Errors.Count)):"
        $summary.Errors | ForEach-Object { Write-Output "  • $_" }
    }

    if ($WhatIf) {
        Write-Output "his was a simulation. No resources were actually deleted."
    } else {
        Write-Output "M deletion process completed successfully!"
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
