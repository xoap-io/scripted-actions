<#
.SYNOPSIS
    List Azure Resource Groups using Azure CLI.

.DESCRIPTION
    This script lists Azure Resource Groups using the Azure CLI with flexible filtering and display options.
    Supports filtering by location, tags, managed status, and provides detailed information about each Resource Group.
    Outputs can be formatted as table, JSON, or TSV for integration with other tools.

    The script uses the Azure CLI command: az group list

.PARAMETER Location
    Filter Resource Groups by Azure location/region.

.PARAMETER Tag
    Filter Resource Groups by tag key=value pairs (e.g., "Environment=Production").

.PARAMETER ShowManagedBy
    Include the 'managedBy' property in the output for managed Resource Groups.

.PARAMETER ShowTags
    Display tags for each Resource Group in the output.

.PARAMETER OutputFormat
    Output format for the results.

.PARAMETER ShowEmpty
    Include Resource Groups that contain no resources.

.PARAMETER SortBy
    Sort Resource Groups by the specified property.

.PARAMETER Subscription
    Azure subscription ID or name to query (uses current subscription if not specified).

.EXAMPLE
    .\az-cli-list-resource-groups.ps1

    Lists all Resource Groups in the current subscription.

.EXAMPLE
    .\az-cli-list-resource-groups.ps1 -Location "East US" -ShowTags

    Lists Resource Groups in East US region with tag information.

.EXAMPLE
    .\az-cli-list-resource-groups.ps1 -Tag "Environment=Production" -OutputFormat "json"

    Lists Production Resource Groups in JSON format.

.EXAMPLE
    .\az-cli-list-resource-groups.ps1 -ShowManagedBy -SortBy "location"

    Lists all Resource Groups sorted by location, showing managed Resource Groups.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/group

