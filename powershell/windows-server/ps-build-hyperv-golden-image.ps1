<#
.SYNOPSIS
    Build a generalized (sysprepped) golden image VHDX on a Hyper-V host, fully
    unattended, directly from a Windows installation ISO - and optionally register
    it as an Azure Local VM image.

.DESCRIPTION
    This script creates a golden image from scratch on any Hyper-V host (including
    Azure Local / Azure Stack HCI cluster nodes) without any manual interaction and
    without repacking the ISO:

    1. Mounts the ISO and resolves the Windows edition from sources\install.wim
       (or install.esd) by name or index.
    2. Creates a new Generation 2 (UEFI/GPT) VHDX at the target path, partitions it
       (EFI + MSR + Windows) and applies the Windows image with Expand-WindowsImage
       (DISM) - this bypasses the interactive installer entirely.
    3. Makes the disk bootable with bcdboot and injects an unattend.xml that skips
       OOBE, auto-logs on as the built-in Administrator and runs first-logon
       commands: an optional customization script, then
       "sysprep /generalize /oobe /shutdown".
    4. Creates a temporary Gen 2 VM from the VHDX, starts it and waits for the
       specialize/customize/sysprep sequence to power the VM off.
    5. Removes the temporary VM (keeping the VHDX) and compacts the disk.
    6. Optionally registers the VHDX as an Azure Local VM image via the Arc
       resource bridge (New-AzStackHCIVMImage) when -ImageName is supplied.

    Designed for the XOAP Scripted Actions module running ON an Azure Local
    cluster node: all parameters are plain strings/switches (no interactive
    prompts, no PSCredential/SecureString input) and the Azure context is expected
    to be pre-established by the scripted action's service principal
    (Connect-AzAccount -ServicePrincipal) - the script never authenticates itself.
    Without -ImageName the script is build-only and needs no Azure connection at
    all; register later with azure-ps/azure-local/az-ps-create-azure-local-image.ps1.

    The default values match the XOAP Jumpstart LocalBox environment (resource
    group 'AzureLocal', custom location 'jumpstart', CSV image path
    C:\ClusterStorage\UserStorage_2\Images).

    The optional customization script runs elevated inside the VM before sysprep.
    It must not reboot the machine (auto-logon only fires once) and must not rely
    on network access unless -SwitchName is supplied.

    Must run elevated on the Hyper-V host itself. Uses the built-in Hyper-V, Storage
    and Dism PowerShell modules; Az.Accounts and Az.StackHCIVM only when -ImageName
    is used.

.PARAMETER IsoPath
    Path to the Windows installation ISO on the Hyper-V host.

.PARAMETER VhdxPath
    Output path of the golden image VHDX. Must end in .vhdx and must not exist yet.
    Defaults to "<StoragePath>\<ImageName>.vhdx" when -ImageName is supplied;
    otherwise it is mandatory. On Azure Local, use a CSV user storage path.

.PARAMETER EditionName
    Windows edition to apply, matched against the image names in install.wim, e.g.
    "Windows Server 2025 Datacenter (Desktop Experience)" or "Windows 11 Enterprise".
    Provide either -EditionName or -ImageIndex; if both are omitted the script lists
    the available editions and exits.

.PARAMETER ImageIndex
    Index of the Windows edition inside install.wim/install.esd. Alternative to
    -EditionName.

.PARAMETER AdminPassword
    Password for the built-in Administrator account during the build, as a plain
    string so it can be supplied as a XOAP Scripted Actions parameter. It is only
    used inside the temporary build VM; sysprep /generalize removes the account
    state again at the end of the build.

.PARAMETER VhdSizeGB
    Size of the created (dynamically expanding) VHDX in GB. Defaults to 60.

.PARAMETER VmName
    Name of the temporary build VM. Defaults to "golden-image-build". The VM is
    removed after a successful build; the VHDX is kept.

.PARAMETER MemoryGB
    Startup memory of the build VM in GB. Defaults to 4.

.PARAMETER CpuCount
    Virtual processor count of the build VM. Defaults to 4.

