<#
.SYNOPSIS
    Deploy a new Azure Local VM from a registered custom VM image.

.DESCRIPTION
    This script deploys a new virtual machine on an Azure Local (Azure Stack HCI) cluster from a
    custom VM image that was previously registered (e.g. by az-ps-deploy-azure-local-image.ps1).
    It performs the following steps:

    1. Validates that the Az.StackHCIVM module and an Azure context are available.
    2. Resolves the custom VM image and the logical network.
    3. Creates a network interface attached to the logical network (dynamic or static IP).
    4. Deploys the VM from the image using New-AzStackHCIVMVirtualMachine (ByImageId parameter set),
       with Secure Boot and vTPM enabled and the Arc guest agents provisioned.
    5. Optionally waits for WinRM to become reachable on the new VM.

    Uses Get-AzStackHCIVMImage, Get-AzStackHCIVMLogicalNetwork,
    New-AzStackHCIVMNetworkInterface, New-AzStackHCIVMVirtualMachine.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER CustomLocationId
    Custom Location resource ID that maps to your HCI cluster (Arc resource bridge).
    Defaults to the XOAP LocalBox custom location "jumpstart".

.PARAMETER Location
    Azure region of the Arc resource. Defaults to "westeurope".

.PARAMETER VmName
    Name of the virtual machine to create.

.PARAMETER VmImageName
    Name of the registered Azure Local VM image to deploy from.

.PARAMETER LogicalNetworkName
    Name of the existing logical network to attach the VM to. Defaults to
    "localboxcluster-InfraLNET" (the LocalBox infrastructure network).

.PARAMETER StaticIpAddress
    Optional static IP address for the NIC. If omitted, the IP is allocated by the logical network.

.PARAMETER VmVcpu
    Number of vCPUs for the VM. Defaults to 4.

.PARAMETER VmMemoryGB
    Memory in GB for the VM. Defaults to 8.

.PARAMETER StoragePathName
    Optional name of the storage path that hosts the VM configuration and disk. If omitted,
    the cluster places the VM automatically (high availability placement).

.PARAMETER LocalAdminCreds
    PSCredential object containing the local administrator credentials for the VM.

.PARAMETER ComputerName
    Windows computer name (hostname) inside the guest. Defaults to VmName (max. 15 characters).

.PARAMETER DataDiskNames
    Optional list of existing Azure Local virtual hard disk names to attach as data disks.

.PARAMETER WaitForWinRM
    If specified, waits until WinRM (TCP 5985) is reachable on the new VM before returning.

.PARAMETER WinRMTimeoutSec
    Timeout in seconds for the WinRM wait. Defaults to 1800 (sysprepped images run through OOBE
    on first boot, which takes a while).

.EXAMPLE
    $creds = Get-Credential
    .\az-ps-deploy-azure-local-vm-from-image.ps1 `
        -VmName "avd-host-01" `
        -VmImageName "win11-23h2-avd-gold" `
        -VmVcpu 4 `
        -VmMemoryGB 16 `
        -LocalAdminCreds $creds `
        -WaitForWinRM

    Deploys a VM with the LocalBox environment defaults (resource group "AzureLocal",
    custom location "jumpstart", logical network "localboxcluster-InfraLNET").

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Accounts, Az.StackHCIVM 1.1.0+ (Install-Module Az.StackHCIVM)

    The deployment requires an Azure Local (HCI) cluster with the Arc resource bridge configured
    and a custom VM image already registered (see az-ps-create-azure-local-image.ps1 or
    az-ps-deploy-azure-local-image.ps1).

