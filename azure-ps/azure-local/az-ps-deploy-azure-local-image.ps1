<#
.SYNOPSIS
    Build a generalized Azure Local VM image: deploy a builder VM from a base VHDX, install the
    XOAP agent, sysprep, and register the result as an Azure Local VM image.

.DESCRIPTION
    This script automates the creation of a generalized Azure Local (Azure Stack HCI) VM image for use
    with Azure Virtual Desktop session host deployments. It performs the following steps:

    1. Validates that the Az.StackHCIVM module and an Azure context are available.
    2. Ensures required infrastructure objects exist (logical network, storage path).
    3. Registers the source VHDX as a base image (New-AzStackHCIVMImage -ImagePath).
       Note: the Az.StackHCIVM module cannot attach a raw VHDX file directly as an OS disk —
       New-AzStackHCIVMVirtualHardDisk only creates new empty disks. Registering the VHDX as an
       image and deploying from it is the supported path.
    4. Creates a network interface attached to the logical network.
    5. Deploys a builder VM from the base image (Secure Boot + vTPM enabled).
    6. Waits for WinRM to become available on the new VM (via its IP address).
    7. Bootstraps the XOAP agent via WinRM remote session.
    8. Optionally triggers a XOAP scripted action via the XOAP API.
    9. Runs Sysprep to generalize the VM and waits for it to power off.
   10. Copies the generalized VHDX to the image path and registers it as an Azure Local VM image.
   11. Optionally removes the builder VM and its NIC.

    IMPORTANT: Steps 9-10 (locating and copying the OS disk VHDX) require this script to run ON a
    cluster node (or a machine with the Hyper-V module and access to the cluster storage), because
    the OS disk file path is resolved via Get-VMHardDiskDrive. This matches the XOAP Scripted
    Actions / LocalBox scenario where the script executes on the Azure Local host.

    Uses Get/New-AzStackHCIVMLogicalNetwork, Get/New-AzStackHCIVMStoragePath,
    New-AzStackHCIVMImage, Get/New-AzStackHCIVMNetworkInterface,
    New-AzStackHCIVMVirtualMachine, Remove-AzStackHCIVMVirtualMachine.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER CustomLocationId
    Custom Location resource ID that maps to your HCI cluster (Arc resource bridge).
    Defaults to the XOAP LocalBox custom location "jumpstart".

.PARAMETER Location
    Azure region of the Arc resource. Defaults to "westeurope".

.PARAMETER LogicalNetworkName
    Name of the logical network to use or create. Defaults to "localboxcluster-InfraLNET"
    (the LocalBox infrastructure network). Pre-creating the logical network
    (az-ps-create-azure-local-logical-network.ps1) is recommended; the fallback creation
    here uses the subnet/pool parameters below.

.PARAMETER SubnetName
    Name of the subnet within the logical network (only used when creating it). Defaults to "default".

.PARAMETER VmSwitchName
    Name of the external Hyper-V switch on the cluster (only used when creating the logical network).
    Defaults to "ConvergedSwitch(compute_management)" (the LocalBox default switch).

.PARAMETER AddressPrefix
    Address prefix for the subnet (only used when creating the logical network). Defaults to "192.168.1.0/24".

.PARAMETER IpPoolStart
    First IP of the static IP pool (only used when creating the logical network). Defaults to "192.168.1.200".

.PARAMETER IpPoolEnd
    Last IP of the static IP pool (only used when creating the logical network). Defaults to "192.168.1.240".

.PARAMETER Gateway
    Default gateway for the subnet, configured as a 0.0.0.0/0 route (only used when creating
    the logical network). Defaults to "192.168.1.1".

.PARAMETER DnsServers
    DNS servers for the logical network (only used when creating it). Defaults to @("192.168.1.254").

.PARAMETER StoragePathName
    Name of the storage path object to use or create. Defaults to "sp-images".

.PARAMETER StoragePath
    Local path on the HCI cluster for the storage path object. Defaults to
    "C:\ClusterStorage\UserStorage_2\Images".

