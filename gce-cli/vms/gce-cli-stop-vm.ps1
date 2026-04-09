<#
.SYNOPSIS
    Stop a running Google Cloud VM instance using the gcloud CLI.

.DESCRIPTION
    This script stops a running Google Compute Engine VM instance using
    `gcloud compute instances stop`. If ProjectId or Zone are not provided
    they are resolved from the active gcloud configuration. Supports
    async mode to return immediately without waiting for the operation.

.PARAMETER ProjectId
    The Google Cloud project ID. If omitted, the value from
    `gcloud config get-value project` is used.

.PARAMETER Zone
    The zone where the VM instance is located.
    Examples: us-central1-a, europe-west1-b, asia-east1-c
    If omitted, the value from `gcloud config get-value compute/zone` is used.

.PARAMETER InstanceName
    The name of the VM instance to stop.

.PARAMETER Async
    Return immediately without waiting for the stop operation to complete.

.EXAMPLE
    .\gce-cli-stop-vm.ps1 -InstanceName "web-server-01"

    Stop a VM using the project and zone from the active gcloud config.

.EXAMPLE
    .\gce-cli-stop-vm.ps1 `
      -ProjectId "my-project-123" `
      -Zone "us-central1-a" `
      -InstanceName "web-server-01" `
      -Async

    Stop a VM in the specified project and zone without waiting for completion.

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
    https://cloud.google.com/sdk/gcloud/reference/compute/instances/stop

.COMPONENT
    Google Cloud CLI Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID. Defaults to the active gcloud config project.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $false, HelpMessage = "The zone where the VM instance is located. Defaults to the active gcloud config zone.")]
    [ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]
    [string]$Zone,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the VM instance to stop.")]
    [ValidateNotNullOrEmpty()]
    [string]$InstanceName,

    [Parameter(Mandatory = $false, HelpMessage = "Return immediately without waiting for the stop operation to complete.")]
    [switch]$Async
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting VM stop operation..." -ForegroundColor Green

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

    # Resolve Zone from gcloud config if not provided
    if (-not $Zone) {
        Write-Host "🔍 Resolving zone from gcloud config..." -ForegroundColor Cyan
        $Zone = & gcloud config get-value compute/zone 2>$null
        if (-not $Zone) {
            throw "No zone specified and no default zone found in gcloud config. " +
                  "Set a default with: gcloud config set compute/zone ZONE"
        }
        Write-Host "ℹ️  Using zone: $Zone" -ForegroundColor Yellow
    }

    Write-Host "🔧 Stopping VM instance '$InstanceName' in project '$ProjectId', zone '$Zone'..." -ForegroundColor Cyan

    $arguments = @(
        'compute', 'instances', 'stop', $InstanceName,
        '--project', $ProjectId,
        '--zone', $Zone
    )

    if ($Async) {
        $arguments += '--async'
    }

    $result = & gcloud @arguments 2>&1

    if ($LASTEXITCODE -eq 0) {
        if ($Async) {
            Write-Host "✅ Stop operation initiated for VM '$InstanceName' (async — not waiting for completion)." -ForegroundColor Green
        }
        else {
            Write-Host "✅ VM instance '$InstanceName' stopped successfully." -ForegroundColor Green
        }
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
