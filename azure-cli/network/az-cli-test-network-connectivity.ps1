<#
.SYNOPSIS
    Perform network connectivity tests using Azure Network Watcher.

.DESCRIPTION
    This script performs comprehensive network connectivity tests using Azure Network Watcher.
    Tests connectivity between Azure resources, validates security group rules, and analyzes routing.
    Provides detailed diagnostics for troubleshooting network connectivity issues.

    The script uses various Azure CLI Network Watcher commands for testing.

.PARAMETER SourceResourceId
    The resource ID of the source Azure resource (VM, Scale Set, etc.).

.PARAMETER DestinationResourceId
    The resource ID of the destination Azure resource.

.PARAMETER DestinationAddress
    The destination IP address or FQDN to test connectivity to.

.PARAMETER DestinationPort
    The destination port number for connectivity testing.

.PARAMETER Protocol
    The protocol to test (TCP or UDP).

.PARAMETER TestType
    The type of network test to perform.

.PARAMETER ResourceGroup
    The resource group containing the Network Watcher.

.PARAMETER Location
    The Azure region where Network Watcher is deployed.

.PARAMETER VMName
    The name of the VM for IP flow verification tests.

.PARAMETER NICName
    The name of the network interface for IP flow tests.

.PARAMETER Direction
    The traffic direction for IP flow verification.

.PARAMETER LocalEndpoint
    The local IP and port for IP flow testing (format: IP:Port).

.PARAMETER RemoteEndpoint
    The remote IP and port for IP flow testing (format: IP:Port).

.PARAMETER ExportResults
    Export test results to a JSON file.

.PARAMETER OutputPath
    Path to save the test results.

.EXAMPLE
    .\az-cli-test-network-connectivity.ps1 -SourceResourceId "/subscriptions/.../vm1" -DestinationAddress "www.google.com" -DestinationPort 443 -Protocol TCP -TestType "Connectivity"

    Tests connectivity from a VM to an external website.

.EXAMPLE
    .\az-cli-test-network-connectivity.ps1 -TestType "IPFlow" -VMName "web-vm" -NICName "web-vm-nic" -Direction "Inbound" -Protocol TCP -LocalEndpoint "10.0.1.4:80" -RemoteEndpoint "0.0.0.0:*" -ResourceGroup "prod-rg"

    Tests if inbound HTTP traffic is allowed to a VM.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI and Network Watcher
    Note: Requires appropriate permissions and Network Watcher Agent on VMs.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/watcher

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(ParameterSetName = 'Connectivity', HelpMessage = "Source resource ID for connectivity test")]
    [ValidatePattern('^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/')]
    [string]$SourceResourceId,

    [Parameter(ParameterSetName = 'Connectivity', HelpMessage = "Destination resource ID for connectivity test")]
    [ValidatePattern('^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/')]
    [string]$DestinationResourceId,

    [Parameter(ParameterSetName = 'Connectivity', HelpMessage = "Destination IP address or FQDN")]
    [string]$DestinationAddress,

    [Parameter(ParameterSetName = 'Connectivity', HelpMessage = "Destination port number")]
    [ValidateRange(1, 65535)]
    [int]$DestinationPort = 80,

    [Parameter(HelpMessage = "Protocol to test")]
    [ValidateSet("TCP", "UDP", "ICMP")]
    [string]$Protocol = "TCP",

    [Parameter(Mandatory = $true, HelpMessage = "Type of network test")]
    [ValidateSet("Connectivity", "IPFlow", "NextHop", "SecurityGroupView", "Topology")]
    [string]$TestType,

    [Parameter(HelpMessage = "Resource group for Network Watcher")]
    [string]$ResourceGroup = "NetworkWatcherRG",

    [Parameter(HelpMessage = "Azure region for Network Watcher")]
    [ValidateSet(
        "East US", "East US 2", "West US", "West US 2", "West US 3", "Central US", "North Central US", "South Central US",
        "Canada Central", "Canada East", "Brazil South", "North Europe", "West Europe", "UK South", "UK West",
        "France Central", "Germany West Central", "Switzerland North", "Norway East", "Sweden Central",
        "Australia East", "Australia Southeast", "Southeast Asia", "East Asia", "Japan East", "Japan West",
        "Korea Central", "Central India", "South India", "West India", "UAE North", "South Africa North"
    )]
    [string]$Location = "East US",

    [Parameter(ParameterSetName = 'IPFlow', HelpMessage = "VM name for IP flow verification")]
    [string]$VMName,

    [Parameter(ParameterSetName = 'IPFlow', HelpMessage = "Network interface name")]
    [string]$NICName,

    [Parameter(ParameterSetName = 'IPFlow', HelpMessage = "Traffic direction")]
    [ValidateSet("Inbound", "Outbound")]
    [string]$Direction = "Inbound",

    [Parameter(ParameterSetName = 'IPFlow', HelpMessage = "Local IP and port (format: IP:Port)")]
    [ValidatePattern('^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+|\*$')]
    [string]$LocalEndpoint,

    [Parameter(ParameterSetName = 'IPFlow', HelpMessage = "Remote IP and port (format: IP:Port)")]
    [ValidatePattern('^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+|\*$')]
    [string]$RemoteEndpoint,

    [Parameter(HelpMessage = "Export results to file")]
    [switch]$ExportResults,

    [Parameter(HelpMessage = "Output path for results")]
    [string]$OutputPath = "network-test-results.json"
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Initialize results object
$testResults = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    TestType = $TestType
    Location = $Location
    Results = @{}
}

