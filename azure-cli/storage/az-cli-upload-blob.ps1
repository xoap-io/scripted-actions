<#
.SYNOPSIS
    Upload a local file to Azure Blob Storage using the Azure CLI.

.DESCRIPTION
    This script uploads a local file to an Azure Blob Storage container using the Azure CLI.
    The script retrieves the storage account key for authentication and uploads the specified file.
    The script uses the following Azure CLI command:
    az storage blob upload --account-name $StorageAccountName --container-name $ContainerName --file $LocalFilePath

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group containing the Storage Account.

.PARAMETER StorageAccountName
    Defines the name of the Azure Storage Account.

.PARAMETER ContainerName
    Defines the name of the blob container to upload the file to.

.PARAMETER LocalFilePath
    Defines the local path to the file to upload. The file must exist.

.PARAMETER BlobName
    Defines the name of the blob in the container. Defaults to the filename of the local file.

.PARAMETER ContentType
    Defines the MIME content type of the blob (e.g. "application/json", "image/png").

.PARAMETER Overwrite
    If specified, overwrites an existing blob with the same name.

.EXAMPLE
    .\az-cli-upload-blob.ps1 -ResourceGroupName "rg-storage" -StorageAccountName "mystorageacct001" -ContainerName "mycontainer" -LocalFilePath "C:\data\report.csv"

.EXAMPLE
    .\az-cli-upload-blob.ps1 -ResourceGroupName "rg-storage" -StorageAccountName "mystorageacct001" -ContainerName "mycontainer" -LocalFilePath "C:\data\report.csv" -BlobName "reports/2026/report.csv" -ContentType "text/csv" -Overwrite

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the blob container to upload the file to")]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName,

    [Parameter(Mandatory = $true, HelpMessage = "The local path to the file to upload (must exist)")]
    [ValidateNotNullOrEmpty()]
    [string]$LocalFilePath,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the blob in the container (defaults to the local filename)")]
    [ValidateNotNullOrEmpty()]
    [string]$BlobName,

    [Parameter(Mandatory = $false, HelpMessage = "The MIME content type of the blob (e.g. 'application/json', 'image/png')")]
    [ValidateNotNullOrEmpty()]
    [string]$ContentType,

    [Parameter(Mandatory = $false, HelpMessage = "Overwrite an existing blob with the same name")]
    [switch]$Overwrite
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Uploading file '$LocalFilePath' to Azure Blob Storage..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Validate the local file exists
    Write-Host "🔍 Validating local file path..." -ForegroundColor Cyan
    if (-not (Test-Path -Path $LocalFilePath -PathType Leaf)) {
        throw "Local file not found at path: $LocalFilePath"
    }

    # Determine the blob name (default to the filename)
    if (-not $BlobName) {
        $BlobName = [System.IO.Path]::GetFileName($LocalFilePath)
        Write-Host "ℹ️  BlobName not specified. Using filename: $BlobName" -ForegroundColor Yellow
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

    # Build the upload command arguments
    $uploadArgs = @(
        'storage', 'blob', 'upload',
        '--account-name', $StorageAccountName,
        '--account-key', $accountKey,
        '--container-name', $ContainerName,
        '--file', $LocalFilePath,
        '--name', $BlobName,
        '--output', 'json'
    )

    if ($ContentType) {
        $uploadArgs += '--content-type'
        $uploadArgs += $ContentType
    }

    if ($Overwrite) {
        $uploadArgs += '--overwrite'
    }

    # Upload the blob
    Write-Host "🔧 Uploading blob '$BlobName' to container '$ContainerName'..." -ForegroundColor Cyan
    $blobJson = az @uploadArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI storage blob upload command failed with exit code $LASTEXITCODE"
    }

    $blob = $blobJson | ConvertFrom-Json

    # Build the blob URI
    $blobUri = "https://$StorageAccountName.blob.core.windows.net/$ContainerName/$BlobName"

    Write-Host "`n✅ Blob '$BlobName' uploaded successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   BlobUri:    $blobUri" -ForegroundColor White
    Write-Host "   ETag:       $($blob.etag)" -ForegroundColor White
    Write-Host "   ContentMd5: $($blob.contentMd5)" -ForegroundColor White
    Write-Host "   Container:  $ContainerName" -ForegroundColor White
    Write-Host "   Account:    $StorageAccountName" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
