<#
.SYNOPSIS
    List Azure resources using Azure CLI.

.DESCRIPTION
    This script lists Azure resources using the Azure CLI with comprehensive filtering and display options.
    Supports filtering by resource group, location, resource type, tags, and provides detailed information about each resource.
    Includes resource inventory analysis, cost estimation hints, and export capabilities.

    The script uses the Azure CLI command: az resource list

.PARAMETER ResourceGroup
    Filter resources by Resource Group name.

.PARAMETER Location
    Filter resources by Azure location/region.

.PARAMETER ResourceType
    Filter resources by resource type (e.g., Microsoft.Compute/virtualMachines).

.PARAMETER Tag
    Filter resources by tag key=value pairs (e.g., "Environment=Production").

.PARAMETER Name
    Filter resources by name pattern (supports wildcards).

.PARAMETER ShowTags
    Display tags for each resource in the output.

.PARAMETER ShowProperties
    Display detailed properties for each resource.

.PARAMETER OutputFormat
    Output format for the results.

.PARAMETER SortBy
    Sort resources by the specified property.

.PARAMETER Subscription
    Azure subscription ID or name to query (uses current subscription if not specified).

.PARAMETER ExportToCsv
    Export results to CSV file.

.PARAMETER GroupBy
    Group resources by the specified property for summary view.

.EXAMPLE
    .\az-cli-list-resources.ps1

    Lists all resources in the current subscription.

.EXAMPLE
    .\az-cli-list-resources.ps1 -ResourceGroup "production-rg" -ShowTags

    Lists resources in specific Resource Group with tag information.

.EXAMPLE
    .\az-cli-list-resources.ps1 -ResourceType "Microsoft.Compute/virtualMachines" -Location "East US"

    Lists all Virtual Machines in East US region.

.EXAMPLE
    .\az-cli-list-resources.ps1 -Tag "Environment=Production" -GroupBy "resourceGroup"

    Lists Production resources grouped by Resource Group.

.EXAMPLE
    .\az-cli-list-resources.ps1 -Name "*web*" -ExportToCsv "web-resources.csv"

    Lists resources with 'web' in the name and exports to CSV.

