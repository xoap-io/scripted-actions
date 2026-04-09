<#
.SYNOPSIS
    Create a Google Cloud VPC network using the gcloud CLI.

.DESCRIPTION
    This script creates a Google Cloud VPC network using
    `gcloud compute networks create`. The subnet creation mode can be set to
    auto (subnets created automatically in each region) or custom (subnets
    must be created manually). If ProjectId is omitted it is resolved from
    the active gcloud configuration.

.PARAMETER ProjectId
    The Google Cloud project ID. If omitted, the value from
    `gcloud config get-value project` is used.

.PARAMETER NetworkName
    The name for the new VPC network. Must follow GCP naming conventions:
    lowercase letters, digits, and hyphens only.

.PARAMETER SubnetMode
    Subnet creation mode: auto or custom. Defaults to auto.
    In auto mode, subnets are created automatically in each region.
    In custom mode, you must create subnets manually.

.PARAMETER Description
    An optional human-readable description for the VPC network.

.PARAMETER Mtu
    The maximum transmission unit (MTU) in bytes for the network.
    Valid values: 1300 to 8896. If omitted, GCP uses the default (1460).

.EXAMPLE
    .\gce-cli-create-vpc.ps1 -NetworkName "my-vpc-network"

    Create a VPC network with auto subnet mode in the active config project.

.EXAMPLE
    .\gce-cli-create-vpc.ps1 `
      -ProjectId "my-project-123" `
      -NetworkName "prod-network" `
      -SubnetMode custom `
      -Description "Production VPC network" `
      -Mtu 1500

    Create a custom-subnet VPC with a specific MTU and description.

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
    https://cloud.google.com/sdk/gcloud/reference/compute/networks/create

.COMPONENT
    Google Cloud CLI Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID. Defaults to the active gcloud config project.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $true, HelpMessage = "The name for the new VPC network. Lowercase letters, digits, and hyphens only.")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z][a-z0-9\-]{0,61}[a-z0-9]$')]
    [string]$NetworkName,

    [Parameter(Mandatory = $false, HelpMessage = "Subnet creation mode: auto or custom. Defaults to auto.")]
    [ValidateSet('auto', 'custom')]
    [string]$SubnetMode = 'auto',

    [Parameter(Mandatory = $false, HelpMessage = "An optional human-readable description for the VPC network.")]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum transmission unit in bytes. Valid range: 1300-8896.")]
    [ValidateRange(1300, 8896)]
    [int]$Mtu
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting VPC network creation..." -ForegroundColor Green

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

    Write-Host "🔧 Creating VPC network '$NetworkName' (subnet mode: $SubnetMode)..." -ForegroundColor Cyan

    $arguments = @(
        'compute', 'networks', 'create', $NetworkName,
        '--project', $ProjectId,
        '--subnet-mode', $SubnetMode
    )

    if ($Description) {
        $arguments += '--description', $Description
    }

    if ($Mtu) {
        $arguments += '--mtu', $Mtu
    }

    $result = & gcloud @arguments 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ VPC network '$NetworkName' created successfully." -ForegroundColor Green
        Write-Host "📊 Summary:" -ForegroundColor Blue
        Write-Host "   Project    : $ProjectId" -ForegroundColor Green
        Write-Host "   Network    : $NetworkName" -ForegroundColor Green
        Write-Host "   SubnetMode : $SubnetMode" -ForegroundColor Green
        if ($Mtu) {
            Write-Host "   MTU        : $Mtu bytes" -ForegroundColor Green
        }
        Write-Host "💡 Next Steps:" -ForegroundColor Yellow
        Write-Host "   Add a subnet : .\gce-cli-create-subnet.ps1 -Network $NetworkName" -ForegroundColor Yellow
        Write-Host "   Add firewall : .\gce-cli-create-firewall-rule.ps1 -Network $NetworkName" -ForegroundColor Yellow
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
