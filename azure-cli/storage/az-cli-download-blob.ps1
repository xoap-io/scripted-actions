<#
.SYNOPSIS
    Download a blob from Azure Blob Storage using the Azure CLI.

.DESCRIPTION
    This script downloads a blob from an Azure Blob Storage container to a local file path using the Azure CLI.
    The script retrieves the storage account key for authentication before downloading.
    The script uses the following Azure CLI command:
    az storage blob download --account-name $StorageAccountName --container-name $ContainerName --name $BlobName --file $LocalFilePath

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group containing the Storage Account.

.PARAMETER StorageAccountName
    Defines the name of the Azure Storage Account.

.PARAMETER ContainerName
    Defines the name of the blob container to download from.

.PARAMETER BlobName
    Defines the name of the blob to download.

.PARAMETER LocalFilePath
    Defines the local destination file path where the blob will be saved.

.PARAMETER Overwrite
    If specified, overwrites an existing local file at the destination path.

.EXAMPLE
    .\az-cli-download-blob.ps1 -ResourceGroupName "rg-storage" -StorageAccountName "mystorageacct001" -ContainerName "mycontainer" -BlobName "report.csv" -LocalFilePath "C:\downloads\report.csv"

.EXAMPLE
    .\az-cli-download-blob.ps1 -ResourceGroupName "rg-storage" -StorageAccountName "mystorageacct001" -ContainerName "mycontainer" -BlobName "reports/2026/report.csv" -LocalFilePath "C:\downloads\report.csv" -Overwrite

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
    https://learn.microsoft.com/en-us/cli/azure/storage/blob

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the blob container to download from")]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the blob to download")]
    [ValidateNotNullOrEmpty()]
    [string]$BlobName,

    [Parameter(Mandatory = $true, HelpMessage = "The local destination file path where the blob will be saved")]
    [ValidateNotNullOrEmpty()]
    [string]$LocalFilePath,

    [Parameter(Mandatory = $false, HelpMessage = "Overwrite an existing local file at the destination path")]
    [switch]$Overwrite
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Downloading blob '$BlobName' from Azure Blob Storage..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Check if the destination file already exists
    if (Test-Path -Path $LocalFilePath -PathType Leaf) {
        if (-not $Overwrite) {
            throw "Destination file already exists at '$LocalFilePath'. Use -Overwrite to replace it."
        }
        Write-Host "⚠️  Destination file exists and will be overwritten: $LocalFilePath" -ForegroundColor Yellow
    }

    # Ensure the destination directory exists
    $destinationDir = [System.IO.Path]::GetDirectoryName($LocalFilePath)
    if ($destinationDir -and -not (Test-Path -Path $destinationDir)) {
        Write-Host "🔧 Creating destination directory: $destinationDir" -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
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

    # Build the download command arguments
    $downloadArgs = @(
        'storage', 'blob', 'download',
        '--account-name', $StorageAccountName,
        '--account-key', $accountKey,
        '--container-name', $ContainerName,
        '--name', $BlobName,
        '--file', $LocalFilePath,
        '--output', 'json'
    )

    if ($Overwrite) {
        $downloadArgs += '--overwrite'
    }

    # Download the blob
    Write-Host "🔧 Downloading blob '$BlobName' to '$LocalFilePath'..." -ForegroundColor Cyan
    az @downloadArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI storage blob download command failed with exit code $LASTEXITCODE"
    }

    # Verify file was created
    if (Test-Path -Path $LocalFilePath) {
        $fileInfo = Get-Item -Path $LocalFilePath
        Write-Host "`n✅ Blob '$BlobName' downloaded successfully." -ForegroundColor Green
        Write-Host "📊 Summary:" -ForegroundColor Blue
        Write-Host "   BlobName:      $BlobName" -ForegroundColor White
        Write-Host "   Container:     $ContainerName" -ForegroundColor White
        Write-Host "   Account:       $StorageAccountName" -ForegroundColor White
        Write-Host "   LocalFilePath: $LocalFilePath" -ForegroundColor White
        Write-Host "   FileSizeMB:    $([math]::Round($fileInfo.Length / 1MB, 2))" -ForegroundColor White
    }
    else {
        throw "Download appeared to succeed but the destination file was not found at '$LocalFilePath'."
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
