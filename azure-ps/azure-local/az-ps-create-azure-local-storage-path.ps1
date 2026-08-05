<#
.SYNOPSIS
    Create a storage path on an Azure Local (Azure Stack HCI) cluster.

.DESCRIPTION
    This script registers a storage path object on an Azure Local cluster via the Arc
    resource bridge. Storage paths tell Azure Local where to place VM configuration files,
    OS/data disks and VM images on the cluster shared volumes (CSV).

    The script is idempotent: if a storage path with the same name already exists in the
    resource group, it is reused and the script exits successfully.

    IMPORTANT: the directory behind -StoragePath must already exist on the cluster shared
    volume. Create it on a cluster node first, e.g.:
    New-Item -Path "C:\ClusterStorage\UserStorage_2\Images" -ItemType Directory

    The default values match the XOAP Jumpstart LocalBox environment (cluster
    'localboxcluster' in resource group 'AzureLocal', CSVs UserStorage_1 / UserStorage_2).

    Uses Get-AzStackHCIVMStoragePath and New-AzStackHCIVMStoragePath.

    This script can run anywhere with an Azure context; it does not need to run on a
    cluster node.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER CustomLocationId
    Custom Location resource ID that maps to your Azure Local cluster (Arc resource bridge).
    Defaults to the XOAP LocalBox custom location "jumpstart".

.PARAMETER Location
    Azure region of the Arc resources. Defaults to "westeurope".

.PARAMETER StoragePathName
    Name of the storage path object to create. Defaults to "sp-images".

.PARAMETER StoragePath
    Cluster-local directory on a cluster shared volume the storage path points to.
    Defaults to "C:\ClusterStorage\UserStorage_2\Images".

.EXAMPLE
    .\az-ps-create-azure-local-storage-path.ps1

    Registers "sp-images" pointing to C:\ClusterStorage\UserStorage_2\Images.

.EXAMPLE
    .\az-ps-create-azure-local-storage-path.ps1 `
        -StoragePathName "sp-vms" `
        -StoragePath "C:\ClusterStorage\UserStorage_1\VMs"

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
    https://learn.microsoft.com/en-us/azure/azure-local/manage/create-storage-path

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

    # Storage path definition
    [Parameter(Mandatory = $false, HelpMessage = "Name of the storage path object to create.")]
    [ValidateNotNullOrEmpty()]
    [string]$StoragePathName = "sp-images",

    [Parameter(Mandatory = $false, HelpMessage = "Cluster-local directory on a cluster shared volume the storage path points to.")]
    [ValidateNotNullOrEmpty()]
    [string]$StoragePath = "C:\ClusterStorage\UserStorage_2\Images"
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

    # 1) Idempotency: reuse an existing storage path with the same name
    $sp = Get-AzStackHCIVMStoragePath -ResourceGroupName $ResourceGroupName -Name $StoragePathName -ErrorAction SilentlyContinue
    if ($sp) {
        Write-Host "ℹ️  Storage path '$StoragePathName' already exists ('$($sp.Path)') - nothing to do" -ForegroundColor Yellow
        return
    }

    # 2) Create the storage path
    Write-Host "🚀 Creating storage path '$StoragePathName' -> '$StoragePath'..." -ForegroundColor Green
    Write-Host "ℹ️  The directory must already exist on the cluster shared volume" -ForegroundColor Yellow

    $spParams = @{
        Name              = $StoragePathName
        ResourceGroupName = $ResourceGroupName
        CustomLocationId  = $CustomLocationId
        Location          = $Location
        Path              = $StoragePath
    }
    $sp = New-AzStackHCIVMStoragePath @spParams

    Write-Host "✅ Storage path '$StoragePathName' created (provisioning state: $($sp.ProvisioningState))" -ForegroundColor Green
    Write-Host "💡 Next Steps: register images with az-ps-create-azure-local-image.ps1 -StoragePathName '$StoragePathName'" -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
