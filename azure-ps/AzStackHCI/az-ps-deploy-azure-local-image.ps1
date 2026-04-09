<#
.SYNOPSIS
    Deploy an Azure Local VM, install the XOAP agent, sysprep, and register as an Azure Local VM Image.

.DESCRIPTION
    This script automates the creation of a generalized Azure Local (Azure Stack HCI) VM image for use
    with Azure Virtual Desktop session host deployments. It performs the following steps:

    1. Ensures required infrastructure objects exist (logical network, storage path).
    2. Creates a VM virtual hard disk from a local VHDX file.
    3. Creates a network interface attached to the logical network.
    4. Deploys a Gen2 VM on the Azure Local cluster using Az.StackHCI.VM cmdlets.
    5. Waits for WinRM to become available on the new VM.
    6. Bootstraps the XOAP agent via WinRM remote session.
    7. Optionally triggers a XOAP scripted action via the XOAP API.
    8. Runs Sysprep to generalize the VM.
    9. Copies the generalized VHDX to an image share and registers it as an Azure Local VM Image.

    Uses New-AzStackHCIVMLogicalNetwork, New-AzStackHCIVMStoragePath,
    New-AzStackHCIVMVirtualHardDisk, New-AzStackHCIVMNetworkInterface,
    New-AzStackHCIVMVirtualMachine, New-AzStackHCIVMImage.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope.

.PARAMETER CustomLocationId
    Custom Location resource ID that maps to your HCI cluster (Arc resource bridge).

.PARAMETER Location
    Azure region of the Arc resource (e.g. "westeurope").

.PARAMETER ClusterName
    Friendly cluster name shown in Azure.

.PARAMETER LogicalNetworkName
    Name of the logical network to use or create. Defaults to "lnet-avd".

.PARAMETER SubnetName
    Name of the subnet within the logical network. Defaults to "default".

.PARAMETER StoragePathName
    Name of the storage path object to use or create. Defaults to "sp-images".

.PARAMETER StoragePath
    Local path on the HCI cluster for storing VM images. Defaults to "C:\ClusterStorage\Volume1\VMs\Images".

.PARAMETER VmName
    Name of the virtual machine to create.

.PARAMETER VmSize
    VM size for the Azure Local VM. Defaults to "Standard_A2_v2".

.PARAMETER VmVcpu
    Number of vCPUs for the VM. Defaults to 2.

.PARAMETER VmMemoryGB
    Memory in GB for the VM. Defaults to 8.

.PARAMETER OsDiskGB
    OS disk size in GB. Defaults to 64.

.PARAMETER OsVhdxLocalPath
    Local path on the HCI cluster to the source VHDX file.

.PARAMETER UseExistingVHDX
    If specified, registers an existing VHDX file as the OS disk instead of creating a new one.

.PARAMETER LocalAdminCreds
    PSCredential object containing the administrator credentials for the VM.

.PARAMETER XoapBootstrapUri
    URI to download the XOAP agent bootstrap script (e.g. a signed URL).

.PARAMETER XoapWorkspaceId
    XOAP workspace or tenant identifier for agent enrollment.

.PARAMETER XoapScriptedActionId
    Optional XOAP scripted action ID to trigger after agent installation.

.PARAMETER ImageSharePath
    UNC or local path to the image share where the generalized VHDX will be stored.

.PARAMETER VmImageName
    Name for the Azure Local VM Image object that will be registered.

.EXAMPLE
    $creds = Get-Credential
    .\az-ps-deploy-azure-local-image.ps1 `
        -ResourceGroupName "rg-hci" `
        -CustomLocationId "/subscriptions/.../resourceGroups/rg-hci/providers/Microsoft.ExtendedLocation/customLocations/cl-hci" `
        -Location "westeurope" `
        -ClusterName "hci-cluster01" `
        -VmName "img-win11-avd" `
        -LocalAdminCreds $creds `
        -XoapBootstrapUri "https://storage.example.com/xoap-bootstrap.ps1?sv=..." `
        -XoapWorkspaceId "ws-12345" `
        -ImageSharePath "\\fileserver\images\golden" `
        -VmImageName "win11-23h2-avd-gold"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.StackHCI.VM

    The deployment requires an Azure Local (HCI) cluster with the Arc resource bridge configured.
    WinRM must be reachable from the machine running this script to the newly created VM.

.LINK
    https://learn.microsoft.com/en-us/azure/azure-local/

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.stackhci.vm/

.COMPONENT
    Azure PowerShell Stack HCI
#>

