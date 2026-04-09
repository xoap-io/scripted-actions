<#
.SYNOPSIS
    List Google Cloud VM instances using the GoogleCloud PowerShell module.

.DESCRIPTION
    This script lists Google Compute Engine VM instances using the Get-GceInstance cmdlet.
    Results can be filtered by status and output as a formatted table or JSON. When no zone
    is specified, all zones in the project are enumerated with Get-GceZone and instances
    from every zone are returned.

.PARAMETER ProjectId
    The Google Cloud project ID to query.
    Must follow GCP project ID naming conventions (6-30 characters, lowercase letters, digits, hyphens).
    If omitted, the active gcloud project context is used.

.PARAMETER Zone
    The zone to list instances from. If omitted, all zones are queried.
    Examples: us-central1-a, europe-west1-b, asia-east1-c

.PARAMETER Status
    Filter instances by power state. Valid values: All, Running, Terminated.
    Default: All

.PARAMETER OutputFormat
    Output format for the results. Valid values: Table, JSON.
    Default: Table

.EXAMPLE
    .\gce-ps-list-vms.ps1 -ProjectId "my-project-123" -Zone "us-central1-a"

    List all VM instances in a specific zone as a table.

.EXAMPLE
    .\gce-ps-list-vms.ps1 -ProjectId "my-project-123" -Status Running -OutputFormat JSON

    List all running VM instances across all zones and output as JSON.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: GoogleCloud PowerShell Module

.LINK
    https://cloud.google.com/powershell/docs/reference/GoogleCloud/1.0.0.0/Get-GceInstance

.COMPONENT
    Google Cloud PowerShell Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID to query.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $false, HelpMessage = "The zone to list instances from. If omitted, all zones are queried.")]
    [ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]
    [string]$Zone,

    [Parameter(Mandatory = $false, HelpMessage = "Filter instances by power state. Valid values: All, Running, Terminated.")]
    [ValidateSet('All', 'Running', 'Terminated')]
    [string]$Status = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Output format for the results. Valid values: Table, JSON.")]
    [ValidateSet('Table', 'JSON')]
    [string]$OutputFormat = 'Table'
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting GCE VM list operation..." -ForegroundColor Green

    # Import module
    Write-Host "🔍 Loading GoogleCloud PowerShell module..." -ForegroundColor Cyan
    if (-not (Get-Module -Name GoogleCloud -ListAvailable)) {
        throw "GoogleCloud PowerShell module is not installed. Install it with: Install-Module GoogleCloud"
    }
    Import-Module GoogleCloud -ErrorAction Stop

    $allInstances = @()

    if ($Zone) {
        Write-Host "🔍 Listing instances in zone '$Zone'..." -ForegroundColor Cyan
        $getParams = @{ Zone = $Zone }
        if ($ProjectId) { $getParams.Project = $ProjectId }
        $allInstances = Get-GceInstance @getParams
    }
    else {
        Write-Host "🔍 Enumerating all zones..." -ForegroundColor Cyan
        $zoneParams = @{}
        if ($ProjectId) { $zoneParams.Project = $ProjectId }
        $zones = Get-GceZone @zoneParams | Where-Object { $_.Status -eq 'UP' }

        Write-Host "ℹ️  Found $($zones.Count) active zones. Querying instances..." -ForegroundColor Yellow
        foreach ($z in $zones) {
            $getParams = @{ Zone = $z.Name }
            if ($ProjectId) { $getParams.Project = $ProjectId }
            try {
                $zoneInstances = Get-GceInstance @getParams
                if ($zoneInstances) { $allInstances += $zoneInstances }
            }
            catch {
                # Skip zones that return errors (e.g. permission denied)
                Write-Host "⚠️  Could not query zone '$($z.Name)': $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }

    # Filter by status
    if ($Status -ne 'All') {
        $statusMap = @{ Running = 'RUNNING'; Terminated = 'TERMINATED' }
        $allInstances = $allInstances | Where-Object { $_.Status -eq $statusMap[$Status] }
    }

    Write-Host "✅ Found $($allInstances.Count) instance(s) matching filter '$Status'." -ForegroundColor Green

    if ($allInstances.Count -eq 0) {
        Write-Host "ℹ️  No instances to display." -ForegroundColor Yellow
        return
    }

    # Build output objects
    $output = $allInstances | ForEach-Object {
        $nic = if ($_.NetworkInterfaces) { $_.NetworkInterfaces[0] } else { $null }
        [PSCustomObject]@{
            Name       = $_.Name
            Status     = $_.Status
            Zone       = ($_.Zone -split '/')[-1]
            MachineType = ($_.MachineType -split '/')[-1]
            InternalIP = if ($nic) { $nic.NetworkIP } else { 'N/A' }
            ExternalIP = if ($nic -and $nic.AccessConfigs -and $nic.AccessConfigs[0].NatIP) { $nic.AccessConfigs[0].NatIP } else { 'N/A' }
        }
    }

    if ($OutputFormat -eq 'JSON') {
        $output | ConvertTo-Json -Depth 5
    }
    else {
        $output | Format-Table -AutoSize
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
