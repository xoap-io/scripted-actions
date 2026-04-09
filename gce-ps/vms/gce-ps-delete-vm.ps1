<#
.SYNOPSIS
    Delete a Google Cloud VM instance using the GoogleCloud PowerShell module.

.DESCRIPTION
    This script deletes a Google Compute Engine VM instance using the Remove-GceInstance cmdlet.
    By default the script requires the user to type YES to confirm deletion. Use the -Force switch
    to skip confirmation. The -WhatIf switch previews the deletion without performing it.

.PARAMETER ProjectId
    The Google Cloud project ID containing the VM instance.
    Must follow GCP project ID naming conventions (6-30 characters, lowercase letters, digits, hyphens).
    If omitted, the active gcloud project context is used.

.PARAMETER Zone
    The zone where the VM instance is located. Must be a valid GCP zone format.
    Examples: us-central1-a, europe-west1-b, asia-east1-c

.PARAMETER InstanceName
    The name of the VM instance to delete.

.PARAMETER Force
    Skip the confirmation prompt and delete the instance immediately.

.PARAMETER WhatIf
    Preview the delete operation without actually removing the instance.

.EXAMPLE
    .\gce-ps-delete-vm.ps1 -Zone "us-central1-a" -InstanceName "old-server-01"

    Delete a VM instance with a typed YES confirmation prompt.

.EXAMPLE
    .\gce-ps-delete-vm.ps1 -ProjectId "my-project-123" -Zone "europe-west1-b" -InstanceName "test-vm" -Force

    Delete a VM instance immediately without confirmation.

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
    https://cloud.google.com/powershell/docs/reference/GoogleCloud/1.0.0.0/Remove-GceInstance

.COMPONENT
    Google Cloud PowerShell Compute Engine
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID containing the VM instance.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $true, HelpMessage = "The zone where the VM instance is located. Example: us-central1-a")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]
    [string]$Zone,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the VM instance to delete.")]
    [ValidateNotNullOrEmpty()]
    [string]$InstanceName,

    [Parameter(Mandatory = $false, HelpMessage = "Skip the confirmation prompt and delete the instance immediately.")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Preview the delete operation without actually removing the instance.")]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting GCE VM delete operation..." -ForegroundColor Green

    # Import module
    Write-Host "🔍 Loading GoogleCloud PowerShell module..." -ForegroundColor Cyan
    if (-not (Get-Module -Name GoogleCloud -ListAvailable)) {
        throw "GoogleCloud PowerShell module is not installed. Install it with: Install-Module GoogleCloud"
    }
    Import-Module GoogleCloud -ErrorAction Stop

    # Verify instance exists
    $getParams = @{
        Zone = $Zone
        Name = $InstanceName
    }
    if ($ProjectId) { $getParams.Project = $ProjectId }

    Write-Host "🔍 Verifying instance '$InstanceName' exists in zone '$Zone'..." -ForegroundColor Cyan
    $instance = Get-GceInstance @getParams

    if (-not $instance) {
        throw "Instance '$InstanceName' not found in zone '$Zone'."
    }

    Write-Host "ℹ️  Instance found: $InstanceName (Status: $($instance.Status))" -ForegroundColor Yellow

    if ($WhatIf) {
        Write-Host "⚠️  WhatIf: Would delete instance '$InstanceName' in zone '$Zone'." -ForegroundColor Yellow
        return
    }

    # Confirmation
    if (-not $Force) {
        Write-Host "⚠️  WARNING: This action will permanently delete instance '$InstanceName'." -ForegroundColor Red
        $confirm = Read-Host "Type YES to confirm deletion"
        if ($confirm -ne 'YES') {
            Write-Host "⚠️  Deletion cancelled. You must type YES to confirm." -ForegroundColor Yellow
            return
        }
    }

    # Build delete params
    $removeParams = @{
        Zone     = $Zone
        Instance = $InstanceName
    }
    if ($ProjectId) { $removeParams.Project = $ProjectId }

    Write-Host "🔧 Deleting instance '$InstanceName'..." -ForegroundColor Cyan
    Remove-GceInstance @removeParams

    Write-Host "✅ Instance '$InstanceName' deleted successfully." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
