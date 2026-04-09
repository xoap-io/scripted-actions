<#
.SYNOPSIS
    Create a Google Cloud firewall rule using the gcloud CLI.

.DESCRIPTION
    This script creates a Google Cloud VPC firewall rule using
    `gcloud compute firewall-rules create`. Supports ingress and egress
    directions, allow and deny actions, TCP/UDP/ICMP/all protocols, and
    filtering by source IP ranges and network tags. If ProjectId is omitted
    it is resolved from the active gcloud configuration.

.PARAMETER ProjectId
    The Google Cloud project ID. If omitted, the value from
    `gcloud config get-value project` is used.

.PARAMETER RuleName
    The name for the new firewall rule.

.PARAMETER Network
    The name of the VPC network to which this rule applies.

.PARAMETER Direction
    Traffic direction the rule applies to: INGRESS or EGRESS.
    Defaults to INGRESS.

.PARAMETER Priority
    Rule priority. Lower values have higher priority. Valid range: 0-65535.
    Defaults to 1000.

.PARAMETER Action
    Whether to allow or deny matching traffic. Defaults to allow.

.PARAMETER Protocol
    Network protocol to match: tcp, udp, icmp, or all. Defaults to tcp.

.PARAMETER Ports
    Comma-separated list of ports or port ranges to match.
    Only applicable for tcp and udp protocols. Example: "80,443,8080-8090".

.PARAMETER SourceRanges
    Comma-separated CIDR ranges that are the source of INGRESS traffic.
    Example: "0.0.0.0/0" or "10.0.0.0/8,192.168.1.0/24".

.PARAMETER TargetTags
    Comma-separated list of network tags. The rule applies only to instances
    with one of these tags.

.PARAMETER Description
    An optional human-readable description for the firewall rule.

.EXAMPLE
    .\gce-cli-create-firewall-rule.ps1 `
      -RuleName "allow-https" `
      -Network "default" `
      -Protocol tcp `
      -Ports "443" `
      -SourceRanges "0.0.0.0/0"

    Create a rule allowing HTTPS traffic from the internet on the default VPC.

.EXAMPLE
    .\gce-cli-create-firewall-rule.ps1 `
      -ProjectId "my-project-123" `
      -RuleName "deny-all-egress" `
      -Network "prod-network" `
      -Direction EGRESS `
      -Action deny `
      -Protocol all `
      -Priority 500 `
      -Description "Block all outbound traffic"

    Create a high-priority deny-all egress rule on a custom VPC.

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
    https://cloud.google.com/sdk/gcloud/reference/compute/firewall-rules/create

.COMPONENT
    Google Cloud CLI Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID. Defaults to the active gcloud config project.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $true, HelpMessage = "The name for the new firewall rule.")]
    [ValidateNotNullOrEmpty()]
    [string]$RuleName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the VPC network to which this rule applies.")]
    [ValidateNotNullOrEmpty()]
    [string]$Network,

    [Parameter(Mandatory = $false, HelpMessage = "Traffic direction: INGRESS or EGRESS. Defaults to INGRESS.")]
    [ValidateSet('INGRESS', 'EGRESS')]
    [string]$Direction = 'INGRESS',

    [Parameter(Mandatory = $false, HelpMessage = "Rule priority (0-65535). Lower values have higher priority. Defaults to 1000.")]
    [ValidateRange(0, 65535)]
    [int]$Priority = 1000,

    [Parameter(Mandatory = $false, HelpMessage = "Whether to allow or deny matching traffic. Defaults to allow.")]
    [ValidateSet('allow', 'deny')]
    [string]$Action = 'allow',

    [Parameter(Mandatory = $false, HelpMessage = "Network protocol to match: tcp, udp, icmp, or all. Defaults to tcp.")]
    [ValidateSet('tcp', 'udp', 'icmp', 'all')]
    [string]$Protocol = 'tcp',

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated ports or port ranges. Example: '80,443,8080-8090'.")]
    [string]$Ports,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated source CIDR ranges for INGRESS. Example: '0.0.0.0/0'.")]
    [string]$SourceRanges,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated network tags. The rule applies only to tagged instances.")]
    [string]$TargetTags,

    [Parameter(Mandatory = $false, HelpMessage = "An optional human-readable description for the firewall rule.")]
    [string]$Description
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting firewall rule creation..." -ForegroundColor Green

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

    # Build the protocol:port string for --allow or --deny
    if ($Protocol -eq 'all') {
        $protocolSpec = 'all'
    }
    elseif ($Ports) {
        $protocolSpec = "${Protocol}:${Ports}"
    }
    else {
        $protocolSpec = $Protocol
    }

    Write-Host "🔧 Creating firewall rule '$RuleName' on network '$Network'..." -ForegroundColor Cyan

    $arguments = @(
        'compute', 'firewall-rules', 'create', $RuleName,
        '--project', $ProjectId,
        '--network', $Network,
        '--direction', $Direction,
        '--priority', $Priority,
        "--$Action", $protocolSpec
    )

    if ($SourceRanges -and $Direction -eq 'INGRESS') {
        $arguments += '--source-ranges', $SourceRanges
    }

    if ($TargetTags) {
        $arguments += '--target-tags', $TargetTags
    }

    if ($Description) {
        $arguments += '--description', $Description
    }

    $result = & gcloud @arguments 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Firewall rule '$RuleName' created successfully." -ForegroundColor Green
        Write-Host "📊 Summary:" -ForegroundColor Blue
        Write-Host "   Project  : $ProjectId" -ForegroundColor Green
        Write-Host "   Rule     : $RuleName" -ForegroundColor Green
        Write-Host "   Network  : $Network" -ForegroundColor Green
        Write-Host "   Direction: $Direction" -ForegroundColor Green
        Write-Host "   Action   : $Action $protocolSpec" -ForegroundColor Green
        Write-Host "   Priority : $Priority" -ForegroundColor Green
        if ($SourceRanges) {
            Write-Host "   Sources  : $SourceRanges" -ForegroundColor Green
        }
        if ($TargetTags) {
            Write-Host "   Tags     : $TargetTags" -ForegroundColor Green
        }
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