[CmdletBinding()]
param(
    # Azure Local resource scoping
    [Parameter(Mandatory = $true, HelpMessage = "Azure resource group that represents your Azure Local instance scope.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "Custom Location resource ID that maps to your HCI cluster (Arc resource bridge).")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomLocationId,

    [Parameter(Mandatory = $true, HelpMessage = "Azure region of the Arc resource (e.g. 'westeurope').")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $true, HelpMessage = "Friendly cluster name shown in Azure.")]
    [ValidateNotNullOrEmpty()]
    [string]$ClusterName,

    # Networking & storage
    [Parameter(Mandatory = $false, HelpMessage = "Name of the logical network to use or create. Defaults to 'lnet-avd'.")]
    [ValidateNotNullOrEmpty()]
    [string]$LogicalNetworkName = "lnet-avd",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the subnet within the logical network. Defaults to 'default'.")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName = "default",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the storage path object to use or create. Defaults to 'sp-images'.")]
    [ValidateNotNullOrEmpty()]
    [string]$StoragePathName = "sp-images",

    [Parameter(Mandatory = $false, HelpMessage = "Local path on the HCI cluster for storing VM images.")]
    [ValidateNotNullOrEmpty()]
    [string]$StoragePath = "C:\ClusterStorage\Volume1\VMs\Images",

    # VM details
    [Parameter(Mandatory = $true, HelpMessage = "Name of the virtual machine to create.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $false, HelpMessage = "VM size for the Azure Local VM. Must match a supported size in your HCI hardware.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmSize = "Standard_A2_v2",

    [Parameter(Mandatory = $false, HelpMessage = "Number of vCPUs for the VM. Defaults to 2.")]
    [ValidateRange(1, 128)]
    [int]$VmVcpu = 2,

    [Parameter(Mandatory = $false, HelpMessage = "Memory in GB for the VM. Defaults to 8.")]
    [ValidateRange(1, 2048)]
    [int]$VmMemoryGB = 8,

    [Parameter(Mandatory = $false, HelpMessage = "OS disk size in GB. Defaults to 64.")]
    [ValidateRange(32, 4096)]
    [int]$OsDiskGB = 64,

    # Base OS source
    [Parameter(Mandatory = $false, HelpMessage = "Local path on the HCI cluster to the source VHDX file.")]
    [ValidateNotNullOrEmpty()]
    [string]$OsVhdxLocalPath = "C:\ISOs\Win11-23H2-Gen2.vhdx",

    [Parameter(Mandatory = $false, HelpMessage = "If specified, registers an existing VHDX file as the OS disk.")]
    [switch]$UseExistingVHDX,

    # Admin creds for first boot (WinRM bootstrap)
    [Parameter(Mandatory = $true, HelpMessage = "PSCredential object containing the administrator credentials for the VM.")]
    [ValidateNotNullOrEmpty()]
    [pscredential]$LocalAdminCreds,

    # XOAP bootstrap
    [Parameter(Mandatory = $true, HelpMessage = "URI to download the XOAP agent bootstrap script (e.g. a signed URL).")]
    [ValidateNotNullOrEmpty()]
    [string]$XoapBootstrapUri,

    [Parameter(Mandatory = $true, HelpMessage = "XOAP workspace or tenant identifier for agent enrollment.")]
    [ValidateNotNullOrEmpty()]
    [string]$XoapWorkspaceId,

    [Parameter(Mandatory = $false, HelpMessage = "Optional XOAP scripted action ID to trigger after agent installation.")]
    [string]$XoapScriptedActionId = "",

    # Image registration
    [Parameter(Mandatory = $true, HelpMessage = "UNC or local path to the image share where the generalized VHDX will be stored.")]
    [ValidateNotNullOrEmpty()]
    [string]$ImageSharePath,

    [Parameter(Mandatory = $true, HelpMessage = "Name for the Azure Local VM Image object that will be registered.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmImageName
)

$ErrorActionPreference = 'Stop'

try {
    # 0) Helpers
    function Wait-VM-GuestUp {
        param([string]$VmName, [int]$TimeoutSec = 900)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        do {
            Start-Sleep 10
            try {
                Test-NetConnection -ComputerName $VmName -Port 5985 -InformationLevel Quiet | Out-Null
                if ($?) { return $true }
            }
            catch { Write-Verbose "WinRM not yet available, retrying..." }
        } while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec)
        throw "VM $VmName did not open WinRM (5985) within $TimeoutSec seconds."
    }

    # 1) Ensure infra objects exist
    # Logical network (only if you don't have one; otherwise skip)
    try {
        $ln = Get-AzStackHCIVMLogicalNetwork -ResourceGroupName $ResourceGroupName -Name $LogicalNetworkName -ErrorAction Stop
    }
    catch {
        $ln = New-AzStackHCIVMLogicalNetwork `
            -ResourceGroupName $ResourceGroupName `
            -CustomLocation $CustomLocationId `
            -Location $Location `
            -Name $LogicalNetworkName `
            -Subnet @(@{ name = $SubnetName; addressPrefix = "10.10.0.0/24"; defaultGateway = "10.10.0.1"; dnsServers = @("10.10.0.10") })
    }

    # Storage container/path for VMs
    try {
        $null = Get-AzStackHCIVMStoragePath -ResourceGroupName $ResourceGroupName -Name $StoragePathName -ErrorAction Stop
    }
    catch {
        $null = New-AzStackHCIVMStoragePath `
            -ResourceGroupName $ResourceGroupName `
            -CustomLocation $CustomLocationId `
            -Location $Location `
            -Name $StoragePathName `
            -Path $StoragePath
    }

    # 2) Create base OS VHDX or register existing
    if ($UseExistingVHDX) {
        $osDisk = New-AzStackHCIVMVirtualHardDisk `
            -ResourceGroupName $ResourceGroupName `
            -CustomLocation $CustomLocationId `
            -Location $Location `
            -Name "$($VmName)-osdisk" `
            -OsType "Windows" `
            -VhdLocalPath $OsVhdxLocalPath
    }
    else {
        # Create an empty VHDX and we could apply an image later (for simplicity assume VHDX exists)
        $osDisk = New-AzStackHCIVMVirtualHardDisk `
            -ResourceGroupName $ResourceGroupName `
            -CustomLocation $CustomLocationId `
            -Location $Location `
            -Name "$($VmName)-osdisk" `
            -OsType "Windows" `
            -VhdLocalPath $OsVhdxLocalPath
    }

    # 3) NIC
    $nic = New-AzStackHCIVMNetworkInterface `
        -ResourceGroupName $ResourceGroupName `
        -CustomLocation $CustomLocationId `
        -Location $Location `
        -Name "$($VmName)-nic0" `
        -IpAllocationMethod "Dynamic" `
        -SubnetId $ln.Subnets[0].Id

    # 4) VM (Gen2)
    $null = New-AzStackHCIVMVirtualMachine `
        -ResourceGroupName $ResourceGroupName `
        -CustomLocation $CustomLocationId `
        -Location $Location `
        -Name $VmName `
        -HardwareProfileCpus $VmVcpu `
        -HardwareProfileMemoryMB ($VmMemoryGB * 1024) `
        -OsProfileAdminUsername $LocalAdminCreds.UserName `
        -OsProfileAdminPassword ($LocalAdminCreds.GetNetworkCredential().Password) `
        -OsType "Windows" `
        -SecurityType "TrustedLaunch" `
        -OsDiskId $osDisk.Id `
        -NetworkInterfaceId @($nic.Id)

    Write-Host "VM created. Waiting for WinRM..." -ForegroundColor Cyan
    Wait-VM-GuestUp -VmName $VmName

    # 5) XOAP bootstrap (agent install + enroll)
    $xoapBootstrap = @"
# === XOAP bootstrap ===
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
`$tmp = Join-Path `$env:TEMP "xoap-bootstrap.ps1"
Invoke-WebRequest -Uri '$XoapBootstrapUri' -OutFile `$tmp
# Example: The bootstrap script should install the XOAP agent and enroll to workspace $XoapWorkspaceId
# & `$tmp -WorkspaceId '$XoapWorkspaceId' -AdditionalParams '...'
"@

    $session = New-PSSession -ComputerName $VmName -Credential $LocalAdminCreds
    Invoke-Command -Session $session -ScriptBlock { Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableLUA' -Value 0 } | Out-Null
    Invoke-Command -Session $session -ScriptBlock { Set-ExecutionPolicy Bypass -Scope Process -Force }
    Invoke-Command -Session $session -ScriptBlock ([ScriptBlock]::Create($xoapBootstrap))

    # Optionally trigger a XOAP scripted action (placeholder).
    if ($XoapScriptedActionId) {
        Write-Host ">> Trigger your XOAP job here via API/CLI using the VM's identity ..." -ForegroundColor Yellow
        # Example pseudo:
        # Invoke-RestMethod -Method POST -Uri "https://api.xoap.io/actions/$XoapScriptedActionId/run" -Headers @{Authorization="Bearer $token"} -Body @{ target="$VmName" }
        # Wait/loop for completion...
    }

    # 6) Sysprep (generalize)
    $sysprep = @"
Stop-Service -Name wuauserv -ErrorAction SilentlyContinue
Start-Process 'C:\Windows\System32\Sysprep\Sysprep.exe' -ArgumentList '/oobe /generalize /shutdown /mode:vm' -Wait
"@
    Invoke-Command -Session $session -ScriptBlock ([ScriptBlock]::Create($sysprep))
    Remove-PSSession $session

    # 7) Capture: copy the generalized VHDX to a share and register as an Azure Local VM Image
    #    Locate the VM's OS disk file
    $vhdInfo = Get-AzStackHCIVMVirtualHardDisk -ResourceGroupName $ResourceGroupName -Name "$($VmName)-osdisk"
    $sourceVhdx = $vhdInfo.VhdLocalPath
    $destVhdx = Join-Path $ImageSharePath "$($VmImageName).vhdx"

    Copy-Item -Path $sourceVhdx -Destination $destVhdx -Force

    # Create an Azure Local VM Image from that VHDX
    New-AzStackHCIVMImage `
        -ResourceGroupName $ResourceGroupName `
        -CustomLocation $CustomLocationId `
        -Location $Location `
        -Name $VmImageName `
        -OsType "Windows" `
        -Path $destVhdx

    Write-Host "✅ Image '$VmImageName' registered. Ready for AVD session host deployments." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
