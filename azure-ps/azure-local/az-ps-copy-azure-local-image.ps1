<#
.SYNOPSIS
    Replicate an Azure Local (Azure Stack HCI) VM image to another storage path on the same
    cluster.

.DESCRIPTION
    This script copies an existing Azure Local VM image to a second storage path on the same
    cluster and registers the copy as a new image (e.g. to distribute images across cluster
    shared volumes UserStorage_1 / UserStorage_2, or to keep a versioned duplicate).

    Two source types are handled:

    - Gallery images (registered from a VHDX): the physical VHDX file is copied to the
      target directory and registered from there. This requires the script to run ON a
      cluster node with access to both CSV paths. A free-space check is attempted before
      the copy.
    - Marketplace images: there is no local source file exposed; the image is re-registered
      on the target storage path via its marketplace identifiers, which triggers a new
      download by the cluster. This variant runs anywhere with an Azure context.

    The script is idempotent: if the target image name already exists, the script exits
    successfully without copying. If the target storage path object does not exist, it is
    created.

    The default values match the XOAP Jumpstart LocalBox environment (source images on
    UserStorage_2, replica on UserStorage_1).

    Uses Get/New-AzStackHCIVMImage, Get/New-AzStackHCIVMStoragePath and Copy-Item.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER CustomLocationId
    Custom Location resource ID that maps to your Azure Local cluster (Arc resource bridge).
    Defaults to the XOAP LocalBox custom location "jumpstart".

.PARAMETER Location
    Azure region of the Arc resources. Defaults to "westeurope".

.PARAMETER SourceImageName
    Name of the existing Azure Local VM image to replicate.

.PARAMETER SourceVhdxPath
    Optional override for the physical path of the source VHDX (gallery images only).
    If omitted, the path registered on the image is used.

.PARAMETER TargetImageName
    Name of the replicated image. Defaults to "<SourceImageName>-copy".

.PARAMETER TargetStoragePathName
    Name of the storage path object that stores the replica. Defaults to "sp-images-2".
    Created if missing.

.PARAMETER TargetStoragePath
    Cluster-local directory behind the target storage path object.
    Defaults to "C:\ClusterStorage\UserStorage_1\Images".

.PARAMETER Force
    Overwrite an existing VHDX file at the target location.

.EXAMPLE
    .\az-ps-copy-azure-local-image.ps1 -SourceImageName "win11-23h2-avd-gold"

    Copies the golden image from UserStorage_2 to UserStorage_1 and registers it as
    "win11-23h2-avd-gold-copy".

