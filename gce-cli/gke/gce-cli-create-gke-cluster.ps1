<#
.SYNOPSIS
    Create a Google Kubernetes Engine (GKE) cluster using gcloud CLI.

.DESCRIPTION
    This script creates a GKE cluster with configurable options including zone or
    region placement, node count, machine type, Kubernetes version, and optional
    cluster autoscaling. Either Zone (for a zonal cluster) or Region (for a
    regional cluster) must be specified. Uses
    gcloud container clusters create to provision the cluster.

.PARAMETER ClusterName
    The name of the GKE cluster to create. Must follow GKE naming conventions
    (lowercase letters, digits, and hyphens, 2-40 characters).

.PARAMETER Zone
    The zone for a zonal GKE cluster. Mutually exclusive with Region.
    Example: us-central1-a

.PARAMETER Region
    The region for a regional GKE cluster. Mutually exclusive with Zone.
    Example: us-central1

.PARAMETER ProjectId
    The Google Cloud project ID. If omitted, the active gcloud project is used.

.PARAMETER NumNodes
    The number of nodes per zone in the cluster. Defaults to 3.

.PARAMETER MachineType
    The machine type for the cluster nodes. Defaults to e2-standard-2.

.PARAMETER ClusterVersion
    The Kubernetes version for the cluster master and nodes.
    Example: 1.29.1-gke.1589000

.PARAMETER EnableAutoscaling
    Enable cluster autoscaling for the default node pool.

.PARAMETER MinNodes
    Minimum number of nodes for autoscaling. Defaults to 1.
    Only used when EnableAutoscaling is specified.

.PARAMETER MaxNodes
    Maximum number of nodes for autoscaling. Defaults to 10.
    Only used when EnableAutoscaling is specified.

.EXAMPLE
    .\gce-cli-create-gke-cluster.ps1 -ClusterName "my-cluster" -Zone "us-central1-a"

.EXAMPLE
    .\gce-cli-create-gke-cluster.ps1 `
        -ClusterName "prod-cluster" `
        -Region "us-central1" `
        -ProjectId "my-project-123" `
        -NumNodes 3 `
        -MachineType "e2-standard-4" `
        -EnableAutoscaling `
        -MinNodes 2 `
        -MaxNodes 10

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
    https://cloud.google.com/sdk/gcloud/reference/container/clusters/create

.COMPONENT
    Google Cloud CLI Kubernetes Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the GKE cluster to create (lowercase letters, digits, hyphens, 2-40 chars).")]
    [ValidatePattern('^[a-z][a-z0-9-]{0,38}[a-z0-9]$')]
    [string]$ClusterName,

    [Parameter(Mandatory = $false, HelpMessage = "The zone for a zonal GKE cluster. Example: us-central1-a. Either Zone or Region must be specified.")]
    [ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]
    [string]$Zone,

    [Parameter(Mandatory = $false, HelpMessage = "The region for a regional GKE cluster. Example: us-central1. Either Zone or Region must be specified.")]
    [ValidatePattern('^[a-z]+-[a-z]+\d+$')]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID. If omitted, the active gcloud project is used.")]
    [ValidatePattern('^[a-z][a-z0-9-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $false, HelpMessage = "The number of nodes per zone in the cluster. Defaults to 3.")]
    [ValidateRange(1, 1000)]
    [int]$NumNodes = 3,

    [Parameter(Mandatory = $false, HelpMessage = "The machine type for cluster nodes. Defaults to e2-standard-2.")]
    [ValidateNotNullOrEmpty()]
    [string]$MachineType = 'e2-standard-2',

    [Parameter(Mandatory = $false, HelpMessage = "The Kubernetes version for the cluster. Example: 1.29.1-gke.1589000.")]
    [ValidateNotNullOrEmpty()]
    [string]$ClusterVersion,

    [Parameter(Mandatory = $false, HelpMessage = "Enable cluster autoscaling for the default node pool.")]
    [switch]$EnableAutoscaling,

    [Parameter(Mandatory = $false, HelpMessage = "Minimum number of nodes for autoscaling. Only used when EnableAutoscaling is specified. Defaults to 1.")]
    [ValidateRange(0, 1000)]
    [int]$MinNodes = 1,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of nodes for autoscaling. Only used when EnableAutoscaling is specified. Defaults to 10.")]
    [ValidateRange(1, 1000)]
    [int]$MaxNodes = 10
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "`n🚀 Starting GKE cluster creation..." -ForegroundColor Green

    # Validate that either Zone or Region is specified
    if (-not $Zone -and -not $Region) {
        throw "Either -Zone or -Region must be specified. Use -Zone for a zonal cluster or -Region for a regional cluster."
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

    # Build gcloud arguments
    $gcloudArgs = @(
        'container', 'clusters', 'create', $ClusterName,
        '--num-nodes', $NumNodes,
        '--machine-type', $MachineType
    )

    if ($Zone) {
        $gcloudArgs += '--zone', $Zone
        Write-Host "ℹ️  Cluster type: Zonal ($($Zone))" -ForegroundColor Yellow
    }
    elseif ($Region) {
        $gcloudArgs += '--region', $Region
        Write-Host "ℹ️  Cluster type: Regional ($($Region))" -ForegroundColor Yellow
    }

    if ($ProjectId) {
        $gcloudArgs += '--project', $ProjectId
    }

    if ($ClusterVersion) {
        $gcloudArgs += '--cluster-version', $ClusterVersion
    }

    if ($EnableAutoscaling) {
        $gcloudArgs += '--enable-autoscaling', '--min-nodes', $MinNodes, '--max-nodes', $MaxNodes
        Write-Host "ℹ️  Autoscaling enabled: min=$($MinNodes), max=$($MaxNodes)" -ForegroundColor Yellow
    }

    Write-Host "🔧 Creating GKE cluster '$($ClusterName)'..." -ForegroundColor Cyan
    Write-Host "ℹ️  Machine type: $($MachineType), Nodes per zone: $($NumNodes)" -ForegroundColor Yellow

    $result = & gcloud @gcloudArgs --format='json' 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "gcloud container clusters create failed: $result"
    }

    $clusterInfo = $result | ConvertFrom-Json

    Write-Host "`n✅ GKE cluster created successfully!" -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Cluster Name : $($clusterInfo.name)" -ForegroundColor Green
    Write-Host "   Status       : $($clusterInfo.status)" -ForegroundColor Green
    Write-Host "   Endpoint     : $($clusterInfo.endpoint)" -ForegroundColor Green
    Write-Host "   K8s Version  : $($clusterInfo.currentMasterVersion)" -ForegroundColor Green
    Write-Host "   Node Count   : $($clusterInfo.currentNodeCount)" -ForegroundColor Green

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    if ($Zone) {
        Write-Host "   gcloud container clusters get-credentials $($ClusterName) --zone $($Zone)" -ForegroundColor Yellow
    }
    else {
        Write-Host "   gcloud container clusters get-credentials $($ClusterName) --region $($Region)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