.NOTES
    Author: Azure CLI Script
    Version: 1.0
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/resource

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Filter by Resource Group name")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._\-\(\)]+$')]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Filter by Azure location/region")]
    [ValidateSet(
        "East US", "East US 2", "West US", "West US 2", "West US 3", "Central US", "North Central US", "South Central US",
        "West Central US", "Canada Central", "Canada East", "Brazil South", "North Europe", "West Europe", "UK South",
        "UK West", "France Central", "Germany West Central", "Switzerland North", "Norway East", "Sweden Central",
        "UAE North", "South Africa North", "Australia East", "Australia Southeast", "East Asia", "Southeast Asia",
        "Japan East", "Japan West", "Korea Central", "India Central", "China East 2", "China North 3"
    )]
    [string]$Location,

    [Parameter(HelpMessage = "Filter by resource type")]
    [ValidateSet(
        "Microsoft.Compute/virtualMachines", "Microsoft.Compute/virtualMachineScaleSets", "Microsoft.Storage/storageAccounts",
        "Microsoft.Network/virtualNetworks", "Microsoft.Network/networkSecurityGroups", "Microsoft.Network/publicIPAddresses",
        "Microsoft.Network/loadBalancers", "Microsoft.Network/applicationGateways", "Microsoft.Web/sites",
        "Microsoft.Sql/servers", "Microsoft.DocumentDB/databaseAccounts", "Microsoft.KeyVault/vaults",
        "Microsoft.ContainerService/managedClusters", "Microsoft.OperationalInsights/workspaces"
    )]
    [string]$ResourceType,

    [Parameter(HelpMessage = "Filter by tag key=value pairs")]
    [ValidatePattern('^[a-zA-Z0-9._-]+=[a-zA-Z0-9._\s-]+$')]
    [string[]]$Tag,

    [Parameter(HelpMessage = "Filter by resource name pattern (supports wildcards)")]
    [ValidateLength(1, 100)]
    [string]$Name,

    [Parameter(HelpMessage = "Display tags for each resource")]
    [switch]$ShowTags,

    [Parameter(HelpMessage = "Display detailed properties for each resource")]
    [switch]$ShowProperties,

    [Parameter(HelpMessage = "Output format for the results")]
    [ValidateSet("table", "json", "jsonc", "yaml", "tsv", "none")]
    [string]$OutputFormat = "table",

    [Parameter(HelpMessage = "Sort resources by property")]
    [ValidateSet("name", "location", "resourceGroup", "type", "provisioningState")]
    [string]$SortBy = "name",

    [Parameter(HelpMessage = "Azure subscription ID or name")]
    [ValidatePattern('^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})|(.+)$')]
    [string]$Subscription,

    [Parameter(HelpMessage = "Export results to CSV file")]
    [ValidatePattern('\.csv$')]
    [string]$ExportToCsv,

    [Parameter(HelpMessage = "Group resources by property for summary view")]
    [ValidateSet("resourceGroup", "location", "type", "provisioningState", "tags")]
    [string]$GroupBy
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

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

    Write-Host "📋 Azure Resources Listing" -ForegroundColor Blue
    Write-Host "==========================" -ForegroundColor Blue
    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green

    # Switch subscription if specified
    if ($Subscription) {
        Write-Host "Switching to subscription: $Subscription" -ForegroundColor Yellow
        az account set --subscription $Subscription
        $azAccount = az account show | ConvertFrom-Json
    }

    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan
    Write-Host ""

    # Location mapping for display names
    $locationMap = @{
        "East US" = "eastus"; "East US 2" = "eastus2"; "West US" = "westus"; "West US 2" = "westus2"; "West US 3" = "westus3"
        "Central US" = "centralus"; "North Central US" = "northcentralus"; "South Central US" = "southcentralus"
        "West Central US" = "westcentralus"; "Canada Central" = "canadacentral"; "Canada East" = "canadaeast"
        "Brazil South" = "brazilsouth"; "North Europe" = "northeurope"; "West Europe" = "westeurope"
        "UK South" = "uksouth"; "UK West" = "ukwest"; "France Central" = "francecentral"
        "Germany West Central" = "germanywestcentral"; "Switzerland North" = "switzerlandnorth"
        "Norway East" = "norwayeast"; "Sweden Central" = "swedencentral"; "UAE North" = "uaenorth"
        "South Africa North" = "southafricanorth"; "Australia East" = "australiaeast"
        "Australia Southeast" = "australiasoutheast"; "East Asia" = "eastasia"; "Southeast Asia" = "southeastasia"
        "Japan East" = "japaneast"; "Japan West" = "japanwest"; "Korea Central" = "koreacentral"
        "India Central" = "centralindia"; "China East 2" = "chinaeast2"; "China North 3" = "chinanorth3"
    }

    # Build Azure CLI command parameters
    $azParams = @('resource', 'list')

    # Add filters
    if ($ResourceGroup) {
        $azParams += '--resource-group', $ResourceGroup
        Write-Host "  📁 Filtering by Resource Group: $ResourceGroup" -ForegroundColor Blue
    }

    if ($Location) {
        $locationCode = $locationMap[$Location]
        if ($locationCode) {
            $azParams += '--location', $locationCode
            Write-Host "  📍 Filtering by location: $Location" -ForegroundColor Blue
        }
    }

    if ($ResourceType) {
        $azParams += '--resource-type', $ResourceType
        Write-Host "  🔧 Filtering by resource type: $ResourceType" -ForegroundColor Blue
    }

    if ($Name) {
        $azParams += '--name', $Name
        Write-Host "  🏷️ Filtering by name pattern: $Name" -ForegroundColor Blue
    }

    if ($Tag -and $Tag.Count -gt 0) {
        foreach ($tagFilter in $Tag) {
            $azParams += '--tag', $tagFilter
        }
        Write-Host "  🏷️ Filtering by tags: $($Tag -join ', ')" -ForegroundColor Blue
    }

    $azParams += '--output', 'json'

    Write-Host ""
    Write-Host "Retrieving resources..." -ForegroundColor Yellow

    # Execute Azure CLI command
    $resourcesJson = & az @azParams 2>&1

    if ($LASTEXITCODE -eq 0) {
        $resources = $resourcesJson | ConvertFrom-Json

        if (-not $resources) {
            $resources = @()
        }

        Write-Host "✓ Retrieved $($resources.Count) resources" -ForegroundColor Green
        Write-Host ""

        if ($resources.Count -eq 0) {
            Write-Host "No resources found matching the specified criteria." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "🏁 Resource listing completed" -ForegroundColor Green
            return
        }

        # Sort resources
        $resources = switch ($SortBy) {
            "location" { $resources | Sort-Object location }
            "resourceGroup" { $resources | Sort-Object resourceGroup }
            "type" { $resources | Sort-Object type }
            "provisioningState" { $resources | Sort-Object { $_.properties.provisioningState } }
            default { $resources | Sort-Object name }
        }

        # Display summary statistics
        Write-Host "📊 Resource Summary:" -ForegroundColor Cyan
        Write-Host "  Total resources: $($resources.Count)" -ForegroundColor White

        # Group by resource type
        $typeGroups = $resources | Group-Object -Property type
        Write-Host "  Resource types: $($typeGroups.Count)" -ForegroundColor White
        foreach ($typeGroup in ($typeGroups | Sort-Object Count -Descending | Select-Object -First 5)) {
            Write-Host "    • $($typeGroup.Name): $($typeGroup.Count)" -ForegroundColor Blue
        }
        if ($typeGroups.Count -gt 5) {
            Write-Host "    • ... and $($typeGroups.Count - 5) more types" -ForegroundColor Gray
        }

        # Group by location
        $locationGroups = $resources | Group-Object -Property location
        Write-Host "  Locations: $($locationGroups.Count)" -ForegroundColor White
        foreach ($locGroup in ($locationGroups | Sort-Object Count -Descending | Select-Object -First 3)) {
            $displayLocation = ($locationMap.GetEnumerator() | Where-Object { $_.Value -eq $locGroup.Name }).Key
            if (-not $displayLocation) { $displayLocation = $locGroup.Name }
            Write-Host "    • $displayLocation : $($locGroup.Count)" -ForegroundColor Blue
        }

        # Group by Resource Group
        $rgGroups = $resources | Group-Object -Property resourceGroup
        Write-Host "  Resource Groups: $($rgGroups.Count)" -ForegroundColor White

        Write-Host ""

        # Handle grouping if specified
        if ($GroupBy) {
            Write-Host "📋 Resources grouped by $GroupBy :" -ForegroundColor Blue
            Write-Host $("-" * 60) -ForegroundColor Gray

            $groupProperty = switch ($GroupBy) {
                "provisioningState" { { $_.properties.provisioningState } }
                "tags" { { ($_.tags | ConvertTo-Json -Compress) } }
                default { $GroupBy }
            }

            $groups = $resources | Group-Object -Property $groupProperty | Sort-Object Count -Descending

            foreach ($group in $groups) {
                $groupName = if ($group.Name) { $group.Name } else { "(none)" }
                Write-Host ""
                Write-Host "🗂️  $groupName ($($group.Count) resources)" -ForegroundColor Blue

                foreach ($resource in ($group.Group | Select-Object -First 10)) {
                    $stateColor = switch ($resource.properties.provisioningState) {
                        "Succeeded" { "Green" }
                        "Failed" { "Red" }
                        "Running" { "Yellow" }
                        default { "White" }
                    }

                    $displayLocation = ($locationMap.GetEnumerator() | Where-Object { $_.Value -eq $resource.location }).Key
                    if (-not $displayLocation) { $displayLocation = $resource.location }

                    Write-Host "  • $($resource.name)" -ForegroundColor White
                    Write-Host "    Type: $($resource.type)" -ForegroundColor Gray
                    Write-Host "    Location: $displayLocation" -ForegroundColor Gray
                    Write-Host "    RG: $($resource.resourceGroup)" -ForegroundColor Gray
                    Write-Host "    State: $($resource.properties.provisioningState)" -ForegroundColor $stateColor
                }

                if ($group.Count -gt 10) {
                    Write-Host "  ... and $($group.Count - 10) more resources" -ForegroundColor Gray
                }
            }
        } else {
            # Display detailed resource list
            Write-Host "📋 Resource Details:" -ForegroundColor Blue
            Write-Host $("-" * 100) -ForegroundColor Gray

            foreach ($resource in $resources) {
                $stateColor = switch ($resource.properties.provisioningState) {
                    "Succeeded" { "Green" }
                    "Failed" { "Red" }
                    "Running" { "Yellow" }
                    default { "White" }
                }

                $displayLocation = ($locationMap.GetEnumerator() | Where-Object { $_.Value -eq $resource.location }).Key
                if (-not $displayLocation) { $displayLocation = $resource.location }

                Write-Host ""
                Write-Host "🔧 $($resource.name)" -ForegroundColor Blue
                Write-Host "   Type: $($resource.type)" -ForegroundColor White
                Write-Host "   Resource Group: $($resource.resourceGroup)" -ForegroundColor White
                Write-Host "   Location: $displayLocation" -ForegroundColor White
                Write-Host "   State: $($resource.properties.provisioningState)" -ForegroundColor $stateColor
                Write-Host "   ID: $($resource.id)" -ForegroundColor Gray

                if ($ShowTags -and $resource.tags) {
                    Write-Host "   Tags:" -ForegroundColor Cyan
                    foreach ($tag in $resource.tags.PSObject.Properties) {
                        Write-Host "     $($tag.Name): $($tag.Value)" -ForegroundColor Gray
                    }
                }

                if ($ShowProperties -and $resource.properties) {
                    Write-Host "   Properties:" -ForegroundColor Cyan
                    $resource.properties.PSObject.Properties | ForEach-Object {
                        if ($_.Value -and $_.Value.ToString().Length -lt 100) {
                            Write-Host "     $($_.Name): $($_.Value)" -ForegroundColor Gray
                        }
                    }
                }
            }
        }

        # Export to CSV if requested
        if ($ExportToCsv) {
            Write-Host ""
            Write-Host "💾 Exporting to CSV: $ExportToCsv" -ForegroundColor Yellow

            $csvData = $resources | Select-Object name, type, resourceGroup, location,
                @{Name='provisioningState'; Expression={$_.properties.provisioningState}},
                @{Name='tags'; Expression={($_.tags | ConvertTo-Json -Compress)}},
                id

            $csvData | Export-Csv -Path $ExportToCsv -NoTypeInformation
            Write-Host "✓ Exported $($resources.Count) resources to $ExportToCsv" -ForegroundColor Green
        }

        # Output in requested format if not table
        if ($OutputFormat -ne "table") {
            Write-Host ""
            Write-Host "📄 Raw output in $OutputFormat format:" -ForegroundColor Blue
            Write-Host $("-" * 40) -ForegroundColor Gray

            $formatParams = @('resource', 'list') + $azParams[2..($azParams.Count-3)] + @('--output', $OutputFormat)
            & az @formatParams
        }

        Write-Host ""
        Write-Host "🏁 Resource listing completed successfully" -ForegroundColor Green
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($resourcesJson -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to list resources" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
