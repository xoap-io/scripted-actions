<#
.SYNOPSIS
    Perform bulk network operations on Azure resources using Azure CLI.

.DESCRIPTION
    This script performs bulk operations on Azure network resources using the Azure CLI.
    Supports bulk creation, deletion, configuration, and management of network resources.
    Includes batch processing capabilities with error handling and progress tracking.

    The script uses various Azure CLI network commands for bulk operations.

.PARAMETER Operation
    The bulk operation to perform on network resources.

.PARAMETER ResourceType
    The type of network resource to operate on.

.PARAMETER ConfigFile
    Path to JSON configuration file containing resource definitions.

.PARAMETER ResourceGroup
    The Azure Resource Group for bulk operations.

.PARAMETER Location
    The Azure region for resource deployment.

.PARAMETER NamePrefix
    Prefix for resource names when creating multiple resources.

.PARAMETER Count
    Number of resources to create (when applicable).

.PARAMETER TagsFilter
    Filter resources by tags (JSON format) for bulk operations.

.PARAMETER Force
    Force operations without confirmation prompts.

.PARAMETER DryRun
    Preview operations without actually executing them.

.PARAMETER ContinueOnError
    Continue processing other resources if one fails.

.PARAMETER ParallelJobs
    Number of parallel jobs for bulk operations.

.PARAMETER ExportResults
    Export operation results to a file.

.PARAMETER OutputPath
    Path to save operation results.

.EXAMPLE
    .\az-cli-bulk-network-operations.ps1 -Operation "Create" -ResourceType "PublicIP" -ResourceGroup "bulk-rg" -Location "East US" -NamePrefix "bulk-pip" -Count 5

    Creates 5 public IP addresses with sequential naming.

.EXAMPLE
    .\az-cli-bulk-network-operations.ps1 -Operation "Delete" -ResourceType "NSG" -ResourceGroup "cleanup-rg" -TagsFilter '{"Environment":"Test"}' -Force

    Deletes all NSGs tagged with Environment=Test.

.EXAMPLE
    .\az-cli-bulk-network-operations.ps1 -Operation "Configure" -ConfigFile "network-config.json" -DryRun

    Previews bulk configuration from JSON file without executing.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
    Note: Use with caution for bulk deletion operations.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network

.COMPONENT
    Azure CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Bulk operation to perform")]
    [ValidateSet("Create", "Delete", "Configure", "List", "Update", "Associate", "Disassociate")]
    [string]$Operation,

    [Parameter(HelpMessage = "Type of network resource")]
    [ValidateSet("VNet", "Subnet", "NSG", "RouteTable", "PublicIP", "LoadBalancer", "ApplicationGateway", "VPNGateway", "LocalGateway", "VNetPeering")]
    [string]$ResourceType,

    [Parameter(HelpMessage = "Configuration file path (JSON format)")]
    [string]$ConfigFile,

    [Parameter(HelpMessage = "Azure Resource Group")]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Azure region")]
    [ValidateSet(
        "East US", "East US 2", "West US", "West US 2", "West US 3", "Central US", "North Central US", "South Central US",
        "Canada Central", "Canada East", "Brazil South", "North Europe", "West Europe", "UK South", "UK West",
        "France Central", "Germany West Central", "Switzerland North", "Norway East", "Sweden Central",
        "Australia East", "Australia Southeast", "Southeast Asia", "East Asia", "Japan East", "Japan West",
        "Korea Central", "Central India", "South India", "West India", "UAE North", "South Africa North"
    )]
    [string]$Location = "East US",

    [Parameter(HelpMessage = "Name prefix for resources")]
    [ValidateLength(1, 20)]
    [string]$NamePrefix = "bulk",

    [Parameter(HelpMessage = "Number of resources to create")]
    [ValidateRange(1, 100)]
    [int]$Count = 1,

    [Parameter(HelpMessage = "Filter by tags (JSON format)")]
    [string]$TagsFilter,

    [Parameter(HelpMessage = "Force operations without confirmation")]
    [switch]$Force,

    [Parameter(HelpMessage = "Preview operations without executing")]
    [switch]$DryRun,

    [Parameter(HelpMessage = "Continue on individual resource errors")]
    [switch]$ContinueOnError,

    [Parameter(HelpMessage = "Number of parallel jobs")]
    [ValidateRange(1, 10)]
    [int]$ParallelJobs = 3,

    [Parameter(HelpMessage = "Export operation results")]
    [switch]$ExportResults,

    [Parameter(HelpMessage = "Output path for results")]
    [string]$OutputPath = "bulk-operations-results.json"
)

