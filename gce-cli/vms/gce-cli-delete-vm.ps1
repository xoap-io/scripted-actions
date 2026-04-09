<#
.SYNOPSIS
    Delete a Google Cloud VM instance using the gcloud CLI.

.DESCRIPTION
    This script deletes a Google Compute Engine VM instance using
    `gcloud compute instances delete`. A YES confirmation is required unless
    the -Force switch is provided. Optionally also deletes non-boot attached
    disks. Use -WhatIf to preview the action without making changes. If
    ProjectId is omitted it is resolved from the active gcloud configuration.

.PARAMETER ProjectId
    The Google Cloud project ID. If omitted, the value from
    `gcloud config get-value project` is used.

.PARAMETER Zone
    The zone where the VM instance is located.
    Examples: us-central1-a, europe-west1-b, asia-east1-c

.PARAMETER InstanceName
    The name of the VM instance to delete.

.PARAMETER Force
    Skip the interactive confirmation prompt and delete immediately.

.PARAMETER DeleteDisks
    Also delete non-boot persistent disks attached to the instance.
    Boot disks follow the instance auto-delete setting.

.PARAMETER WhatIf
    Preview the deletion without making any changes.

.EXAMPLE
    .\gce-cli-delete-vm.ps1 `
      -Zone "us-central1-a" `
      -InstanceName "web-server-01"

    Delete a VM instance with an interactive confirmation prompt.

.EXAMPLE
    .\gce-cli-delete-vm.ps1 `
      -ProjectId "my-project-123" `
      -Zone "us-central1-a" `
      -InstanceName "web-server-01" `
      -Force `
      -DeleteDisks

    Delete a VM and all attached disks without a confirmation prompt.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Google Cloud CLI (gcloud) - https://cloud.google.com/sdk/docs/install

.LINK
    https://cloud.google.com/sdk/gcloud/reference/compute/instances/delete

.COMPONENT
    Google Cloud CLI Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID. Defaults to the active gcloud config project.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $true, HelpMessage = "The zone where the VM instance is located. Example: us-central1-a.")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]
    [string]$Zone,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the VM instance to delete.")]
    [ValidateNotNullOrEmpty()]
    [string]$InstanceName,

    [Parameter(Mandatory = $false, HelpMessage = "Skip the interactive confirmation prompt and delete immediately.")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Also delete non-boot persistent disks attached to the instance.")]
    [switch]$DeleteDisks,

    [Parameter(Mandatory = $false, HelpMessage = "Preview the deletion without making any changes.")]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting VM delete operation..." -ForegroundColor Green

    # Resolve ProjectId from gcloud config if not provided
    if (-not $ProjectId) {
        Write-Host "🔍 Resolving project from gcloud config..." -ForegroundColor Cyan
        $ProjectId = & gcloud config get-value project 2>$null
        if (-not $ProjectId) {
            throw "No project specified and no default project found in gcloud config. " +
                  "Set a default with: gcloud config set project PROJECT_ID"
        }
        Write-Host "ℹ️  Using project: $ProjectId" -ForegroundColor Yellow
    }

    Write-Host "🔍 Target: instance '$InstanceName' in project '$ProjectId', zone '$Zone'." -ForegroundColor Cyan

    if ($DeleteDisks) {
        Write-Host "⚠️  Non-boot attached disks will also be deleted." -ForegroundColor Yellow
    }

    if ($WhatIf) {
        Write-Host "ℹ️  WhatIf mode — no changes will be made." -ForegroundColor Yellow
        Write-Host "   Would delete VM instance '$InstanceName' in zone '$Zone'." -ForegroundColor Yellow
        if ($DeleteDisks) {
            Write-Host "   Would also delete non-boot attached disks." -ForegroundColor Yellow
        }
        return
    }

    # Confirmation prompt unless -Force
    if (-not $Force) {
        Write-Host "⚠️  WARNING: This operation is DESTRUCTIVE and cannot be undone!" -ForegroundColor Yellow
        $confirmation = Read-Host "Type YES to confirm deletion of '$InstanceName'"
        if ($confirmation -ne 'YES') {
            Write-Host "ℹ️  Operation cancelled by user." -ForegroundColor Yellow
            return
        }
    }

    Write-Host "🔧 Deleting VM instance '$InstanceName'..." -ForegroundColor Cyan

    # Discover and delete non-boot disks first if requested
    if ($DeleteDisks) {
        Write-Host "🔍 Discovering attached disks..." -ForegroundColor Cyan
        $diskResult = & gcloud compute instances describe $InstanceName `
            --project $ProjectId `
            --zone $Zone `
            --format "json(disks)" 2>&1

        if ($LASTEXITCODE -eq 0) {
            $diskInfo = $diskResult | ConvertFrom-Json
            $nonBootDisks = $diskInfo.disks | Where-Object { -not $_.boot }
            foreach ($disk in $nonBootDisks) {
                $diskName = $disk.source.Split('/')[-1]
                Write-Host "🔧 Deleting attached disk '$diskName'..." -ForegroundColor Cyan
                $delDiskResult = & gcloud compute disks delete $diskName `
                    --project $ProjectId `
                    --zone $Zone `
                    --quiet 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Disk '$diskName' deleted." -ForegroundColor Green
                }
                else {
                    Write-Host "⚠️  Could not delete disk '$diskName': $($delDiskResult -join ' ')" -ForegroundColor Yellow
                }
            }
        }
        else {
            Write-Host "⚠️  Could not retrieve disk list. Proceeding with instance deletion only." -ForegroundColor Yellow
        }
    }

    $arguments = @(
        'compute', 'instances', 'delete', $InstanceName,
        '--project', $ProjectId,
        '--zone', $Zone,
        '--quiet'
    )

    $result = & gcloud @arguments 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ VM instance '$InstanceName' deleted successfully." -ForegroundColor Green
        Write-Host "📊 Summary:" -ForegroundColor Blue
        Write-Host "   Project : $ProjectId" -ForegroundColor Green
        Write-Host "   Zone    : $Zone" -ForegroundColor Green
        Write-Host "   Instance: $InstanceName" -ForegroundColor Green
    }
    else {
        $errorMessage = $result -join "`n"
        throw "gcloud exited with code $LASTEXITCODE. $errorMessage"
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
