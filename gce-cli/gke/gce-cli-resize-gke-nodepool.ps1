<#
.SYNOPSIS
    Resize a node pool in a GKE cluster using gcloud CLI.

.DESCRIPTION
    This script resizes a specific node pool within a GKE cluster to a given
    number of nodes. Either Zone or Region must be specified to locate the cluster.
    Uses gcloud container clusters resize with --quiet to suppress interactive
    confirmation prompts.

.PARAMETER ClusterName
    The name of the GKE cluster containing the node pool to resize.

.PARAMETER NodePool
    The name of the node pool to resize.

.PARAMETER NumNodes
    The target number of nodes for the node pool. Set to 0 to scale down completely.

.PARAMETER Zone
    The zone of the zonal GKE cluster. Either Zone or Region must be specified.
    Example: us-central1-a

.PARAMETER Region
    The region of the regional GKE cluster. Either Zone or Region must be specified.
    Example: us-central1

.PARAMETER ProjectId
    The Google Cloud project ID. If omitted, the active gcloud project is used.

.EXAMPLE
    .\gce-cli-resize-gke-nodepool.ps1 `
        -ClusterName "my-cluster" `
        -NodePool "default-pool" `
        -NumNodes 5 `
        -Zone "us-central1-a"

.EXAMPLE
    .\gce-cli-resize-gke-nodepool.ps1 `
        -ClusterName "prod-cluster" `
        -NodePool "high-memory-pool" `
        -NumNodes 10 `
        -Region "us-central1" `
        -ProjectId "my-project-123"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Google Cloud SDK

.LINK
    https://cloud.google.com/sdk/gcloud/reference/container/clusters/resize

.COMPONENT
    Google Cloud CLI Kubernetes Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the GKE cluster containing the node pool to resize.")]
    [ValidatePattern('^[a-z][a-z0-9-]{0,38}[a-z0-9]$')]
    [string]$ClusterName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the node pool to resize.")]
    [ValidateNotNullOrEmpty()]
    [string]$NodePool,

    [Parameter(Mandatory = $true, HelpMessage = "The target number of nodes for the node pool. Set to 0 to scale down completely.")]
    [ValidateRange(0, 1000)]
    [int]$NumNodes,

    [Parameter(Mandatory = $false, HelpMessage = "The zone of the zonal GKE cluster. Example: us-central1-a. Either Zone or Region must be specified.")]
    [ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]
    [string]$Zone,

    [Parameter(Mandatory = $false, HelpMessage = "The region of the regional GKE cluster. Example: us-central1. Either Zone or Region must be specified.")]
    [ValidatePattern('^[a-z]+-[a-z]+\d+$')]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID. If omitted, the active gcloud project is used.")]
    [ValidatePattern('^[a-z][a-z0-9-]{4,28}[a-z0-9]$')]
    [string]$ProjectId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "`n🚀 Starting GKE node pool resize..." -ForegroundColor Green

    # Validate that either Zone or Region is specified
    if (-not $Zone -and -not $Region) {
        throw "Either -Zone or -Region must be specified to locate the GKE cluster."
    }
    if ($Zone -and $Region) {
        throw "Only one of -Zone or -Region may be specified, not both."
    }

    # Check gcloud availability
    Write-Host "🔍 Checking gcloud CLI availability..." -ForegroundColor Cyan
    if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
        throw "gcloud CLI is not installed or not in PATH. Please install the Google Cloud SDK."
    }

    # Set project if specified
    if ($ProjectId) {
        Write-Host "🔧 Setting active project to '$($ProjectId)'..." -ForegroundColor Cyan
        $setProject = & gcloud config set project $ProjectId 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set project '$($ProjectId)': $setProject"
        }
    }

    Write-Host "🔍 Validating cluster '$($ClusterName)'..." -ForegroundColor Cyan

    # Build gcloud arguments
    $gcloudArgs = @(
        'container', 'clusters', 'resize', $ClusterName,
        '--node-pool', $NodePool,
        '--num-nodes', $NumNodes,
        '--quiet'
    )

    if ($Zone) {
        $gcloudArgs += '--zone', $Zone
        Write-Host "ℹ️  Cluster location: Zone ($($Zone))" -ForegroundColor Yellow
    }
    elseif ($Region) {
        $gcloudArgs += '--region', $Region
        Write-Host "ℹ️  Cluster location: Region ($($Region))" -ForegroundColor Yellow
    }

    if ($ProjectId) {
        $gcloudArgs += '--project', $ProjectId
    }

    Write-Host "🔧 Resizing node pool '$($NodePool)' in cluster '$($ClusterName)' to $($NumNodes) node(s)..." -ForegroundColor Cyan

    $result = & gcloud @gcloudArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "gcloud container clusters resize failed: $result"
    }

    Write-Host "`n✅ Node pool resized successfully!" -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Cluster   : $($ClusterName)" -ForegroundColor Green
    Write-Host "   Node Pool : $($NodePool)" -ForegroundColor Green
    Write-Host "   New Size  : $($NumNodes) node(s)" -ForegroundColor Green

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   Verify node pool size:" -ForegroundColor Yellow
    if ($Zone) {
        Write-Host "   gcloud container node-pools describe $($NodePool) --cluster $($ClusterName) --zone $($Zone)" -ForegroundColor Yellow
    }
    else {
        Write-Host "   gcloud container node-pools describe $($NodePool) --cluster $($ClusterName) --region $($Region)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