try {
    # Check if Azure CLI is available
    if (-not (Get-Command 'az' -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not found in PATH. Please install Azure CLI first."
    }

    # Check if user is logged in to Azure CLI
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $azAccount) {
        throw "Not logged in to Azure CLI. Please run 'az login' first."
    }

    Write-Host "🔍 Azure Network Connectivity Tester" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green
    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan
    Write-Host ""

    # Check if Network Watcher exists in the region
    Write-Host "Checking Network Watcher availability..." -ForegroundColor Yellow
    $nwList = az network watcher list 2>$null | ConvertFrom-Json
    $networkWatcher = $nwList | Where-Object { $_.location -eq $Location.Replace(' ', '').ToLower() }

    if (-not $networkWatcher) {
        throw "Network Watcher not found in $Location. Please enable Network Watcher first."
    }
    Write-Host "✓ Network Watcher found: $($networkWatcher.name)" -ForegroundColor Green

    # Function to perform connectivity test
    function Test-NetworkConnectivity {
        Write-Host "🔗 Testing Network Connectivity" -ForegroundColor Yellow
        Write-Host "==============================" -ForegroundColor Yellow

        if (-not $SourceResourceId) {
            throw "Source resource ID is required for connectivity testing"
        }

        $azParams = @(
            'network', 'watcher', 'test-connectivity',
            '--source-resource', $SourceResourceId,
            '--protocol', $Protocol,
            '--dest-port', $DestinationPort.ToString()
        )

        if ($DestinationResourceId) {
            $azParams += '--dest-resource', $DestinationResourceId
            Write-Host "Testing connectivity to resource: $DestinationResourceId" -ForegroundColor Cyan
        } elseif ($DestinationAddress) {
            $azParams += '--dest-address', $DestinationAddress
            Write-Host "Testing connectivity to address: $DestinationAddress" -ForegroundColor Cyan
        } else {
            throw "Either destination resource ID or destination address must be specified"
        }

        Write-Host "Source: $SourceResourceId" -ForegroundColor White
        Write-Host "Protocol: $Protocol" -ForegroundColor White
        Write-Host "Port: $DestinationPort" -ForegroundColor White
        Write-Host ""
        Write-Host "Running connectivity test..." -ForegroundColor Yellow

        $result = & az @azParams 2>&1 | ConvertFrom-Json

        if ($LASTEXITCODE -eq 0) {
            $testResults.Results.Connectivity = $result

            Write-Host "Connectivity Test Results:" -ForegroundColor Cyan
            Write-Host "  Status: $($result.connectionStatus)" -ForegroundColor $(if ($result.connectionStatus -eq "Reachable") { "Green" } else { "Red" })
            Write-Host "  Average Latency: $($result.avgLatencyInMs) ms" -ForegroundColor White
            Write-Host "  Min Latency: $($result.minLatencyInMs) ms" -ForegroundColor White
            Write-Host "  Max Latency: $($result.maxLatencyInMs) ms" -ForegroundColor White
            Write-Host "  Probes Sent: $($result.probesSent)" -ForegroundColor White
            Write-Host "  Probes Failed: $($result.probesFailed)" -ForegroundColor White

            if ($result.hops) {
                Write-Host "  Network Hops:" -ForegroundColor Blue
                foreach ($hop in $result.hops) {
                    $hopStatus = if ($hop.issues) { "Issues" } else { "OK" }
                    $hopColor = if ($hop.issues) { "Yellow" } else { "Green" }
                    Write-Host "    $($hop.address) - $hopStatus" -ForegroundColor $hopColor
                    if ($hop.issues) {
                        foreach ($issue in $hop.issues) {
                            Write-Host "      Issue: $($issue.type)" -ForegroundColor Red
                        }
                    }
                }
            }
        } else {
            throw "Connectivity test failed: $($result -join "`n")"
        }
    }

    # Function to perform IP flow verification
    function Test-IPFlow {
        Write-Host "📊 Testing IP Flow Verification" -ForegroundColor Yellow
        Write-Host "===============================" -ForegroundColor Yellow

        if (-not $VMName -or -not $LocalEndpoint -or -not $RemoteEndpoint) {
            throw "VM name, local endpoint, and remote endpoint are required for IP flow testing"
        }

        $azParams = @(
            'network', 'watcher', 'test-ip-flow',
            '--vm', $VMName,
            '--direction', $Direction,
            '--protocol', $Protocol,
            '--local', $LocalEndpoint,
            '--remote', $RemoteEndpoint
        )

        if ($NICName) {
            $azParams += '--nic', $NICName
        }

        Write-Host "VM: $VMName" -ForegroundColor White
        Write-Host "Direction: $Direction" -ForegroundColor White
        Write-Host "Protocol: $Protocol" -ForegroundColor White
        Write-Host "Local: $LocalEndpoint" -ForegroundColor White
        Write-Host "Remote: $RemoteEndpoint" -ForegroundColor White
        Write-Host ""
        Write-Host "Running IP flow verification..." -ForegroundColor Yellow

        $result = & az @azParams 2>&1 | ConvertFrom-Json

        if ($LASTEXITCODE -eq 0) {
            $testResults.Results.IPFlow = $result

            Write-Host "IP Flow Verification Results:" -ForegroundColor Cyan
            Write-Host "  Access: $($result.access)" -ForegroundColor $(if ($result.access -eq "Allow") { "Green" } else { "Red" })
            Write-Host "  Rule Name: $($result.ruleName)" -ForegroundColor White
            if ($result.access -eq "Deny") {
                Write-Host "  🚫 Traffic is blocked by security rule: $($result.ruleName)" -ForegroundColor Red
            } else {
                Write-Host "  ✅ Traffic is allowed by security rule: $($result.ruleName)" -ForegroundColor Green
            }
        } else {
            throw "IP flow verification failed: $($result -join "`n")"
        }
    }

    # Function to check next hop
    function Test-NextHop {
        Write-Host "🧭 Testing Next Hop Analysis" -ForegroundColor Yellow
        Write-Host "============================" -ForegroundColor Yellow

        if (-not $VMName -or -not $DestinationAddress) {
            throw "VM name and destination address are required for next hop testing"
        }

        $azParams = @(
            'network', 'watcher', 'show-next-hop',
            '--vm', $VMName,
            '--dest-ip', $DestinationAddress
        )

        if ($NICName) {
            $azParams += '--nic', $NICName
        }

        Write-Host "VM: $VMName" -ForegroundColor White
        Write-Host "Destination: $DestinationAddress" -ForegroundColor White
        Write-Host ""
        Write-Host "Analyzing next hop..." -ForegroundColor Yellow

        $result = & az @azParams 2>&1 | ConvertFrom-Json

        if ($LASTEXITCODE -eq 0) {
            $testResults.Results.NextHop = $result

            Write-Host "Next Hop Analysis Results:" -ForegroundColor Cyan
            Write-Host "  Next Hop Type: $($result.nextHopType)" -ForegroundColor White
            Write-Host "  Next Hop IP: $($result.nextHopIpAddress)" -ForegroundColor White
            Write-Host "  Route Table ID: $($result.routeTableId)" -ForegroundColor White
        } else {
            throw "Next hop analysis failed: $($result -join "`n")"
        }
    }

    # Function to show security group view
    function Show-SecurityGroupView {
        Write-Host "🛡️ Analyzing Security Group View" -ForegroundColor Yellow
        Write-Host "================================" -ForegroundColor Yellow

        if (-not $VMName) {
            throw "VM name is required for security group view"
        }

        $azParams = @(
            'network', 'watcher', 'show-security-group-view',
            '--vm', $VMName
        )

        Write-Host "VM: $VMName" -ForegroundColor White
        Write-Host ""
        Write-Host "Retrieving security group view..." -ForegroundColor Yellow

        $result = & az @azParams 2>&1 | ConvertFrom-Json

        if ($LASTEXITCODE -eq 0) {
            $testResults.Results.SecurityGroupView = $result

            Write-Host "Security Group View Results:" -ForegroundColor Cyan

            if ($result.networkInterfaces) {
                foreach ($nic in $result.networkInterfaces) {
                    Write-Host "  Network Interface: $($nic.id -split '/')[-1]" -ForegroundColor Blue

                    if ($nic.securityRuleAssociations.networkInterfaceAssociation) {
                        $nsgAssoc = $nic.securityRuleAssociations.networkInterfaceAssociation
                        Write-Host "    Associated NSG: $($nsgAssoc.id -split '/')[-1]" -ForegroundColor White
                    }

                    if ($nic.securityRuleAssociations.subnetAssociation) {
                        $subnetAssoc = $nic.securityRuleAssociations.subnetAssociation
                        Write-Host "    Subnet NSG: $($subnetAssoc.id -split '/')[-1]" -ForegroundColor White
                    }

                    if ($nic.securityRuleAssociations.effectiveSecurityRules) {
                        Write-Host "    Effective Security Rules: $($nic.securityRuleAssociations.effectiveSecurityRules.Count)" -ForegroundColor White
                    }
                }
            }
        } else {
            throw "Security group view failed: $($result -join "`n")"
        }
    }

    # Function to show network topology
    function Show-NetworkTopology {
        Write-Host "🌐 Analyzing Network Topology" -ForegroundColor Yellow
        Write-Host "=============================" -ForegroundColor Yellow

        $azParams = @('network', 'watcher', 'show-topology')

        if ($ResourceGroup -and $ResourceGroup -ne "NetworkWatcherRG") {
            $azParams += '--resource-group', $ResourceGroup
            Write-Host "Resource Group: $ResourceGroup" -ForegroundColor White
        }

        Write-Host ""
        Write-Host "Retrieving network topology..." -ForegroundColor Yellow

        $result = & az @azParams 2>&1 | ConvertFrom-Json

        if ($LASTEXITCODE -eq 0) {
            $testResults.Results.Topology = $result

            Write-Host "Network Topology Results:" -ForegroundColor Cyan
            Write-Host "  Resources found: $($result.resources.Count)" -ForegroundColor White

            $resourceCounts = @{}
            foreach ($resource in $result.resources) {
                $resourceType = ($resource.id -split '/')[6]
                $resourceCounts[$resourceType] = ($resourceCounts[$resourceType] ?? 0) + 1
            }

            Write-Host "  Resource breakdown:" -ForegroundColor Blue
            foreach ($type in $resourceCounts.Keys) {
                Write-Host "    $type`: $($resourceCounts[$type])" -ForegroundColor White
            }
        } else {
            throw "Network topology analysis failed: $($result -join "`n")"
        }
    }

    # Execute the specified test type
    switch ($TestType) {
        "Connectivity" { Test-NetworkConnectivity }
        "IPFlow" { Test-IPFlow }
        "NextHop" { Test-NextHop }
        "SecurityGroupView" { Show-SecurityGroupView }
        "Topology" { Show-NetworkTopology }
    }

    # Export results if requested
    if ($ExportResults) {
        Write-Host ""
        Write-Host "Exporting results to: $OutputPath" -ForegroundColor Yellow
        $testResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "✓ Results exported successfully" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "✅ Network testing completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "✗ Network testing failed" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
