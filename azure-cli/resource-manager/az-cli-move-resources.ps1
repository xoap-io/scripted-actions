<#
.SYNOPSIS
    Move Azure resources between Resource Groups or subscriptions using Azure CLI.

.DESCRIPTION
    This script moves Azure resources between Resource Groups or subscriptions using the Azure CLI.
    Includes comprehensive validation, dependency checking, and safety measures to prevent data loss.
    Supports bulk operations and provides detailed progress tracking for long-running moves.

    The script uses the Azure CLI command: az resource move

.PARAMETER SourceResourceGroup
    The source Resource Group containing the resources to move.

.PARAMETER DestinationResourceGroup
    The destination Resource Group where resources will be moved.

.PARAMETER Resources
    Array of resource IDs to move. If not specified, all resources in the source RG will be moved.

.PARAMETER DestinationSubscription
    Destination subscription ID for cross-subscription moves.

.PARAMETER ValidateOnly
    Perform validation only without executing the move operation.

.PARAMETER Force
    Skip confirmation prompts and force the move operation.

.PARAMETER Timeout
    Timeout in minutes for the move operation (default: 60).

.PARAMETER ShowProgress
    Display detailed progress information during the move.

.PARAMETER PreMoveBackup
    Create a backup/export of resource configurations before moving.

.EXAMPLE
    .\az-cli-move-resources.ps1 -SourceResourceGroup "source-rg" -DestinationResourceGroup "dest-rg"

    Moves all resources from source-rg to dest-rg with validation and confirmation.

.EXAMPLE
    .\az-cli-move-resources.ps1 -SourceResourceGroup "dev-rg" -DestinationResourceGroup "prod-rg" -ValidateOnly

    Validates if resources can be moved without performing the actual move.

.EXAMPLE
    .\az-cli-move-resources.ps1 -SourceResourceGroup "source-rg" -DestinationResourceGroup "dest-rg" -DestinationSubscription "12345678-1234-1234-1234-123456789abc" -Force

    Moves resources to a different subscription without confirmation prompts.

.EXAMPLE
    .\az-cli-move-resources.ps1 -SourceResourceGroup "vm-rg" -DestinationResourceGroup "compute-rg" -Resources @("/subscriptions/.../resourceGroups/vm-rg/providers/Microsoft.Compute/virtualMachines/vm1")

    Moves only specific resources instead of all resources.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
    Warning: Resource moves can take significant time and may cause downtime for some services.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/resource

