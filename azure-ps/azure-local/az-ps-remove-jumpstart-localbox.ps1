<#
.SYNOPSIS
    Remove Azure Arc Jumpstart LocalBox deployment and all related resources.

.DESCRIPTION
    This script removes the complete Azure Arc Jumpstart LocalBox environment including all resources
    that were created during deployment. LocalBox deployments contain numerous Azure resources including
    VMs, networks, storage accounts, Key Vaults, Log Analytics workspaces, and Azure Arc resources.

    The script supports both DryRun mode for testing and actual resource deletion. In DryRun mode,
    all operations are simulated without deleting actual Azure resources.

    IMPORTANT: This script will remove the ENTIRE resource group and ALL resources within it.
    If you have other resources in the same resource group that you want to keep, do NOT use this script.

    Resources typically included in LocalBox deployment:
    - Virtual Machines (Client VM and nested VMs)
    - Virtual Networks and Subnets
    - Network Security Groups
    - Public IP Addresses
    - Storage Accounts
    - Key Vault
    - Log Analytics Workspace
    - Azure Bastion (if deployed)
    - Arc-enabled servers and Kubernetes clusters
    - Various managed identities and role assignments

.PARAMETER ResourceGroup
    Name of the Azure resource group containing the LocalBox deployment to remove.

.PARAMETER SubscriptionId
    Azure subscription ID containing the LocalBox deployment.

.PARAMETER Force
    If specified, skips confirmation prompts for resource deletion.
    Use with extreme caution.

.PARAMETER ListResourcesOnly
    If specified, only lists the resources that would be deleted without performing any deletion.
    Useful for understanding what's in the resource group before cleanup.

.PARAMETER DryRun
    If specified, performs a dry run without deleting actual resources.

.EXAMPLE
    .\az-ps-remove-jumpstart-localbox.ps1 -ResourceGroup "rg-localbox" -SubscriptionId "12345678-1234-1234-1234-123456789012"

.EXAMPLE
    .\az-ps-remove-jumpstart-localbox.ps1 -ResourceGroup "rg-localbox" -SubscriptionId "12345678-1234-1234-1234-123456789012" -DryRun

.EXAMPLE
    .\az-ps-remove-jumpstart-localbox.ps1 -ResourceGroup "rg-localbox" -SubscriptionId "12345678-1234-1234-1234-123456789012" -ListResourcesOnly

.EXAMPLE
    .\az-ps-remove-jumpstart-localbox.ps1 -ResourceGroup "rg-localbox" -SubscriptionId "12345678-1234-1234-1234-123456789012" -Force

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.StackHCI

    WARNING: This script will permanently delete ALL Azure resources in the specified resource group.
    Ensure you have backups of any important data before running this script.

    The cleanup process can take 15-30 minutes depending on the number and types of resources.
    Some resources may have soft-delete enabled and require additional cleanup steps.

    Arc-enabled resources may need to be disconnected from Azure Arc before deletion.

.LINK
    https://learn.microsoft.com/en-us/azure/azure-local/

