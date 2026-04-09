<#
.SYNOPSIS
    List Google Cloud VM instances using the gcloud CLI.

.DESCRIPTION
    This script lists Google Compute Engine VM instances using
    `gcloud compute instances list --format json`. Results can be filtered by
    status (RUNNING, STOPPED, or ALL) and output as a formatted table or raw
    JSON. If Zone is omitted all zones are queried. If ProjectId is omitted it
    is resolved from the active gcloud configuration.

.PARAMETER ProjectId
    The Google Cloud project ID. If omitted, the value from
    `gcloud config get-value project` is used.

.PARAMETER Zone
    The zone to list instances from. If omitted, instances from all zones
    in the project are listed.

.PARAMETER Filter
    An optional OData-style filter string passed to gcloud --filter.
    Example: "labels.environment=prod"

.PARAMETER Status
    Filter instances by status. Valid values: All, Running, Stopped.
    Defaults to All.

.PARAMETER OutputFormat
    Output format for the results. Valid values: Table, JSON.
    Defaults to Table.

.EXAMPLE
    .\gce-cli-list-vms.ps1

    List all VM instances in all zones using the active gcloud config project.

.EXAMPLE
    .\gce-cli-list-vms.ps1 `
      -ProjectId "my-project-123" `
      -Zone "us-central1-a" `
      -Status Running `
      -OutputFormat JSON

    List running VMs in a specific zone and return raw JSON output.

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
    https://cloud.google.com/sdk/gcloud/reference/compute/instances/list

.COMPONENT
    Google Cloud CLI Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID. Defaults to the active gcloud config project.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $false, HelpMessage = "The zone to list instances from. If omitted, all zones are queried.")]
    [ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]
    [string]$Zone,

    [Parameter(Mandatory = $false, HelpMessage = "An optional OData-style filter string. Example: 'labels.environment=prod'.")]
    [string]$Filter,

    [Parameter(Mandatory = $false, HelpMessage = "Filter instances by status: All, Running, or Stopped. Defaults to All.")]
    [ValidateSet('All', 'Running', 'Stopped')]
    [string]$Status = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Output format: Table or JSON. Defaults to Table.")]
    [ValidateSet('Table', 'JSON')]
    [string]$OutputFormat = 'Table'
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting VM list operation..." -ForegroundColor Green

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

    Write-Host "🔍 Querying VM instances in project '$ProjectId'..." -ForegroundColor Cyan

    $arguments = @(
        'compute', 'instances', 'list',
        '--project', $ProjectId,
        '--format', 'json'
    )

    if ($Zone) {
        $arguments += '--zones', $Zone
    }

    # Build composite filter
    $filterParts = @()

    if ($Status -eq 'Running') {
        $filterParts += 'status=RUNNING'
    }
    elseif ($Status -eq 'Stopped') {
        $filterParts += 'status=TERMINATED'
    }

    if ($Filter) {
        $filterParts += $Filter
    }

    if ($filterParts.Count -gt 0) {
        $arguments += '--filter', ($filterParts -join ' AND ')
    }

    $result = & gcloud @arguments 2>&1

    if ($LASTEXITCODE -ne 0) {
        $errorMessage = $result -join "`n"
        throw "gcloud exited with code $LASTEXITCODE. $errorMessage"
    }

    $instances = $result | ConvertFrom-Json

    if (-not $instances -or $instances.Count -eq 0) {
        Write-Host "ℹ️  No VM instances found matching the criteria." -ForegroundColor Yellow
    }
    else {
        Write-Host "✅ Found $($instances.Count) instance(s)." -ForegroundColor Green

        if ($OutputFormat -eq 'JSON') {
            $instances | ConvertTo-Json -Depth 10
        }
        else {
            $instances | ForEach-Object {
                [PSCustomObject]@{
                    Name        = $_.name
                    Zone        = $_.zone.Split('/')[-1]
                    Status      = $_.status
                    MachineType = $_.machineType.Split('/')[-1]
                    InternalIP  = $_.networkInterfaces[0].networkIP
                    ExternalIP  = if ($_.networkInterfaces[0].accessConfigs) {
                                      $_.networkInterfaces[0].accessConfigs[0].natIP
                                  } else { '' }
                }
            } | Format-Table -AutoSize
        }
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
