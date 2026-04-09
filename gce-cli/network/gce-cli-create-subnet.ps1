<#
.SYNOPSIS
    Create a subnetwork in a Google Cloud VPC using the gcloud CLI.

.DESCRIPTION
    This script creates a subnetwork in a Google Cloud VPC network using
    `gcloud compute networks subnets create`. The VPC network must already
    exist and be in custom subnet mode. Optionally enables Private Google
    Access and VPC Flow Logs. If ProjectId is omitted it is resolved from
    the active gcloud configuration.

.PARAMETER ProjectId
    The Google Cloud project ID. If omitted, the value from
    `gcloud config get-value project` is used.

.PARAMETER SubnetName
    The name for the new subnetwork.

.PARAMETER Network
    The name of the VPC network in which to create the subnet.

.PARAMETER Region
    The region in which to create the subnet.
    Examples: us-central1, europe-west1, asia-east1

.PARAMETER IpRange
    The primary IP CIDR range for the subnet. Example: 10.0.1.0/24

.PARAMETER EnablePrivateGoogleAccess
    Enable Private Google Access so VMs without external IPs can reach
    Google APIs and services.

.PARAMETER EnableFlowLogs
    Enable VPC Flow Logs to capture network flow information for the subnet.

.PARAMETER Description
    An optional human-readable description for the subnetwork.

.EXAMPLE
    .\gce-cli-create-subnet.ps1 `
      -SubnetName "web-subnet" `
      -Network "prod-network" `
      -Region "us-central1" `
      -IpRange "10.0.1.0/24"

    Create a subnet in the active config project.

.EXAMPLE
    .\gce-cli-create-subnet.ps1 `
      -ProjectId "my-project-123" `
      -SubnetName "private-subnet" `
      -Network "prod-network" `
      -Region "europe-west1" `
      -IpRange "10.1.0.0/20" `
      -EnablePrivateGoogleAccess `
      -EnableFlowLogs `
      -Description "Private workload subnet with flow logs"

    Create a subnet with Private Google Access and flow logs enabled.

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
    https://cloud.google.com/sdk/gcloud/reference/compute/networks/subnets/create

.COMPONENT
    Google Cloud CLI Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID. Defaults to the active gcloud config project.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $true, HelpMessage = "The name for the new subnetwork.")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the VPC network in which to create the subnet.")]
    [ValidateNotNullOrEmpty()]
    [string]$Network,

    [Parameter(Mandatory = $true, HelpMessage = "The region in which to create the subnet. Example: us-central1.")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z]+-[a-z]+\d+$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The primary IP CIDR range for the subnet. Example: 10.0.1.0/24.")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$IpRange,

    [Parameter(Mandatory = $false, HelpMessage = "Enable Private Google Access for VMs without external IPs.")]
    [switch]$EnablePrivateGoogleAccess,

    [Parameter(Mandatory = $false, HelpMessage = "Enable VPC Flow Logs to capture network flow information.")]
    [switch]$EnableFlowLogs,

    [Parameter(Mandatory = $false, HelpMessage = "An optional human-readable description for the subnetwork.")]
    [string]$Description
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting subnetwork creation..." -ForegroundColor Green

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

    Write-Host "🔧 Creating subnet '$SubnetName' ($IpRange) in network '$Network', region '$Region'..." -ForegroundColor Cyan

    $arguments = @(
        'compute', 'networks', 'subnets', 'create', $SubnetName,
        '--project', $ProjectId,
        '--network', $Network,
        '--region', $Region,
        '--range', $IpRange
    )

    if ($EnablePrivateGoogleAccess) {
        $arguments += '--enable-private-ip-google-access'
    }

    if ($EnableFlowLogs) {
        $arguments += '--enable-flow-logs'
    }

    if ($Description) {
        $arguments += '--description', $Description
    }

    $result = & gcloud @arguments 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Subnet '$SubnetName' created successfully." -ForegroundColor Green
        Write-Host "📊 Summary:" -ForegroundColor Blue
        Write-Host "   Project               : $ProjectId" -ForegroundColor Green
        Write-Host "   Subnet                : $SubnetName" -ForegroundColor Green
        Write-Host "   Network               : $Network" -ForegroundColor Green
        Write-Host "   Region                : $Region" -ForegroundColor Green
        Write-Host "   IP Range              : $IpRange" -ForegroundColor Green
        Write-Host "   Private Google Access : $($EnablePrivateGoogleAccess.IsPresent)" -ForegroundColor Green
        Write-Host "   Flow Logs             : $($EnableFlowLogs.IsPresent)" -ForegroundColor Green
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