.COMPONENT
    Azure PowerShell Stack HCI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure resource group containing the LocalBox deployment to remove.")]
    [ValidatePattern('^[a-zA-Z0-9\-_\.]{1,90}$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "Azure subscription ID containing the LocalBox deployment.")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false, HelpMessage = "If specified, skips confirmation prompts for resource deletion.")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "If specified, only lists the resources that would be deleted without performing any deletion.")]
    [switch]$ListResourcesOnly,

    [Parameter(Mandatory = $false, HelpMessage = "If specified, performs a dry run without deleting actual resources.")]
    [switch]$DryRun
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )

    if ($DryRun) {
        Write-Host "[DRY RUN] $Message" -ForegroundColor Cyan
    } elseif ($ListResourcesOnly) {
        Write-Host "[LIST ONLY] $Message" -ForegroundColor Magenta
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

# Function to validate Azure login
function Test-AzureLogin {
    try {
        $context = Get-AzContext
        if (-not $context) {
            throw "Not logged in to Azure"
        }
        Write-ColorOutput "Azure context validated: $($context.Account.Id)" -Color Green
        return $true
    }
    catch {
        Write-Error "Azure login required. Please run 'Connect-AzAccount' first."
        return $false
    }
}

# Function to get resource group resources
function Get-ResourceGroupContents {
    param(
        [string]$ResourceGroupName,
        [string]$SubscriptionId
    )

    try {
        $resources = Get-AzResource -ResourceGroupName $ResourceGroupName
        return $resources
    }
    catch {
        Write-Warning "Failed to get resources from resource group: $($_.Exception.Message)"
        return @()
    }
}

# Function to display resources
function Show-ResourceInventory {
    param(
        [array]$Resources
    )

    if ($Resources.Count -eq 0) {
        Write-ColorOutput "No resources found in the resource group." -Color Green
        return
    }

    Write-ColorOutput "`nResource Inventory:" -Color Cyan
    Write-ColorOutput "==================" -Color Cyan

    # Group resources by type
    $resourceGroups = $Resources | Group-Object ResourceType | Sort-Object Name

    foreach ($group in $resourceGroups) {
        Write-ColorOutput "`n$($group.Name) ($($group.Count) resources):" -Color Yellow
        foreach ($resource in $group.Group) {
            Write-ColorOutput "  - $($resource.Name)" -Color White
        }
    }

    Write-ColorOutput "`nTotal resources: $($Resources.Count)" -Color Cyan
}

# Function to confirm deletion
function Confirm-Deletion {
    param(
        [string]$ResourceGroupName,
        [int]$ResourceCount
    )

    if ($Force -or $DryRun -or $ListResourcesOnly) {
        return $true
    }

    Write-Host "`nWARNING: You are about to DELETE the entire resource group '$ResourceGroupName'" -ForegroundColor Red
    Write-Host "This will permanently remove ALL $ResourceCount resources in this resource group!" -ForegroundColor Red
    Write-Host "This action CANNOT be undone!" -ForegroundColor Red
    Write-Host ""

    $confirmation1 = Read-Host "Type 'DELETE' to confirm you want to delete the resource group"
    if ($confirmation1 -ne 'DELETE') {
        Write-Host "Deletion cancelled." -ForegroundColor Yellow
        return $false
    }

    $confirmation2 = Read-Host "Type the resource group name '$ResourceGroupName' to confirm"
    if ($confirmation2 -ne $ResourceGroupName) {
        Write-Host "Resource group name mismatch. Deletion cancelled." -ForegroundColor Yellow
        return $false
    }

    return $true
}

# Function to handle Arc-enabled resources cleanup
function Remove-ArcResources {
    param(
        [array]$Resources
    )

    # Find Arc-enabled resources
    $arcServers = $Resources | Where-Object { $_.ResourceType -eq "Microsoft.HybridCompute/machines" }
    $arcClusters = $Resources | Where-Object { $_.ResourceType -eq "Microsoft.Kubernetes/connectedClusters" }

    if ($arcServers.Count -gt 0 -or $arcClusters.Count -gt 0) {
        Write-ColorOutput "`nHandling Arc-enabled resources..." -Color Yellow

        if ($DryRun -or $ListResourcesOnly) {
            Write-ColorOutput "Would disconnect and remove Arc-enabled resources:" -Color Cyan
            foreach ($server in $arcServers) {
                Write-ColorOutput "  - Arc Server: $($server.Name)" -Color White
            }
            foreach ($cluster in $arcClusters) {
                Write-ColorOutput "  - Arc Cluster: $($cluster.Name)" -Color White
            }
        } else {
            # Disconnect Arc servers
            foreach ($server in $arcServers) {
                try {
                    Write-ColorOutput "Disconnecting Arc server: $($server.Name)" -Color Yellow
                    Remove-AzConnectedMachine -ResourceGroupName $ResourceGroup -Name $server.Name -Force
                    Write-ColorOutput "Arc server disconnected: $($server.Name)" -Color Green
                }
                catch {
                    Write-Warning "Failed to disconnect Arc server $($server.Name): $($_.Exception.Message)"
                }
            }

            # Disconnect Arc clusters
            foreach ($cluster in $arcClusters) {
                try {
                    Write-ColorOutput "Disconnecting Arc cluster: $($cluster.Name)" -Color Yellow
                    Remove-AzConnectedKubernetes -ResourceGroupName $ResourceGroup -Name $cluster.Name -Force
                    Write-ColorOutput "Arc cluster disconnected: $($cluster.Name)" -Color Green
                }
                catch {
                    Write-Warning "Failed to disconnect Arc cluster $($cluster.Name): $($_.Exception.Message)"
                }
            }
        }
    }
}

# Main execution
try {
    Write-ColorOutput "Starting Azure Arc Jumpstart LocalBox cleanup script" -Color Cyan
    Write-ColorOutput "Target Subscription: $SubscriptionId" -Color White
    Write-ColorOutput "Target Resource Group: $ResourceGroup" -Color White

    if ($DryRun) {
        Write-ColorOutput "DRY RUN MODE - No actual resources will be deleted" -Color Yellow
    } elseif ($ListResourcesOnly) {
        Write-ColorOutput "LIST ONLY MODE - Only showing resources, no deletion" -Color Yellow
    } elseif (-not $Force) {
        Write-ColorOutput "Running in interactive mode - you will be prompted for confirmation" -Color Yellow
    } else {
        Write-ColorOutput "FORCE MODE - Skipping confirmations" -Color Red
    }

    # Validate Azure login
    if (-not (Test-AzureLogin)) {
        exit 1
    }

    # Select subscription
    if ($DryRun -or $ListResourcesOnly) {
        Write-ColorOutput "Would select Azure subscription: $SubscriptionId" -Color Cyan
    } else {
        try {
            $selectedSub = Select-AzSubscription -SubscriptionId $SubscriptionId
            Write-ColorOutput "Selected subscription: $($selectedSub.Subscription.Name)" -Color Green
        }
        catch {
            Write-Error "Failed to select subscription '$SubscriptionId': $($_.Exception.Message)"
            exit 1
        }
    }

    # Check if resource group exists
    Write-ColorOutput "Checking if resource group '$ResourceGroup' exists..." -Color Yellow

    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue
        if (-not $rg) {
            Write-ColorOutput "Resource group '$ResourceGroup' does not exist. Nothing to clean up." -Color Green
            exit 0
        }
        Write-ColorOutput "Resource group found: $($rg.ResourceGroupName) in $($rg.Location)" -Color Green
    }
    catch {
        Write-Error "Failed to check resource group: $($_.Exception.Message)"
        exit 1
    }

    # Get all resources in the resource group
    Write-ColorOutput "Scanning resources in resource group..." -Color Yellow
    $resources = Get-ResourceGroupContents -ResourceGroupName $ResourceGroup -SubscriptionId $SubscriptionId

    # Display resource inventory
    Show-ResourceInventory -Resources $resources

    # If only listing resources, exit here
    if ($ListResourcesOnly) {
        Write-ColorOutput "`nResource listing completed. No resources were deleted." -Color Green
        exit 0
    }

    # Handle Arc-enabled resources first
    Remove-ArcResources -Resources $resources

    # Confirm deletion
    if (-not (Confirm-Deletion -ResourceGroupName $ResourceGroup -ResourceCount $resources.Count)) {
        Write-ColorOutput "Cleanup cancelled by user." -Color Yellow
        exit 0
    }

    # Perform cleanup
    Write-ColorOutput "`n=== Starting LocalBox Cleanup ===" -Color Cyan

    if ($DryRun) {
        Write-ColorOutput "Would delete resource group '$ResourceGroup' and ALL $($resources.Count) resources" -Color Cyan
        Write-ColorOutput "Estimated cleanup time: 15-30 minutes" -Color Yellow
        Write-ColorOutput "Resources that would be deleted:" -Color Cyan

        # Show what would be deleted
        $resourceTypes = $resources | Group-Object ResourceType | Sort-Object Count -Descending
        foreach ($type in $resourceTypes) {
            Write-ColorOutput "  - $($type.Count)x $($type.Name)" -Color White
        }
    } else {
        try {
            Write-ColorOutput "Deleting resource group '$ResourceGroup'..." -Color Yellow
            Write-ColorOutput "This will take 15-30 minutes depending on the resources..." -Color Yellow

            # Start the deletion
            $job = Remove-AzResourceGroup -Name $ResourceGroup -Force -AsJob

            Write-ColorOutput "Resource group deletion job started. Job ID: $($job.Id)" -Color Green
            Write-ColorOutput "Monitoring deletion progress..." -Color Yellow

            # Monitor the job
            $completed = $false
            $startTime = Get-Date

            while (-not $completed) {
                Start-Sleep -Seconds 30
                $jobState = Get-Job -Id $job.Id
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)

                Write-ColorOutput "Deletion in progress... (Elapsed: $elapsed minutes)" -Color Yellow

                if ($jobState.State -eq "Completed") {
                    $completed = $true
                    Write-ColorOutput "Resource group deletion completed successfully!" -Color Green
                } elseif ($jobState.State -eq "Failed") {
                    $completed = $true
                    Write-Error "Resource group deletion failed. Check the job output for details."
                    Receive-Job -Id $job.Id
                    exit 1
                }

                # Safety timeout after 45 minutes
                if ($elapsed -gt 45) {
                    Write-Warning "Deletion is taking longer than expected (45+ minutes). Check Azure portal for status."
                    Write-ColorOutput "Job is still running. You can check status with: Get-Job -Id $($job.Id)" -Color Yellow
                    break
                }
            }

            # Clean up the job
            Remove-Job -Id $job.Id -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Error "Failed to delete resource group: $($_.Exception.Message)"
            exit 1
        }
    }

    # Display cleanup summary
    Write-ColorOutput "`n=== Cleanup Summary ===" -Color Cyan

    if ($DryRun) {
        Write-ColorOutput "DRY RUN COMPLETED - LocalBox resources that would be deleted:" -Color Yellow
        Write-ColorOutput "- Resource Group: $ResourceGroup" -Color White
        Write-ColorOutput "- Total Resources: $($resources.Count)" -Color White
        Write-ColorOutput "- Location: $($rg.Location)" -Color White
        Write-ColorOutput "`nTo perform actual deletion, run the script again without the -DryRun parameter" -Color Yellow
        Write-ColorOutput "WARNING: Deletion will permanently remove ALL resources and cannot be undone!" -Color Red
    } else {
        Write-ColorOutput "LOCALBOX CLEANUP COMPLETED!" -Color Green
        Write-ColorOutput "Deleted resources:" -Color White
        Write-ColorOutput "- Resource Group: $ResourceGroup" -Color White
        Write-ColorOutput "- Total Resources: $($resources.Count)" -Color White

        $endTime = Get-Date
        $totalTime = [math]::Round(($endTime - $startTime).TotalMinutes, 1)
        Write-ColorOutput "- Total cleanup time: $totalTime minutes" -Color White

        Write-ColorOutput "`nAll LocalBox resources have been permanently deleted." -Color Green
        Write-ColorOutput "Your Azure subscription is no longer being charged for these resources." -Color Green

        Write-ColorOutput "`nNote: Some resources with soft-delete (Key Vaults, etc.) may still appear in the portal" -Color Yellow
        Write-ColorOutput "but are not billable. They will be permanently deleted after the retention period." -Color Yellow
    }
}
catch {
    Write-Error "LocalBox cleanup failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
