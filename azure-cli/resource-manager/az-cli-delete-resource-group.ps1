<#
.SYNOPSIS
    Delete an Azure Resource Group using Azure CLI.

.DESCRIPTION
    This script deletes an Azure Resource Group using the Azure CLI with comprehensive safety checks and validation.
    Includes resource inventory, dependency checking, and confirmation prompts to prevent accidental deletion.
    Supports force deletion for specific resource types and background operation modes.

    The script uses the Azure CLI command: az group delete

.PARAMETER ResourceGroup
    The name of the Azure Resource Group to delete.

.PARAMETER ForceDeletionTypes
    Comma-separated list of resource types to force delete.

.PARAMETER NoWait
    Run the deletion operation in the background without waiting for completion.

.PARAMETER Force
    Skip confirmation prompts and force deletion.

.PARAMETER ShowResources
    Display all resources in the Resource Group before deletion.

.PARAMETER SkipDependencyCheck
    Skip checking for dependencies and locks.

.EXAMPLE
    .\az-cli-delete-resource-group.ps1 -ResourceGroup "test-rg"

    Deletes a Resource Group with safety checks and confirmation.

.EXAMPLE
    .\az-cli-delete-resource-group.ps1 -ResourceGroup "dev-rg" -Force -NoWait

    Forces deletion without confirmation and runs in background.

.EXAMPLE
    .\az-cli-delete-resource-group.ps1 -ResourceGroup "vm-rg" -ForceDeletionTypes "Microsoft.Compute/virtualMachines,Microsoft.Compute/virtualMachineScaleSets" -ShowResources

    Deletes Resource Group with force deletion for VMs and shows resource inventory.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
    Warning: This operation permanently deletes all resources in the Resource Group.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/group