.PARAMETER SwitchName
    Optional Hyper-V virtual switch to connect the build VM to. Omit for a fully
    offline build; supply it if the customization script needs network/internet.

.PARAMETER CustomizeScriptPath
    Optional path to a PowerShell script that is copied into the image
    (C:\Windows\Setup\Scripts\customize.ps1) and executed elevated at first logon,
    before sysprep. Use it to install agents, apps or updates.

.PARAMETER ProductKey
    Optional product key (e.g. a KMS client setup key) written into the unattend
    specialize pass. Usually not required for evaluation or KMS/AD-activated builds.

.PARAMETER TimeZone
    Windows time zone id applied in the specialize pass.
    Defaults to "W. Europe Standard Time".

.PARAMETER Locale
    Language/locale (input, system, UI and user locale) applied via unattend.
    Defaults to "en-US".

.PARAMETER EnableVmTpm
    Add a virtual TPM (with a local key protector) to the build VM. Not required for
    the offline image apply, but useful if the customization step needs a TPM.

.PARAMETER TimeoutMinutes
    Maximum time to wait for the in-VM customize + sysprep sequence to shut the VM
    down. Defaults to 120.

.PARAMETER ImageName
    Optional name of the Azure Local VM image to register after the build. When
    supplied, the script registers the VHDX via New-AzStackHCIVMImage using the
    Azure context pre-established by the XOAP Scripted Actions service principal.
    Omit for a build-only run without any Azure connection.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope (only
    used with -ImageName). Defaults to "AzureLocal".

.PARAMETER CustomLocationId
    Custom Location resource ID that maps to your Azure Local cluster / Arc
    resource bridge (only used with -ImageName). Defaults to the XOAP LocalBox
    custom location "jumpstart".

.PARAMETER Location
    Azure region of the Arc resources (only used with -ImageName).
    Defaults to "westeurope".

.PARAMETER StoragePathName
    Name of the Azure Local storage path object that stores the image (only used
    with -ImageName). Defaults to "sp-images". Created if missing.

.PARAMETER StoragePath
    Cluster-local CSV directory backing the storage path object and default
    location of the built VHDX. Defaults to "C:\ClusterStorage\UserStorage_2\Images".

.EXAMPLE
    .\ps-build-hyperv-golden-image.ps1 `
        -IsoPath "C:\ClusterStorage\UserStorage_2\ISOs\WindowsServer2025.iso" `
        -EditionName "Windows Server 2025 Datacenter (Desktop Experience)" `
        -AdminPassword "P@ssw0rd-only-for-build" `
        -ImageName "ws2025-golden"

    XOAP Scripted Actions scenario: builds the VHDX to
    C:\ClusterStorage\UserStorage_2\Images\ws2025-golden.vhdx and registers it as
    the Azure Local VM image "ws2025-golden" via the pre-established service
    principal context.

.EXAMPLE
    .\ps-build-hyperv-golden-image.ps1 `
        -IsoPath "D:\ISO\Win11-24H2.iso" `
        -VhdxPath "D:\Images\win11-golden.vhdx" `
        -ImageIndex 6 `
        -AdminPassword "P@ssw0rd-only-for-build" `
        -SwitchName "Default Switch" `
        -CustomizeScriptPath ".\install-apps.ps1"

    Build-only run (no Azure connection): builds a Windows 11 image, connects the
    build VM to a switch and runs a customization script inside the VM before
    sysprep.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Hyper-V role with PowerShell module, Dism and Storage modules (in-box), elevated session on the Hyper-V host; Az.Accounts + Az.StackHCIVM with a connected service principal context when -ImageName is used

.LINK
    https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/sysprep--generalize--a-windows-installation

.LINK
    https://learn.microsoft.com/en-us/azure/azure-local/manage/virtual-machine-image-local-share

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.stackhcivm/

