<#
.SYNOPSIS
    Apply tags to Azure resources and Resource Groups using Azure CLI.

.DESCRIPTION
    This script applies tags to Azure resources and Resource Groups using the Azure CLI.
    Supports bulk tagging operations, tag inheritance, compliance tagging, and tag management.
    Includes validation, conflict resolution, and reporting capabilities for enterprise tag governance.

    The script uses the Azure CLI commands: az resource tag, az group update

.PARAMETER ResourceGroup
    Target Resource Group for tagging operations.

.PARAMETER Resources
    Array of specific resource IDs to tag (tags all resources in RG if not specified).

.PARAMETER Tags
    Hashtable of tags to apply (key=value pairs).

.PARAMETER TagsFromFile
    Path to JSON file containing tags to apply.

.PARAMETER Operation
    Tag operation type: merge (add/update), replace (replace all), or delete (remove tags).

.PARAMETER InheritFromResourceGroup
    Apply Resource Group tags to all resources within it.

.PARAMETER TagResourceGroup
    Apply tags to the Resource Group itself.

.PARAMETER Force
    Overwrite existing tags without confirmation.

.PARAMETER WhatIf
    Show what tags would be applied without making changes.

.PARAMETER ComplianceTemplate
    Apply predefined compliance tag templates.

.PARAMETER ReportExisting
    Generate a report of existing tags before applying changes.

.EXAMPLE
    .\az-cli-tag-resources.ps1 -ResourceGroup "production-rg" -Tags @{"Environment"="Production"; "Owner"="TeamA"}

    Applies Environment and Owner tags to all resources in the Resource Group.

.EXAMPLE
    .\az-cli-tag-resources.ps1 -ResourceGroup "dev-rg" -TagsFromFile "tags.json" -TagResourceGroup

    Applies tags from JSON file to Resource Group and all its resources.

.EXAMPLE
    .\az-cli-tag-resources.ps1 -Resources @("/subscriptions/.../resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1") -Tags @{"CostCenter"="12345"} -Operation "merge"

    Merges CostCenter tag with existing tags on specific resource.

.EXAMPLE
    .\az-cli-tag-resources.ps1 -ResourceGroup "compliance-rg" -ComplianceTemplate "DataClassification" -ReportExisting

    Applies data classification compliance tags with existing tags report.

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
    https://learn.microsoft.com/en-us/cli/azure/resource