# Set strict error handling
$ErrorActionPreference = if ($ContinueOnError) { 'Continue' } else { 'Stop' }

# Initialize results tracking
$bulkResults = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    Operation = $Operation
    ResourceType = $ResourceType
    TotalOperations = 0
    SuccessfulOperations = 0
    FailedOperations = 0
    Details = @()
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

    Write-Host "🔄 Azure Bulk Network Operations" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green
    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan
    Write-Host ""

    if ($DryRun) {
        Write-Host "🔍 DRY RUN MODE - No actual changes will be made" -ForegroundColor Yellow
        Write-Host ""
    }

    # Function to add operation result
    function Add-OperationResult {
        param(
            [string]$ResourceName,
            [string]$Status,
            [string]$Message,
            [hashtable]$Details = @{}
        )

        $result = @{
            ResourceName = $ResourceName
            Status = $Status
            Message = $Message
            Details = $Details
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }

        $bulkResults.Details += $result
        $bulkResults.TotalOperations++

        if ($Status -eq "Success") {
            $bulkResults.SuccessfulOperations++
        } else {
            $bulkResults.FailedOperations++
        }
    }

    # Function to load configuration from file
    function Get-ConfigurationFromFile {
        if (-not (Test-Path $ConfigFile)) {
            throw "Configuration file not found: $ConfigFile"
        }

        try {
            $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            Write-Host "✓ Configuration loaded from file: $ConfigFile" -ForegroundColor Green
            return $config
        }
        catch {
            throw "Failed to parse configuration file: $($_.Exception.Message)"
        }
    }

    # Function to filter resources by tags
    function Get-FilteredResources {
        param([array]$Resources)

        if (-not $TagsFilter) {
            return $Resources
        }

        try {
            $tagFilter = $TagsFilter | ConvertFrom-Json
            $filtered = @()

            foreach ($resource in $Resources) {
                $match = $true
                foreach ($key in $tagFilter.PSObject.Properties.Name) {
                    if (-not $resource.tags -or $resource.tags.$key -ne $tagFilter.$key) {
                        $match = $false
                        break
                    }
                }
                if ($match) {
                    $filtered += $resource
                }
            }

            Write-Host "✓ Filtered to $($filtered.Count) resources based on tags" -ForegroundColor Green
            return $filtered
        }
        catch {
            Write-Host "⚠ Warning: Invalid tags filter format. Proceeding without filtering." -ForegroundColor Yellow
            return $Resources
        }
    }

    # Function to create multiple public IPs
    function New-BulkPublicIPs {
        Write-Host "Creating $Count public IP addresses..." -ForegroundColor Yellow

        for ($i = 1; $i -le $Count; $i++) {
            $pipName = "$NamePrefix-pip-$($i.ToString('D3'))"

            if ($DryRun) {
                Write-Host "  [DRY RUN] Would create: $pipName" -ForegroundColor Blue
                Add-OperationResult -ResourceName $pipName -Status "Success" -Message "Dry run - would create public IP"
                continue
            }

            try {
                $azParams = @(
                    'network', 'public-ip', 'create',
                    '--name', $pipName,
                    '--resource-group', $ResourceGroup,
                    '--location', $Location,
                    '--sku', 'Standard',
                    '--allocation-method', 'Static'
                )

                Write-Host "  Creating: $pipName" -ForegroundColor Cyan
                $result = & az @azParams 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✓ Created successfully" -ForegroundColor Green
                    Add-OperationResult -ResourceName $pipName -Status "Success" -Message "Public IP created successfully"
                } else {
                    Write-Host "    ✗ Failed to create" -ForegroundColor Red
                    Add-OperationResult -ResourceName $pipName -Status "Failed" -Message "Creation failed: $($result -join ' ')"
                }
            }
            catch {
                Write-Host "    ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
                Add-OperationResult -ResourceName $pipName -Status "Failed" -Message $_.Exception.Message
            }
        }
    }

    # Function to delete resources by type
    function Remove-BulkResources {
        Write-Host "Retrieving $ResourceType resources for deletion..." -ForegroundColor Yellow

        $azListParams = @('network')

        switch ($ResourceType) {
            "VNet" { $azListParams += 'vnet', 'list' }
            "NSG" { $azListParams += 'nsg', 'list' }
            "PublicIP" { $azListParams += 'public-ip', 'list' }
            "RouteTable" { $azListParams += 'route-table', 'list' }
            "LoadBalancer" { $azListParams += 'lb', 'list' }
            default { throw "Bulk deletion not supported for resource type: $ResourceType" }
        }

        if ($ResourceGroup) {
            $azListParams += '--resource-group', $ResourceGroup
        }

        $resources = & az @azListParams | ConvertFrom-Json
        $filteredResources = Get-FilteredResources -Resources $resources

        if ($filteredResources.Count -eq 0) {
            Write-Host "No resources found matching the criteria" -ForegroundColor Yellow
            return
        }

        Write-Host "Found $($filteredResources.Count) $ResourceType resources for deletion" -ForegroundColor White

        if (-not $Force -and -not $DryRun) {
            Write-Host ""
            Write-Host "⚠ WARNING: This will permanently delete $($filteredResources.Count) resources!" -ForegroundColor Red
            foreach ($resource in $filteredResources) {
                Write-Host "  • $($resource.name) (RG: $($resource.resourceGroup))" -ForegroundColor Yellow
            }
            Write-Host ""
            $confirmation = Read-Host "Are you sure you want to proceed? (yes/no)"
            if ($confirmation -ne "yes") {
                Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                return
            }
        }

        foreach ($resource in $filteredResources) {
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would delete: $($resource.name)" -ForegroundColor Blue
                Add-OperationResult -ResourceName $resource.name -Status "Success" -Message "Dry run - would delete resource"
                continue
            }

            try {
                $azDeleteParams = @('network')

                switch ($ResourceType) {
                    "VNet" { $azDeleteParams += 'vnet', 'delete' }
                    "NSG" { $azDeleteParams += 'nsg', 'delete' }
                    "PublicIP" { $azDeleteParams += 'public-ip', 'delete' }
                    "RouteTable" { $azDeleteParams += 'route-table', 'delete' }
                    "LoadBalancer" { $azDeleteParams += 'lb', 'delete' }
                }

                $azDeleteParams += '--name', $resource.name
                $azDeleteParams += '--resource-group', $resource.resourceGroup
                $azDeleteParams += '--yes'

                Write-Host "  Deleting: $($resource.name)" -ForegroundColor Cyan
                $result = & az @azDeleteParams 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✓ Deleted successfully" -ForegroundColor Green
                    Add-OperationResult -ResourceName $resource.name -Status "Success" -Message "Resource deleted successfully"
                } else {
                    Write-Host "    ✗ Failed to delete" -ForegroundColor Red
                    Add-OperationResult -ResourceName $resource.name -Status "Failed" -Message "Deletion failed: $($result -join ' ')"
                }
            }
            catch {
                Write-Host "    ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
                Add-OperationResult -ResourceName $resource.name -Status "Failed" -Message $_.Exception.Message
            }
        }
    }

    # Function to configure resources from file
    function Set-BulkConfiguration {
        $config = Get-ConfigurationFromFile

        if (-not $config.resources) {
            throw "Configuration file must contain a 'resources' array"
        }

        Write-Host "Processing $($config.resources.Count) resources from configuration..." -ForegroundColor Yellow

        foreach ($resourceConfig in $config.resources) {
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would configure: $($resourceConfig.name)" -ForegroundColor Blue
                Add-OperationResult -ResourceName $resourceConfig.name -Status "Success" -Message "Dry run - would configure resource"
                continue
            }

            try {
                # Build Azure CLI command based on resource configuration
                $azParams = @('network', $resourceConfig.type.ToLower(), 'create')

                foreach ($property in $resourceConfig.properties.PSObject.Properties) {
                    $azParams += "--$($property.Name.Replace('_', '-'))", $property.Value
                }

                Write-Host "  Configuring: $($resourceConfig.name)" -ForegroundColor Cyan
                $result = & az @azParams 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✓ Configured successfully" -ForegroundColor Green
                    Add-OperationResult -ResourceName $resourceConfig.name -Status "Success" -Message "Resource configured successfully"
                } else {
                    Write-Host "    ✗ Failed to configure" -ForegroundColor Red
                    Add-OperationResult -ResourceName $resourceConfig.name -Status "Failed" -Message "Configuration failed: $($result -join ' ')"
                }
            }
            catch {
                Write-Host "    ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
                Add-OperationResult -ResourceName $resourceConfig.name -Status "Failed" -Message $_.Exception.Message
            }
        }
    }

    # Function to list resources with details
    function Get-BulkResourceList {
        Write-Host "Listing $ResourceType resources..." -ForegroundColor Yellow

        $azListParams = @('network')

        switch ($ResourceType) {
            "VNet" { $azListParams += 'vnet', 'list' }
            "NSG" { $azListParams += 'nsg', 'list' }
            "PublicIP" { $azListParams += 'public-ip', 'list' }
            "RouteTable" { $azListParams += 'route-table', 'list' }
            "LoadBalancer" { $azListParams += 'lb', 'list' }
            default { $azListParams += $ResourceType.ToLower(), 'list' }
        }

        if ($ResourceGroup) {
            $azListParams += '--resource-group', $ResourceGroup
        }

        $resources = & az @azListParams | ConvertFrom-Json
        $filteredResources = Get-FilteredResources -Resources $resources

        Write-Host "Resource List Summary:" -ForegroundColor Cyan
        Write-Host "  Total Resources: $($filteredResources.Count)" -ForegroundColor White
        Write-Host ""

        foreach ($resource in $filteredResources) {
            Write-Host "  📋 $($resource.name)" -ForegroundColor Blue
            Write-Host "     Resource Group: $($resource.resourceGroup)" -ForegroundColor White
            Write-Host "     Location: $($resource.location)" -ForegroundColor White
            Write-Host "     Provisioning State: $($resource.provisioningState)" -ForegroundColor White
            if ($resource.tags) {
                Write-Host "     Tags: $($resource.tags | ConvertTo-Json -Compress)" -ForegroundColor White
            }
            Write-Host ""

            Add-OperationResult -ResourceName $resource.name -Status "Success" -Message "Resource listed" -Details @{
                ResourceGroup = $resource.resourceGroup
                Location = $resource.location
                ProvisioningState = $resource.provisioningState
                Tags = $resource.tags
            }
        }
    }

    # Execute the specified operation
    switch ($Operation) {
        "Create" {
            if ($ConfigFile) {
                Set-BulkConfiguration
            } elseif ($ResourceType -eq "PublicIP") {
                New-BulkPublicIPs
            } else {
                throw "Bulk creation for $ResourceType requires a configuration file"
            }
        }
        "Delete" {
            Remove-BulkResources
        }
        "Configure" {
            if (-not $ConfigFile) {
                throw "Configure operation requires a configuration file"
            }
            Set-BulkConfiguration
        }
        "List" {
            Get-BulkResourceList
        }
        default {
            throw "Operation '$Operation' is not yet implemented for bulk operations"
        }
    }

    # Display operation summary
    Write-Host ""
    Write-Host "📊 Bulk Operation Summary" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    Write-Host "Operation: $Operation" -ForegroundColor White
    Write-Host "Resource Type: $ResourceType" -ForegroundColor White
    Write-Host "Total Operations: $($bulkResults.TotalOperations)" -ForegroundColor White
    Write-Host "Successful: $($bulkResults.SuccessfulOperations)" -ForegroundColor Green
    Write-Host "Failed: $($bulkResults.FailedOperations)" -ForegroundColor Red

    if ($bulkResults.FailedOperations -gt 0) {
        Write-Host ""
        Write-Host "Failed Operations:" -ForegroundColor Red
        foreach ($detail in $bulkResults.Details | Where-Object { $_.Status -eq "Failed" }) {
            Write-Host "  ✗ $($detail.ResourceName): $($detail.Message)" -ForegroundColor Red
        }
    }

    # Export results if requested
    if ($ExportResults) {
        Write-Host ""
        Write-Host "Exporting results to: $OutputPath" -ForegroundColor Yellow
        $bulkResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "✓ Results exported successfully" -ForegroundColor Green
    }

    if ($bulkResults.FailedOperations -eq 0) {
        Write-Host ""
        Write-Host "✅ All bulk operations completed successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "⚠ Bulk operations completed with $($bulkResults.FailedOperations) failures" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
