param(
  # Azure Local resource scoping
  [Parameter(Mandatory)] [string] $ResourceGroupName,      # Azure resource group that represents your Azure Local instance scope
  [Parameter(Mandatory)] [string] $CustomLocationId,       # Custom Location resourceId that maps to your HCI cluster (Arc RB)
  [Parameter(Mandatory)] [string] $Location,               # Azure region of the Arc resource (e.g. "westeurope")
  [Parameter(Mandatory)] [string] $ClusterName,            # Friendly cluster name shown in Azure

  # Networking & storage (re-use existing if you have them)
  [string] $LogicalNetworkName = "lnet-avd",
  [string] $SubnetName = "default",
  [string] $StoragePathName = "sp-images",
  [string] $StoragePath = "C:\\ClusterStorage\\Volume1\\VMs\\Images",

  # VM details
  [Parameter(Mandatory)] [string] $VmName,
  [string] $VmSize = "Standard_A2_v2",                     # match supported size in your HCI hardware
  [int]    $VmVcpu = 2,
  [int]    $VmMemoryGB = 8,
  [int]    $OsDiskGB = 64,

  # Base OS source (choose one: marketplace image your HCI has, or a prepared VHDX path)
  [string] $OsVhdxLocalPath = "C:\\ISOs\\Win11-23H2-Gen2.vhdx",   # if you import a VHDX
  [switch] $UseExistingVHDX,

  # Admin creds for first boot (WinRM bootstrap)
  [Parameter(Mandatory)] [pscredential] $LocalAdminCreds,

  # XOAP bootstrap
  [Parameter(Mandatory)] [string] $XoapBootstrapUri,       # e.g. a signed URL to your XOAP agent/bootstrap ps1
  [Parameter(Mandatory)] [string] $XoapWorkspaceId,        # your XOAP workspace/tenant marker
  [string] $XoapScriptedActionId = "",                     # optional scripted action to trigger post-agent install

  # Image registration
  [Parameter(Mandatory)] [string] $ImageSharePath,         # e.g. \\fileserver\images\golden
  [Parameter(Mandatory)] [string] $VmImageName             # name for the Azure Local VM Image object
)

# 0) Helpers
function Wait-VM-GuestUp {
  param([string]$VmName,[int]$TimeoutSec=900)
  $sw=[Diagnostics.Stopwatch]::StartNew()
  do {
    Start-Sleep 10
    try {
      Test-NetConnection -ComputerName $VmName -Port 5985 -InformationLevel Quiet | Out-Null
      if ($?) { return $true }
    } catch {}
  } while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec)
  throw "VM $VmName did not open WinRM (5985) within $TimeoutSec seconds."
}

# 1) Ensure infra objects exist
# Logical network (only if you don't have one; otherwise skip)
try {
  $ln = Get-AzStackHCIVMLogicalNetwork -ResourceGroupName $ResourceGroupName -Name $LogicalNetworkName -ErrorAction Stop
} catch {
  $ln = New-AzStackHCIVMLogicalNetwork `
        -ResourceGroupName $ResourceGroupName `
        -CustomLocation $CustomLocationId `
        -Location $Location `
        -Name $LogicalNetworkName `
        -Subnet @(@{ name=$SubnetName; addressPrefix="10.10.0.0/24"; defaultGateway="10.10.0.1"; dnsServers=@("10.10.0.10") })
}

# Storage container/path for VMs
try {
  $sp = Get-AzStackHCIVMStoragePath -ResourceGroupName $ResourceGroupName -Name $StoragePathName -ErrorAction Stop
} catch {
  $sp = New-AzStackHCIVMStoragePath `
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
} else {
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
$vm = New-AzStackHCIVMVirtualMachine `
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

Write-Host "VM created. Waiting for WinRM..."
Wait-VM-GuestUp -VmName $VmName

# 5) XOAP bootstrap (agent install + enroll)
$xoapBootstrap = @"
# === XOAP bootstrap ===
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
\$tmp = Join-Path \$env:TEMP "xoap-bootstrap.ps1"
Invoke-WebRequest -Uri '$XoapBootstrapUri' -OutFile \$tmp
# Example: The bootstrap script should install the XOAP agent and enroll to workspace $XoapWorkspaceId
# & \$tmp -WorkspaceId '$XoapWorkspaceId' -AdditionalParams '...'
"@

$session = New-PSSession -ComputerName $VmName -Credential $LocalAdminCreds
Invoke-Command -Session $session -ScriptBlock { Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableLUA' -Value 0 } | Out-Null
Invoke-Command -Session $session -ScriptBlock { Set-ExecutionPolicy Bypass -Scope Process -Force }
Invoke-Command -Session $session -ScriptBlock ([ScriptBlock]::Create($xoapBootstrap))

# Optionally trigger a XOAP scripted action (placeholder).
if ($XoapScriptedActionId) {
  Write-Host ">> Trigger your XOAP job here via API/CLI using the VM's identity …"
  # Example pseudo:
  # Invoke-RestMethod -Method POST -Uri "https://api.xoap.io/actions/$XoapScriptedActionId/run" -Headers @{Authorization="Bearer $token"} -Body @{ target="$VmName" }
  # Wait/loop for completion…
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
$destVhdx   = Join-Path $ImageSharePath "$($VmImageName).vhdx"

Copy-Item -Path $sourceVhdx -Destination $destVhdx -Force

# Create an Azure Local VM Image from that VHDX
New-AzStackHCIVMImage `
  -ResourceGroupName $ResourceGroupName `
  -CustomLocation $CustomLocationId `
  -Location $Location `
  -Name $VmImageName `
  -OsType "Windows" `
  -Path $destVhdx

Write-Host ">> Image '$VmImageName' registered. Ready for AVD session host deployments."