.COMPONENT
    Azure CLI Resource Manager
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Target Resource Group for tagging operations")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._\-\(\)]+$')]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Array of specific resource IDs to tag")]
    [string[]]$Resources,

    [Parameter(HelpMessage = "Hashtable of tags to apply")]
    [hashtable]$Tags,

    [Parameter(HelpMessage = "Path to JSON file containing tags to apply")]
    [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
    [string]$TagsFromFile,

    [Parameter(HelpMessage = "Tag operation type")]
    [ValidateSet("merge", "replace", "delete")]
    [string]$Operation = "merge",

    [Parameter(HelpMessage = "Apply Resource Group tags to all resources within it")]
    [switch]$InheritFromResourceGroup,

    [Parameter(HelpMessage = "Apply tags to the Resource Group itself")]
    [switch]$TagResourceGroup,

    [Parameter(HelpMessage = "Overwrite existing tags without confirmation")]
    [switch]$Force,

    [Parameter(HelpMessage = "Show what tags would be applied without making changes")]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Apply predefined compliance tag templates")]
    [ValidateSet("DataClassification", "CostManagement", "Security", "Governance", "Environment")]
    [string]$ComplianceTemplate,

    [Parameter(HelpMessage = "Generate a report of existing tags before applying changes")]
    [switch]$ReportExisting,

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

    Write-Host "🏷️ Azure Resource Tagging" -ForegroundColor Blue
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

    # Validate parameters
    if (-not $ResourceGroup -and -not $Resources) {
        throw "Either ResourceGroup or Resources parameter must be specified"
    }

    if (-not $Tags -and -not $TagsFromFile -and -not $InheritFromResourceGroup -and -not $ComplianceTemplate) {
        throw "Must specify tags via Tags, TagsFromFile, InheritFromResourceGroup, or ComplianceTemplate parameter"
    }

    # Load tags from file if specified
    if ($TagsFromFile) {
        Write-Host "Loading tags from file: $TagsFromFile" -ForegroundColor Yellow
        $fileContent = Get-Content -Path $TagsFromFile -Raw | ConvertFrom-Json
        $Tags = @{}
        foreach ($property in $fileContent.PSObject.Properties) {
            $Tags[$property.Name] = $property.Value
        }
        Write-Host "✓ Loaded $($Tags.Count) tags from file" -ForegroundColor Green
    }

    # Apply compliance template if specified
    if ($ComplianceTemplate) {
        Write-Host "Applying compliance template: $ComplianceTemplate" -ForegroundColor Yellow

        $complianceTags = switch ($ComplianceTemplate) {
            "DataClassification" {
                @{
                    "DataClassification" = "Internal"
                    "DataSensitivity" = "Standard"
                    "DataRetention" = "Standard"
                    "ComplianceScope" = "General"
                }
            }
            "CostManagement" {
                @{
                    "CostCenter" = "Unknown"
                    "Project" = "General"
                    "Budget" = "Standard"
                    "CostOwner" = "IT"
                }
            }
            "Security" {
                @{
                    "SecurityLevel" = "Standard"
                    "SecurityContact" = "SecurityTeam"
                    "SecurityReviewDate" = (Get-Date).AddDays(365).ToString("yyyy-MM-dd")
                    "SecurityCompliance" = "Required"
                }
            }
            "Governance" {
                @{
                    "ResourceOwner" = "IT"
                    "BusinessUnit" = "Corporate"
                    "ReviewDate" = (Get-Date).AddDays(90).ToString("yyyy-MM-dd")
                    "Criticality" = "Medium"
                }
            }
            "Environment" {
                @{
                    "Environment" = "Production"
                    "Lifecycle" = "Active"
                    "MaintenanceWindow" = "Saturday 02:00-04:00 UTC"
                    "SupportLevel" = "Standard"
                }
            }
        }

        if ($Tags) {
            # Merge with existing tags
            foreach ($key in $complianceTags.Keys) {
                if (-not $Tags.ContainsKey($key)) {
                    $Tags[$key] = $complianceTags[$key]
                }
            }
        } else {
            $Tags = $complianceTags
        }

        Write-Host "✓ Applied $($complianceTags.Count) compliance tags" -ForegroundColor Green
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

    # Get resources to tag
    $resourcesToTag = @()

    if ($Resources -and $Resources.Count -gt 0) {
        Write-Host "Using specified resource IDs..." -ForegroundColor Blue
        foreach ($resourceId in $Resources) {
            $resourceInfo = az resource show --ids $resourceId 2>$null | ConvertFrom-Json
            if ($resourceInfo) {
                $resourcesToTag += $resourceInfo
            } else {
                Write-Host "⚠ Warning: Resource ID '$resourceId' not found or not accessible" -ForegroundColor Yellow
            }
        }
    } elseif ($ResourceGroup) {
        Write-Host "Retrieving all resources from Resource Group..." -ForegroundColor Blue
        $allResources = az resource list --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
        $resourcesToTag = if ($allResources) { $allResources } else { @() }
    }

    # Handle Resource Group tag inheritance
    if ($InheritFromResourceGroup -and $ResourceGroup) {
        Write-Host "Retrieving Resource Group tags for inheritance..." -ForegroundColor Yellow
        $rgTags = $rgInfo.tags
        if ($rgTags) {
            $inheritedTags = @{}
            foreach ($property in $rgTags.PSObject.Properties) {
                $inheritedTags[$property.Name] = $property.Value
            }

            if ($Tags) {
                # Merge with existing tags (Tags parameter takes precedence)
                foreach ($key in $inheritedTags.Keys) {
                    if (-not $Tags.ContainsKey($key)) {
                        $Tags[$key] = $inheritedTags[$key]
                    }
                }
            } else {
                $Tags = $inheritedTags
            }

            Write-Host "✓ Inherited $($inheritedTags.Count) tags from Resource Group" -ForegroundColor Green
        } else {
            Write-Host "No tags found on Resource Group to inherit" -ForegroundColor Yellow
        }
    }

    # Display tagging configuration
    Write-Host ""
    Write-Host "Tagging Configuration:" -ForegroundColor Cyan
    if ($ResourceGroup) {
        Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
    }
    Write-Host "  Resources to tag: $($resourcesToTag.Count)" -ForegroundColor White
    Write-Host "  Tags to apply: $($Tags.Count)" -ForegroundColor White
    Write-Host "  Operation: $Operation" -ForegroundColor White
    if ($TagResourceGroup) {
        Write-Host "  Tag Resource Group: Yes" -ForegroundColor White
    }
    Write-Host "  What-If mode: $(if ($WhatIf) { 'Yes' } else { 'No' })" -ForegroundColor White

    Write-Host ""
    Write-Host "Tags to apply:" -ForegroundColor Blue
    foreach ($tag in $Tags.GetEnumerator()) {
        Write-Host "  $($tag.Key): $($tag.Value)" -ForegroundColor White
    }

    # Generate existing tags report if requested
    if ($ReportExisting) {
        Write-Host ""
        Write-Host "📊 Existing Tags Report:" -ForegroundColor Blue
        Write-Host $("-" * 60) -ForegroundColor Gray

        $allExistingTags = @{}

        if ($TagResourceGroup -and $ResourceGroup) {
            Write-Host "Resource Group Tags:" -ForegroundColor Yellow
            if ($rgInfo.tags) {
                foreach ($property in $rgInfo.tags.PSObject.Properties) {
                    Write-Host "  $($property.Name): $($property.Value)" -ForegroundColor White
                    $allExistingTags[$property.Name] = $property.Value
                }
            } else {
                Write-Host "  (No tags)" -ForegroundColor Gray
            }
            Write-Host ""
        }

        Write-Host "Resource Tags Summary:" -ForegroundColor Yellow
        $tagStats = @{}

        foreach ($resource in $resourcesToTag) {
            Write-Host "🔧 $($resource.name) ($($resource.type))" -ForegroundColor Blue
            if ($resource.tags) {
                foreach ($property in $resource.tags.PSObject.Properties) {
                    Write-Host "    $($property.Name): $($property.Value)" -ForegroundColor White
                    if ($tagStats.ContainsKey($property.Name)) {
                        $tagStats[$property.Name]++
                    } else {
                        $tagStats[$property.Name] = 1
                    }
                }
            } else {
                Write-Host "    (No tags)" -ForegroundColor Gray
            }
        }

        if ($tagStats.Count -gt 0) {
            Write-Host ""
            Write-Host "Tag Usage Statistics:" -ForegroundColor Cyan
            foreach ($tagStat in ($tagStats.GetEnumerator() | Sort-Object Value -Descending)) {
                Write-Host "  $($tagStat.Key): $($tagStat.Value) resources" -ForegroundColor White
            }
        }

        Write-Host ""
    }

    # What-If analysis
    if ($WhatIf) {
        Write-Host ""
        Write-Host "🔍 What-If Analysis:" -ForegroundColor Yellow
        Write-Host $("-" * 40) -ForegroundColor Gray

        if ($TagResourceGroup -and $ResourceGroup) {
            Write-Host "Resource Group '$ResourceGroup' would be tagged with:" -ForegroundColor Blue
            foreach ($tag in $Tags.GetEnumerator()) {
                $existingValue = if ($rgInfo.tags -and $rgInfo.tags.PSObject.Properties[$tag.Key]) {
                    $rgInfo.tags.PSObject.Properties[$tag.Key].Value
                } else {
                    "(new)"
                }
                Write-Host "  $($tag.Key): $($tag.Value) $(if ($existingValue -ne '(new)') { "(was: $existingValue)" })" -ForegroundColor White
            }
            Write-Host ""
        }

        foreach ($resource in ($resourcesToTag | Select-Object -First 5)) {
            Write-Host "Resource '$($resource.name)' would be tagged with:" -ForegroundColor Blue
            foreach ($tag in $Tags.GetEnumerator()) {
                $existingValue = if ($resource.tags -and $resource.tags.PSObject.Properties[$tag.Key]) {
                    $resource.tags.PSObject.Properties[$tag.Key].Value
                } else {
                    "(new)"
                }
                Write-Host "  $($tag.Key): $($tag.Value) $(if ($existingValue -ne '(new)') { "(was: $existingValue)" })" -ForegroundColor White
            }
            Write-Host ""
        }

        if ($resourcesToTag.Count -gt 5) {
            Write-Host "... and $($resourcesToTag.Count - 5) more resources" -ForegroundColor Gray
        }

        Write-Host "🏁 What-If analysis completed - no changes made" -ForegroundColor Green
        exit 0
    }

    # Confirmation prompt unless forced
    if (-not $Force) {
        Write-Host ""
        Write-Host "⚠ Tagging Confirmation" -ForegroundColor Yellow
        Write-Host "This will apply tags to:" -ForegroundColor White
        if ($TagResourceGroup) {
            Write-Host "  • Resource Group: $ResourceGroup" -ForegroundColor Blue
        }
        Write-Host "  • $($resourcesToTag.Count) resources" -ForegroundColor Blue
        Write-Host ""
        Write-Host "Operation: $Operation" -ForegroundColor White
        Write-Host "Tags to apply: $($Tags.Count)" -ForegroundColor White
        Write-Host ""

        $confirmation = Read-Host "Do you want to proceed with the tagging operation? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-Host "Tagging operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Execute tagging operations
    Write-Host ""
    Write-Host "🏷️ Applying tags..." -ForegroundColor Blue
    $startTime = Get-Date
    $successCount = 0
    $errorCount = 0

    # Tag Resource Group if requested
    if ($TagResourceGroup -and $ResourceGroup) {
        Write-Host "Tagging Resource Group..." -ForegroundColor Yellow
        try {
            $rgTagParams = @('group', 'update', '--name', $ResourceGroup, '--tags')
            foreach ($tag in $Tags.GetEnumerator()) {
                $rgTagParams += "$($tag.Key)=$($tag.Value)"
            }

            & az @rgTagParams | Out-Null
            Write-Host "✓ Resource Group tagged successfully" -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host "✗ Failed to tag Resource Group: $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
        }
    }

    # Tag resources
    $current = 0
    foreach ($resource in $resourcesToTag) {
        $current++
        $percentComplete = [math]::Round(($current / $resourcesToTag.Count) * 100, 1)
        Write-Host "[$current/$($resourcesToTag.Count)] ($percentComplete%) Tagging: $($resource.name)" -ForegroundColor Yellow

        try {
            $resourceTagParams = @('resource', 'tag', '--ids', $resource.id)

            if ($Operation -eq "replace") {
                $resourceTagParams += '--tags'
                foreach ($tag in $Tags.GetEnumerator()) {
                    $resourceTagParams += "$($tag.Key)=$($tag.Value)"
                }
            } elseif ($Operation -eq "merge") {
                $resourceTagParams += '--tags'
                foreach ($tag in $Tags.GetEnumerator()) {
                    $resourceTagParams += "$($tag.Key)=$($tag.Value)"
                }
                $resourceTagParams += '--operation', 'merge'
            } elseif ($Operation -eq "delete") {
                $resourceTagParams += '--tags'
                foreach ($tag in $Tags.GetEnumerator()) {
                    $resourceTagParams += $tag.Key
                }
                $resourceTagParams += '--operation', 'delete'
            }

            & az @resourceTagParams | Out-Null
            $successCount++
        }
        catch {
            Write-Host "  ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
        }
    }

    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host ""
    Write-Host "✓ Tagging operation completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Operation Summary:" -ForegroundColor Cyan
    Write-Host "  Successful operations: $successCount" -ForegroundColor Green
    Write-Host "  Failed operations: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Total resources processed: $($resourcesToTag.Count)" -ForegroundColor White
    Write-Host "  Tags applied: $($Tags.Count)" -ForegroundColor White
    Write-Host "  Operation time: $([math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor White

    Write-Host ""
    Write-Host "🏁 Resource tagging completed successfully" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
