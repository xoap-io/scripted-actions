<#
.SYNOPSIS
    Create a blob container in an Azure Storage Account using the Azure CLI.

.DESCRIPTION
    This script creates a blob container in an existing Azure Storage Account using the Azure CLI.
    The script retrieves the storage account key and uses it to authenticate the container creation.
    The script uses the following Azure CLI command:
    az storage container create --name $ContainerName --account-name $StorageAccountName

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group containing the Storage Account.

.PARAMETER StorageAccountName
    Defines the name of the Azure Storage Account where the container will be created.

.PARAMETER ContainerName
    Defines the name of the blob container to create.

.PARAMETER PublicAccess
    Defines the public access level for the container.
    Valid values: off (no public access), blob (public read for blobs), container (full public read). Default: off.

.EXAMPLE
    .\az-cli-create-blob-container.ps1 -ResourceGroupName "rg-storage" -StorageAccountName "mystorageacct001" -ContainerName "mycontainer"

.EXAMPLE
    .\az-cli-create-blob-container.ps1 -ResourceGroupName "rg-storage" -StorageAccountName "mystorageacct001" -ContainerName "public-assets" -PublicAccess "blob"

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
    https://learn.microsoft.com/en-us/cli/azure/storage/container

.COMPONENT
    Azure CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group containing the Storage Account")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Storage Account")]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the blob container to create")]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName,

    [Parameter(Mandatory = $false, HelpMessage = "Public access level: off (none), blob (public blobs), container (full public read)")]
    [ValidateSet('off', 'blob', 'container')]
    [string]$PublicAccess = 'off'
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating blob container '$ContainerName' in storage account '$StorageAccountName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Retrieve the storage account key for authentication
    Write-Host "🔍 Retrieving storage account key..." -ForegroundColor Cyan
    $keyJson = az storage account keys list `
        --resource-group $ResourceGroupName `
        --account-name $StorageAccountName `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve storage account keys. Verify the storage account name and resource group are correct."
    }

    $keys = $keyJson | ConvertFrom-Json
    $accountKey = $keys[0].value

    # Create the blob container
    Write-Host "🔧 Creating blob container '$ContainerName' with public access '$PublicAccess'..." -ForegroundColor Cyan
    $containerJson = az storage container create `
        --name $ContainerName `
        --account-name $StorageAccountName `
        --account-key $accountKey `
        --public-access $PublicAccess `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI storage container create command failed with exit code $LASTEXITCODE"
    }

    $container = $containerJson | ConvertFrom-Json

    Write-Host "`n✅ Blob container '$ContainerName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   ContainerName:  $ContainerName" -ForegroundColor White
    Write-Host "   PublicAccess:   $PublicAccess" -ForegroundColor White
    Write-Host "   StorageAccount: $StorageAccountName" -ForegroundColor White
    Write-Host "   Created:        $($container.created)" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