.COMPONENT
    Azure CLI Resource Manager
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Filter by Azure location/region")]
    [ValidateSet(
        "East US", "East US 2", "West US", "West US 2", "West US 3", "Central US", "North Central US", "South Central US",
        "West Central US", "Canada Central", "Canada East", "Brazil South", "North Europe", "West Europe", "UK South",
        "UK West", "France Central", "Germany West Central", "Switzerland North", "Norway East", "Sweden Central",
        "UAE North", "South Africa North", "Australia East", "Australia Southeast", "East Asia", "Southeast Asia",
        "Japan East", "Japan West", "Korea Central", "India Central", "China East 2", "China North 3"
    )]
    [string]$Location,

    [Parameter(HelpMessage = "Filter by tag key=value pairs")]
    [ValidatePattern('^[a-zA-Z0-9._-]+=[a-zA-Z0-9._\s-]+$')]
    [string[]]$Tag,

    [Parameter(HelpMessage = "Include managedBy property for managed Resource Groups")]
    [switch]$ShowManagedBy,

    [Parameter(HelpMessage = "Display tags for each Resource Group")]
    [switch]$ShowTags,

    [Parameter(HelpMessage = "Output format for the results")]
    [ValidateSet("table", "json", "jsonc", "yaml", "tsv", "none")]
    [string]$OutputFormat = "table",

    [Parameter(HelpMessage = "Include Resource Groups that contain no resources")]
    [switch]$ShowEmpty,

    [Parameter(HelpMessage = "Sort Resource Groups by property")]
    [ValidateSet("name", "location", "resourceGroup", "provisioningState")]
    [string]$SortBy = "name",

    [Parameter(HelpMessage = "Azure subscription ID or name")]
    [ValidatePattern('^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})|(.+)$')]
    [string]$Subscription
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

    Write-Host "📋 Azure Resource Groups Listing" -ForegroundColor Blue
    Write-Host "================================" -ForegroundColor Blue
    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green

    # Switch subscription if specified
    if ($Subscription) {
        Write-Host "Switching to subscription: $Subscription" -ForegroundColor Yellow
        az account set --subscription $Subscription
        $azAccount = az account show | ConvertFrom-Json
    }

    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan
    Write-Host ""

    # Build Azure CLI command parameters
    $azParams = @('group', 'list')

    # Build query filter
    $queryParts = @()

    if ($Location) {
        # Convert display name to location code
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
        $locationCode = $locationMap[$Location]
        if ($locationCode) {
            $queryParts += "[?location=='$locationCode']"
        }
    }

    if ($Tag -and $Tag.Count -gt 0) {
        foreach ($tagFilter in $Tag) {
            $tagParts = $tagFilter -split '=', 2
            $tagKey = $tagParts[0]
            $tagValue = $tagParts[1]
            $queryParts += "[?tags.$tagKey=='$tagValue']"
        }
    }

    # Build output columns
    $outputColumns = @("name", "location", "properties.provisioningState")

    if ($ShowManagedBy) {
        $outputColumns += "managedBy"
    }

    if ($ShowTags) {
        $outputColumns += "tags"
    }

    # Sort specification
    $sortColumn = switch ($SortBy) {
        "location" { "location" }
        "provisioningState" { "properties.provisioningState" }
        default { "name" }
    }
    $queryParts += "sort_by(@, &$sortColumn)"

    # Combine query parts
    if ($queryParts.Count -gt 0) {
        $query = $queryParts -join " | "
        $query = "[$query].{" + (($outputColumns | ForEach-Object { "$($_): $_" }) -join ", ") + "}"
        $azParams += '--query', $query
    }

    $azParams += '--output', $OutputFormat

    Write-Host "Retrieving Resource Groups..." -ForegroundColor Yellow
    if ($Location) {
        Write-Host "  📍 Filtering by location: $Location" -ForegroundColor Blue
    }
    if ($Tag) {
        Write-Host "  🏷️ Filtering by tags: $($Tag -join ', ')" -ForegroundColor Blue
    }

    # Execute Azure CLI command
    $result = & az @azParams 2>&1

    if ($LASTEXITCODE -eq 0) {
        if ($OutputFormat -eq "table" -or $OutputFormat -eq "none") {
            # Parse and enhance table output
            $resourceGroups = az group list | ConvertFrom-Json

            # Apply manual filtering if needed (for complex scenarios)
            if ($Location) {
                $locationCode = $locationMap[$Location]
                $resourceGroups = $resourceGroups | Where-Object { $_.location -eq $locationCode }
            }

            # Count resources in each RG if ShowEmpty is specified
            if ($ShowEmpty -eq $false) {
                Write-Host "Filtering out empty Resource Groups..." -ForegroundColor Yellow
                $nonEmptyRGs = @()
                foreach ($rg in $resourceGroups) {
                    $resourceCount = (az resource list --resource-group $rg.name 2>$null | ConvertFrom-Json).Count
                    if ($resourceCount -gt 0) {
                        $rg | Add-Member -NotePropertyName ResourceCount -NotePropertyValue $resourceCount
                        $nonEmptyRGs += $rg
                    }
                }
                $resourceGroups = $nonEmptyRGs
            }

            Write-Host ""
            Write-Host "📊 Resource Groups Summary:" -ForegroundColor Cyan
            Write-Host "  Total found: $($resourceGroups.Count)" -ForegroundColor White

            if ($resourceGroups.Count -gt 0) {
                # Group by location
                $locationGroups = $resourceGroups | Group-Object -Property location
                Write-Host "  Locations:" -ForegroundColor Blue
                foreach ($locGroup in $locationGroups) {
                    $displayLocation = ($locationMap.GetEnumerator() | Where-Object { $_.Value -eq $locGroup.Name }).Key
                    if (-not $displayLocation) { $displayLocation = $locGroup.Name }
                    Write-Host "    • $displayLocation : $($locGroup.Count)" -ForegroundColor White
                }

                # Group by provisioning state
                $stateGroups = $resourceGroups | Group-Object -Property { $_.properties.provisioningState }
                Write-Host "  States:" -ForegroundColor Blue
                foreach ($stateGroup in $stateGroups) {
                    $stateColor = switch ($stateGroup.Name) {
                        "Succeeded" { "Green" }
                        "Failed" { "Red" }
                        "Creating" { "Yellow" }
                        default { "White" }
                    }
                    Write-Host "    • $($stateGroup.Name): $($stateGroup.Count)" -ForegroundColor $stateColor
                }

                Write-Host ""
                Write-Host "Resource Groups Details:" -ForegroundColor Blue
                Write-Host $("-" * 80) -ForegroundColor Gray

                foreach ($rg in $resourceGroups) {
                    $stateColor = switch ($rg.properties.provisioningState) {
                        "Succeeded" { "Green" }
                        "Failed" { "Red" }
                        "Creating" { "Yellow" }
                        default { "White" }
                    }

                    $displayLocation = ($locationMap.GetEnumerator() | Where-Object { $_.Value -eq $rg.location }).Key
                    if (-not $displayLocation) { $displayLocation = $rg.location }

                    Write-Host "🗂️  $($rg.name)" -ForegroundColor Blue
                    Write-Host "    Location: $displayLocation" -ForegroundColor White
                    Write-Host "    State: $($rg.properties.provisioningState)" -ForegroundColor $stateColor

                    if ($rg.managedBy) {
                        Write-Host "    Managed By: $($rg.managedBy)" -ForegroundColor Yellow
                    }

                    if ($ShowTags -and $rg.tags) {
                        Write-Host "    Tags:" -ForegroundColor Cyan
                        foreach ($tag in $rg.tags.PSObject.Properties) {
                            Write-Host "      $($tag.Name): $($tag.Value)" -ForegroundColor Gray
                        }
                    }

                    if ($rg.ResourceCount) {
                        Write-Host "    Resources: $($rg.ResourceCount)" -ForegroundColor Blue
                    }

                    Write-Host ""
                }
            } else {
                Write-Host "No Resource Groups found matching the specified criteria." -ForegroundColor Yellow
            }
        } else {
            # For JSON/YAML/TSV output, display the raw result
            Write-Host $result
        }

        Write-Host ""
        Write-Host "🏁 Resource Groups listing completed successfully" -ForegroundColor Green
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
