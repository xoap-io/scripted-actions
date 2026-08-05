<#
.SYNOPSIS
    Update an existing Azure Local (Azure Stack HCI) VM image: deploy a builder VM from it,
    apply Windows updates and/or a custom script, sysprep and register the result as a new
    image.

.DESCRIPTION
    This script modifies (refreshes) an existing generalized Azure Local VM image. It
    performs the following steps:

    1. Validates that the Az.StackHCIVM module and an Azure context are available.
    2. Resolves the source image and refuses to overwrite an existing target image name.
    3. Deploys a temporary builder VM from the source image (Secure Boot + vTPM enabled).
    4. Waits for WinRM to become reachable on the builder VM (via its IP address).
    5. Optionally installs all pending Windows updates in rounds (search - install -
       reboot - repeat) using the built-in Microsoft.Update.Session COM API, until no
       updates remain or -MaxUpdateRounds is reached.
    6. Optionally downloads and executes a custom PowerShell script inside the guest
       (e.g. application installs or configuration changes).
    7. Runs Sysprep to generalize the VM and waits for it to power off.
    8. Copies the generalized VHDX to the image share path and registers it as a new
       Azure Local VM image.
    9. Optionally removes the builder VM and its NIC, and optionally the source image.

    IMPORTANT: the capture phase (steps 7-8) requires this script to run ON a cluster node
    (Hyper-V module + access to the cluster storage), because the OS disk path is resolved
    via Get-VMHardDiskDrive. This matches the XOAP Scripted Actions / LocalBox scenario
    where the script executes on the Azure Local host. WinRM from this machine to the
    builder VM must be possible.

    The default values match the XOAP Jumpstart LocalBox environment (cluster
    'localboxcluster' in resource group 'AzureLocal').

    Uses Get/New-AzStackHCIVMImage, Get-AzStackHCIVMLogicalNetwork,
    Get/New/Remove-AzStackHCIVMNetworkInterface, New/Remove-AzStackHCIVMVirtualMachine,
    Remove-AzStackHCIVMImage plus Hyper-V Get-VM/Get-VMHardDiskDrive for the capture.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER CustomLocationId
    Custom Location resource ID that maps to your Azure Local cluster (Arc resource bridge).
    Defaults to the XOAP LocalBox custom location "jumpstart".

.PARAMETER Location
    Azure region of the Arc resources. Defaults to "westeurope".

.PARAMETER SourceImageName
    Name of the existing Azure Local VM image to update.

.PARAMETER NewImageName
    Name of the updated image to register. Defaults to "<SourceImageName>-<yyyyMMdd>".

.PARAMETER LocalAdminCreds
    PSCredential object containing the local administrator credentials baked into the
    source image (used for the WinRM session to the builder VM).

.PARAMETER RunWindowsUpdate
    Install all pending Windows updates in the builder VM before sysprep.

.PARAMETER CustomScriptUri
    Optional URI of a PowerShell script that is downloaded and executed inside the builder
    VM (e.g. a signed blob URL with application install steps).

.PARAMETER BuilderVmName
    Name of the temporary builder VM (max. 15 characters). Defaults to "imgb-<MMddHHmm>".

.PARAMETER VmVcpu
    Number of vCPUs for the builder VM. Defaults to 4.

.PARAMETER VmMemoryGB
    Memory in GB for the builder VM. Defaults to 8.

.PARAMETER LogicalNetworkName
    Name of the existing logical network for the builder VM. Defaults to
    "localboxcluster-InfraLNET".

.PARAMETER StoragePathName
    Name of the storage path object for the builder VM and the new image. Defaults to "sp-images".

.PARAMETER ImageSharePath
    Cluster-local directory where the generalized VHDX is stored and registered from.
    Defaults to "C:\ClusterStorage\UserStorage_2\Images".

.PARAMETER RemoveBuilderVm
    Delete the builder VM and its NIC after the new image has been registered.

.PARAMETER RemoveSourceImage
    Delete the source image after the new image has been registered successfully.

.PARAMETER WinRMTimeoutSec
    Timeout in seconds waiting for WinRM on the builder VM (per boot). Defaults to 1800.

.PARAMETER MaxUpdateRounds
    Maximum number of Windows Update install/reboot rounds. Defaults to 3.

.EXAMPLE
    $creds = Get-Credential
    .\az-ps-update-azure-local-image.ps1 `
        -SourceImageName "win11-23h2-avd-gold" `
        -LocalAdminCreds $creds `
        -RunWindowsUpdate `
        -RemoveBuilderVm

    Patches the golden image with the latest Windows updates and registers it as
    "win11-23h2-avd-gold-<yyyyMMdd>".

