<#
.SYNOPSIS
    Create an Azure Kubernetes Service (AKS) cluster using Azure CLI.

.DESCRIPTION
    This script creates an Azure Kubernetes Service (AKS) cluster using the Azure CLI.
    It supports optional autoscaling, managed identity, custom Kubernetes versions,
    VM size selection, and resource tagging.
    The script uses the following Azure CLI command:
    az aks create --resource-group $ResourceGroupName --name $ClusterName --location $Location

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group where the AKS cluster will be created.

.PARAMETER ClusterName
    Defines the name of the AKS cluster to create.

.PARAMETER Location
    Defines the Azure region where the AKS cluster will be created (e.g. 'eastus', 'westeurope').

.PARAMETER NodeCount
    Defines the initial number of nodes in the default node pool. Default: 3.

.PARAMETER NodeVmSize
    Defines the VM size for nodes in the default node pool. Default: 'Standard_D2s_v3'.

.PARAMETER KubernetesVersion
    Defines the Kubernetes version to use (e.g. '1.29'). If omitted, the latest stable
    version is used.

.PARAMETER EnableAutoScaling
    If specified, enables the cluster autoscaler on the default node pool.

.PARAMETER MinCount
    Defines the minimum number of nodes for the autoscaler. Default: 1.
    Only used when EnableAutoScaling is specified.

.PARAMETER MaxCount
    Defines the maximum number of nodes for the autoscaler. Default: 10.
    Only used when EnableAutoScaling is specified.

.PARAMETER EnableManagedIdentity
    If specified, configures the cluster to use a system-assigned managed identity
    instead of a service principal.

.PARAMETER Tags
    Defines resource tags in 'key=value' format (e.g. 'env=prod owner=ops').
    Multiple tags should be space-separated.

.EXAMPLE
    .\az-cli-create-aks-cluster.ps1 -ResourceGroupName "rg-aks-prod" -ClusterName "aks-prod-01" -Location "eastus"

.EXAMPLE
    .\az-cli-create-aks-cluster.ps1 -ResourceGroupName "rg-aks-prod" -ClusterName "aks-prod-01" -Location "eastus" -NodeCount 5 -NodeVmSize "Standard_D4s_v3" -KubernetesVersion "1.29" -EnableAutoScaling -MinCount 2 -MaxCount 20 -EnableManagedIdentity -Tags "env=prod owner=ops"

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
    https://learn.microsoft.com/en-us/cli/azure/aks

.COMPONENT
    Azure CLI Kubernetes Service
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group where the AKS cluster will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the AKS cluster to create")]
    [ValidateNotNullOrEmpty()]
    [string]$ClusterName,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where the AKS cluster will be created (e.g. 'eastus', 'westeurope')")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "The initial number of nodes in the default node pool (1-100)")]
    [ValidateRange(1, 100)]
    [int]$NodeCount = 3,

    [Parameter(Mandatory = $false, HelpMessage = "The VM size for nodes in the default node pool")]
    [ValidateNotNullOrEmpty()]
    [string]$NodeVmSize = 'Standard_D2s_v3',

    [Parameter(Mandatory = $false, HelpMessage = "The Kubernetes version to use (e.g. '1.29'). Omit for latest stable.")]
    [ValidateNotNullOrEmpty()]
    [string]$KubernetesVersion,

    [Parameter(Mandatory = $false, HelpMessage = "Enable the cluster autoscaler on the default node pool")]
    [switch]$EnableAutoScaling,

    [Parameter(Mandatory = $false, HelpMessage = "The minimum number of nodes for the autoscaler (1-100)")]
    [ValidateRange(1, 100)]
    [int]$MinCount = 1,

    [Parameter(Mandatory = $false, HelpMessage = "The maximum number of nodes for the autoscaler (1-1000)")]
    [ValidateRange(1, 1000)]
    [int]$MaxCount = 10,

    [Parameter(Mandatory = $false, HelpMessage = "Use a system-assigned managed identity instead of a service principal")]
    [switch]$EnableManagedIdentity,

    [Parameter(Mandatory = $false, HelpMessage = "Resource tags in 'key=value' format, space-separated (e.g. 'env=prod owner=ops')")]
    [ValidateNotNullOrEmpty()]
    [string]$Tags
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating AKS cluster '$ClusterName' in resource group '$ResourceGroupName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Validate autoscaler bounds
    if ($EnableAutoScaling -and ($MinCount -gt $MaxCount)) {
        throw "MinCount ($MinCount) must be less than or equal to MaxCount ($($MaxCount))."
    }

    if ($EnableAutoScaling -and ($NodeCount -lt $MinCount -or $NodeCount -gt $MaxCount)) {
        throw "NodeCount ($NodeCount) must be between MinCount ($MinCount) and MaxCount ($($MaxCount)) when autoscaling is enabled."
    }

    Write-Host "🔍 Validating resource group '$ResourceGroupName'..." -ForegroundColor Cyan
    $null = az group show --name $ResourceGroupName --query "name" --output tsv 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Resource group '$ResourceGroupName' not found or not accessible."
    }

    # Build the az aks create command arguments
    $createArgs = @(
        'aks', 'create',
        '--resource-group', $ResourceGroupName,
        '--name', $ClusterName,
        '--location', $Location,
        '--node-count', $NodeCount,
        '--node-vm-size', $NodeVmSize,
        '--output', 'json'
    )

    if ($KubernetesVersion) {
        $createArgs += '--kubernetes-version'
        $createArgs += $KubernetesVersion
    }

    if ($EnableAutoScaling) {
        $createArgs += '--enable-cluster-autoscaler'
        $createArgs += '--min-count'
        $createArgs += $MinCount
        $createArgs += '--max-count'
        $createArgs += $MaxCount
        Write-Host "ℹ️  Autoscaling enabled: min=$MinCount, max=$MaxCount" -ForegroundColor Yellow
    }

    if ($EnableManagedIdentity) {
        $createArgs += '--enable-managed-identity'
        Write-Host "ℹ️  Using system-assigned managed identity" -ForegroundColor Yellow
    }

    if ($Tags) {
        $createArgs += '--tags'
        $createArgs += $Tags
    }

    # Create the AKS cluster
    Write-Host "🔧 Running az aks create for '$ClusterName' (this may take several minutes)..." -ForegroundColor Cyan
    $clusterJson = az @createArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI aks create command failed with exit code $LASTEXITCODE"
    }

    $cluster = $clusterJson | ConvertFrom-Json

    Write-Host "`n✅ AKS cluster '$ClusterName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Cluster Name:       $($cluster.name)" -ForegroundColor White
    Write-Host "   Resource Group:     $($cluster.resourceGroup)" -ForegroundColor White
    Write-Host "   FQDN:               $($cluster.fqdn)" -ForegroundColor White
    Write-Host "   Kubernetes Version: $($cluster.kubernetesVersion)" -ForegroundColor White
    Write-Host "   Node Count:         $($cluster.agentPoolProfiles[0].count)" -ForegroundColor White
    Write-Host "   Provisioning State: $($cluster.provisioningState)" -ForegroundColor White

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   Get credentials: az aks get-credentials --resource-group $ResourceGroupName --name $ClusterName" -ForegroundColor White
    Write-Host "   Verify nodes:    kubectl get nodes" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
