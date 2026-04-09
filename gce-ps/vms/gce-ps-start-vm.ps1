<#
.SYNOPSIS
    Start a stopped Google Cloud VM instance using the GoogleCloud PowerShell module.

.DESCRIPTION
    This script starts a stopped (TERMINATED) Google Compute Engine VM instance using the
    Start-GceInstance cmdlet from the GoogleCloud PowerShell module. It validates the instance
    exists and checks its current state before attempting the start operation.

.PARAMETER ProjectId
    The Google Cloud project ID containing the VM instance.
    Must follow GCP project ID naming conventions (6-30 characters, lowercase letters, digits, hyphens).
    If omitted, the active gcloud project context is used.

.PARAMETER Zone
    The zone where the VM instance is located. Must be a valid GCP zone format.
    Examples: us-central1-a, europe-west1-b, asia-east1-c

.PARAMETER InstanceName
    The name of the VM instance to start.

.EXAMPLE
    .\gce-ps-start-vm.ps1 -Zone "us-central1-a" -InstanceName "web-server-01"

    Start a stopped VM instance using the active project context.

.EXAMPLE
    .\gce-ps-start-vm.ps1 -ProjectId "my-project-123" -Zone "europe-west1-b" -InstanceName "app-server"

    Start a stopped VM instance in a specific project.

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
    https://cloud.google.com/powershell/docs/reference/GoogleCloud/1.0.0.0/Start-GceInstance

.COMPONENT
    Google Cloud PowerShell Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID containing the VM instance.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $true, HelpMessage = "The zone where the VM instance is located. Example: us-central1-a")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]
    [string]$Zone,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the VM instance to start.")]
    [ValidateNotNullOrEmpty()]
    [string]$InstanceName
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting GCE VM start operation..." -ForegroundColor Green

    # Import module
    Write-Host "🔍 Loading GoogleCloud PowerShell module..." -ForegroundColor Cyan
    if (-not (Get-Module -Name GoogleCloud -ListAvailable)) {
        throw "GoogleCloud PowerShell module is not installed. Install it with: Install-Module GoogleCloud"
    }
    Import-Module GoogleCloud -ErrorAction Stop

    # Build Get-GceInstance params
    $getParams = @{
        Zone = $Zone
        Name = $InstanceName
    }
    if ($ProjectId) { $getParams.Project = $ProjectId }

    Write-Host "🔍 Retrieving instance '$InstanceName' in zone '$Zone'..." -ForegroundColor Cyan
    $instance = Get-GceInstance @getParams

    if (-not $instance) {
        throw "Instance '$InstanceName' not found in zone '$Zone'."
    }

    $currentStatus = $instance.Status
    Write-Host "ℹ️  Current instance status: $currentStatus" -ForegroundColor Yellow

    if ($currentStatus -eq 'RUNNING') {
        Write-Host "⚠️  Instance '$InstanceName' is already running. No action taken." -ForegroundColor Yellow
        return
    }

    if ($currentStatus -ne 'TERMINATED') {
        Write-Host "⚠️  Instance '$InstanceName' is in state '$currentStatus'. Proceeding with start attempt." -ForegroundColor Yellow
    }

    # Build start params
    $startParams = @{
        Zone     = $Zone
        Instance = $InstanceName
    }
    if ($ProjectId) { $startParams.Project = $ProjectId }

    Write-Host "🔧 Starting instance '$InstanceName'..." -ForegroundColor Cyan
    Start-GceInstance @startParams

    Write-Host "✅ Instance '$InstanceName' started successfully." -ForegroundColor Green

    # Display updated network info
    try {
        $updated = Get-GceInstance @getParams
        if ($updated.NetworkInterfaces) {
            $nic = $updated.NetworkInterfaces[0]
            Write-Host "ℹ️  Internal IP: $($nic.NetworkIP)" -ForegroundColor Yellow
            if ($nic.AccessConfigs -and $nic.AccessConfigs[0].NatIP) {
                Write-Host "ℹ️  External IP: $($nic.AccessConfigs[0].NatIP)" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "⚠️  Could not retrieve updated network information." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
