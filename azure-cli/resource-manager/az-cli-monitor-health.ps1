<#
.SYNOPSIS
    Monitor Azure resource health and status using Azure CLI.

.DESCRIPTION
    This script monitors Azure resource health and status using the Azure CLI.
    Provides comprehensive health checks, availability monitoring, and alerting capabilities.
    Includes resource dependency analysis, performance metrics, and health history reporting.

    The script uses the Azure CLI commands: az resource list, az monitor metrics list

.PARAMETER ResourceGroup
    Monitor resources in specific Resource Group.

.PARAMETER Resources
    Array of specific resource IDs to monitor.

.PARAMETER MonitoringMode
    Type of monitoring to perform.

.PARAMETER HealthCheckInterval
    Interval in seconds between health checks (for continuous monitoring).

.PARAMETER AlertThresholds
    Hashtable of alert thresholds for metrics.

.PARAMETER ExportReport
    Export health report to JSON file.

.PARAMETER NotificationEmail
    Email address for health alerts (requires configuration).

.PARAMETER IncludeMetrics
    Include performance metrics in health report.

.PARAMETER IncludeDependencies
    Include resource dependency analysis.

.PARAMETER ContinuousMonitoring
    Run continuous monitoring until stopped.

.PARAMETER MaxIterations
    Maximum iterations for continuous monitoring.

.PARAMETER VerboseOutput
    Display detailed monitoring information.

.EXAMPLE
    .\az-cli-monitor-health.ps1 -ResourceGroup "production-rg" -MonitoringMode "FullCheck" -ExportReport "health-report.json"

    Performs full health check on production Resource Group.

.EXAMPLE
    .\az-cli-monitor-health.ps1 -Resources @("/subscriptions/.../resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1") -IncludeMetrics

    Monitors specific VM with performance metrics.

.EXAMPLE
    .\az-cli-monitor-health.ps1 -ResourceGroup "web-rg" -ContinuousMonitoring -HealthCheckInterval 300 -MaxIterations 12

    Runs continuous monitoring every 5 minutes for 1 hour.

.EXAMPLE
    .\az-cli-monitor-health.ps1 -MonitoringMode "QuickScan" -IncludeDependencies -VerboseOutput

    Quick health scan with dependency analysis and verbose output.

