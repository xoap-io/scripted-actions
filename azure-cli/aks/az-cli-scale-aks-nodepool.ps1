<#
.SYNOPSIS
    Scale the default node pool of an AKS cluster using Azure CLI.

.DESCRIPTION
    This script scales a node pool in an Azure Kubernetes Service (AKS) cluster
    to the specified node count using the Azure CLI.
    It displays the current node count before scaling and confirms the new count
    after the operation completes.
    The script uses the following Azure CLI command:
    az aks nodepool scale --resource-group $ResourceGroupName --cluster-name $ClusterName --name $NodePoolName --node-count $NodeCount

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group containing the AKS cluster.

.PARAMETER ClusterName
    Defines the name of the AKS cluster whose node pool will be scaled.

.PARAMETER NodePoolName
    Defines the name of the node pool to scale. Default: 'nodepool1'.

.PARAMETER NodeCount
    Defines the target number of nodes in the node pool (0-1000).

.EXAMPLE
    .\az-cli-scale-aks-nodepool.ps1 -ResourceGroupName "rg-aks-prod" -ClusterName "aks-prod-01" -NodeCount 5

.EXAMPLE
    .\az-cli-scale-aks-nodepool.ps1 -ResourceGroupName "rg-aks-prod" -ClusterName "aks-prod-01" -NodePoolName "userpool" -NodeCount 10

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
    https://learn.microsoft.com/en-us/cli/azure/aks/nodepool

.COMPONENT
    Azure CLI Kubernetes Service
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group containing the AKS cluster")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the AKS cluster whose node pool will be scaled")]
    [ValidateNotNullOrEmpty()]
    [string]$ClusterName,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the node pool to scale")]
    [ValidateNotNullOrEmpty()]
    [string]$NodePoolName = 'nodepool1',

    [Parameter(Mandatory = $true, HelpMessage = "The target number of nodes in the node pool (0-1000)")]
    [ValidateRange(0, 1000)]
    [int]$NodeCount
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Scaling node pool '$NodePoolName' in AKS cluster '$ClusterName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Retrieve current node count before scaling
    Write-Host "🔍 Retrieving current node pool state..." -ForegroundColor Cyan
    $currentPoolJson = az aks nodepool show `
        --resource-group $ResourceGroupName `
        --cluster-name $ClusterName `
        --name $NodePoolName `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve node pool '$NodePoolName'. Verify the cluster name and resource group. Details: $currentPoolJson"
    }

    $currentPool = $currentPoolJson | ConvertFrom-Json
    $beforeCount = $currentPool.count

    Write-Host "ℹ️  Current node count: $beforeCount" -ForegroundColor Yellow
    Write-Host "ℹ️  Target node count:  $NodeCount" -ForegroundColor Yellow

    if ($beforeCount -eq $NodeCount) {
        Write-Host "`n✅ Node pool '$NodePoolName' is already at the target count of $NodeCount. No action taken." -ForegroundColor Green
        return
    }

    # Build the scale command arguments
    $scaleArgs = @(
        'aks', 'nodepool', 'scale',
        '--resource-group', $ResourceGroupName,
        '--cluster-name', $ClusterName,
        '--name', $NodePoolName,
        '--node-count', $NodeCount,
        '--output', 'json'
    )

    # Scale the node pool
    Write-Host "🔧 Scaling node pool '$NodePoolName' from $beforeCount to $NodeCount nodes (this may take several minutes)..." -ForegroundColor Cyan
    $scaleResultJson = az @scaleArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI aks nodepool scale command failed with exit code $LASTEXITCODE"
    }

    $scaleResult = $scaleResultJson | ConvertFrom-Json
    $afterCount = $scaleResult.count

    Write-Host "`n✅ Node pool '$NodePoolName' scaled successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Cluster Name:       $ClusterName" -ForegroundColor White
    Write-Host "   Node Pool:          $NodePoolName" -ForegroundColor White
    Write-Host "   Before Node Count:  $beforeCount" -ForegroundColor White
    Write-Host "   After Node Count:   $afterCount" -ForegroundColor White
    Write-Host "   Provisioning State: $($scaleResult.provisioningState)" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