.EXAMPLE
    $creds = Get-Credential
    .\az-ps-update-azure-local-image.ps1 `
        -SourceImageName "win11-23h2-avd-gold" `
        -NewImageName "win11-23h2-avd-gold-v2" `
        -LocalAdminCreds $creds `
        -CustomScriptUri "https://storage.example.com/install-apps.ps1?sv=..." `
        -RemoveBuilderVm `
        -RemoveSourceImage

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Accounts, Az.StackHCIVM 1.1.0+ (Install-Module Az.StackHCIVM), Hyper-V module for the capture phase.

    Windows images can only be sysprepped a limited number of times (rearm count). Keep an
    unsysprepped master or use fresh marketplace bases regularly.

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

    # Image identities
    [Parameter(Mandatory = $true, HelpMessage = "Name of the existing Azure Local VM image to update.")]
    [ValidateNotNullOrEmpty()]
    [string]$SourceImageName,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the updated image to register. Defaults to '<SourceImageName>-<yyyyMMdd>'.")]
    [string]$NewImageName = "",

    # Guest access
    [Parameter(Mandatory = $true, HelpMessage = "PSCredential with the local administrator credentials baked into the source image.")]
    [ValidateNotNullOrEmpty()]
    [pscredential]$LocalAdminCreds,

    # Modification steps
    [Parameter(Mandatory = $false, HelpMessage = "Install all pending Windows updates in the builder VM before sysprep.")]
    [switch]$RunWindowsUpdate,

    [Parameter(Mandatory = $false, HelpMessage = "Optional URI of a PowerShell script executed inside the builder VM.")]
    [string]$CustomScriptUri = "",

    # Builder VM
    [Parameter(Mandatory = $false, HelpMessage = "Name of the temporary builder VM (max. 15 characters). Defaults to 'imgb-<MMddHHmm>'.")]
    [ValidateLength(0, 15)]
    [string]$BuilderVmName = "",

    [Parameter(Mandatory = $false, HelpMessage = "Number of vCPUs for the builder VM. Defaults to 4.")]
    [ValidateRange(1, 128)]
    [int]$VmVcpu = 4,

    [Parameter(Mandatory = $false, HelpMessage = "Memory in GB for the builder VM. Defaults to 8.")]
    [ValidateRange(1, 2048)]
    [int]$VmMemoryGB = 8,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the existing logical network for the builder VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$LogicalNetworkName = "localboxcluster-InfraLNET",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the storage path object for the builder VM and the new image.")]
    [ValidateNotNullOrEmpty()]
    [string]$StoragePathName = "sp-images",

    # Capture / registration
    [Parameter(Mandatory = $false, HelpMessage = "Cluster-local directory where the generalized VHDX is stored and registered from.")]
    [ValidateNotNullOrEmpty()]
    [string]$ImageSharePath = "C:\ClusterStorage\UserStorage_2\Images",

    # Cleanup
    [Parameter(Mandatory = $false, HelpMessage = "Delete the builder VM and its NIC after the new image has been registered.")]
    [switch]$RemoveBuilderVm,

    [Parameter(Mandatory = $false, HelpMessage = "Delete the source image after the new image has been registered successfully.")]
    [switch]$RemoveSourceImage,

    # Timeouts / limits
    [Parameter(Mandatory = $false, HelpMessage = "Timeout in seconds waiting for WinRM on the builder VM (per boot). Defaults to 1800.")]
    [ValidateRange(60, 14400)]
    [int]$WinRMTimeoutSec = 1800,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of Windows Update install/reboot rounds. Defaults to 3.")]
    [ValidateRange(1, 10)]
    [int]$MaxUpdateRounds = 3
)

$ErrorActionPreference = 'Stop'