.COMPONENT
    Hyper-V
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to the Windows installation ISO on the Hyper-V host.")]
    [ValidateNotNullOrEmpty()]
    [string]$IsoPath,

    [Parameter(Mandatory = $false, HelpMessage = "Output path of the golden image VHDX (must end in .vhdx and not exist yet). Defaults to '<StoragePath>\<ImageName>.vhdx' when -ImageName is supplied.")]
    [ValidatePattern('\.vhdx$')]
    [string]$VhdxPath,

    [Parameter(Mandatory = $false, HelpMessage = "Windows edition name inside install.wim, e.g. 'Windows Server 2025 Datacenter (Desktop Experience)'.")]
    [ValidateNotNullOrEmpty()]
    [string]$EditionName,

    [Parameter(Mandatory = $false, HelpMessage = "Index of the Windows edition inside install.wim/install.esd (alternative to -EditionName).")]
    [ValidateRange(1, 99)]
    [int]$ImageIndex,

    [Parameter(Mandatory = $true, HelpMessage = "Password for the built-in Administrator account used during the build (plain string for XOAP Scripted Actions; removed again by sysprep).")]
    [ValidateNotNullOrEmpty()]
    [string]$AdminPassword,

    [Parameter(Mandatory = $false, HelpMessage = "Size of the created dynamically expanding VHDX in GB.")]
    [ValidateRange(20, 2048)]
    [int]$VhdSizeGB = 60,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the temporary build VM (removed after a successful build).")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName = "golden-image-build",

    [Parameter(Mandatory = $false, HelpMessage = "Startup memory of the build VM in GB.")]
    [ValidateRange(2, 128)]
    [int]$MemoryGB = 4,

    [Parameter(Mandatory = $false, HelpMessage = "Virtual processor count of the build VM.")]
    [ValidateRange(1, 64)]
    [int]$CpuCount = 4,

    [Parameter(Mandatory = $false, HelpMessage = "Optional Hyper-V virtual switch to connect the build VM to (omit for an offline build).")]
    [ValidateNotNullOrEmpty()]
    [string]$SwitchName,

    [Parameter(Mandatory = $false, HelpMessage = "Optional PowerShell script executed inside the VM at first logon, before sysprep.")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomizeScriptPath,

    [Parameter(Mandatory = $false, HelpMessage = "Optional product key (e.g. KMS client setup key) for the unattend specialize pass.")]
    [ValidatePattern('^[A-Za-z0-9]{5}-[A-Za-z0-9]{5}-[A-Za-z0-9]{5}-[A-Za-z0-9]{5}-[A-Za-z0-9]{5}$')]
    [string]$ProductKey,

    [Parameter(Mandatory = $false, HelpMessage = "Windows time zone id applied in the specialize pass.")]
    [ValidateNotNullOrEmpty()]
    [string]$TimeZone = "W. Europe Standard Time",

    [Parameter(Mandatory = $false, HelpMessage = "Language/locale applied via unattend (input, system, UI and user locale).")]
    [ValidatePattern('^[a-z]{2}-[A-Z]{2}$')]
    [string]$Locale = "en-US",

    [Parameter(Mandatory = $false, HelpMessage = "Add a virtual TPM with a local key protector to the build VM.")]
    [switch]$EnableVmTpm,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum minutes to wait for the in-VM customize + sysprep sequence to finish.")]
    [ValidateRange(10, 1440)]
    [int]$TimeoutMinutes = 120,

    # Azure Local image registration (optional - requires a pre-established SPN Azure context)
    [Parameter(Mandatory = $false, HelpMessage = "Optional name of the Azure Local VM image to register after the build (omit for a build-only run).")]
    [ValidateNotNullOrEmpty()]
    [string]$ImageName,

    [Parameter(Mandatory = $false, HelpMessage = "Azure resource group that represents your Azure Local instance scope (used with -ImageName).")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroupName = "AzureLocal",

    [Parameter(Mandatory = $false, HelpMessage = "Custom Location resource ID that maps to your Azure Local cluster / Arc resource bridge (used with -ImageName).")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomLocationId = "/subscriptions/e5373ae1-c1cf-418e-8044-a2851af745b6/resourceGroups/AzureLocal/providers/Microsoft.ExtendedLocation/customLocations/jumpstart",

    [Parameter(Mandatory = $false, HelpMessage = "Azure region of the Arc resources (used with -ImageName).")]
    [ValidateNotNullOrEmpty()]
    [string]$Location = "westeurope",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the Azure Local storage path object that stores the image (used with -ImageName; created if missing).")]
    [ValidateNotNullOrEmpty()]
    [string]$StoragePathName = "sp-images",

    [Parameter(Mandatory = $false, HelpMessage = "Cluster-local CSV directory backing the storage path object and default location of the built VHDX.")]
    [ValidateNotNullOrEmpty()]
    [string]$StoragePath = "C:\ClusterStorage\UserStorage_2\Images"
)

$ErrorActionPreference = 'Stop'

$isoMounted = $false
$vhdMounted = $false
$vmCreated  = $false

try {
    # 0) Preflight checks
    Write-Host "🚀 Starting unattended golden image build" -ForegroundColor Green

    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must run in an elevated (Administrator) session on the Hyper-V host."
    }
    foreach ($module in @('Hyper-V', 'Dism', 'Storage')) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            throw "Required module '$module' is not available. Run this script directly on a Hyper-V host."
        }
    }

    # Registration preflight (fail fast before the long build)
    if ($ImageName) {
        foreach ($module in @('Az.Accounts', 'Az.StackHCIVM')) {
            if (-not (Get-Module -ListAvailable -Name $module)) {
                throw "The $module module is required to register image '$ImageName'. Run: Install-Module $module -Scope CurrentUser"
            }
        }
        $azContext = Get-AzContext
        if (-not $azContext) {
            throw "No Azure context found. The XOAP Scripted Actions service principal must be connected (Connect-AzAccount -ServicePrincipal) before this script runs."
        }
        Write-Host "🔍 Using subscription '$($azContext.Subscription.Name)' ($($azContext.Subscription.Id))" -ForegroundColor Cyan

        $existingImage = Get-AzStackHCIVMImage -ResourceGroupName $ResourceGroupName -Name $ImageName -ErrorAction SilentlyContinue
        if ($existingImage) {
            Write-Host "ℹ️  Azure Local image '$ImageName' already exists (OS: $($existingImage.OSType), state: $($existingImage.ProvisioningState)) - nothing to do" -ForegroundColor Yellow
            return
        }
    }

    if (-not $VhdxPath) {
        if (-not $ImageName) {
            throw "Provide -VhdxPath, or -ImageName so the VHDX path defaults to '<StoragePath>\<ImageName>.vhdx'."
        }
        $VhdxPath = Join-Path -Path $StoragePath -ChildPath "$($ImageName).vhdx"
        Write-Host "ℹ️  Using default VHDX path '$VhdxPath'" -ForegroundColor Yellow
    }

    if (-not (Test-Path -Path $IsoPath -PathType Leaf)) {
        throw "ISO file not found: $IsoPath"
    }
    if (Test-Path -Path $VhdxPath) {
        throw "Target VHDX already exists: $VhdxPath - refusing to overwrite an existing image."
    }
    if ($CustomizeScriptPath -and -not (Test-Path -Path $CustomizeScriptPath -PathType Leaf)) {
        throw "Customization script not found: $CustomizeScriptPath"
    }
    if ($SwitchName -and -not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
        throw "Hyper-V switch '$SwitchName' does not exist on this host."
    }
    if (Get-VM -Name $VmName -ErrorAction SilentlyContinue) {
        throw "A VM named '$VmName' already exists on this host. Remove it or pass a different -VmName."
    }
    $vhdxParent = Split-Path -Path $VhdxPath -Parent
    if ($vhdxParent -and -not (Test-Path -Path $vhdxParent)) {
        Write-Host "🔧 Creating output directory '$vhdxParent'..." -ForegroundColor Cyan
        $null = New-Item -Path $vhdxParent -ItemType Directory -Force
    }

    # 1) Mount the ISO and resolve the Windows edition
    Write-Host "🔍 Mounting ISO '$IsoPath'..." -ForegroundColor Cyan
    $isoImage   = Mount-DiskImage -ImagePath $IsoPath -PassThru
    $isoMounted = $true
    $isoLetter  = ($isoImage | Get-Volume).DriveLetter
    if (-not $isoLetter) {
        throw "Could not determine the drive letter of the mounted ISO."
    }

    $wimPath = "$($isoLetter):\sources\install.wim"
    if (-not (Test-Path -Path $wimPath)) {
        $wimPath = "$($isoLetter):\sources\install.esd"
    }
    if (-not (Test-Path -Path $wimPath)) {
        throw "Neither install.wim nor install.esd found under $($isoLetter):\sources - is this a Windows installation ISO?"
    }

    $editions = Get-WindowsImage -ImagePath $wimPath
    if ($EditionName) {
        $edition = $editions | Where-Object { $_.ImageName -eq $EditionName }
        if (-not $edition) {
            $available = ($editions | ForEach-Object { "  [$($_.ImageIndex)] $($_.ImageName)" }) -join "`n"
            throw "Edition '$EditionName' not found in the ISO. Available editions:`n$available"
        }
        $ImageIndex = [int]$edition.ImageIndex
    }
    elseif (-not $ImageIndex) {
        Write-Host "ℹ️  No -EditionName or -ImageIndex supplied. Available editions:" -ForegroundColor Yellow
        foreach ($e in $editions) {
            Write-Host "  [$($e.ImageIndex)] $($e.ImageName)" -ForegroundColor Yellow
        }
        throw "Re-run the script with -EditionName or -ImageIndex."
    }
    $selected = $editions | Where-Object { [int]$_.ImageIndex -eq $ImageIndex }
    if (-not $selected) {
        throw "Image index $ImageIndex does not exist in $wimPath."
    }
    Write-Host "✅ Selected edition [$ImageIndex] '$($selected.ImageName)'" -ForegroundColor Green

    # 2) Create and partition the VHDX (UEFI/GPT: EFI + MSR + Windows)
    Write-Host "🔧 Creating $($VhdSizeGB) GB dynamic VHDX at '$VhdxPath'..." -ForegroundColor Cyan
    $null       = New-VHD -Path $VhdxPath -SizeBytes ($VhdSizeGB * 1GB) -Dynamic
    $vhd        = Mount-VHD -Path $VhdxPath -Passthru
    $vhdMounted = $true
    $diskNumber = $vhd.DiskNumber

    Initialize-Disk -Number $diskNumber -PartitionStyle GPT

    $efiPartition = New-Partition -DiskNumber $diskNumber -Size 260MB -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
    $null = $efiPartition | Format-Volume -FileSystem FAT32 -NewFileSystemLabel "System" -Confirm:$false
    $efiPartition | Add-PartitionAccessPath -AssignDriveLetter
    $efiLetter = ($efiPartition | Get-Partition).DriveLetter

    $null = New-Partition -DiskNumber $diskNumber -Size 16MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'

    $osPartition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -AssignDriveLetter
    $null = $osPartition | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false
    $osLetter = ($osPartition | Get-Partition).DriveLetter

    if (-not $efiLetter -or -not $osLetter) {
        throw "Failed to assign drive letters to the EFI/Windows partitions of the mounted VHDX."
    }

    # 3) Apply the Windows image and make the disk bootable
    Write-Host "🔧 Applying '$($selected.ImageName)' to $($osLetter):\ (this takes several minutes)..." -ForegroundColor Cyan
    $null = Expand-WindowsImage -ImagePath $wimPath -Index $ImageIndex -ApplyPath "$($osLetter):\"

    Write-Host "🔧 Writing UEFI boot files with bcdboot..." -ForegroundColor Cyan
    $bcdbootOutput = & "$($osLetter):\Windows\System32\bcdboot.exe" "$($osLetter):\Windows" /s "$($efiLetter):" /f UEFI 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "bcdboot failed (exit code $($LASTEXITCODE)): $bcdbootOutput"
    }

    # 4) Inject unattend.xml (skip OOBE, auto-logon, customize, sysprep /generalize)
    Write-Host "🔧 Injecting unattend.xml (auto-logon + sysprep /generalize /oobe /shutdown)..." -ForegroundColor Cyan
    $escapedPassword = [System.Security.SecurityElement]::Escape($AdminPassword)

    $firstLogonCommands = @()
    if ($CustomizeScriptPath) {
        $scriptsDir = "$($osLetter):\Windows\Setup\Scripts"
        $null = New-Item -Path $scriptsDir -ItemType Directory -Force
        Copy-Item -Path $CustomizeScriptPath -Destination (Join-Path $scriptsDir "customize.ps1") -Force
        $firstLogonCommands += 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\customize.ps1'
    }
    $firstLogonCommands += 'cmd.exe /c del /f /q C:\Windows\Panther\unattend.xml'
    $firstLogonCommands += 'C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /quiet'

    $commandsXml = ""
    for ($i = 0; $i -lt $firstLogonCommands.Count; $i++) {
        $commandsXml += @"

                <SynchronousCommand wcm:action="add">
                    <Order>$($i + 1)</Order>
                    <CommandLine>$([System.Security.SecurityElement]::Escape($firstLogonCommands[$i]))</CommandLine>
                    <Description>Golden image build step $($i + 1)</Description>
                </SynchronousCommand>
"@
    }

    $productKeyXml = ""
    if ($ProductKey) {
        $productKeyXml = "            <ProductKey>$($ProductKey.ToUpper())</ProductKey>`n"
    }

    $unattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <ComputerName>*</ComputerName>
            <TimeZone>$TimeZone</TimeZone>
