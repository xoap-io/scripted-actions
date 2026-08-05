<#
.SYNOPSIS
    Register a VM image on an Azure Local (Azure Stack HCI) cluster from the Azure
    Marketplace or from a VHDX file.

.DESCRIPTION
    This script registers a new VM image on an Azure Local cluster via the Arc resource
    bridge. Three sources are supported (parameter sets):

    - LocalPath (default): register an existing VHD/VHDX file that resides on a cluster
      shared volume (e.g. a downloaded or exported golden image).
    - MarketplaceUrn: download an Azure Marketplace image identified by its URN
      "publisher:offer:sku:version".
    - Marketplace: download an Azure Marketplace image identified by explicit
      -Publisher/-Offer/-Sku/-MarketplaceVersion values.

    Marketplace image downloads are performed by the cluster and can take 30-90+ minutes
    depending on bandwidth; the Az.StackHCIVM module reports download progress and blocks
    until the download completes. For VHDX registration, -NoWait returns immediately.

    The script is idempotent: if an image with the same name already exists in the resource
    group, it is reused and the script exits successfully. If the target storage path object
    does not exist, it is created (the underlying CSV directory must exist on the cluster).

    The default values match the XOAP Jumpstart LocalBox environment (cluster
    'localboxcluster' in resource group 'AzureLocal').

    Uses Get/New-AzStackHCIVMImage and Get/New-AzStackHCIVMStoragePath.

    This script can run anywhere with an Azure context; it does not need to run on a
    cluster node (the VHDX path is resolved by the cluster, not by this machine).

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER CustomLocationId
    Custom Location resource ID that maps to your Azure Local cluster (Arc resource bridge).
    Defaults to the XOAP LocalBox custom location "jumpstart".

.PARAMETER Location
    Azure region of the Arc resources. Defaults to "westeurope".

.PARAMETER ImageName
    Name of the Azure Local VM image to register.

.PARAMETER VhdxPath
    Cluster-local path to the source VHD/VHDX file (LocalPath parameter set), e.g.
    "C:\ClusterStorage\UserStorage_2\Images\win11-golden.vhdx".

.PARAMETER Urn
    Azure Marketplace URN "publisher:offer:sku:version" (MarketplaceUrn parameter set), e.g.
    "microsoftwindowsdesktop:windows-11:win11-23h2-avd:22631.3155.240229".

.PARAMETER Publisher
    Azure Marketplace publisher (Marketplace parameter set), e.g. "microsoftwindowsdesktop".

.PARAMETER Offer
    Azure Marketplace offer (Marketplace parameter set), e.g. "windows-11".

.PARAMETER Sku
    Azure Marketplace SKU (Marketplace parameter set), e.g. "win11-23h2-avd".

.PARAMETER MarketplaceVersion
    Azure Marketplace image version (Marketplace parameter set), e.g. "22631.3155.240229".
    A concrete version number is required; find versions with:
    az vm image list --publisher <publisher> --offer <offer> --sku <sku> --all

.PARAMETER OsType
    Operating system type of the image: "Windows" or "Linux". Defaults to "Windows".

.PARAMETER StoragePathName
    Name of the storage path object that stores the image. Defaults to "sp-images".
    Created if missing (see az-ps-create-azure-local-storage-path.ps1).

.PARAMETER StoragePath
    Cluster-local directory used when the storage path object has to be created.
    Defaults to "C:\ClusterStorage\UserStorage_2\Images".

.PARAMETER NoWait
    Return immediately instead of waiting for the image registration to complete
    (LocalPath set only; marketplace downloads always report progress until finished).

.EXAMPLE
    .\az-ps-create-azure-local-image.ps1 `
        -ImageName "win11-23h2-avd" `
        -Urn "microsoftwindowsdesktop:windows-11:win11-23h2-avd:22631.3155.240229"

    Downloads the Windows 11 AVD marketplace image to the LocalBox cluster.

.EXAMPLE
    .\az-ps-create-azure-local-image.ps1 `
        -ImageName "win11-golden" `
        -VhdxPath "C:\ClusterStorage\UserStorage_2\Images\win11-golden.vhdx"

    Registers an existing generalized VHDX from cluster storage as a VM image.

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
    https://learn.microsoft.com/en-us/azure/azure-local/manage/virtual-machine-image-local-share

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.stackhcivm/

.COMPONENT
    Azure PowerShell Stack HCI
#>

