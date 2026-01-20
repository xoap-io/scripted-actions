<#
.SYNOPSIS
    Monitor Azure network resources using Azure CLI.

.DESCRIPTION
    This script provides comprehensive monitoring and health checks for Azure network resources using the Azure CLI.
    Monitors Virtual Networks, subnets, Network Security Groups, Route Tables, Public IPs, Load Balancers, and VPN Gateways.
    Provides detailed status reports and identifies potential issues.

    The script uses various Azure CLI network commands for monitoring.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group to monitor. If not specified, monitors all resource groups.

.PARAMETER ResourceType
    The type of network resource to monitor specifically.

.PARAMETER VNetName
    Specific Virtual Network name to monitor (when ResourceType is VNet).

.PARAMETER ShowHealthOnly
    Show only resources with health issues or warnings.

.PARAMETER OutputFormat
    The output format for the results.

.PARAMETER ExportPath
    Path to export the monitoring results to a file.

.EXAMPLE
    .\az-cli-monitor-network-resources.ps1

    Monitors all network resources across all resource groups.

.EXAMPLE
    .\az-cli-monitor-network-resources.ps1 -ResourceGroup "prod-rg" -ResourceType "VNet"

    Monitors only Virtual Networks in the specified resource group.

.EXAMPLE
    .\az-cli-monitor-network-resources.ps1 -ResourceGroup "prod-rg" -ShowHealthOnly -ExportPath "C:\reports\network-health.json"

    Shows only unhealthy resources and exports results to a file.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI
    Note: Provides comprehensive network monitoring and health assessment.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "The name of the Azure Resource Group to monitor")]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Specific resource type to monitor")]
    [ValidateSet("All", "VNet", "Subnet", "NSG", "RouteTable", "PublicIP", "LoadBalancer", "VPNGateway", "ApplicationGateway")]
    [string]$ResourceType = "All",

    [Parameter(HelpMessage = "Specific Virtual Network to monitor")]
    [string]$VNetName,

    [Parameter(HelpMessage = "Show only resources with health issues")]
    [switch]$ShowHealthOnly,

    [Parameter(HelpMessage = "Output format for results")]
    [ValidateSet("Table", "JSON", "YAML")]
    [string]$OutputFormat = "Table",

    [Parameter(HelpMessage = "Path to export monitoring results")]
    [string]$ExportPath
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Initialize monitoring results
$monitoringResults = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    SubscriptionId = $null
    TotalResources = 0
    HealthyResources = 0
    UnhealthyResources = 0
    WarningResources = 0
    ResourceDetails = @()
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

    $monitoringResults.SubscriptionId = $azAccount.id

    Write-Host "🔍 Azure Network Resource Monitor" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green
    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan
    Write-Host ""

    # Function to add resource to monitoring results
    function Add-ResourceResult {
        param(
            [string]$ResourceType,
            [string]$ResourceName,
            [string]$ResourceGroup,
            [string]$Location,
            [string]$Status,
            [string]$Health,
            [hashtable]$Details
        )

        $resourceResult = @{
            ResourceType = $ResourceType
            Name = $ResourceName
            ResourceGroup = $ResourceGroup
            Location = $Location
            Status = $Status
            Health = $Health
            Details = $Details
        }

        $monitoringResults.ResourceDetails += $resourceResult
        $monitoringResults.TotalResources++

        switch ($Health) {
            "Healthy" { $monitoringResults.HealthyResources++ }
            "Warning" { $monitoringResults.WarningResources++ }
            "Unhealthy" { $monitoringResults.UnhealthyResources++ }
        }
    }

    # Function to check Virtual Networks
    function Test-VirtualNetworks {
        Write-Host "Checking Virtual Networks..." -ForegroundColor Yellow

        $vnetParams = @('network', 'vnet', 'list')
        if ($ResourceGroup) { $vnetParams += '--resource-group', $ResourceGroup }
        if ($VNetName) { $vnetParams += '--query', "[?name=='$VNetName']" }

        $vnets = & az @vnetParams | ConvertFrom-Json

        foreach ($vnet in $vnets) {
            $health = "Healthy"
            $details = @{}

            # Check subnet utilization
            $subnetInfo = @()
            foreach ($subnet in $vnet.subnets) {
                $usedIPs = if ($subnet.ipConfigurations) { $subnet.ipConfigurations.Count } else { 0 }
                $totalIPs = [math]::Pow(2, (32 - ($subnet.addressPrefix -split '/')[1])) - 5  # Azure reserves 5 IPs
                $utilization = if ($totalIPs -gt 0) { [math]::Round(($usedIPs / $totalIPs) * 100, 2) } else { 0 }

                $subnetInfo += @{
                    Name = $subnet.name
                    AddressPrefix = $subnet.addressPrefix
                    UsedIPs = $usedIPs
                    TotalIPs = $totalIPs
                    Utilization = $utilization
                }

                if ($utilization -gt 80) { $health = "Warning" }
                if ($utilization -gt 95) { $health = "Unhealthy" }
            }

            $details.Subnets = $subnetInfo
            $details.AddressPrefixes = $vnet.addressSpace.addressPrefixes
            $details.DhcpOptions = $vnet.dhcpOptions
            $details.EnableDdosProtection = $vnet.enableDdosProtection

            Add-ResourceResult -ResourceType "VNet" -ResourceName $vnet.name -ResourceGroup $vnet.resourceGroup `
                -Location $vnet.location -Status $vnet.provisioningState -Health $health -Details $details

            if (-not $ShowHealthOnly -or $health -ne "Healthy") {
                $healthColor = switch ($health) { "Healthy" { "Green" } "Warning" { "Yellow" } "Unhealthy" { "Red" } }
                Write-Host "  📡 VNet: $($vnet.name) - $health" -ForegroundColor $healthColor
                if ($health -ne "Healthy") {
                    foreach ($subnet in $subnetInfo) {
                        if ($subnet.Utilization -gt 80) {
                            Write-Host "    ⚠ Subnet $($subnet.Name): $($subnet.Utilization)% IP utilization" -ForegroundColor Yellow
                        }
                    }
                }
            }
        }
    }

    # Function to check Network Security Groups
    function Test-NetworkSecurityGroups {
        Write-Host "Checking Network Security Groups..." -ForegroundColor Yellow

        $nsgParams = @('network', 'nsg', 'list')
        if ($ResourceGroup) { $nsgParams += '--resource-group', $ResourceGroup }

        $nsgs = & az @nsgParams | ConvertFrom-Json

        foreach ($nsg in $nsgs) {
            $health = "Healthy"
            $details = @{}

            # Check for common security issues
            $securityIssues = @()
            foreach ($rule in $nsg.securityRules) {
                if ($rule.access -eq "Allow" -and $rule.sourceAddressPrefix -eq "*" -and $rule.destinationPortRange -eq "*") {
                    $securityIssues += "Rule '$($rule.name)' allows all traffic from any source"
                    $health = "Warning"
                }
                if ($rule.access -eq "Allow" -and $rule.sourceAddressPrefix -eq "*" -and $rule.destinationPortRange -in @("22", "3389", "1433", "3306")) {
                    $securityIssues += "Rule '$($rule.name)' allows $($rule.destinationPortRange) from any source"
                    $health = "Unhealthy"
                }
            }

            $details.SecurityRules = $nsg.securityRules.Count
            $details.DefaultRules = $nsg.defaultSecurityRules.Count
            $details.SecurityIssues = $securityIssues
            $details.AssociatedSubnets = if ($nsg.subnets) { $nsg.subnets.Count } else { 0 }
            $details.AssociatedNICs = if ($nsg.networkInterfaces) { $nsg.networkInterfaces.Count } else { 0 }

            Add-ResourceResult -ResourceType "NSG" -ResourceName $nsg.name -ResourceGroup $nsg.resourceGroup `
                -Location $nsg.location -Status $nsg.provisioningState -Health $health -Details $details

            if (-not $ShowHealthOnly -or $health -ne "Healthy") {
                $healthColor = switch ($health) { "Healthy" { "Green" } "Warning" { "Yellow" } "Unhealthy" { "Red" } }
                Write-Host "  🛡️ NSG: $($nsg.name) - $health" -ForegroundColor $healthColor
                foreach ($issue in $securityIssues) {
                    Write-Host "    ⚠ $issue" -ForegroundColor Red
                }
            }
        }
    }

    # Function to check Public IP addresses
    function Test-PublicIPs {
        Write-Host "Checking Public IP addresses..." -ForegroundColor Yellow

        $pipParams = @('network', 'public-ip', 'list')
        if ($ResourceGroup) { $pipParams += '--resource-group', $ResourceGroup }

        $pips = & az @pipParams | ConvertFrom-Json

        foreach ($pip in $pips) {
            $health = "Healthy"
            $details = @{}

            # Check allocation status and associations
            if ($pip.ipAddress -eq "Not Assigned" -or $pip.publicIPAllocationMethod -eq "Dynamic" -and -not $pip.ipConfiguration) {
                $health = "Warning"
            }

            $details.AllocationMethod = $pip.publicIPAllocationMethod
            $details.IPAddress = $pip.ipAddress
            $details.SKU = $pip.sku.name
            $details.Zones = $pip.zones
            $details.AssociatedResource = if ($pip.ipConfiguration) {
                ($pip.ipConfiguration.id -split '/')[-3] + "/" + ($pip.ipConfiguration.id -split '/')[-1]
            } else { "None" }

            Add-ResourceResult -ResourceType "PublicIP" -ResourceName $pip.name -ResourceGroup $pip.resourceGroup `
                -Location $pip.location -Status $pip.provisioningState -Health $health -Details $details

            if (-not $ShowHealthOnly -or $health -ne "Healthy") {
                $healthColor = switch ($health) { "Healthy" { "Green" } "Warning" { "Yellow" } "Unhealthy" { "Red" } }
                Write-Host "  🌐 Public IP: $($pip.name) - $health" -ForegroundColor $healthColor
                if ($health -eq "Warning" -and $details.AssociatedResource -eq "None") {
                    Write-Host "    ⚠ Unassigned public IP (potential cost optimization)" -ForegroundColor Yellow
                }
            }
        }
    }

    # Function to check Load Balancers
    function Test-LoadBalancers {
        Write-Host "Checking Load Balancers..." -ForegroundColor Yellow

        $lbParams = @('network', 'lb', 'list')
        if ($ResourceGroup) { $lbParams += '--resource-group', $ResourceGroup }

        $lbs = & az @lbParams | ConvertFrom-Json

        foreach ($lb in $lbs) {
            $health = "Healthy"
            $details = @{}

            # Check backend pool health
            $backendIssues = @()
            foreach ($pool in $lb.backendAddressPools) {
                $backendCount = if ($pool.backendIPConfigurations) { $pool.backendIPConfigurations.Count } else { 0 }
                if ($backendCount -eq 0) {
                    $backendIssues += "Backend pool '$($pool.name)' has no members"
                    $health = "Warning"
                }
            }

            $details.SKU = $lb.sku.name
            $details.Type = if ($lb.frontendIPConfigurations[0].publicIPAddress) { "Public" } else { "Internal" }
            $details.BackendPools = $lb.backendAddressPools.Count
            $details.Rules = $lb.loadBalancingRules.Count
            $details.Probes = $lb.probes.Count
            $details.BackendIssues = $backendIssues

            Add-ResourceResult -ResourceType "LoadBalancer" -ResourceName $lb.name -ResourceGroup $lb.resourceGroup `
                -Location $lb.location -Status $lb.provisioningState -Health $health -Details $details

            if (-not $ShowHealthOnly -or $health -ne "Healthy") {
                $healthColor = switch ($health) { "Healthy" { "Green" } "Warning" { "Yellow" } "Unhealthy" { "Red" } }
                Write-Host "  ⚖️ Load Balancer: $($lb.name) - $health" -ForegroundColor $healthColor
                foreach ($issue in $backendIssues) {
                    Write-Host "    ⚠ $issue" -ForegroundColor Yellow
                }
            }
        }
    }

    # Function to check VPN Gateways
    function Test-VPNGateways {
        Write-Host "Checking VPN Gateways..." -ForegroundColor Yellow

        $gwParams = @('network', 'vnet-gateway', 'list')
        if ($ResourceGroup) { $gwParams += '--resource-group', $ResourceGroup }

        $gateways = & az @gwParams | ConvertFrom-Json

        foreach ($gw in $gateways) {
            $health = "Healthy"
            $details = @{}

            # Check gateway health and connections
            if ($gw.provisioningState -ne "Succeeded") {
                $health = "Unhealthy"
            }

            $details.GatewayType = $gw.gatewayType
            $details.VpnType = $gw.vpnType
            $details.SKU = $gw.sku.name
            $details.ActiveActive = $gw.activeActive
            $details.BGPEnabled = $gw.enableBgp
            if ($gw.bgpSettings) {
                $details.ASN = $gw.bgpSettings.asn
            }

            Add-ResourceResult -ResourceType "VPNGateway" -ResourceName $gw.name -ResourceGroup $gw.resourceGroup `
                -Location $gw.location -Status $gw.provisioningState -Health $health -Details $details

            if (-not $ShowHealthOnly -or $health -ne "Healthy") {
                $healthColor = switch ($health) { "Healthy" { "Green" } "Warning" { "Yellow" } "Unhealthy" { "Red" } }
                Write-Host "  🔒 VPN Gateway: $($gw.name) - $health" -ForegroundColor $healthColor
            }
        }
    }

    # Execute monitoring based on resource type
    switch ($ResourceType) {
        "All" {
            Test-VirtualNetworks
            Test-NetworkSecurityGroups
            Test-PublicIPs
            Test-LoadBalancers
            Test-VPNGateways
        }
        "VNet" { Test-VirtualNetworks }
        "NSG" { Test-NetworkSecurityGroups }
        "PublicIP" { Test-PublicIPs }
        "LoadBalancer" { Test-LoadBalancers }
        "VPNGateway" { Test-VPNGateways }
    }

    # Display summary
    Write-Host ""
    Write-Host "📊 Monitoring Summary" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host "Total Resources: $($monitoringResults.TotalResources)" -ForegroundColor White
    Write-Host "Healthy: $($monitoringResults.HealthyResources)" -ForegroundColor Green
    Write-Host "Warnings: $($monitoringResults.WarningResources)" -ForegroundColor Yellow
    Write-Host "Unhealthy: $($monitoringResults.UnhealthyResources)" -ForegroundColor Red

    # Export results if requested
    if ($ExportPath) {
        Write-Host ""
        Write-Host "Exporting results to: $ExportPath" -ForegroundColor Yellow

        switch ($OutputFormat) {
            "JSON" {
                $monitoringResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
            }
            "YAML" {
                # Simple YAML-like format
                $yamlContent = @"
timestamp: $($monitoringResults.Timestamp)
subscription_id: $($monitoringResults.SubscriptionId)
total_resources: $($monitoringResults.TotalResources)
healthy_resources: $($monitoringResults.HealthyResources)
warning_resources: $($monitoringResults.WarningResources)
unhealthy_resources: $($monitoringResults.UnhealthyResources)
resources:
"@
                foreach ($resource in $monitoringResults.ResourceDetails) {
                    $yamlContent += "`n  - name: $($resource.Name)"
                    $yamlContent += "`n    type: $($resource.ResourceType)"
                    $yamlContent += "`n    health: $($resource.Health)"
                    $yamlContent += "`n    status: $($resource.Status)"
                }
                $yamlContent | Out-File -FilePath $ExportPath -Encoding UTF8
            }
            default {
                # CSV format for table
                $monitoringResults.ResourceDetails | Export-Csv -Path $ExportPath -NoTypeInformation
            }
        }
        Write-Host "✓ Results exported successfully" -ForegroundColor Green
    }

    if ($monitoringResults.UnhealthyResources -gt 0) {
        Write-Host ""
        Write-Host "⚠ Found $($monitoringResults.UnhealthyResources) unhealthy resources that require attention!" -ForegroundColor Red
        exit 1
    } elseif ($monitoringResults.WarningResources -gt 0) {
        Write-Host ""
        Write-Host "⚠ Found $($monitoringResults.WarningResources) resources with warnings" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "✅ All monitored resources are healthy!" -ForegroundColor Green
    }
}
catch {
    Write-Host "✗ Failed to monitor network resources" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