.LINK
    https://learn.microsoft.com/en-us/azure/azure-local/manage/create-arc-virtual-machines

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

    [Parameter(Mandatory = $false, HelpMessage = "Custom Location resource ID that maps to your HCI cluster (Arc resource bridge).")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomLocationId = "/subscriptions/e5373ae1-c1cf-418e-8044-a2851af745b6/resourceGroups/AzureLocal/providers/Microsoft.ExtendedLocation/customLocations/jumpstart",

    [Parameter(Mandatory = $false, HelpMessage = "Azure region of the Arc resource (e.g. 'westeurope').")]
    [ValidateNotNullOrEmpty()]
    [string]$Location = "westeurope",

    # VM details
    [Parameter(Mandatory = $true, HelpMessage = "Name of the virtual machine to create.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the registered Azure Local VM image to deploy from.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmImageName,

    # Networking
    [Parameter(Mandatory = $false, HelpMessage = "Name of the existing logical network to attach the VM to.")]
    [ValidateNotNullOrEmpty()]
    [string]$LogicalNetworkName = "localboxcluster-InfraLNET",

    [Parameter(Mandatory = $false, HelpMessage = "Optional static IP address for the NIC.")]
    [string]$StaticIpAddress = "",

    # Sizing
    [Parameter(Mandatory = $false, HelpMessage = "Number of vCPUs for the VM. Defaults to 4.")]
    [ValidateRange(1, 128)]
    [int]$VmVcpu = 4,

    [Parameter(Mandatory = $false, HelpMessage = "Memory in GB for the VM. Defaults to 8.")]
    [ValidateRange(1, 2048)]
    [int]$VmMemoryGB = 8,

    [Parameter(Mandatory = $false, HelpMessage = "Optional storage path name that hosts the VM configuration and disk.")]
    [string]$StoragePathName = "",

    # Guest OS
    [Parameter(Mandatory = $true, HelpMessage = "PSCredential object containing the local administrator credentials for the VM.")]
    [ValidateNotNullOrEmpty()]
    [pscredential]$LocalAdminCreds,

    [Parameter(Mandatory = $false, HelpMessage = "Windows computer name inside the guest. Defaults to VmName (max. 15 characters).")]
    [ValidateLength(1, 15)]
    [string]$ComputerName = "",

    # Optional extras
    [Parameter(Mandatory = $false, HelpMessage = "Optional list of existing virtual hard disk names to attach as data disks.")]
    [string[]]$DataDiskNames = @(),

    [Parameter(Mandatory = $false, HelpMessage = "Wait until WinRM (TCP 5985) is reachable on the new VM before returning.")]
    [switch]$WaitForWinRM,

    [Parameter(Mandatory = $false, HelpMessage = "Timeout in seconds for the WinRM wait. Defaults to 1800.")]
    [ValidateRange(60, 14400)]
    [int]$WinRMTimeoutSec = 1800
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
    Write-Host "Using subscription '$($context.Subscription.Name)' ($($context.Subscription.Id))" -ForegroundColor Cyan

    if (-not $ComputerName) {
        $ComputerName = $VmName.Substring(0, [Math]::Min($VmName.Length, 15))
    }

    # 1) Resolve the custom image
    $image = Get-AzStackHCIVMImage -ResourceGroupName $ResourceGroupName -Name $VmImageName -ErrorAction SilentlyContinue
    if (-not $image) {
        $available = (Get-AzStackHCIVMImage -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue).Name -join ", "
        throw "Image '$VmImageName' not found in resource group '$ResourceGroupName'. Available images: $available"
    }
    Write-Host "Found image '$VmImageName' (OS: $($image.OsType))" -ForegroundColor Cyan

    # 2) Resolve the logical network
    $lnet = Get-AzStackHCIVMLogicalNetwork -ResourceGroupName $ResourceGroupName -Name $LogicalNetworkName -ErrorAction SilentlyContinue
    if (-not $lnet) {
        throw "Logical network '$LogicalNetworkName' not found in resource group '$ResourceGroupName'. Create it first or pass -LogicalNetworkName."
    }

    # 3) Create (or reuse) the NIC
    $nicName = "$($VmName)-nic0"
    $nic = Get-AzStackHCIVMNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName -ErrorAction SilentlyContinue
    if (-not $nic) {
        $nicParams = @{
            Name             = $nicName
            ResourceGroupName = $ResourceGroupName
            CustomLocationId = $CustomLocationId
            Location         = $Location
            SubnetId         = $lnet.Id
        }
        if ($StaticIpAddress) { $nicParams['IpAddress'] = $StaticIpAddress }

        $nic = New-AzStackHCIVMNetworkInterface @nicParams
        Write-Host "Created network interface '$nicName' on '$LogicalNetworkName'" -ForegroundColor Cyan
    }
    else {
        Write-Host "Reusing existing network interface '$nicName'" -ForegroundColor Yellow
    }

    # 4) Deploy the VM from the image
    $vmParams = @{
        Name              = $VmName
        ResourceGroupName = $ResourceGroupName
        CustomLocationId  = $CustomLocationId
        Location          = $Location
        OsType            = "Windows"
        ImageId           = $image.Id
        VmSize            = "Custom"
        VmProcessor       = $VmVcpu
        VmMemoryInMB      = ($VmMemoryGB * 1024)
        AdminUsername     = $LocalAdminCreds.UserName
        AdminPassword     = $LocalAdminCreds.Password
        ComputerName      = $ComputerName
        NicId             = @($nic.Id)
        SecureBootEnabled = $true
        EnableTpm         = $true
        ProvisionVMConfigAgent = $true
    }
    if ($StoragePathName) { $vmParams['StoragePathName'] = $StoragePathName }
    if ($DataDiskNames.Count -gt 0) { $vmParams['DataDiskName'] = $DataDiskNames }

    Write-Host "Deploying VM '$VmName' from image '$VmImageName' ($VmVcpu vCPU / $VmMemoryGB GB)..." -ForegroundColor Cyan
    $vm = New-AzStackHCIVMVirtualMachine @vmParams
    Write-Host "VM provisioning state: $($vm.ProvisioningState)" -ForegroundColor Cyan

    # 5) Report the assigned IP
    $nic = Get-AzStackHCIVMNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName
    $vmIp = $nic.IPConfiguration.IPAddress | Select-Object -First 1
    if ($vmIp) {
        Write-Host "VM IP address: $vmIp" -ForegroundColor Cyan
    }

    # 6) Optionally wait for the guest to come up (sysprepped images run OOBE on first boot)
    if ($WaitForWinRM) {
        $target = if ($vmIp) { $vmIp } else { $ComputerName }
        Write-Host "Waiting for WinRM on '$target' (timeout: $WinRMTimeoutSec s)..." -ForegroundColor Cyan
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $up = $false
        do {
            Start-Sleep -Seconds 15
            $up = Test-NetConnection -ComputerName $target -Port 5985 -InformationLevel Quiet -WarningAction SilentlyContinue
        } while (-not $up -and $sw.Elapsed.TotalSeconds -lt $WinRMTimeoutSec)

        if (-not $up) {
            throw "VM '$VmName' did not open WinRM (5985) within $WinRMTimeoutSec seconds."
        }
        Write-Host "WinRM is reachable." -ForegroundColor Cyan
    }

    Write-Host "✅ VM '$VmName' deployed from image '$VmImageName'." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