[CmdletBinding(DefaultParameterSetName = 'LocalPath')]
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

    # Image identity
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Local VM image to register.")]
    [ValidateNotNullOrEmpty()]
    [string]$ImageName,

    # Source: local VHDX
    [Parameter(Mandatory = $true, ParameterSetName = 'LocalPath', HelpMessage = "Cluster-local path to the source VHD/VHDX file.")]
    [ValidateNotNullOrEmpty()]
    [string]$VhdxPath,

    # Source: marketplace by URN
    [Parameter(Mandatory = $true, ParameterSetName = 'MarketplaceUrn', HelpMessage = "Azure Marketplace URN 'publisher:offer:sku:version'.")]
    [ValidatePattern('^[-._a-zA-Z0-9]+:[-._a-zA-Z0-9]+:[-._a-zA-Z0-9]+:[-._a-zA-Z0-9]+$')]
    [string]$Urn,

    # Source: marketplace by explicit identifiers
    [Parameter(Mandatory = $true, ParameterSetName = 'Marketplace', HelpMessage = "Azure Marketplace publisher, e.g. 'microsoftwindowsdesktop'.")]
    [ValidateNotNullOrEmpty()]
    [string]$Publisher,

    [Parameter(Mandatory = $true, ParameterSetName = 'Marketplace', HelpMessage = "Azure Marketplace offer, e.g. 'windows-11'.")]
    [ValidateNotNullOrEmpty()]
    [string]$Offer,

    [Parameter(Mandatory = $true, ParameterSetName = 'Marketplace', HelpMessage = "Azure Marketplace SKU, e.g. 'win11-23h2-avd'.")]
    [ValidateNotNullOrEmpty()]
    [string]$Sku,

    [Parameter(Mandatory = $true, ParameterSetName = 'Marketplace', HelpMessage = "Azure Marketplace image version, e.g. '22631.3155.240229'.")]
    [ValidateNotNullOrEmpty()]
    [string]$MarketplaceVersion,

    # Image properties
    [Parameter(Mandatory = $false, HelpMessage = "Operating system type of the image: Windows or Linux.")]
    [ValidateSet("Windows", "Linux")]
    [string]$OsType = "Windows",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the storage path object that stores the image.")]
    [ValidateNotNullOrEmpty()]
    [string]$StoragePathName = "sp-images",

    [Parameter(Mandatory = $false, HelpMessage = "Cluster-local directory used when the storage path object has to be created.")]
    [ValidateNotNullOrEmpty()]
    [string]$StoragePath = "C:\ClusterStorage\UserStorage_2\Images",

    [Parameter(Mandatory = $false, HelpMessage = "Return immediately instead of waiting for the registration to complete (LocalPath set only).")]
    [switch]$NoWait
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

    # 1) Idempotency: reuse an existing image with the same name
    $existing = Get-AzStackHCIVMImage -ResourceGroupName $ResourceGroupName -Name $ImageName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "ℹ️  Image '$ImageName' already exists (OS: $($existing.OSType), state: $($existing.ProvisioningState)) - nothing to do" -ForegroundColor Yellow
        return
    }

    # 2) Ensure the storage path object exists
    $sp = Get-AzStackHCIVMStoragePath -ResourceGroupName $ResourceGroupName -Name $StoragePathName -ErrorAction SilentlyContinue
    if (-not $sp) {
        Write-Host "🔧 Creating storage path '$StoragePathName' -> '$StoragePath'..." -ForegroundColor Cyan
        $sp = New-AzStackHCIVMStoragePath -Name $StoragePathName -ResourceGroupName $ResourceGroupName `
            -CustomLocationId $CustomLocationId -Location $Location -Path $StoragePath
    }

    # 3) Register the image
    $imageParams = @{
        Name              = $ImageName
        ResourceGroupName = $ResourceGroupName
        CustomLocationId  = $CustomLocationId
        Location          = $Location
        OSType            = $OsType
        StoragePathName   = $StoragePathName
    }

    switch ($PSCmdlet.ParameterSetName) {
        'LocalPath' {
            Write-Host "🚀 Registering image '$ImageName' from '$VhdxPath'..." -ForegroundColor Green
            $imageParams['ImagePath'] = $VhdxPath
            if ($NoWait) { $imageParams['NoWait'] = $true }
        }
        'MarketplaceUrn' {
            Write-Host "🚀 Downloading marketplace image '$ImageName' from URN '$Urn'..." -ForegroundColor Green
            Write-Host "⚠️  Marketplace downloads can take 30-90+ minutes; progress is reported below" -ForegroundColor Yellow
            $imageParams['URN'] = $Urn
        }
        'Marketplace' {
            Write-Host "🚀 Downloading marketplace image '$ImageName' ($($Publisher):$($Offer):$($Sku):$($MarketplaceVersion))..." -ForegroundColor Green
            Write-Host "⚠️  Marketplace downloads can take 30-90+ minutes; progress is reported below" -ForegroundColor Yellow
            $imageParams['Publisher'] = $Publisher
            $imageParams['Offer']     = $Offer
            $imageParams['Sku']       = $Sku
            $imageParams['Version']   = $MarketplaceVersion
        }
    }

    $image = New-AzStackHCIVMImage @imageParams

    if ($NoWait -and $PSCmdlet.ParameterSetName -eq 'LocalPath') {
        Write-Host "✅ Image registration for '$ImageName' started (check status with az-ps-get-azure-local-images.ps1)" -ForegroundColor Green
    }
    else {
        Write-Host "✅ Image '$ImageName' registered (provisioning state: $($image.ProvisioningState))" -ForegroundColor Green
        Write-Host "💡 Next Steps: deploy a VM with az-ps-deploy-azure-local-vm-from-image.ps1 -VmImageName '$ImageName'" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
