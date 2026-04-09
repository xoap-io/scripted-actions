<#
.SYNOPSIS
    Download kubeconfig credentials for an AKS cluster using Azure CLI.

.DESCRIPTION
    This script downloads and merges the kubeconfig credentials for an Azure Kubernetes
    Service (AKS) cluster into the local kubeconfig file using the Azure CLI.
    Supports retrieving standard user credentials or admin credentials, and can
    overwrite an existing kubeconfig entry for the cluster.
    The script uses the following Azure CLI command:
    az aks get-credentials --resource-group $ResourceGroupName --name $ClusterName

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group containing the AKS cluster.

.PARAMETER ClusterName
    Defines the name of the AKS cluster for which to download credentials.

.PARAMETER AdminCredentials
    If specified, downloads admin credentials instead of standard user credentials.
    Admin credentials bypass Kubernetes RBAC and should be used with caution.

.PARAMETER Overwrite
    If specified, overwrites an existing kubeconfig entry for this cluster without
    prompting for confirmation.

.EXAMPLE
    .\az-cli-get-aks-credentials.ps1 -ResourceGroupName "rg-aks-prod" -ClusterName "aks-prod-01"

.EXAMPLE
    .\az-cli-get-aks-credentials.ps1 -ResourceGroupName "rg-aks-prod" -ClusterName "aks-prod-01" -AdminCredentials -Overwrite

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
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group containing the AKS cluster")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the AKS cluster for which to download credentials")]
    [ValidateNotNullOrEmpty()]
    [string]$ClusterName,

    [Parameter(Mandatory = $false, HelpMessage = "Download admin credentials instead of standard user credentials")]
    [switch]$AdminCredentials,

    [Parameter(Mandatory = $false, HelpMessage = "Overwrite an existing kubeconfig entry for this cluster without prompting")]
    [switch]$Overwrite
)

$ErrorActionPreference = 'Stop'

try {
    $credentialType = if ($AdminCredentials) { 'admin' } else { 'user' }
    Write-Host "🚀 Downloading $credentialType credentials for AKS cluster '$ClusterName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    Write-Host "🔍 Verifying cluster '$ClusterName' in resource group '$ResourceGroupName'..." -ForegroundColor Cyan
    $null = az aks show `
        --resource-group $ResourceGroupName `
        --name $ClusterName `
        --query "name" `
        --output tsv 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "AKS cluster '$ClusterName' not found in resource group '$ResourceGroupName'."
    }

    # Determine the kubeconfig path
    if ($env:KUBECONFIG) {
        $kubeconfigPath = $env:KUBECONFIG
    }
    else {
        $kubeconfigPath = Join-Path $HOME '.kube' 'config'
    }

    # Build the get-credentials command arguments
    $getCredsArgs = @(
        'aks', 'get-credentials',
        '--resource-group', $ResourceGroupName,
        '--name', $ClusterName
    )

    if ($AdminCredentials) {
        $getCredsArgs += '--admin'
        Write-Host "⚠️  Admin credentials requested — these bypass Kubernetes RBAC. Use with caution." -ForegroundColor Yellow
    }

    if ($Overwrite) {
        $getCredsArgs += '--overwrite-existing'
        Write-Host "ℹ️  Existing kubeconfig entry will be overwritten." -ForegroundColor Yellow
    }

    # Download credentials
    Write-Host "🔧 Running az aks get-credentials for '$ClusterName'..." -ForegroundColor Cyan
    $result = az @getCredsArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI aks get-credentials command failed with exit code $LASTEXITCODE. Details: $result"
    }

    Write-Host "`n✅ Credentials for '$ClusterName' downloaded successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Cluster Name:     $ClusterName" -ForegroundColor White
    Write-Host "   Resource Group:   $ResourceGroupName" -ForegroundColor White
    Write-Host "   Credential Type:  $credentialType" -ForegroundColor White
    Write-Host "   Kubeconfig Path:  $kubeconfigPath" -ForegroundColor White

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   Verify connection: kubectl get nodes" -ForegroundColor White
    Write-Host "   Current context:   kubectl config current-context" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