.PARAMETER VmName
    Name of the builder virtual machine to create (also used as the guest computer name, max. 15 characters).

.PARAMETER VmVcpu
    Number of vCPUs for the VM. Defaults to 4.

.PARAMETER VmMemoryGB
    Memory in GB for the VM. Defaults to 8.

.PARAMETER OsVhdxLocalPath
    Path to the source (base) VHDX file. Must be reachable by the Arc resource bridge,
    i.e. a cluster-local path such as "C:\ClusterStorage\Volume1\ISOs\Win11-23H2-Gen2.vhdx".

.PARAMETER BaseImageName
    Name for the base image registered from OsVhdxLocalPath. Defaults to "<VmImageName>-base".

.PARAMETER LocalAdminCreds
    PSCredential object containing the administrator credentials for the VM.

.PARAMETER XoapBootstrapUri
    URI to download the XOAP agent bootstrap script (e.g. a signed URL).

.PARAMETER XoapWorkspaceId
    XOAP workspace or tenant identifier for agent enrollment.

.PARAMETER XoapScriptedActionId
    Optional XOAP scripted action ID to trigger after agent installation.

.PARAMETER ImageSharePath
    Cluster-local path where the generalized VHDX will be stored and registered from
    (e.g. "C:\ClusterStorage\Volume1\VMs\Images\golden"). Must be reachable by the Arc resource
    bridge — plain UNC shares outside the cluster are not supported for image registration.

.PARAMETER VmImageName
    Name for the Azure Local VM image that will be registered.

.PARAMETER RemoveBuilderVm
    If specified, deletes the builder VM and its NIC after the image has been registered.

.PARAMETER WinRMTimeoutSec
    Timeout in seconds waiting for WinRM on the builder VM. Defaults to 1800.