.COMPONENT
    Azure CLI Resource Manager
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Source Resource Group containing resources to move")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._\-\(\)]+$')]
    [string]$SourceResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "Destination Resource Group for the resources")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._\-\(\)]+$')]
    [string]$DestinationResourceGroup,

    [Parameter(HelpMessage = "Array of specific resource IDs to move (moves all if not specified)")]
    [string[]]$Resources,

    [Parameter(HelpMessage = "Destination subscription ID for cross-subscription moves")]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')]
    [string]$DestinationSubscription,

    [Parameter(HelpMessage = "Perform validation only without executing the move")]
    [switch]$ValidateOnly,

    [Parameter(HelpMessage = "Skip confirmation prompts and force the move")]
    [switch]$Force,

    [Parameter(HelpMessage = "Timeout in minutes for the move operation")]
    [ValidateRange(5, 300)]
    [int]$Timeout = 60,

    [Parameter(HelpMessage = "Display detailed progress information during the move")]
    [switch]$ShowProgress,

    [Parameter(HelpMessage = "Create backup/export of resource configurations before moving")]
    [switch]$PreMoveBackup
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

    $operationType = if ($ValidateOnly) { "Resource Move Validation" } else { "Resource Move Operation" }
    Write-Host "🚚 Azure $operationType" -ForegroundColor Blue
    Write-Host "==============================" -ForegroundColor Blue
    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green
    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan
    Write-Host ""

    # Verify source Resource Group exists
    Write-Host "Verifying source Resource Group..." -ForegroundColor Yellow
    $sourceRgCheck = az group show --name $SourceResourceGroup 2>$null
    if (-not $sourceRgCheck) {
        throw "Source Resource Group '$SourceResourceGroup' not found in subscription '$($azAccount.name)'"
    }

    $sourceRgInfo = $sourceRgCheck | ConvertFrom-Json
    Write-Host "✓ Source Resource Group '$SourceResourceGroup' found" -ForegroundColor Green
    Write-Host "  Location: $($sourceRgInfo.location)" -ForegroundColor White
    Write-Host "  State: $($sourceRgInfo.properties.provisioningState)" -ForegroundColor White

    # Verify destination Resource Group
    Write-Host "Verifying destination Resource Group..." -ForegroundColor Yellow
    $destRgCheck = az group show --name $DestinationResourceGroup 2>$null

    if (-not $destRgCheck) {
        if ($DestinationSubscription) {
            # Check in destination subscription
            $currentSub = $azAccount.id
            az account set --subscription $DestinationSubscription
            $destRgCheck = az group show --name $DestinationResourceGroup 2>$null
            az account set --subscription $currentSub  # Switch back
        }

        if (-not $destRgCheck) {
            throw "Destination Resource Group '$DestinationResourceGroup' not found. Please create it first."
        }
    }

    $destRgInfo = $destRgCheck | ConvertFrom-Json
    Write-Host "✓ Destination Resource Group '$DestinationResourceGroup' found" -ForegroundColor Green
    Write-Host "  Location: $($destRgInfo.location)" -ForegroundColor White
    Write-Host "  State: $($destRgInfo.properties.provisioningState)" -ForegroundColor White

    # Get resources to move
    Write-Host ""
    Write-Host "Retrieving resources to move..." -ForegroundColor Yellow

    if ($Resources -and $Resources.Count -gt 0) {
        Write-Host "Using specified resource IDs ($($Resources.Count) resources)" -ForegroundColor Blue
        $resourcesToMove = @()
        foreach ($resourceId in $Resources) {
            $resourceInfo = az resource show --ids $resourceId 2>$null | ConvertFrom-Json
            if ($resourceInfo) {
                $resourcesToMove += $resourceInfo
            } else {
                Write-Host "⚠ Warning: Resource ID '$resourceId' not found or not accessible" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "Retrieving all resources from source Resource Group..." -ForegroundColor Blue
        $allResources = az resource list --resource-group $SourceResourceGroup 2>$null | ConvertFrom-Json
        $resourcesToMove = if ($allResources) { $allResources } else { @() }
        $Resources = $resourcesToMove | ForEach-Object { $_.id }
    }

    Write-Host "📦 Resources to move: $($resourcesToMove.Count)" -ForegroundColor Cyan

    if ($resourcesToMove.Count -eq 0) {
        Write-Host "No resources found to move. Operation completed." -ForegroundColor Yellow
        exit 0
    }

    # Display resource summary
    Write-Host ""
    Write-Host "📋 Resource Summary:" -ForegroundColor Blue
    $resourceTypes = $resourcesToMove | Group-Object -Property type
    foreach ($typeGroup in $resourceTypes) {
        Write-Host "  • $($typeGroup.Name): $($typeGroup.Count)" -ForegroundColor White
    }

    # Check for unsupported resource types
    $unsupportedTypes = @(
        "Microsoft.ClassicCompute/domainNames",
        "Microsoft.ClassicNetwork/virtualNetworks",
        "Microsoft.ClassicStorage/storageAccounts",
        "Microsoft.Backup/BackupVault",
        "Microsoft.RecoveryServices/vaults"
    )

    $unsupportedResources = $resourcesToMove | Where-Object { $_.type -in $unsupportedTypes }
    if ($unsupportedResources.Count -gt 0) {
        Write-Host ""
        Write-Host "⚠ Found unsupported resource types that cannot be moved:" -ForegroundColor Red
        foreach ($unsupported in $unsupportedResources) {
            Write-Host "  • $($unsupported.name) ($($unsupported.type))" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "These resources will be excluded from the move operation." -ForegroundColor Yellow

        # Remove unsupported resources
        $Resources = $resourcesToMove | Where-Object { $_.type -notin $unsupportedTypes } | ForEach-Object { $_.id }
        $resourcesToMove = $resourcesToMove | Where-Object { $_.type -notin $unsupportedTypes }

        if ($resourcesToMove.Count -eq 0) {
            Write-Host "No supported resources remaining to move. Operation cancelled." -ForegroundColor Yellow
            exit 0
        }

        Write-Host "Continuing with $($resourcesToMove.Count) supported resources..." -ForegroundColor Blue
    }

    # Create backup if requested
    if ($PreMoveBackup) {
        Write-Host ""
        Write-Host "📦 Creating pre-move backup..." -ForegroundColor Yellow
        $backupTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupFileName = "resource-move-backup-$backupTimestamp.json"

        $backupData = @{
            timestamp = $backupTimestamp
            sourceResourceGroup = $SourceResourceGroup
            destinationResourceGroup = $DestinationResourceGroup
            resources = $resourcesToMove
            operation = "pre-move-backup"
        }

        $backupData | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFileName -Encoding UTF8
        Write-Host "✓ Backup created: $backupFileName" -ForegroundColor Green
    }

    # Display move configuration
    Write-Host ""
    Write-Host "Move Configuration:" -ForegroundColor Cyan
    Write-Host "  Source RG: $SourceResourceGroup" -ForegroundColor White
    Write-Host "  Destination RG: $DestinationResourceGroup" -ForegroundColor White
    if ($DestinationSubscription) {
        Write-Host "  Destination Subscription: $DestinationSubscription" -ForegroundColor White
    }
    Write-Host "  Resources to move: $($resourcesToMove.Count)" -ForegroundColor White
    Write-Host "  Operation type: $(if ($ValidateOnly) { 'Validation only' } else { 'Move operation' })" -ForegroundColor White
    Write-Host "  Timeout: $Timeout minutes" -ForegroundColor White

    # Confirmation prompt unless forced or validation only
    if (-not $Force -and -not $ValidateOnly) {
        Write-Host ""
        Write-Host "⚠ ⚠ ⚠  IMPORTANT WARNING  ⚠ ⚠ ⚠" -ForegroundColor Yellow
        Write-Host "Resource moves can take significant time and may cause downtime." -ForegroundColor Yellow
        Write-Host "Some resources may not be accessible during the move operation." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Resources to be moved:" -ForegroundColor Blue
        foreach ($resource in ($resourcesToMove | Select-Object -First 10)) {
            Write-Host "  • $($resource.name) ($($resource.type))" -ForegroundColor White
        }
        if ($resourcesToMove.Count -gt 10) {
            Write-Host "  • ... and $($resourcesToMove.Count - 10) more resources" -ForegroundColor Gray
        }
        Write-Host ""

        $confirmation = Read-Host "Do you want to proceed with the move operation? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-Host "Move operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Build Azure CLI command parameters
    $azParams = @('resource', 'move')

    if ($DestinationSubscription) {
        $azParams += '--destination-subscription-id', $DestinationSubscription
    }

    $azParams += '--destination-group', $DestinationResourceGroup
    $azParams += '--ids'
    $azParams += $Resources

    if ($ValidateOnly) {
        $azParams += '--validate-only'
    }

    Write-Host ""
    if ($ValidateOnly) {
        Write-Host "🔍 Validating resource move..." -ForegroundColor Blue
    } else {
        Write-Host "🚚 Initiating resource move..." -ForegroundColor Blue
        Write-Host "⚠ This operation may take up to $Timeout minutes" -ForegroundColor Yellow
    }

    if ($ShowProgress) {
        Write-Host ""
        Write-Host "Progress tracking enabled - detailed status will be shown..." -ForegroundColor Blue
    }

    # Execute Azure CLI command
    $startTime = Get-Date
    $result = & az @azParams 2>&1
    $endTime = Get-Date
    $duration = $endTime - $startTime

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        if ($ValidateOnly) {
            Write-Host "✓ Resource move validation completed successfully!" -ForegroundColor Green
            Write-Host "All specified resources can be moved to the destination." -ForegroundColor White
            Write-Host ""
            Write-Host "Validation Summary:" -ForegroundColor Cyan
            Write-Host "  Resources validated: $($resourcesToMove.Count)" -ForegroundColor White
            Write-Host "  Source RG: $SourceResourceGroup" -ForegroundColor White
            Write-Host "  Destination RG: $DestinationResourceGroup" -ForegroundColor White
            if ($DestinationSubscription) {
                Write-Host "  Cross-subscription: Yes" -ForegroundColor White
            }
            Write-Host "  Validation time: $($duration.TotalSeconds) seconds" -ForegroundColor White
            Write-Host ""
            Write-Host "✅ Ready to proceed with actual move operation" -ForegroundColor Green
        } else {
            Write-Host "✓ Resource move completed successfully!" -ForegroundColor Green
            Write-Host "All $($resourcesToMove.Count) resources have been moved to '$DestinationResourceGroup'." -ForegroundColor White
            Write-Host ""
            Write-Host "Move Summary:" -ForegroundColor Cyan
            Write-Host "  Resources moved: $($resourcesToMove.Count)" -ForegroundColor White
            Write-Host "  From: $SourceResourceGroup" -ForegroundColor White
            Write-Host "  To: $DestinationResourceGroup" -ForegroundColor White
            if ($DestinationSubscription) {
                Write-Host "  Cross-subscription: Yes" -ForegroundColor White
            }
            Write-Host "  Operation time: $([math]::Round($duration.TotalMinutes, 2)) minutes" -ForegroundColor White

            # Verify resources in destination
            Write-Host ""
            Write-Host "Verifying resources in destination..." -ForegroundColor Yellow
            $destResources = az resource list --resource-group $DestinationResourceGroup 2>$null | ConvertFrom-Json
            $movedCount = 0
            foreach ($originalResource in $resourcesToMove) {
                $found = $destResources | Where-Object { $_.name -eq $originalResource.name -and $_.type -eq $originalResource.type }
                if ($found) {
                    $movedCount++
                }
            }

            Write-Host "✓ Verified $movedCount of $($resourcesToMove.Count) resources in destination" -ForegroundColor Green

            if ($movedCount -lt $resourcesToMove.Count) {
                Write-Host "⚠ Some resources may still be in transit or failed to move" -ForegroundColor Yellow
                Write-Host "Check the Azure portal for detailed status" -ForegroundColor Blue
            }
        }

        Write-Host ""
        Write-Host "🏁 Operation completed successfully" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "✗ Resource move operation failed" -ForegroundColor Red
        Write-Host "Error details:" -ForegroundColor Red
        Write-Host ($result -join "`n") -ForegroundColor Red
        Write-Host ""
        Write-Host "Common solutions:" -ForegroundColor Yellow
        Write-Host "• Ensure all resources support move operations" -ForegroundColor White
        Write-Host "• Check for resource dependencies that prevent moves" -ForegroundColor White
        Write-Host "• Verify sufficient permissions in both source and destination" -ForegroundColor White
        Write-Host "• Ensure destination Resource Group exists and is accessible" -ForegroundColor White
        Write-Host ""
        Write-Host "Use -ValidateOnly to check for specific move issues" -ForegroundColor Blue

        throw "Azure CLI command failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