$productKeyXml        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <InputLocale>$Locale</InputLocale>
            <SystemLocale>$Locale</SystemLocale>
            <UILanguage>$Locale</UILanguage>
            <UserLocale>$Locale</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$escapedPassword</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <AutoLogon>
                <Enabled>true</Enabled>
                <LogonCount>1</LogonCount>
                <Username>Administrator</Username>
                <Password>
                    <Value>$escapedPassword</Value>
                    <PlainText>true</PlainText>
                </Password>
            </AutoLogon>
            <FirstLogonCommands>$commandsXml
            </FirstLogonCommands>
        </component>
    </settings>
</unattend>
"@

    $pantherDir = "$($osLetter):\Windows\Panther"
    $null = New-Item -Path $pantherDir -ItemType Directory -Force
    Set-Content -Path (Join-Path $pantherDir "unattend.xml") -Value $unattendXml -Encoding UTF8

    # 5) Dismount ISO + VHDX
    Write-Host "🔧 Dismounting VHDX and ISO..." -ForegroundColor Cyan
    Dismount-VHD -Path $VhdxPath
    $vhdMounted = $false
    $null = Dismount-DiskImage -ImagePath $IsoPath
    $isoMounted = $false

    # 6) Create the temporary Gen 2 build VM and boot it
    Write-Host "🔧 Creating temporary build VM '$VmName'..." -ForegroundColor Cyan
    $vmParams = @{
        Name               = $VmName
        Generation         = 2
        MemoryStartupBytes = $MemoryGB * 1GB
        VHDPath            = $VhdxPath
    }
    if ($SwitchName) { $vmParams['SwitchName'] = $SwitchName }
    $null = New-VM @vmParams
    $vmCreated = $true

    Set-VMProcessor -VMName $VmName -Count $CpuCount
    Set-VM -Name $VmName -CheckpointType Disabled -AutomaticStopAction ShutDown
    Set-VMFirmware -VMName $VmName -EnableSecureBoot On -SecureBootTemplate MicrosoftWindows
    if ($EnableVmTpm) {
        Set-VMKeyProtector -VMName $VmName -NewLocalKeyProtector
        Enable-VMTPM -VMName $VmName
    }

    Write-Host "🚀 Starting build VM - specialize, first logon and sysprep run unattended now" -ForegroundColor Green
    Write-Host "⚠️  The VM powers itself off when sysprep completes (timeout: $TimeoutMinutes minutes)" -ForegroundColor Yellow
    Start-VM -Name $VmName

    # 7) Wait for sysprep to shut the VM down
    $started  = Get-Date
    $deadline = $started.AddMinutes($TimeoutMinutes)
    while ((Get-VM -Name $VmName).State -ne 'Off') {
        if ((Get-Date) -gt $deadline) {
            throw "Timed out after $TimeoutMinutes minutes waiting for the build VM to shut down. Connect to VM '$VmName' to inspect the build (VHDX: $VhdxPath)."
        }
        Start-Sleep -Seconds 30
        $elapsed = [int]((Get-Date) - $started).TotalMinutes
        if ($elapsed -gt 0 -and ($elapsed % 5) -eq 0) {
            Write-Host "ℹ️  Still building... ($($elapsed) minutes elapsed)" -ForegroundColor Yellow
        }
    }
    Write-Host "✅ Build VM shut down - image is generalized" -ForegroundColor Green

    # 8) Remove the build VM (keep the VHDX) and compact the disk
    Write-Host "🔧 Removing temporary VM '$VmName' (keeping the VHDX)..." -ForegroundColor Cyan
    Remove-VM -Name $VmName -Force
    $vmCreated = $false

    Write-Host "🔧 Compacting VHDX..." -ForegroundColor Cyan
    Optimize-VHD -Path $VhdxPath -Mode Full

    # 9) Optionally register the image on Azure Local (pre-established SPN context)
    $registeredState = ""
    if ($ImageName) {
        $sp = Get-AzStackHCIVMStoragePath -ResourceGroupName $ResourceGroupName -Name $StoragePathName -ErrorAction SilentlyContinue
        if (-not $sp) {
            Write-Host "🔧 Creating storage path '$StoragePathName' -> '$StoragePath'..." -ForegroundColor Cyan
            $sp = New-AzStackHCIVMStoragePath -Name $StoragePathName -ResourceGroupName $ResourceGroupName `
                -CustomLocationId $CustomLocationId -Location $Location -Path $StoragePath
        }

        Write-Host "🚀 Registering Azure Local VM image '$ImageName' from '$VhdxPath'..." -ForegroundColor Green
        $image = New-AzStackHCIVMImage -Name $ImageName -ResourceGroupName $ResourceGroupName `
            -CustomLocationId $CustomLocationId -Location $Location -OSType Windows `
            -StoragePathName $StoragePathName -ImagePath $VhdxPath
        $registeredState = $image.ProvisioningState
        Write-Host "✅ Image '$ImageName' registered (provisioning state: $($registeredState))" -ForegroundColor Green
    }

    $vhdxFile = Get-Item -Path $VhdxPath
    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "   Edition:   $($selected.ImageName)" -ForegroundColor Blue
    Write-Host "   VHDX:      $VhdxPath" -ForegroundColor Blue
    Write-Host "   File size: $([math]::Round($vhdxFile.Length / 1GB, 2)) GB" -ForegroundColor Blue
    if ($ImageName) {
        Write-Host "   Image:     $ImageName ($registeredState)" -ForegroundColor Blue
        Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
        Write-Host "   Deploy a VM with az-ps-deploy-azure-local-vm-from-image.ps1 -VmImageName '$ImageName'" -ForegroundColor Yellow
    }
    else {
        Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
        Write-Host "   Register the image on Azure Local:" -ForegroundColor Yellow
        Write-Host "   .\az-ps-create-azure-local-image.ps1 -ImageName '<name>' -VhdxPath '$VhdxPath'" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n❌ Golden image build failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($vhdMounted) {
        Dismount-VHD -Path $VhdxPath -ErrorAction SilentlyContinue
    }
    if ($isoMounted) {
        $null = Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue
    }
    if ($vmCreated) {
        Write-Host "⚠️  Build VM '$VmName' was left on the host for troubleshooting - remove it with: Remove-VM -Name '$VmName' -Force" -ForegroundColor Yellow
    }
    if ($VhdxPath -and (Test-Path -Path $VhdxPath)) {
        Write-Host "⚠️  Incomplete VHDX left at '$VhdxPath' - delete it before re-running" -ForegroundColor Yellow
    }
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