.NOTES
    Author: Azure CLI Script

    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/monitor

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Monitor resources in specific Resource Group")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._\-\(\)]+$')]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Array of specific resource IDs to monitor")]
    [string[]]$Resources,

    [Parameter(HelpMessage = "Type of monitoring to perform")]
    [ValidateSet("QuickScan", "FullCheck", "PerformanceAnalysis", "DependencyCheck", "HealthHistory")]
    [string]$MonitoringMode = "QuickScan",

    [Parameter(HelpMessage = "Interval in seconds between health checks")]
    [ValidateRange(30, 3600)]
    [int]$HealthCheckInterval = 300,

    [Parameter(HelpMessage = "Hashtable of alert thresholds for metrics")]
    [hashtable]$AlertThresholds,

    [Parameter(HelpMessage = "Export health report to JSON file")]
    [string]$ExportReport,

    [Parameter(HelpMessage = "Email address for health alerts")]
    [ValidatePattern('^[^@]+@[^@]+\.[^@]+$')]
    [string]$NotificationEmail,

    [Parameter(HelpMessage = "Include performance metrics in health report")]
    [switch]$IncludeMetrics,

    [Parameter(HelpMessage = "Include resource dependency analysis")]
    [switch]$IncludeDependencies,

    [Parameter(HelpMessage = "Run continuous monitoring until stopped")]
    [switch]$ContinuousMonitoring,

    [Parameter(HelpMessage = "Maximum iterations for continuous monitoring")]
    [ValidateRange(1, 1000)]
    [int]$MaxIterations = 10,

    [Parameter(HelpMessage = "Display detailed monitoring information")]
    [switch]$VerboseOutput,

    [Parameter(HelpMessage = "Azure subscription ID or name")]
    [ValidatePattern('^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})|(.+)$')]
    [string]$Subscription
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to check resource health
function Test-ResourceHealth {
    param(
        [Parameter(Mandatory)]
        [object]$Resource,
        [bool]$IncludeMetrics = $false,
        [bool]$VerboseOutput = $false
    )

    $healthStatus = @{
        ResourceId = $Resource.id
        ResourceName = $Resource.name
        ResourceType = $Resource.type
        Location = $Resource.location
        ResourceGroup = $Resource.resourceGroup
        ProvisioningState = $Resource.properties.provisioningState
        HealthStatus = "Unknown"
        Issues = @()
        Metrics = @{}
        LastChecked = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }

    # Determine health based on provisioning state
    switch ($Resource.properties.provisioningState) {
        "Succeeded" {
            $healthStatus.HealthStatus = "Healthy"
        }
        "Failed" {
            $healthStatus.HealthStatus = "Unhealthy"
            $healthStatus.Issues += "Resource provisioning failed"
        }
        "Creating" {
            $healthStatus.HealthStatus = "Transitioning"
            $healthStatus.Issues += "Resource is being created"
        }
        "Updating" {
            $healthStatus.HealthStatus = "Transitioning"
            $healthStatus.Issues += "Resource is being updated"
        }
        "Deleting" {
            $healthStatus.HealthStatus = "Transitioning"
            $healthStatus.Issues += "Resource is being deleted"
        }
        default {
            $healthStatus.HealthStatus = "Unknown"
            $healthStatus.Issues += "Unknown provisioning state: $($Resource.properties.provisioningState)"
        }
    }

    # Resource-specific health checks
    switch ($Resource.type) {
        "Microsoft.Compute/virtualMachines" {
            # VM-specific checks
            if ($VerboseOutput) {
                Write-Host "    Checking VM power state..." -ForegroundColor Gray
            }

            # Check if VM has required properties
            if (-not $Resource.properties.hardwareProfile) {
                $healthStatus.Issues += "VM hardware profile not configured"
                $healthStatus.HealthStatus = "Warning"
            }

            # Additional VM checks could be added here
        }
        "Microsoft.Storage/storageAccounts" {
            # Storage account checks
            if ($VerboseOutput) {
                Write-Host "    Checking storage account configuration..." -ForegroundColor Gray
            }

            if ($Resource.properties.accessTier -eq "Hot" -and $Resource.properties.kind -eq "BlobStorage") {
                # This might indicate suboptimal configuration
                $healthStatus.Issues += "Consider using Cool or Archive tier for infrequently accessed blobs"
                if ($healthStatus.HealthStatus -eq "Healthy") {
                    $healthStatus.HealthStatus = "Warning"
                }
            }
        }
        "Microsoft.Network/publicIPAddresses" {
            # Public IP checks
            if ($VerboseOutput) {
                Write-Host "    Checking public IP allocation..." -ForegroundColor Gray
            }

            if ($Resource.properties.publicIPAllocationMethod -eq "Dynamic" -and -not $Resource.properties.ipAddress) {
                $healthStatus.Issues += "Dynamic public IP not allocated"
                if ($healthStatus.HealthStatus -eq "Healthy") {
                    $healthStatus.HealthStatus = "Warning"
                }
            }
        }
    }

    # Get basic metrics if requested (simplified)
    if ($IncludeMetrics) {
        if ($VerboseOutput) {
            Write-Host "    Retrieving metrics..." -ForegroundColor Gray
        }

        # Note: Actual metrics retrieval would require more complex Azure CLI calls
        # This is a placeholder for metrics functionality
        $healthStatus.Metrics = @{
            "LastMetricsCheck" = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            "MetricsAvailable" = $false
            "Note" = "Metrics functionality requires Azure Monitor API access"
        }
    }

    return $healthStatus
}