.COMPONENT
    Azure CLI Resource Manager
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group to delete")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Comma-separated resource types to force delete")]
    [ValidateSet(
        "Microsoft.Compute/virtualMachineScaleSets",
        "Microsoft.Compute/virtualMachines",
        "Microsoft.Databricks/workspaces",
        "Microsoft.HDInsight/clusters",
        "Microsoft.Kusto/clusters",
        "Microsoft.MachineLearningServices/workspaces",
        "Microsoft.NetApp/netAppAccounts",
        "Microsoft.Cache/Redis"
    )]
    [string[]]$ForceDeletionTypes,

    [Parameter(HelpMessage = "Run deletion in background without waiting for completion")]
    [switch]$NoWait,

    [Parameter(HelpMessage = "Skip confirmation prompts and force deletion")]
    [switch]$Force,

    [Parameter(HelpMessage = "Display all resources in the Resource Group before deletion")]
    [switch]$ShowResources,

    [Parameter(HelpMessage = "Skip checking for resource locks and dependencies")]
    [switch]$SkipDependencyCheck
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

    Write-Host "🗑️ Azure Resource Group Deletion" -ForegroundColor Red
    Write-Host "================================" -ForegroundColor Red
    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green
    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan
    Write-Host ""

    # Verify the Resource Group exists
    Write-Host "Verifying Resource Group exists..." -ForegroundColor Yellow
    $rgCheck = az group show --name $ResourceGroup 2>$null
    if (-not $rgCheck) {
        throw "Resource Group '$ResourceGroup' not found in subscription '$($azAccount.name)'"
    }

    $rgInfo = $rgCheck | ConvertFrom-Json
    Write-Host "✓ Resource Group '$ResourceGroup' found" -ForegroundColor Green

    # Display Resource Group details
    Write-Host "Resource Group Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($rgInfo.name)" -ForegroundColor White
    Write-Host "  Location: $($rgInfo.location)" -ForegroundColor White
    Write-Host "  Provisioning State: $($rgInfo.properties.provisioningState)" -ForegroundColor White
    if ($rgInfo.managedBy) {
        Write-Host "  Managed By: $($rgInfo.managedBy)" -ForegroundColor Yellow
        Write-Host "  ⚠ This is a managed Resource Group!" -ForegroundColor Yellow
    }
    if ($rgInfo.tags) {
        Write-Host "  Tags:" -ForegroundColor White
        foreach ($tag in $rgInfo.tags.PSObject.Properties) {
            Write-Host "    $($tag.Name): $($tag.Value)" -ForegroundColor White
        }
    }
    Write-Host ""

    # Get resource inventory unless skipped
    Write-Host "Retrieving resource inventory..." -ForegroundColor Yellow
    $resources = az resource list --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
    $resourceCount = if ($resources) { $resources.Count } else { 0 }

    Write-Host "📊 Resource Inventory Summary:" -ForegroundColor Cyan
    Write-Host "  Total Resources: $resourceCount" -ForegroundColor White

    if ($resourceCount -eq 0) {
        Write-Host "  🎉 Resource Group is empty" -ForegroundColor Green
    } else {
        # Group resources by type
        $resourceGroups = $resources | Group-Object -Property type
        Write-Host "  Resource Types:" -ForegroundColor Blue
        foreach ($group in $resourceGroups) {
            Write-Host "    • $($group.Name): $($group.Count)" -ForegroundColor White
        }

        # Show detailed resource list if requested
        if ($ShowResources) {
            Write-Host ""
            Write-Host "📋 Detailed Resource List:" -ForegroundColor Blue
            foreach ($resource in $resources) {
                $statusColor = switch ($resource.properties.provisioningState) {
                    "Succeeded" { "Green" }
                    "Failed" { "Red" }
                    "Running" { "Yellow" }
                    default { "White" }
                }
                Write-Host "  🔹 $($resource.name)" -ForegroundColor Blue
                Write-Host "     Type: $($resource.type)" -ForegroundColor White
                Write-Host "     Location: $($resource.location)" -ForegroundColor White
                Write-Host "     Status: $($resource.properties.provisioningState)" -ForegroundColor $statusColor
                if ($resource.tags) {
                    Write-Host "     Tags: $($resource.tags | ConvertTo-Json -Compress)" -ForegroundColor Gray
                }
                Write-Host ""
            }
        }
    }

    # Check for resource locks unless skipped
    if (-not $SkipDependencyCheck) {
        Write-Host "Checking for resource locks..." -ForegroundColor Yellow
        $locks = az lock list --resource-group $ResourceGroup 2>$null | ConvertFrom-Json

        if ($locks -and $locks.Count -gt 0) {
            Write-Host "🔒 Found $($locks.Count) resource lock(s):" -ForegroundColor Red
            foreach ($lock in $locks) {
                Write-Host "  • $($lock.name) ($($lock.level)): $($lock.notes)" -ForegroundColor Red
            }

            if (-not $Force) {
                Write-Host ""
                Write-Host "⚠ Resource locks prevent deletion. Remove locks first or use -Force to override." -ForegroundColor Red
                $confirmation = Read-Host "Do you want to continue anyway? (yes/no)"
                if ($confirmation -ne "yes") {
                    Write-Host "Deletion cancelled due to resource locks." -ForegroundColor Yellow
                    exit 0
                }
            }
        } else {
            Write-Host "✓ No resource locks found" -ForegroundColor Green
        }

        # Check for policy assignments
        Write-Host "Checking for policy assignments..." -ForegroundColor Yellow
        $policies = az policy assignment list --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
        if ($policies -and $policies.Count -gt 0) {
            Write-Host "📋 Found $($policies.Count) policy assignment(s)" -ForegroundColor Blue
            foreach ($policy in $policies) {
                Write-Host "  • $($policy.displayName): $($policy.policyDefinitionId -split '/')[-1]" -ForegroundColor Blue
            }
        } else {
            Write-Host "✓ No policy assignments found" -ForegroundColor Green
        }
    }

    # Warning and confirmation prompt unless forced
    if (-not $Force) {
        Write-Host ""
        Write-Host "⚠ ⚠ ⚠  CRITICAL WARNING  ⚠ ⚠ ⚠" -ForegroundColor Red
        Write-Host "This will PERMANENTLY DELETE the Resource Group '$ResourceGroup'" -ForegroundColor Red
        Write-Host "and ALL $resourceCount resources it contains!" -ForegroundColor Red
        Write-Host "This action CANNOT be undone!" -ForegroundColor Red
        Write-Host ""

        if ($resourceCount -gt 0) {
            Write-Host "Resources that will be deleted:" -ForegroundColor Yellow
            foreach ($group in $resourceGroups) {
                Write-Host "  💥 $($group.Count) x $($group.Name)" -ForegroundColor Red
            }
            Write-Host ""
        }

        if ($rgInfo.managedBy) {
            Write-Host "⚠ WARNING: This Resource Group is managed by: $($rgInfo.managedBy)" -ForegroundColor Red
            Write-Host "Deleting it may cause issues with the managing service!" -ForegroundColor Red
            Write-Host ""
        }

        $confirmation = Read-Host "Type 'DELETE' to confirm permanent deletion of Resource Group '$ResourceGroup'"
        if ($confirmation -ne "DELETE") {
            Write-Host "Deletion cancelled by user. Resource Group was NOT deleted." -ForegroundColor Yellow
            exit 0
        }
    }

    # Build Azure CLI command parameters
    $azParams = @(
        'group', 'delete',
        '--name', $ResourceGroup,
        '--yes'  # Skip Azure CLI confirmation
    )

    # Add force deletion types if specified
    if ($ForceDeletionTypes -and $ForceDeletionTypes.Count -gt 0) {
        $azParams += '--force-deletion-types', ($ForceDeletionTypes -join ',')
        Write-Host "🔧 Force deletion enabled for: $($ForceDeletionTypes -join ', ')" -ForegroundColor Yellow
    }

    # Add no-wait parameter if specified
    if ($NoWait) {
        $azParams += '--no-wait'
        Write-Host "⏳ Background mode: Deletion will continue in the background" -ForegroundColor Blue
    }

    # Display final configuration
    Write-Host ""
    Write-Host "Deletion Configuration:" -ForegroundColor Cyan
    Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
    Write-Host "  Resources to delete: $resourceCount" -ForegroundColor White
    Write-Host "  Background mode: $(if ($NoWait) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White
    if ($ForceDeletionTypes) {
        Write-Host "  Force deletion types: $($ForceDeletionTypes -join ', ')" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "🗑️ Initiating Resource Group deletion..." -ForegroundColor Red
    if (-not $NoWait) {
        Write-Host "⚠ This operation may take several minutes to complete" -ForegroundColor Yellow
    }

    # Execute Azure CLI command
    $result = & az @azParams 2>&1

    if ($LASTEXITCODE -eq 0) {
        if ($NoWait) {
            Write-Host "✓ Resource Group deletion initiated successfully!" -ForegroundColor Green
            Write-Host "The deletion is running in the background." -ForegroundColor White
            Write-Host ""
            Write-Host "To check deletion status:" -ForegroundColor Cyan
            Write-Host "az group show --name $ResourceGroup --query 'properties.provisioningState'" -ForegroundColor White
            Write-Host ""
            Write-Host "Note: The Resource Group will appear as 'Deleting' until completion." -ForegroundColor Blue
        } else {
            Write-Host "✓ Resource Group deleted successfully!" -ForegroundColor Green
            Write-Host "Resource Group '$ResourceGroup' and all $resourceCount resources have been permanently deleted." -ForegroundColor White
        }

        Write-Host ""
        Write-Host "🏁 Deletion operation completed successfully" -ForegroundColor Green
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