.EXAMPLE
    .\az-ps-copy-azure-local-image.ps1 `
        -SourceImageName "win11-23h2-avd-gold" `
        -TargetImageName "win11-23h2-avd-gold-us1" `
        -TargetStoragePathName "sp-images-us1" `
        -TargetStoragePath "C:\ClusterStorage\UserStorage_1\Images" `
        -Force

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Accounts, Az.StackHCIVM 1.1.0+ (Install-Module Az.StackHCIVM); cluster node
    with CSV access for gallery image copies.

.LINK
    https://learn.microsoft.com/en-us/azure/azure-local/manage/virtual-machine-image-local-share

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.stackhcivm/

.COMPONENT
    Azure PowerShell Stack HCI
#>

[CmdletBinding()]
param(
    # Azure Local resource scoping
    [Parameter(Mandatory = $false, HelpMessage = "Azure resource group that represents your Azure Local instance scope.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName = "AzureLocal",

    [Parameter(Mandatory = $false, HelpMessage = "Custom Location resource ID that maps to your Azure Local cluster (Arc resource bridge).")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomLocationId = "/subscriptions/e5373ae1-c1cf-418e-8044-a2851af745b6/resourceGroups/AzureLocal/providers/Microsoft.ExtendedLocation/customLocations/jumpstart",

    [Parameter(Mandatory = $false, HelpMessage = "Azure region of the Arc resources.")]
    [ValidateNotNullOrEmpty()]
    [string]$Location = "westeurope",

    # Source
    [Parameter(Mandatory = $true, HelpMessage = "Name of the existing Azure Local VM image to replicate.")]
    [ValidateNotNullOrEmpty()]
    [string]$SourceImageName,

    [Parameter(Mandatory = $false, HelpMessage = "Optional override for the physical path of the source VHDX (gallery images only).")]
    [string]$SourceVhdxPath = "",

    # Target
    [Parameter(Mandatory = $false, HelpMessage = "Name of the replicated image. Defaults to '<SourceImageName>-copy'.")]
    [string]$TargetImageName = "",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the storage path object that stores the replica.")]
    [ValidateNotNullOrEmpty()]
    [string]$TargetStoragePathName = "sp-images-2",

    [Parameter(Mandatory = $false, HelpMessage = "Cluster-local directory behind the target storage path object.")]
    [ValidateNotNullOrEmpty()]
    [string]$TargetStoragePath = "C:\ClusterStorage\UserStorage_1\Images",

    [Parameter(Mandatory = $false, HelpMessage = "Overwrite an existing VHDX file at the target location.")]
    [switch]$Force
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

    if (-not $TargetImageName) { $TargetImageName = "$SourceImageName-copy" }

    # 1) Resolve source image; idempotency check on the target name
    $sourceImage = Get-AzStackHCIVMImage -ResourceGroupName $ResourceGroupName -Name $SourceImageName -ErrorAction SilentlyContinue
    if (-not $sourceImage) {
        throw "Source image '$SourceImageName' not found in resource group '$ResourceGroupName'."
    }
    $existingTarget = Get-AzStackHCIVMImage -ResourceGroupName $ResourceGroupName -Name $TargetImageName -ErrorAction SilentlyContinue
    if ($existingTarget) {
        Write-Host "ℹ️  Target image '$TargetImageName' already exists - nothing to do" -ForegroundColor Yellow
        return
    }

    # 2) Ensure the target storage path object exists
    $targetSp = Get-AzStackHCIVMStoragePath -ResourceGroupName $ResourceGroupName -Name $TargetStoragePathName -ErrorAction SilentlyContinue
    if (-not $targetSp) {
        Write-Host "🔧 Creating target storage path '$TargetStoragePathName' -> '$TargetStoragePath'..." -ForegroundColor Cyan
        $targetSp = New-AzStackHCIVMStoragePath -Name $TargetStoragePathName -ResourceGroupName $ResourceGroupName `
            -CustomLocationId $CustomLocationId -Location $Location -Path $TargetStoragePath
    }
    else {
        $TargetStoragePath = $targetSp.Path
    }

    $isMarketplace = [bool]$sourceImage.IdentifierPublisher

    if ($isMarketplace) {
        # 3a) Marketplace image: re-register on the target storage path (new download)
        $urn = "$($sourceImage.IdentifierPublisher):$($sourceImage.IdentifierOffer):$($sourceImage.IdentifierSku):$($sourceImage.VersionName)"
        Write-Host "🚀 Source is a marketplace image - re-registering '$TargetImageName' from URN '$urn' on '$TargetStoragePathName'..." -ForegroundColor Green
        Write-Host "⚠️  This triggers a new marketplace download and can take 30-90+ minutes" -ForegroundColor Yellow

        $imageParams = @{
            Name              = $TargetImageName
            ResourceGroupName = $ResourceGroupName
            CustomLocationId  = $CustomLocationId
            Location          = $Location
            OSType            = "$($sourceImage.OSType)"
            URN               = $urn
            StoragePathName   = $TargetStoragePathName
        }
        $newImage = New-AzStackHCIVMImage @imageParams
    }
    else {
        # 3b) Gallery image: copy the physical VHDX and register the copy
        $vhdxSource = if ($SourceVhdxPath) { $SourceVhdxPath } else { $sourceImage.ImagePath }
        if (-not $vhdxSource) {
            throw "Could not determine the source VHDX path of image '$SourceImageName'. Pass -SourceVhdxPath explicitly."
        }
        if (-not (Test-Path $vhdxSource)) {
            throw "Source VHDX '$vhdxSource' is not accessible from this machine. Run the script on a cluster node."
        }

        if (-not (Test-Path $TargetStoragePath)) {
            New-Item -Path $TargetStoragePath -ItemType Directory -Force | Out-Null
        }
        $destVhdx = Join-Path $TargetStoragePath "$($TargetImageName).vhdx"
        if ((Test-Path $destVhdx) -and (-not $Force)) {
            throw "Target file '$destVhdx' already exists. Pass -Force to overwrite it."
        }

        # Best-effort free-space check (CSV mount points resolve via Get-Volume)
        $sourceSizeGB = [math]::Round((Get-Item $vhdxSource).Length / 1GB, 1)
        try {
            $targetVolume = Get-Volume -FilePath $TargetStoragePath -ErrorAction Stop
            $freeGB = [math]::Round($targetVolume.SizeRemaining / 1GB, 1)
            if ($freeGB -lt $sourceSizeGB) {
                throw "Not enough free space on the target volume: $freeGB GB free, $sourceSizeGB GB needed."
            }
            Write-Host "🔍 Source size: $sourceSizeGB GB, target volume free: $freeGB GB" -ForegroundColor Cyan
        }
        catch {
            if ($_.Exception.Message -like "Not enough free space*") { throw }
            Write-Host "ℹ️  Skipping free-space check ($($_.Exception.Message))" -ForegroundColor Yellow
        }

        Write-Host "🚀 Copying '$vhdxSource' -> '$destVhdx' ($sourceSizeGB GB)..." -ForegroundColor Green
        Copy-Item -Path $vhdxSource -Destination $destVhdx -Force

        Write-Host "🔧 Registering image '$TargetImageName' on '$TargetStoragePathName'..." -ForegroundColor Cyan
        $imageParams = @{
            Name              = $TargetImageName
            ResourceGroupName = $ResourceGroupName
            CustomLocationId  = $CustomLocationId
            Location          = $Location
            OSType            = "$($sourceImage.OSType)"
            ImagePath         = $destVhdx
            StoragePathName   = $TargetStoragePathName
        }
        $newImage = New-AzStackHCIVMImage @imageParams
    }

    Write-Host "✅ Image '$SourceImageName' replicated as '$TargetImageName' (provisioning state: $($newImage.ProvisioningState))" -ForegroundColor Green
    Write-Host "💡 Next Steps: verify with az-ps-get-azure-local-images.ps1" -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
