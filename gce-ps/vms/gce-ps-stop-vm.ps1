<#
.SYNOPSIS
    Stop a running Google Cloud VM instance using the GoogleCloud PowerShell module.

.DESCRIPTION
    This script stops a running Google Compute Engine VM instance using the Stop-GceInstance
    cmdlet from the GoogleCloud PowerShell module. It validates the instance exists and checks
    its current state before attempting to stop it. Optionally skips the confirmation prompt
    when the -Force switch is provided.

.PARAMETER ProjectId
    The Google Cloud project ID containing the VM instance.
    Must follow GCP project ID naming conventions (6-30 characters, lowercase letters, digits, hyphens).
    If omitted, the active gcloud project context is used.

.PARAMETER Zone
    The zone where the VM instance is located. Must be a valid GCP zone format.
    Examples: us-central1-a, europe-west1-b, asia-east1-c

.PARAMETER InstanceName
    The name of the VM instance to stop.

.PARAMETER Force
    Skip the confirmation prompt and stop the instance immediately.

.EXAMPLE
    .\gce-ps-stop-vm.ps1 -Zone "us-central1-a" -InstanceName "web-server-01"

    Stop a VM instance with confirmation prompt.

.EXAMPLE
    .\gce-ps-stop-vm.ps1 -ProjectId "my-project-123" -Zone "europe-west1-b" -InstanceName "app-server" -Force

    Stop a VM instance immediately without confirmation.

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
    https://cloud.google.com/powershell/docs/reference/GoogleCloud/1.0.0.0/Stop-GceInstance

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the VM instance to stop.")]
    [ValidateNotNullOrEmpty()]
    [string]$InstanceName,

    [Parameter(Mandatory = $false, HelpMessage = "Skip the confirmation prompt and stop the instance immediately.")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting GCE VM stop operation..." -ForegroundColor Green

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

    if ($currentStatus -eq 'TERMINATED') {
        Write-Host "⚠️  Instance '$InstanceName' is already stopped (TERMINATED). No action taken." -ForegroundColor Yellow
        return
    }

    if ($currentStatus -ne 'RUNNING') {
        Write-Host "⚠️  Instance '$InstanceName' is in state '$currentStatus'. Proceeding with stop attempt." -ForegroundColor Yellow
    }

    # Confirmation
    if (-not $Force) {
        $confirm = Read-Host "Stop instance '$InstanceName' in zone '$Zone'? (y/N)"
        if ($confirm -notmatch '^[Yy]$') {
            Write-Host "⚠️  Operation cancelled by user." -ForegroundColor Yellow
            return
        }
    }

    # Build stop params
    $stopParams = @{
        Zone     = $Zone
        Instance = $InstanceName
    }
    if ($ProjectId) { $stopParams.Project = $ProjectId }

    Write-Host "🔧 Stopping instance '$InstanceName'..." -ForegroundColor Cyan
    Stop-GceInstance @stopParams

    Write-Host "✅ Instance '$InstanceName' stopped successfully." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