.EXAMPLE
    $creds = Get-Credential
    .\az-ps-deploy-azure-local-image.ps1 `
        -VmName "img-win11-avd" `
        -OsVhdxLocalPath "C:\ClusterStorage\UserStorage_2\ISOs\Win11-23H2-Gen2.vhdx" `
        -LocalAdminCreds $creds `
        -XoapBootstrapUri "https://storage.example.com/xoap-bootstrap.ps1?sv=..." `
        -XoapWorkspaceId "ws-12345" `
        -ImageSharePath "C:\ClusterStorage\UserStorage_2\Images\golden" `
        -VmImageName "win11-23h2-avd-gold" `
        -RemoveBuilderVm

    Builds a golden image with the LocalBox environment defaults (resource group
    "AzureLocal", custom location "jumpstart", logical network "localboxcluster-InfraLNET").

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Accounts, Az.StackHCIVM 1.1.0+ (Install-Module Az.StackHCIVM), Hyper-V module for the capture phase.

    The deployment requires an Azure Local (HCI) cluster with the Arc resource bridge configured.
    WinRM must be reachable from the machine running this script to the newly created VM.

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

    [Parameter(Mandatory = $false, HelpMessage = "Custom Location resource ID that maps to your HCI cluster (Arc resource bridge).")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomLocationId = "/subscriptions/e5373ae1-c1cf-418e-8044-a2851af745b6/resourceGroups/AzureLocal/providers/Microsoft.ExtendedLocation/customLocations/jumpstart",

    [Parameter(Mandatory = $false, HelpMessage = "Azure region of the Arc resource (e.g. 'westeurope').")]
    [ValidateNotNullOrEmpty()]
    [string]$Location = "westeurope",

    # Networking & storage
    [Parameter(Mandatory = $false, HelpMessage = "Name of the logical network to use or create. Defaults to 'localboxcluster-InfraLNET'.")]
    [ValidateNotNullOrEmpty()]
    [string]$LogicalNetworkName = "localboxcluster-InfraLNET",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the subnet within the logical network (creation only). Defaults to 'default'.")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName = "default",

    [Parameter(Mandatory = $false, HelpMessage = "External Hyper-V switch name on the cluster (creation only).")]
    [ValidateNotNullOrEmpty()]
    [string]$VmSwitchName = "ConvergedSwitch(compute_management)",

    [Parameter(Mandatory = $false, HelpMessage = "Subnet address prefix (creation only). Defaults to '192.168.1.0/24'.")]
    [ValidateNotNullOrEmpty()]
    [string]$AddressPrefix = "192.168.1.0/24",

    [Parameter(Mandatory = $false, HelpMessage = "First IP of the static IP pool (creation only).")]
    [ValidateNotNullOrEmpty()]
    [string]$IpPoolStart = "192.168.1.200",

    [Parameter(Mandatory = $false, HelpMessage = "Last IP of the static IP pool (creation only).")]
    [ValidateNotNullOrEmpty()]
    [string]$IpPoolEnd = "192.168.1.240",

    [Parameter(Mandatory = $false, HelpMessage = "Default gateway for the subnet, set as 0.0.0.0/0 route (creation only).")]
    [ValidateNotNullOrEmpty()]
    [string]$Gateway = "192.168.1.1",

    [Parameter(Mandatory = $false, HelpMessage = "DNS servers for the logical network (creation only).")]
    [string[]]$DnsServers = @("192.168.1.254"),

    [Parameter(Mandatory = $false, HelpMessage = "Name of the storage path object to use or create. Defaults to 'sp-images'.")]
    [ValidateNotNullOrEmpty()]
    [string]$StoragePathName = "sp-images",

    [Parameter(Mandatory = $false, HelpMessage = "Local path on the HCI cluster for the storage path object.")]
    [ValidateNotNullOrEmpty()]
    [string]$StoragePath = "C:\ClusterStorage\UserStorage_2\Images",

    # VM details
    [Parameter(Mandatory = $true, HelpMessage = "Name of the builder virtual machine to create (max. 15 characters).")]
    [ValidateLength(1, 15)]
    [string]$VmName,

    [Parameter(Mandatory = $false, HelpMessage = "Number of vCPUs for the VM. Defaults to 4.")]
    [ValidateRange(1, 128)]
    [int]$VmVcpu = 4,

    [Parameter(Mandatory = $false, HelpMessage = "Memory in GB for the VM. Defaults to 8.")]
    [ValidateRange(1, 2048)]
    [int]$VmMemoryGB = 8,

    # Base OS source
    [Parameter(Mandatory = $true, HelpMessage = "Cluster-local path to the source VHDX file.")]
    [ValidateNotNullOrEmpty()]
    [string]$OsVhdxLocalPath,

    [Parameter(Mandatory = $false, HelpMessage = "Name for the base image registered from the source VHDX. Defaults to '<VmImageName>-base'.")]
    [string]$BaseImageName = "",

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
    [Parameter(Mandatory = $true, HelpMessage = "Cluster-local path where the generalized VHDX will be stored and registered from.")]
    [ValidateNotNullOrEmpty()]
    [string]$ImageSharePath,

    [Parameter(Mandatory = $true, HelpMessage = "Name for the Azure Local VM image that will be registered.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmImageName,

    [Parameter(Mandatory = $false, HelpMessage = "Delete the builder VM and its NIC after the image has been registered.")]
    [switch]$RemoveBuilderVm,

    [Parameter(Mandatory = $false, HelpMessage = "Timeout in seconds waiting for WinRM on the builder VM. Defaults to 1800.")]
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

    if (-not $BaseImageName) { $BaseImageName = "$VmImageName-base" }

    # Helper: wait until WinRM (5985) answers on the given address
    function Wait-VMGuestUp {
        param([string]$Target, [int]$TimeoutSec)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        do {
            Start-Sleep -Seconds 15
            $up = Test-NetConnection -ComputerName $Target -Port 5985 -InformationLevel Quiet -WarningAction SilentlyContinue
        } while (-not $up -and $sw.Elapsed.TotalSeconds -lt $TimeoutSec)
        if (-not $up) {
            throw "Target '$Target' did not open WinRM (5985) within $TimeoutSec seconds."
        }
    }

    # 1) Ensure infra objects exist
    $ln = Get-AzStackHCIVMLogicalNetwork -ResourceGroupName $ResourceGroupName -Name $LogicalNetworkName -ErrorAction SilentlyContinue
    if (-not $ln) {
        Write-Host "Creating logical network '$LogicalNetworkName' on switch '$VmSwitchName'..." -ForegroundColor Cyan
        $lnetParams = @{
            Name               = $LogicalNetworkName
            ResourceGroupName  = $ResourceGroupName
            CustomLocationId   = $CustomLocationId
            Location           = $Location
            VMSwitchName       = $VmSwitchName
            SubnetName         = $SubnetName
            AddressPrefix      = @($AddressPrefix)
            IpAllocationMethod = "Static"
            IpPoolStart        = $IpPoolStart
            IpPoolEnd          = $IpPoolEnd
            DnsServer          = $DnsServers
            Route              = @(
                @{
                    Name             = "default"
                    AddressPrefix    = "0.0.0.0/0"
                    NextHopIpAddress = $Gateway
                }
            )
        }
        $ln = New-AzStackHCIVMLogicalNetwork @lnetParams
    }

    $sp = Get-AzStackHCIVMStoragePath -ResourceGroupName $ResourceGroupName -Name $StoragePathName -ErrorAction SilentlyContinue
    if (-not $sp) {
        Write-Host "Creating storage path '$StoragePathName' -> '$StoragePath'..." -ForegroundColor Cyan
        $sp = New-AzStackHCIVMStoragePath `
            -Name $StoragePathName `
            -ResourceGroupName $ResourceGroupName `
            -CustomLocationId $CustomLocationId `
            -Location $Location `
            -Path $StoragePath
    }

    # 2) Register the source VHDX as the base image
    $baseImage = Get-AzStackHCIVMImage -ResourceGroupName $ResourceGroupName -Name $BaseImageName -ErrorAction SilentlyContinue
    if (-not $baseImage) {
        Write-Host "Registering base image '$BaseImageName' from '$OsVhdxLocalPath' (this copies the VHDX and can take a while)..." -ForegroundColor Cyan
        $baseImage = New-AzStackHCIVMImage `
            -Name $BaseImageName `
            -ResourceGroupName $ResourceGroupName `
            -CustomLocationId $CustomLocationId `
            -Location $Location `
            -OSType "Windows" `
            -ImagePath $OsVhdxLocalPath `
            -StoragePathName $StoragePathName
    }
    else {
        Write-Host "Reusing existing base image '$BaseImageName'" -ForegroundColor Yellow
    }

    # 3) NIC
    $nicName = "$($VmName)-nic0"
    $nic = Get-AzStackHCIVMNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName -ErrorAction SilentlyContinue
    if (-not $nic) {
        $nic = New-AzStackHCIVMNetworkInterface `
            -Name $nicName `
            -ResourceGroupName $ResourceGroupName `
            -CustomLocationId $CustomLocationId `
            -Location $Location `
            -SubnetId $ln.Id
    }

    # 4) Builder VM (Gen2, Secure Boot + vTPM) from the base image
    Write-Host "Deploying builder VM '$VmName' from image '$BaseImageName'..." -ForegroundColor Cyan
    $null = New-AzStackHCIVMVirtualMachine `
        -Name $VmName `
        -ResourceGroupName $ResourceGroupName `
        -CustomLocationId $CustomLocationId `
        -Location $Location `
        -OsType "Windows" `
        -ImageId $baseImage.Id `
        -VmSize "Custom" `
        -VmProcessor $VmVcpu `
        -VmMemoryInMB ($VmMemoryGB * 1024) `
        -AdminUsername $LocalAdminCreds.UserName `
        -AdminPassword $LocalAdminCreds.Password `
        -ComputerName $VmName `
        -NicId @($nic.Id) `
        -StoragePathName $StoragePathName `
        -SecureBootEnabled `
        -EnableTpm `
        -ProvisionVMConfigAgent

    # Resolve the VM's IP from the NIC (name resolution for a fresh workgroup VM is unreliable)
    $nic = Get-AzStackHCIVMNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName
    $vmIp = $nic.IPConfiguration.IPAddress | Select-Object -First 1
    if (-not $vmIp) { $vmIp = $VmName }
    Write-Host "VM created (IP: $vmIp). Waiting for WinRM..." -ForegroundColor Cyan
    Wait-VMGuestUp -Target $vmIp -TimeoutSec $WinRMTimeoutSec

    # WinRM to a workgroup machine by IP requires it in TrustedHosts
    $trusted = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
    if ($trusted -notlike "*$vmIp*" -and $trusted -ne '*') {
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $vmIp -Concatenate -Force
    }

    # 5) XOAP bootstrap (agent install + enroll)
    $xoapBootstrap = @"
# === XOAP bootstrap ===
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
`$tmp = Join-Path `$env:TEMP "xoap-bootstrap.ps1"
Invoke-WebRequest -Uri '$XoapBootstrapUri' -OutFile `$tmp
# Example: The bootstrap script should install the XOAP agent and enroll to workspace $XoapWorkspaceId
# & `$tmp -WorkspaceId '$XoapWorkspaceId' -AdditionalParams '...'
"@

    $session = New-PSSession -ComputerName $vmIp -Credential $LocalAdminCreds
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

    # 6) Sysprep (generalize + shutdown). The connection drops when the guest shuts down.
    Write-Host "Running Sysprep in '$VmName'..." -ForegroundColor Cyan
    $sysprep = @"
Stop-Service -Name wuauserv -ErrorAction SilentlyContinue
Start-Process 'C:\Windows\System32\Sysprep\Sysprep.exe' -ArgumentList '/oobe /generalize /shutdown /mode:vm' -Wait
"@
    try {
        Invoke-Command -Session $session -ScriptBlock ([ScriptBlock]::Create($sysprep))
    }
    catch {
        Write-Verbose "WinRM session ended during sysprep shutdown (expected): $($_.Exception.Message)"
    }
    Remove-PSSession $session -ErrorAction SilentlyContinue

    # Wait until Hyper-V reports the VM as powered off (requires running on a cluster node)
    if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
        throw "The Hyper-V module is required for the capture phase. Run this script on a cluster node."
    }
    Write-Host "Waiting for '$VmName' to power off..." -ForegroundColor Cyan
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ((Get-VM -Name $VmName).State -ne 'Off') {
        if ($sw.Elapsed.TotalMinutes -gt 30) { throw "VM '$VmName' did not shut down within 30 minutes after sysprep." }
        Start-Sleep 15
    }

    # 7) Capture: copy the generalized VHDX and register it as an Azure Local VM image
    $sourceVhdx = (Get-VM -Name $VmName | Get-VMHardDiskDrive | Select-Object -First 1).Path
    if (-not $sourceVhdx) { throw "Could not locate the OS disk VHDX of VM '$VmName' via Get-VMHardDiskDrive." }

    if (-not (Test-Path $ImageSharePath)) { New-Item -Path $ImageSharePath -ItemType Directory -Force | Out-Null }
    $destVhdx = Join-Path $ImageSharePath "$($VmImageName).vhdx"
    Write-Host "Copying '$sourceVhdx' -> '$destVhdx'..." -ForegroundColor Cyan
    Copy-Item -Path $sourceVhdx -Destination $destVhdx -Force

    Write-Host "Registering image '$VmImageName'..." -ForegroundColor Cyan
    New-AzStackHCIVMImage `
        -Name $VmImageName `
        -ResourceGroupName $ResourceGroupName `
        -CustomLocationId $CustomLocationId `
        -Location $Location `
        -OSType "Windows" `
        -ImagePath $destVhdx `
        -StoragePathName $StoragePathName

    # 8) Optional cleanup of the builder VM
    if ($RemoveBuilderVm) {
        Write-Host "Removing builder VM '$VmName' and NIC '$nicName'..." -ForegroundColor Cyan
        Remove-AzStackHCIVMVirtualMachine -Name $VmName -ResourceGroupName $ResourceGroupName -Confirm:$false
        Remove-AzStackHCIVMNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName -Confirm:$false
    }

    Write-Host "✅ Image '$VmImageName' registered. Ready for AVD session host deployments." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