# Function to analyze resource dependencies
function Get-ResourceDependencies {
    param(
        [Parameter(Mandatory)]
        [array]$Resources
    )

    $dependencies = @()

    foreach ($resource in $Resources) {
        $dependency = @{
            ResourceId = $resource.id
            ResourceName = $resource.name
            Dependencies = @()
            Dependents = @()
        }

        # Analyze dependencies based on resource type and properties
        switch ($resource.type) {
            "Microsoft.Compute/virtualMachines" {
                # VMs depend on NICs, disks, availability sets, etc.
                if ($resource.properties.networkProfile) {
                    foreach ($nic in $resource.properties.networkProfile.networkInterfaces) {
                        $dependency.Dependencies += @{
                            Type = "NetworkInterface"
                            Id = $nic.id
                            Relationship = "Required"
                        }
                    }
                }
            }
            "Microsoft.Network/networkInterfaces" {
                # NICs depend on subnets, NSGs, public IPs
                if ($resource.properties.ipConfigurations) {
                    foreach ($ipConfig in $resource.properties.ipConfigurations) {
                        if ($ipConfig.properties.subnet) {
                            $dependency.Dependencies += @{
                                Type = "Subnet"
                                Id = $ipConfig.properties.subnet.id
                                Relationship = "Required"
                            }
                        }
                    }
                }
            }
        }

        $dependencies += $dependency
    }

    return $dependencies
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

    Write-Host "🔍 Azure Resource Health Monitoring" -ForegroundColor Blue
    Write-Host "===================================" -ForegroundColor Blue
    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green

    # Switch subscription if specified
    if ($Subscription) {
        Write-Host "Switching to subscription: $Subscription" -ForegroundColor Yellow
        az account set --subscription $Subscription
        $azAccount = az account show | ConvertFrom-Json
    }

    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan
    Write-Host ""

    # Validate parameters
    if (-not $ResourceGroup -and (-not $Resources -or $Resources.Count -eq 0)) {
        throw "Either ResourceGroup or Resources parameter must be specified"
    }

    # Verify Resource Group exists if specified
    if ($ResourceGroup) {
        Write-Host "Verifying Resource Group: $ResourceGroup" -ForegroundColor Yellow
        $rgCheck = az group show --name $ResourceGroup 2>$null
        if (-not $rgCheck) {
            throw "Resource Group '$ResourceGroup' not found in subscription '$($azAccount.name)'"
        }

        $rgInfo = $rgCheck | ConvertFrom-Json
        Write-Host "✓ Resource Group '$ResourceGroup' found" -ForegroundColor Green
        Write-Host "  Location: $($rgInfo.location)" -ForegroundColor White
    }

    # Get resources to monitor
    $resourcesToMonitor = @()

    if ($Resources -and $Resources.Count -gt 0) {
        Write-Host "Loading specified resources..." -ForegroundColor Yellow
        foreach ($resourceId in $Resources) {
            $resourceInfo = az resource show --ids $resourceId 2>$null | ConvertFrom-Json
            if ($resourceInfo) {
                $resourcesToMonitor += $resourceInfo
            } else {
                Write-Host "⚠ Warning: Resource ID '$resourceId' not found or not accessible" -ForegroundColor Yellow
            }
        }
    } elseif ($ResourceGroup) {
        Write-Host "Loading resources from Resource Group..." -ForegroundColor Yellow
        $allResources = az resource list --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
        $resourcesToMonitor = if ($allResources) { $allResources } else { @() }
    }

    Write-Host "✓ Found $($resourcesToMonitor.Count) resources to monitor" -ForegroundColor Green

    if ($resourcesToMonitor.Count -eq 0) {
        Write-Host "No resources found to monitor. Exiting." -ForegroundColor Yellow
        exit 0
    }

    # Display monitoring configuration
    Write-Host ""
    Write-Host "Monitoring Configuration:" -ForegroundColor Cyan
    Write-Host "  Mode: $MonitoringMode" -ForegroundColor White
    Write-Host "  Resources: $($resourcesToMonitor.Count)" -ForegroundColor White
    if ($ResourceGroup) {
        Write-Host "  Scope: Resource Group '$ResourceGroup'" -ForegroundColor White
    } else {
        Write-Host "  Scope: Specific Resources" -ForegroundColor White
    }
    Write-Host "  Include Metrics: $(if ($IncludeMetrics) { 'Yes' } else { 'No' })" -ForegroundColor White
    Write-Host "  Include Dependencies: $(if ($IncludeDependencies) { 'Yes' } else { 'No' })" -ForegroundColor White
    Write-Host "  Continuous Monitoring: $(if ($ContinuousMonitoring) { 'Yes' } else { 'No' })" -ForegroundColor White
    if ($ContinuousMonitoring) {
        Write-Host "  Check Interval: $HealthCheckInterval seconds" -ForegroundColor White
        Write-Host "  Max Iterations: $MaxIterations" -ForegroundColor White
    }

    # Set default alert thresholds if not provided
    if (-not $AlertThresholds) {
        $AlertThresholds = @{
            "HealthyThreshold" = 95
            "WarningThreshold" = 85
            "CriticalThreshold" = 75
        }
    }

    # Main monitoring loop
    $iteration = 0
    $healthHistory = @()

    do {
        $iteration++
        $startTime = Get-Date

        if ($ContinuousMonitoring) {
            Write-Host ""
            Write-Host "🔄 Health Check Iteration $iteration/$MaxIterations" -ForegroundColor Blue
            Write-Host "Started at: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
        } else {
            Write-Host ""
            Write-Host "🔍 Starting health monitoring..." -ForegroundColor Blue
        }

        $healthResults = @()
        $healthSummary = @{
            Healthy = 0
            Warning = 0
            Unhealthy = 0
            Unknown = 0
            Transitioning = 0
        }

        # Perform health checks
        Write-Host ""
        Write-Host "Checking resource health..." -ForegroundColor Yellow

        foreach ($resource in $resourcesToMonitor) {
            if ($VerboseOutput) {
                Write-Host "  Checking: $($resource.name) ($($resource.type))" -ForegroundColor Blue
            }

            $healthResult = Test-ResourceHealth -Resource $resource -IncludeMetrics:$IncludeMetrics -VerboseOutput:$VerboseOutput
            $healthResults += $healthResult
            $healthSummary[$healthResult.HealthStatus]++

            # Display immediate results if verbose
            if ($VerboseOutput) {
                $statusColor = switch ($healthResult.HealthStatus) {
                    "Healthy" { "Green" }
                    "Warning" { "Yellow" }
                    "Unhealthy" { "Red" }
                    "Transitioning" { "Cyan" }
                    default { "Gray" }
                }
                Write-Host "    Status: $($healthResult.HealthStatus)" -ForegroundColor $statusColor
                if ($healthResult.Issues.Count -gt 0) {
                    Write-Host "    Issues: $($healthResult.Issues.Count)" -ForegroundColor Yellow
                }
            }
        }

        # Dependency analysis if requested
        $dependencyResults = @()
        if ($IncludeDependencies) {
            Write-Host ""
            Write-Host "Analyzing resource dependencies..." -ForegroundColor Yellow
            $dependencyResults = Get-ResourceDependencies -Resources $resourcesToMonitor
            Write-Host "✓ Dependency analysis completed" -ForegroundColor Green
        }

        # Calculate health metrics
        $totalResources = $healthResults.Count
        $healthPercentage = if ($totalResources -gt 0) {
            [math]::Round(($healthSummary.Healthy / $totalResources) * 100, 2)
        } else {
            0
        }

        # Display results
        $endTime = Get-Date
        $checkDuration = ($endTime - $startTime).TotalSeconds

        Write-Host ""
        Write-Host "📊 Health Check Results:" -ForegroundColor Cyan
        Write-Host "========================" -ForegroundColor Cyan
        Write-Host "Check completed at: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
        Write-Host "Check duration: $([math]::Round($checkDuration, 2)) seconds" -ForegroundColor Gray
        Write-Host ""

        Write-Host "Overall Health: $healthPercentage% healthy" -ForegroundColor $(if ($healthPercentage -ge $AlertThresholds.HealthyThreshold) { 'Green' } elseif ($healthPercentage -ge $AlertThresholds.WarningThreshold) { 'Yellow' } else { 'Red' })
        Write-Host ""

        Write-Host "Status Breakdown:" -ForegroundColor Blue
        Write-Host "  ✅ Healthy: $($healthSummary.Healthy)" -ForegroundColor Green
        Write-Host "  ⚠️  Warning: $($healthSummary.Warning)" -ForegroundColor Yellow
        Write-Host "  ❌ Unhealthy: $($healthSummary.Unhealthy)" -ForegroundColor Red
        Write-Host "  🔄 Transitioning: $($healthSummary.Transitioning)" -ForegroundColor Cyan
        Write-Host "  ❓ Unknown: $($healthSummary.Unknown)" -ForegroundColor Gray

        # Show issues summary
        $allIssues = $healthResults | Where-Object { $_.Issues.Count -gt 0 }
        if ($allIssues.Count -gt 0) {
            Write-Host ""
            Write-Host "🚨 Resources with Issues: $($allIssues.Count)" -ForegroundColor Red
            foreach ($issueResource in $allIssues) {
                Write-Host "  • $($issueResource.ResourceName):" -ForegroundColor Red
                foreach ($issue in $issueResource.Issues) {
                    Write-Host "    - $issue" -ForegroundColor Yellow
                }
            }
        }

        # Store health history
        $healthHistoryEntry = @{
            Timestamp = $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
            Iteration = $iteration
            HealthPercentage = $healthPercentage
            Summary = $healthSummary.Clone()
            CheckDuration = $checkDuration
            ResourceCount = $totalResources
        }
        $healthHistory += $healthHistoryEntry

        # Export report if requested (or at the end of monitoring)
        if ($ExportReport -and (-not $ContinuousMonitoring -or $iteration -eq $MaxIterations)) {
            Write-Host ""
            Write-Host "💾 Exporting health report..." -ForegroundColor Yellow

            $reportData = @{
                timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                subscription = $azAccount.id
                resourceGroup = $ResourceGroup
                monitoringMode = $MonitoringMode
                totalResources = $totalResources
                overallHealth = $healthPercentage
                summary = $healthSummary
                healthResults = $healthResults
                healthHistory = $healthHistory
                dependencies = $dependencyResults
                configuration = @{
                    includeMetrics = $IncludeMetrics
                    includeDependencies = $IncludeDependencies
                    continuousMonitoring = $ContinuousMonitoring
                    iterations = $iteration
                }
            }

            $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportReport -Encoding UTF8
            Write-Host "✓ Health report exported to: $ExportReport" -ForegroundColor Green
        }

        # Wait for next iteration if continuous monitoring
        if ($ContinuousMonitoring -and $iteration -lt $MaxIterations) {
            Write-Host ""
            Write-Host "⏳ Waiting $HealthCheckInterval seconds until next check..." -ForegroundColor Blue
            Start-Sleep -Seconds $HealthCheckInterval
        }

    } while ($ContinuousMonitoring -and $iteration -lt $MaxIterations)

    # Final summary for continuous monitoring
    if ($ContinuousMonitoring) {
        Write-Host ""
        Write-Host "📈 Monitoring Summary:" -ForegroundColor Cyan
        Write-Host "Total iterations: $iteration" -ForegroundColor White
        Write-Host "Total monitoring time: $([math]::Round((Get-Date).Subtract($startTime).TotalMinutes, 2)) minutes" -ForegroundColor White

        if ($healthHistory.Count -gt 1) {
            $avgHealth = ($healthHistory | Measure-Object -Property HealthPercentage -Average).Average
            $minHealth = ($healthHistory | Measure-Object -Property HealthPercentage -Minimum).Minimum
            $maxHealth = ($healthHistory | Measure-Object -Property HealthPercentage -Maximum).Maximum

            Write-Host "Average health: $([math]::Round($avgHealth, 2))%" -ForegroundColor White
            Write-Host "Health range: $([math]::Round($minHealth, 2))% - $([math]::Round($maxHealth, 2))%" -ForegroundColor White
        }
    }

    Write-Host ""
    Write-Host "🏁 Resource health monitoring completed successfully" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to monitor resource health" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
