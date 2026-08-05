<#
.SYNOPSIS
    List all VM images registered on an Azure Local (Azure Stack HCI) cluster.

.DESCRIPTION
    This script lists the VM images (both gallery images registered from VHDX files and
    downloaded Azure Marketplace images) of an Azure Local resource group, including OS
    type, source, provisioning state, storage path and size. The result is printed as a
    table and can optionally be exported to a timestamped CSV file.

    Uses Get-AzStackHCIVMImage and Get-AzStackHCIVMStoragePath.

    This script can run anywhere with an Azure context; it does not need to run on a
    cluster node.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER ImageName
    Optional name filter. Supports wildcards, e.g. "win11*".

.PARAMETER ExportCsv
    Export the inventory to a CSV file in addition to the console output.

.PARAMETER CsvPath
    Path of the CSV export file. Defaults to "azure-local-images-<timestamp>.csv" in the
    current directory.

.EXAMPLE
    .\az-ps-get-azure-local-images.ps1

    Lists all images in the "AzureLocal" resource group.

.EXAMPLE
    .\az-ps-get-azure-local-images.ps1 -ImageName "win11*" -ExportCsv

    Lists all Windows 11 images and exports them to a timestamped CSV file.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Accounts, Az.StackHCIVM 1.1.0+ (Install-Module Az.StackHCIVM)

.LINK
    https://learn.microsoft.com/en-us/azure/azure-local/manage/virtual-machine-image-azure-marketplace

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.stackhcivm/

.COMPONENT
    Azure PowerShell Stack HCI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Azure resource group that represents your Azure Local instance scope.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName = "AzureLocal",

    [Parameter(Mandatory = $false, HelpMessage = "Optional image name filter. Supports wildcards, e.g. 'win11*'.")]
    [string]$ImageName = "",

    [Parameter(Mandatory = $false, HelpMessage = "Export the inventory to a CSV file in addition to the console output.")]
    [switch]$ExportCsv,

    [Parameter(Mandatory = $false, HelpMessage = "Path of the CSV export file. Defaults to a timestamped file in the current directory.")]
    [string]$CsvPath = ""
)

$ErrorActionPreference = 'Stop'

try {
    # 0) Preflight: module + Azure context
    if (-not (Get-Module -ListAvailable -Name Az.StackHCIVM)) {
        throw "The Az.StackHCIVM module is not installed. Run: Install-Module Az.StackHCIVM -Scope CurrentUser"
    }
    $context = Get-AzContext
    if (-not $context) {
        throw "No Azure context found. Run Connect-AzAccount (or sign in with your service principal) first."
    }
    Write-Host "🔍 Using subscription '$($context.Subscription.Name)' ($($context.Subscription.Id))" -ForegroundColor Cyan

    # 1) Collect images and storage paths
    Write-Host "🔍 Listing images in resource group '$ResourceGroupName'..." -ForegroundColor Cyan
    $images = @(Get-AzStackHCIVMImage -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue)
    if ($ImageName) {
        $images = @($images | Where-Object { $_.Name -like $ImageName })
    }

    if ($images.Count -eq 0) {
        Write-Host "ℹ️  No images found in resource group '$ResourceGroupName'$(if ($ImageName) { " matching '$ImageName'" })" -ForegroundColor Yellow
        Write-Host "💡 Next Steps: register an image with az-ps-create-azure-local-image.ps1" -ForegroundColor Yellow
        return
    }

    # Map storage path resource IDs to names for readable output
    $storagePaths = @{}
    foreach ($sp in @(Get-AzStackHCIVMStoragePath -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue)) {
        if ($sp.Id) { $storagePaths[$sp.Id.ToLower()] = $sp.Name }
    }

    # 2) Project the inventory
    $inventory = foreach ($img in $images) {
        $isMarketplace = [bool]$img.IdentifierPublisher
        $source = if ($isMarketplace) {
            "$($img.IdentifierPublisher):$($img.IdentifierOffer):$($img.IdentifierSku):$($img.VersionName)"
        }
        else {
            $img.ImagePath
        }
        $storagePathName = ""
        if ($img.ContainerId -and $storagePaths.ContainsKey($img.ContainerId.ToLower())) {
            $storagePathName = $storagePaths[$img.ContainerId.ToLower()]
        }

        [PSCustomObject]@{
            Name              = $img.Name
            Type              = if ($isMarketplace) { "Marketplace" } else { "Gallery" }
            OsType            = "$($img.OSType)"
            ProvisioningState = "$($img.ProvisioningState)"
            SizeMB            = $img.DownloadStatusDownloadSizeInMb
            StoragePath       = $storagePathName
            Source            = $source
        }
    }

    # 3) Output
    $inventory | Format-Table -AutoSize | Out-String -Width 4096 | Write-Host

    Write-Host "📊 Summary: $($images.Count) image(s) found" -ForegroundColor Blue

    if ($ExportCsv) {
        if (-not $CsvPath) {
            $CsvPath = Join-Path (Get-Location) "azure-local-images-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
        }
        $inventory | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding utf8
        Write-Host "✅ Inventory exported to '$CsvPath'" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