try {
    # 0) Preflight: module + Azure context + Hyper-V (needed later for the capture phase)
    if (-not (Get-Module -ListAvailable -Name Az.StackHCIVM)) {
        throw "The Az.StackHCIVM module is not installed. Run: Install-Module Az.StackHCIVM -Scope CurrentUser"
    }
    if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
        throw "The Hyper-V module is required for the capture phase. Run this script on a cluster node."
    }
    $context = Get-AzContext
    if (-not $context) {
        throw "No Azure context found. Run Connect-AzAccount (or sign in with your service principal) first."
    }
    Write-Host "🔍 Using subscription '$($context.Subscription.Name)' ($($context.Subscription.Id))" -ForegroundColor Cyan

    if (-not $NewImageName)  { $NewImageName = "$SourceImageName-$(Get-Date -Format 'yyyyMMdd')" }
    if (-not $BuilderVmName) { $BuilderVmName = "imgb-$(Get-Date -Format 'MMddHHmm')" }

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

    # 1) Resolve source image, refuse existing target image
    $sourceImage = Get-AzStackHCIVMImage -ResourceGroupName $ResourceGroupName -Name $SourceImageName -ErrorAction SilentlyContinue
    if (-not $sourceImage) {
        throw "Source image '$SourceImageName' not found in resource group '$ResourceGroupName'."
    }
    $existingTarget = Get-AzStackHCIVMImage -ResourceGroupName $ResourceGroupName -Name $NewImageName -ErrorAction SilentlyContinue
    if ($existingTarget) {
        throw "Target image '$NewImageName' already exists. Choose a different -NewImageName."
    }
    Write-Host "🔍 Updating image '$SourceImageName' -> '$NewImageName'" -ForegroundColor Cyan

    # 2) Resolve the logical network and create the builder NIC
    $lnet = Get-AzStackHCIVMLogicalNetwork -ResourceGroupName $ResourceGroupName -Name $LogicalNetworkName -ErrorAction SilentlyContinue
    if (-not $lnet) {
        throw "Logical network '$LogicalNetworkName' not found in resource group '$ResourceGroupName'."
    }

    $nicName = "$($BuilderVmName)-nic0"
    $nic = Get-AzStackHCIVMNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName -ErrorAction SilentlyContinue
    if (-not $nic) {
        $nic = New-AzStackHCIVMNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName `
            -CustomLocationId $CustomLocationId -Location $Location -SubnetId $lnet.Id
        Write-Host "🔧 Created network interface '$nicName' on '$LogicalNetworkName'" -ForegroundColor Cyan
    }

    # 3) Deploy the builder VM from the source image
    Write-Host "🚀 Deploying builder VM '$BuilderVmName' from image '$SourceImageName'..." -ForegroundColor Green
    $vmParams = @{
        Name                   = $BuilderVmName
        ResourceGroupName      = $ResourceGroupName
        CustomLocationId       = $CustomLocationId
        Location               = $Location
        OsType                 = "Windows"
        ImageId                = $sourceImage.Id
        VmSize                 = "Custom"
        VmProcessor            = $VmVcpu
        VmMemoryInMB           = ($VmMemoryGB * 1024)
        AdminUsername          = $LocalAdminCreds.UserName
        AdminPassword          = $LocalAdminCreds.Password
        ComputerName           = $BuilderVmName
        NicId                  = @($nic.Id)
        StoragePathName        = $StoragePathName
        SecureBootEnabled      = $true
        EnableTpm              = $true
        ProvisionVMConfigAgent = $true
    }
    $null = New-AzStackHCIVMVirtualMachine @vmParams

    # 4) Wait for the guest and open a WinRM session (workgroup VM by IP needs TrustedHosts)
    $nic = Get-AzStackHCIVMNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName
    $vmIp = $nic.IPConfiguration.IPAddress | Select-Object -First 1
    if (-not $vmIp) { $vmIp = $BuilderVmName }
    Write-Host "🔧 Builder VM created (IP: $vmIp). Waiting for WinRM (sysprepped images run OOBE on first boot)..." -ForegroundColor Cyan
    Wait-VMGuestUp -Target $vmIp -TimeoutSec $WinRMTimeoutSec

    $trusted = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
    if ($trusted -notlike "*$vmIp*" -and $trusted -ne '*') {
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $vmIp -Concatenate -Force
    }

    # 5) Windows Update rounds via the built-in Microsoft.Update.Session COM API
    if ($RunWindowsUpdate) {
        $updateScriptBlock = {
            $updateSession  = New-Object -ComObject Microsoft.Update.Session
            $searcher       = $updateSession.CreateUpdateSearcher()
            $searchResult   = $searcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
            if ($searchResult.Updates.Count -eq 0) { return 0 }
            $downloader         = $updateSession.CreateUpdateDownloader()
            $downloader.Updates = $searchResult.Updates
            $null = $downloader.Download()
            $installer         = $updateSession.CreateUpdateInstaller()
            $installer.Updates = $searchResult.Updates
            $null = $installer.Install()
            return $searchResult.Updates.Count
        }

        for ($round = 1; $round -le $MaxUpdateRounds; $round++) {
            Write-Host "🔧 Windows Update round $round/$($MaxUpdateRounds): searching and installing..." -ForegroundColor Cyan
            $session = New-PSSession -ComputerName $vmIp -Credential $LocalAdminCreds
            $installedCount = Invoke-Command -Session $session -ScriptBlock $updateScriptBlock

            if ($installedCount -eq 0) {
                Write-Host "✅ No pending updates left" -ForegroundColor Green
                Remove-PSSession $session -ErrorAction SilentlyContinue
                break
            }

            Write-Host "🔧 Installed $installedCount update(s), rebooting the builder VM..." -ForegroundColor Cyan
            try {
                Invoke-Command -Session $session -ScriptBlock { Restart-Computer -Force }
            }
            catch {
                Write-Verbose "WinRM session ended during reboot (expected): $($_.Exception.Message)"
            }
            Remove-PSSession $session -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 60
            Wait-VMGuestUp -Target $vmIp -TimeoutSec $WinRMTimeoutSec
        }
    }

    # 6) Optional custom script inside the guest
    if ($CustomScriptUri) {
        Write-Host "🔧 Executing custom script from '$CustomScriptUri' in the builder VM..." -ForegroundColor Cyan
        $customBootstrap = @"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
`$tmp = Join-Path `$env:TEMP "custom-image-script.ps1"
Invoke-WebRequest -Uri '$CustomScriptUri' -OutFile `$tmp
Set-ExecutionPolicy Bypass -Scope Process -Force
& `$tmp
"@
        $session = New-PSSession -ComputerName $vmIp -Credential $LocalAdminCreds
        Invoke-Command -Session $session -ScriptBlock ([ScriptBlock]::Create($customBootstrap))
        Remove-PSSession $session -ErrorAction SilentlyContinue
    }

    # 7) Sysprep (generalize + shutdown). The connection drops when the guest shuts down.
    Write-Host "🔧 Running Sysprep in '$BuilderVmName'..." -ForegroundColor Cyan
    $sysprep = @"
Stop-Service -Name wuauserv -ErrorAction SilentlyContinue
Start-Process 'C:\Windows\System32\Sysprep\Sysprep.exe' -ArgumentList '/oobe /generalize /shutdown /mode:vm' -Wait
"@
    $session = New-PSSession -ComputerName $vmIp -Credential $LocalAdminCreds
    try {
        Invoke-Command -Session $session -ScriptBlock ([ScriptBlock]::Create($sysprep))
    }
    catch {
        Write-Verbose "WinRM session ended during sysprep shutdown (expected): $($_.Exception.Message)"
    }
    Remove-PSSession $session -ErrorAction SilentlyContinue

    Write-Host "🔧 Waiting for '$BuilderVmName' to power off..." -ForegroundColor Cyan
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ((Get-VM -Name $BuilderVmName).State -ne 'Off') {
        if ($sw.Elapsed.TotalMinutes -gt 30) { throw "VM '$BuilderVmName' did not shut down within 30 minutes after sysprep." }
        Start-Sleep -Seconds 15
    }

    # 8) Capture: copy the generalized VHDX and register it as the new image
    $sourceVhdx = (Get-VM -Name $BuilderVmName | Get-VMHardDiskDrive | Select-Object -First 1).Path
    if (-not $sourceVhdx) { throw "Could not locate the OS disk VHDX of VM '$BuilderVmName' via Get-VMHardDiskDrive." }

    if (-not (Test-Path $ImageSharePath)) { New-Item -Path $ImageSharePath -ItemType Directory -Force | Out-Null }
    $destVhdx = Join-Path $ImageSharePath "$($NewImageName).vhdx"
    Write-Host "🔧 Copying '$sourceVhdx' -> '$destVhdx'..." -ForegroundColor Cyan
    Copy-Item -Path $sourceVhdx -Destination $destVhdx -Force

    Write-Host "🔧 Registering image '$NewImageName'..." -ForegroundColor Cyan
    $newImage = New-AzStackHCIVMImage -Name $NewImageName -ResourceGroupName $ResourceGroupName `
        -CustomLocationId $CustomLocationId -Location $Location -OSType "Windows" `
        -ImagePath $destVhdx -StoragePathName $StoragePathName

    # 9) Optional cleanup
    if ($RemoveBuilderVm) {
        Write-Host "🔧 Removing builder VM '$BuilderVmName' and NIC '$nicName'..." -ForegroundColor Cyan
        Remove-AzStackHCIVMVirtualMachine -Name $BuilderVmName -ResourceGroupName $ResourceGroupName -Confirm:$false
        Remove-AzStackHCIVMNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName -Confirm:$false
    }

    if ($RemoveSourceImage) {
        if ("$($newImage.ProvisioningState)" -eq 'Succeeded') {
            Write-Host "🔧 Removing source image '$SourceImageName'..." -ForegroundColor Cyan
            Remove-AzStackHCIVMImage -Name $SourceImageName -ResourceGroupName $ResourceGroupName -Confirm:$false
        }
        else {
            Write-Host "⚠️  New image state is '$($newImage.ProvisioningState)' - keeping the source image '$SourceImageName'" -ForegroundColor Yellow
        }
    }

    Write-Host "✅ Image '$NewImageName' registered (updated from '$SourceImageName')" -ForegroundColor Green
    Write-Host "💡 Next Steps: deploy a VM with az-ps-deploy-azure-local-vm-from-image.ps1 -VmImageName '$NewImageName'" -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
