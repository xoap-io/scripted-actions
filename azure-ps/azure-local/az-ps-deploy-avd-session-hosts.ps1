<#
.SYNOPSIS
    Deploy AVD session hosts on an Azure Local (Azure Stack HCI) cluster and register
    them to an existing host pool - end to end, fully unattended.

.DESCRIPTION
    This script performs the complete session host rollout for Azure Virtual Desktop
    on Azure Local, replicating what the Azure portal wizard does, but scriptable:

    For each of the requested session hosts it:

    1. Creates a network interface on the logical network and deploys an Arc VM from a
       registered Azure Local VM image (Secure Boot + vTPM + VM config agent enabled)
       via New-AzStackHCIVMVirtualMachine.
    2. Waits for WinRM in the guest, then joins the VM to your Active Directory domain
       (AVD session hosts on Azure Local must be AD DS-joined) and reboots it.
    3. Installs the Remote Desktop Session Host role if the image is a Windows Server OS.
    4. Optionally onboards the guest to Azure Arc with the Azure Connected Machine agent
       (azcmagent connect using the provided service principal). This is required by
       Azure Virtual Desktop for session hosts created outside the portal so they can
       reach the Azure Instance Metadata Service.
    5. Installs the Azure Virtual Desktop Agent and Agent Boot Loader with a host pool
       registration token (generated automatically via New-AzWvdRegistrationInfo if no
       valid token exists), then restarts the VM.
    6. Verifies that the session hosts appear in the host pool.

    Individual hosts that fail are reported and the script continues with the remaining
    hosts; the script exits non-zero if any host failed. Existing VMs with the same name
    are skipped (idempotent re-runs).

    Designed for the XOAP Scripted Actions module running on an Azure Local cluster
    node: all parameters are plain strings/switches and the Azure context is expected
    to be pre-established by the scripted action's service principal. The service
    principal needs Desktop Virtualization Host Pool Contributor and Azure Stack HCI
    VM Contributor; for -Arc* onboarding, the Arc service principal needs the
    Azure Connected Machine Onboarding role.

    The machine running this script must be able to reach the session host IPs over
    WinRM (TCP 5985). When connecting by IP with NTLM, the local WinRM client must
    trust the target - use -UpdateTrustedHosts to add the VM IPs automatically.

    Create the host pool first with az-ps-create-avd-control-plane.ps1.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER CustomLocationId
    Custom Location resource ID that maps to your Azure Local cluster (Arc resource bridge).
    Defaults to the XOAP LocalBox custom location "jumpstart".

.PARAMETER Location
    Azure region of the Arc resources. Defaults to "westeurope".

.PARAMETER HostPoolName
    Name of the existing AVD host pool to register the session hosts to.

.PARAMETER HostPoolResourceGroupName
    Resource group of the host pool. Defaults to ResourceGroupName.

.PARAMETER NamePrefix
    Name prefix for the session hosts (max. 11 characters). Each host is named
    "<NamePrefix>-<index>", e.g. "hp01-sh-0", which is also the computer name.

.PARAMETER SessionHostCount
    Number of session hosts to deploy. Defaults to 1.

.PARAMETER StartIndex
    First index used in the session host names. Defaults to 0. Use this to add more
    hosts to a pool that already has "<NamePrefix>-0..n".

.PARAMETER VmImageName
    Name of the registered Azure Local VM image to deploy from (see
    az-ps-create-azure-local-image.ps1 or ps-build-hyperv-golden-image.ps1).

.PARAMETER LogicalNetworkName
    Name of the existing logical network to attach the session hosts to.
    Defaults to "localboxcluster-InfraLNET".

.PARAMETER VmVcpu
    Number of vCPUs per session host. Defaults to 4.

.PARAMETER VmMemoryGB
    Memory in GB per session host. Defaults to 8.

.PARAMETER StoragePathName
    Optional storage path name that hosts the VM configuration and disks.

.PARAMETER LocalAdminUser
    Local administrator user name created in the guest. Defaults to "avdadmin".

.PARAMETER LocalAdminPassword
    Password of the local administrator (plain string for XOAP Scripted Actions).

.PARAMETER DomainFqdn
    Fully qualified name of the Active Directory domain to join, e.g. "corp.contoso.com".

.PARAMETER DomainOuPath
    Optional distinguished name of the OU for the computer accounts, e.g.
    "OU=AVD,DC=corp,DC=contoso,DC=com".

.PARAMETER DomainJoinUser
    Account with permission to join computers to the domain, e.g. "CORP\svc-join" or
    "svc-join@corp.contoso.com".

.PARAMETER DomainJoinPassword
    Password of the domain join account (plain string for XOAP Scripted Actions).

.PARAMETER ArcServicePrincipalId
    Optional application (client) ID of a service principal used to onboard the guests
    to Azure Arc (azcmagent connect). Provide together with -ArcServicePrincipalSecret
    and -ArcTenantId; if omitted, Arc onboarding is skipped with a warning.

.PARAMETER ArcServicePrincipalSecret
    Client secret of the Arc onboarding service principal.

.PARAMETER ArcTenantId
    Entra ID tenant ID of the Arc onboarding service principal.

.PARAMETER TokenExpirationHours
    Validity in hours of a newly generated host pool registration token. Defaults to 24.

.PARAMETER WinRMTimeoutSec
    Timeout in seconds for each wait on guest WinRM (first boot and after reboots).
    Defaults to 1800.

.PARAMETER VerifyTimeoutSec
    Timeout in seconds for the final wait until the session hosts appear in the host
    pool. Defaults to 900.

.PARAMETER UpdateTrustedHosts
    Add the session host IPs to the local WinRM TrustedHosts list so the script can
    connect by IP with NTLM authentication.

.EXAMPLE
    .\az-ps-deploy-avd-session-hosts.ps1 `
        -HostPoolName "hp-azlocal-01" `
        -NamePrefix "avd-sh" `
        -SessionHostCount 2 `
        -VmImageName "win11-avd-golden" `
        -LocalAdminPassword "P@ssw0rd-local" `
        -DomainFqdn "corp.contoso.com" `
        -DomainJoinUser "CORP\svc-domainjoin" `
        -DomainJoinPassword "P@ssw0rd-join" `
        -ArcServicePrincipalId "00000000-0000-0000-0000-000000000000" `
        -ArcServicePrincipalSecret "<secret>" `
        -ArcTenantId "00000000-0000-0000-0000-000000000000" `
        -UpdateTrustedHosts

    Deploys avd-sh-0 and avd-sh-1 on the LocalBox cluster, joins them to
    corp.contoso.com, onboards them to Azure Arc and registers them to host pool
    "hp-azlocal-01".

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Accounts, Az.StackHCIVM, Az.DesktopVirtualization; a connected Azure context (service principal); WinRM reachability to the session host IPs

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-desktop/add-session-hosts-host-pool

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-desktop/azure-local-overview

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.stackhcivm/

.COMPONENT
    Azure PowerShell Stack HCI
#>

[CmdletBinding()]
param(
    # Azure Local resource scoping
    [Parameter(Mandatory = $false, HelpMessage = "Azure resource group that represents your Azure Local instance scope.")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroupName = "AzureLocal",

    [Parameter(Mandatory = $false, HelpMessage = "Custom Location resource ID that maps to your Azure Local cluster (Arc resource bridge).")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomLocationId = "/subscriptions/e5373ae1-c1cf-418e-8044-a2851af745b6/resourceGroups/AzureLocal/providers/Microsoft.ExtendedLocation/customLocations/jumpstart",

    [Parameter(Mandatory = $false, HelpMessage = "Azure region of the Arc resources.")]
    [ValidateNotNullOrEmpty()]
    [string]$Location = "westeurope",

    # Host pool
    [Parameter(Mandatory = $true, HelpMessage = "Name of the existing AVD host pool to register the session hosts to.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory = $false, HelpMessage = "Resource group of the host pool. Defaults to ResourceGroupName.")]
    [string]$HostPoolResourceGroupName = "",

    # Session hosts
    [Parameter(Mandatory = $true, HelpMessage = "Name prefix for the session hosts (max. 11 characters); hosts are named '<prefix>-<index>'.")]
    [ValidateLength(1, 11)]
    [ValidatePattern('^[a-zA-Z0-9-]+$')]
    [string]$NamePrefix,

    [Parameter(Mandatory = $false, HelpMessage = "Number of session hosts to deploy.")]
    [ValidateRange(1, 64)]
    [int]$SessionHostCount = 1,

    [Parameter(Mandatory = $false, HelpMessage = "First index used in the session host names.")]
    [ValidateRange(0, 999)]
    [int]$StartIndex = 0,

    # Image / sizing / network
    [Parameter(Mandatory = $true, HelpMessage = "Name of the registered Azure Local VM image to deploy from.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmImageName,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the existing logical network to attach the session hosts to.")]
    [ValidateNotNullOrEmpty()]
    [string]$LogicalNetworkName = "localboxcluster-InfraLNET",

    [Parameter(Mandatory = $false, HelpMessage = "Number of vCPUs per session host.")]
    [ValidateRange(1, 128)]
    [int]$VmVcpu = 4,

    [Parameter(Mandatory = $false, HelpMessage = "Memory in GB per session host.")]
    [ValidateRange(2, 2048)]
    [int]$VmMemoryGB = 8,

    [Parameter(Mandatory = $false, HelpMessage = "Optional storage path name that hosts the VM configuration and disks.")]
    [string]$StoragePathName = "",

    # Guest OS local admin
    [Parameter(Mandatory = $false, HelpMessage = "Local administrator user name created in the guest.")]
    [ValidateNotNullOrEmpty()]
    [string]$LocalAdminUser = "avdadmin",

    [Parameter(Mandatory = $true, HelpMessage = "Password of the local administrator (plain string for XOAP Scripted Actions).")]
    [ValidateNotNullOrEmpty()]
    [string]$LocalAdminPassword,

    # Domain join
    [Parameter(Mandatory = $true, HelpMessage = "Fully qualified name of the Active Directory domain to join, e.g. 'corp.contoso.com'.")]
    [ValidatePattern('^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$')]
    [string]$DomainFqdn,

    [Parameter(Mandatory = $false, HelpMessage = "Optional distinguished name of the OU for the computer accounts.")]
    [string]$DomainOuPath = "",

    [Parameter(Mandatory = $true, HelpMessage = "Account with permission to join computers to the domain, e.g. 'CORP\svc-join'.")]
    [ValidateNotNullOrEmpty()]
    [string]$DomainJoinUser,

    [Parameter(Mandatory = $true, HelpMessage = "Password of the domain join account (plain string for XOAP Scripted Actions).")]
    [ValidateNotNullOrEmpty()]
    [string]$DomainJoinPassword,

    # Azure Arc onboarding (optional)
    [Parameter(Mandatory = $false, HelpMessage = "Application (client) ID of the service principal used to onboard the guests to Azure Arc (omit to skip Arc onboarding).")]
    [string]$ArcServicePrincipalId = "",

    [Parameter(Mandatory = $false, HelpMessage = "Client secret of the Arc onboarding service principal.")]
    [string]$ArcServicePrincipalSecret = "",

    [Parameter(Mandatory = $false, HelpMessage = "Entra ID tenant ID of the Arc onboarding service principal.")]
    [string]$ArcTenantId = "",

    # Timing
    [Parameter(Mandatory = $false, HelpMessage = "Validity in hours of a newly generated host pool registration token.")]
    [ValidateRange(1, 648)]
    [int]$TokenExpirationHours = 24,

    [Parameter(Mandatory = $false, HelpMessage = "Timeout in seconds for each wait on guest WinRM.")]
    [ValidateRange(60, 14400)]
    [int]$WinRMTimeoutSec = 1800,

    [Parameter(Mandatory = $false, HelpMessage = "Timeout in seconds for the final wait until the session hosts appear in the host pool.")]
    [ValidateRange(60, 7200)]
    [int]$VerifyTimeoutSec = 900,

    [Parameter(Mandatory = $false, HelpMessage = "Add the session host IPs to the local WinRM TrustedHosts list.")]
    [switch]$UpdateTrustedHosts
)

$ErrorActionPreference = 'Stop'

function ConvertTo-SecureStringFromPlain {
    param([string]$Plain)
    $secure = New-Object System.Security.SecureString
    foreach ($char in $Plain.ToCharArray()) { $secure.AppendChar($char) }
    return $secure
}

function Wait-GuestWinRM {
    param([string]$Target, [int]$TimeoutSec)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Seconds 15
        $up = Test-NetConnection -ComputerName $Target -Port 5985 -InformationLevel Quiet -WarningAction SilentlyContinue
    } while (-not $up -and $sw.Elapsed.TotalSeconds -lt $TimeoutSec)
    if (-not $up) {
        throw "WinRM (TCP 5985) on '$Target' did not become reachable within $TimeoutSec seconds."
    }
}

function Connect-GuestSession {
    param([string]$Target, [pscredential]$Credential, [int]$TimeoutSec)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        try {
            return New-PSSession -ComputerName $Target -Credential $Credential -ErrorAction Stop
        }
        catch {
            if ($sw.Elapsed.TotalSeconds -ge $TimeoutSec) {
                throw "Could not establish a PowerShell session to '$($Target)': $($_.Exception.Message)"
            }
            Start-Sleep -Seconds 15
        }
    }
}

function Restart-Guest {
    param([System.Management.Automation.Runspaces.PSSession]$Session, [string]$Target, [pscredential]$Credential, [int]$TimeoutSec)
    Invoke-Command -Session $Session -ScriptBlock { Restart-Computer -Force } -ErrorAction SilentlyContinue
    Remove-PSSession -Session $Session -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 30
    Wait-GuestWinRM -Target $Target -TimeoutSec $TimeoutSec
    return Connect-GuestSession -Target $Target -Credential $Credential -TimeoutSec $TimeoutSec
}

try {
    # 0) Preflight: modules + Azure context + host pool
    Write-Host "🚀 Deploying $SessionHostCount AVD session host(s) '$NamePrefix-*' on Azure Local" -ForegroundColor Green

    foreach ($module in @('Az.Accounts', 'Az.StackHCIVM', 'Az.DesktopVirtualization')) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            throw "The $module module is not installed. Run: Install-Module $module -Scope CurrentUser"
        }
    }
    $context = Get-AzContext
    if (-not $context) {
        throw "No Azure context found. The XOAP Scripted Actions service principal must be connected (Connect-AzAccount -ServicePrincipal) before this script runs."
    }
    Write-Host "🔍 Using subscription '$($context.Subscription.Name)' ($($context.Subscription.Id))" -ForegroundColor Cyan

    if (-not $HostPoolResourceGroupName) { $HostPoolResourceGroupName = $ResourceGroupName }

    $hostPool = Get-AzWvdHostPool -ResourceGroupName $HostPoolResourceGroupName -Name $HostPoolName -ErrorAction SilentlyContinue
    if (-not $hostPool) {
        throw "Host pool '$HostPoolName' not found in resource group '$HostPoolResourceGroupName'. Create it first with az-ps-create-avd-control-plane.ps1."
    }

    $arcOnboarding = ($ArcServicePrincipalId -and $ArcServicePrincipalSecret -and $ArcTenantId)
    if (-not $arcOnboarding) {
        Write-Host "⚠️  No Arc onboarding service principal provided - skipping azcmagent onboarding. AVD requires the Azure Connected Machine agent on session hosts created outside the portal; onboard them separately if needed." -ForegroundColor Yellow
    }

    # 1) Resolve image + logical network
    $image = Get-AzStackHCIVMImage -ResourceGroupName $ResourceGroupName -Name $VmImageName -ErrorAction SilentlyContinue
    if (-not $image) {
        $available = (Get-AzStackHCIVMImage -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue).Name -join ", "
        throw "Image '$VmImageName' not found in resource group '$ResourceGroupName'. Available images: $available"
    }
    $lnet = Get-AzStackHCIVMLogicalNetwork -ResourceGroupName $ResourceGroupName -Name $LogicalNetworkName -ErrorAction SilentlyContinue
    if (-not $lnet) {
        throw "Logical network '$LogicalNetworkName' not found in resource group '$ResourceGroupName'. Create it first with az-ps-create-azure-local-logical-network.ps1."
    }

    # 2) Host pool registration token (reuse a valid one, otherwise generate)
    $token = (Get-AzWvdHostPoolRegistrationToken -ResourceGroupName $HostPoolResourceGroupName -HostPoolName $HostPoolName -ErrorAction SilentlyContinue).Token
    if (-not $token) {
        Write-Host "🔧 Generating host pool registration token (valid $TokenExpirationHours h)..." -ForegroundColor Cyan
        $expiration = (Get-Date).ToUniversalTime().AddHours($TokenExpirationHours).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
        $token = (New-AzWvdRegistrationInfo -ResourceGroupName $HostPoolResourceGroupName -HostPoolName $HostPoolName -ExpirationTime $expiration).Token
    }
    if (-not $token) {
        throw "Could not obtain a registration token for host pool '$HostPoolName'."
    }

    $localAdminCred = New-Object System.Management.Automation.PSCredential($LocalAdminUser, (ConvertTo-SecureStringFromPlain -Plain $LocalAdminPassword))

    $succeeded = @()
    $failed    = @()

    # 3) Deploy and configure each session host
    for ($i = $StartIndex; $i -lt ($StartIndex + $SessionHostCount); $i++) {
        $vmName  = "$($NamePrefix)-$($i)"
        $session = $null
        try {
            Write-Host "`n🔧 [$vmName] Deploying session host..." -ForegroundColor Cyan

            # 3a) NIC + VM (skip creation if the VM already exists)
            $vm = Get-AzStackHCIVMVirtualMachine -ResourceGroupName $ResourceGroupName -Name $vmName -ErrorAction SilentlyContinue
            if ($vm) {
                Write-Host "ℹ️  [$vmName] VM already exists - reusing it for configuration" -ForegroundColor Yellow
            }
            else {
                $nicName = "$($vmName)-nic0"
                $nic = Get-AzStackHCIVMNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName -ErrorAction SilentlyContinue
                if (-not $nic) {
                    $nicParams = @{
                        Name              = $nicName
                        ResourceGroupName = $ResourceGroupName
                        CustomLocationId  = $CustomLocationId
                        Location          = $Location
                        SubnetId          = $lnet.Id
                    }
                    $nic = New-AzStackHCIVMNetworkInterface @nicParams
                }

                $vmParams = @{
                    Name                   = $vmName
                    ResourceGroupName      = $ResourceGroupName
                    CustomLocationId       = $CustomLocationId
                    Location               = $Location
                    OsType                 = "Windows"
                    ImageId                = $image.Id
                    VmSize                 = "Custom"
                    VmProcessor            = $VmVcpu
                    VmMemoryInMB           = ($VmMemoryGB * 1024)
                    AdminUsername          = $LocalAdminUser
                    AdminPassword          = (ConvertTo-SecureStringFromPlain -Plain $LocalAdminPassword)
                    ComputerName           = $vmName
                    NicId                  = @((Get-AzStackHCIVMNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName).Id)
                    SecureBootEnabled      = $true
                    EnableTpm              = $true
                    ProvisionVMConfigAgent = $true
                }
                if ($StoragePathName) { $vmParams['StoragePathName'] = $StoragePathName }
                $vm = New-AzStackHCIVMVirtualMachine @vmParams
                Write-Host "✅ [$vmName] VM deployed (state: $($vm.ProvisioningState))" -ForegroundColor Green
            }

            # 3b) Resolve the guest IP and wait for WinRM
            $nic  = Get-AzStackHCIVMNetworkInterface -ResourceGroupName $ResourceGroupName -Name "$($vmName)-nic0"
            $vmIp = $nic.IPConfiguration.IPAddress | Select-Object -First 1
            if (-not $vmIp) {
                throw "Could not determine the IP address of '$vmName'."
            }
            Write-Host "🔍 [$vmName] Guest IP: $vmIp - waiting for WinRM..." -ForegroundColor Cyan

            if ($UpdateTrustedHosts) {
                $trusted = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
                if ($trusted -ne '*' -and $trusted -notmatch [regex]::Escape($vmIp)) {
                    if ([string]::IsNullOrEmpty($trusted)) { $newTrusted = $vmIp } else { $newTrusted = "$($trusted),$($vmIp)" }
                    Set-Item WSMan:\localhost\Client\TrustedHosts -Value $newTrusted -Force
                    Write-Host "🔧 [$vmName] Added $vmIp to WinRM TrustedHosts" -ForegroundColor Cyan
                }
            }

            Wait-GuestWinRM -Target $vmIp -TimeoutSec $WinRMTimeoutSec
            $session = Connect-GuestSession -Target $vmIp -Credential $localAdminCred -TimeoutSec $WinRMTimeoutSec

            # 3c) Domain join (skip if already joined) + reboot
            $inDomain = Invoke-Command -Session $session -ScriptBlock {
                (Get-CimInstance -ClassName Win32_ComputerSystem).PartOfDomain
            }
            if ($inDomain) {
                Write-Host "ℹ️  [$vmName] Already domain-joined - skipping join" -ForegroundColor Yellow
            }
            else {
                Write-Host "🔧 [$vmName] Joining domain '$DomainFqdn'..." -ForegroundColor Cyan
                Invoke-Command -Session $session -ScriptBlock {
                    param($JoinUser, $JoinPassword, $Domain, $OuPath)
                    $secure = New-Object System.Security.SecureString
                    foreach ($char in $JoinPassword.ToCharArray()) { $secure.AppendChar($char) }
                    $cred = New-Object System.Management.Automation.PSCredential($JoinUser, $secure)
                    $joinParams = @{ DomainName = $Domain; Credential = $cred; ErrorAction = 'Stop' }
                    if ($OuPath) { $joinParams['OUPath'] = $OuPath }
                    Add-Computer @joinParams
                } -ArgumentList $DomainJoinUser, $DomainJoinPassword, $DomainFqdn, $DomainOuPath
                $session = Restart-Guest -Session $session -Target $vmIp -Credential $localAdminCred -TimeoutSec $WinRMTimeoutSec
                Write-Host "✅ [$vmName] Domain joined" -ForegroundColor Green
            }

            # 3d) RDS role for Windows Server images
            $productType = Invoke-Command -Session $session -ScriptBlock {
                (Get-CimInstance -ClassName Win32_OperatingSystem).ProductType
            }
            if ($productType -ne 1) {
                $rdsInstalled = Invoke-Command -Session $session -ScriptBlock {
                    (Get-WindowsFeature -Name RDS-RD-Server).Installed
                }
                if (-not $rdsInstalled) {
                    Write-Host "🔧 [$vmName] Windows Server detected - installing Remote Desktop Session Host role..." -ForegroundColor Cyan
                    Invoke-Command -Session $session -ScriptBlock {
                        $null = Install-WindowsFeature -Name RDS-RD-Server -ErrorAction Stop
                    }
                    $session = Restart-Guest -Session $session -Target $vmIp -Credential $localAdminCred -TimeoutSec $WinRMTimeoutSec
                    Write-Host "✅ [$vmName] RDS role installed" -ForegroundColor Green
                }
            }

            # 3e) Azure Arc onboarding (Azure Connected Machine agent)
            if ($arcOnboarding) {
                Write-Host "🔧 [$vmName] Onboarding to Azure Arc (azcmagent connect)..." -ForegroundColor Cyan
                Invoke-Command -Session $session -ScriptBlock {
                    param($SpnId, $SpnSecret, $TenantId, $SubscriptionId, $ResourceGroup, $AzLocation)
                    $agentExe = "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe"
                    if (-not (Test-Path $agentExe)) {
                        $msi = Join-Path $env:TEMP "AzureConnectedMachineAgent.msi"
                        Invoke-WebRequest -Uri 'https://aka.ms/azcmagent-windows' -OutFile $msi -UseBasicParsing
                        $install = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$msi`" /quiet /norestart" -Wait -PassThru
                        if ($install.ExitCode -ne 0) {
                            throw "Azure Connected Machine agent installation failed with exit code $($install.ExitCode)."
                        }
                    }
                    $status = & $agentExe show 2>&1
                    if ($LASTEXITCODE -eq 0 -and (($status | Out-String) -match 'Connected')) {
                        return
                    }
                    $connectOutput = & $agentExe connect `
                        --service-principal-id $SpnId `
                        --service-principal-secret $SpnSecret `
                        --tenant-id $TenantId `
                        --subscription-id $SubscriptionId `
                        --resource-group $ResourceGroup `
                        --location $AzLocation 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "azcmagent connect failed: $($connectOutput | Out-String)"
                    }
                } -ArgumentList $ArcServicePrincipalId, $ArcServicePrincipalSecret, $ArcTenantId, $context.Subscription.Id, $ResourceGroupName, $Location
                Write-Host "✅ [$vmName] Azure Arc onboarding complete" -ForegroundColor Green
            }

            # 3f) AVD Agent + Boot Loader with registration token, then reboot
            $avdInstalled = Invoke-Command -Session $session -ScriptBlock {
                Test-Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent'
            }
            if ($avdInstalled) {
                Write-Host "ℹ️  [$vmName] AVD agent already installed - skipping" -ForegroundColor Yellow
            }
            else {
                Write-Host "🔧 [$vmName] Installing AVD Agent and Boot Loader..." -ForegroundColor Cyan
                Invoke-Command -Session $session -ScriptBlock {
                    param($RegistrationToken)
                    $agentMsi      = Join-Path $env:TEMP "AVDAgent.msi"
                    $bootLoaderMsi = Join-Path $env:TEMP "AVDBootLoader.msi"
                    Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2310011' -OutFile $agentMsi -UseBasicParsing
                    Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2311028' -OutFile $bootLoaderMsi -UseBasicParsing

                    $agentInstall = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$agentMsi`" /quiet REGISTRATIONTOKEN=$RegistrationToken" -Wait -PassThru
                    if ($agentInstall.ExitCode -ne 0) {
                        throw "AVD Agent installation failed with exit code $($agentInstall.ExitCode)."
                    }
                    $bootLoaderInstall = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$bootLoaderMsi`" /quiet" -Wait -PassThru
                    if ($bootLoaderInstall.ExitCode -ne 0) {
                        throw "AVD Agent Boot Loader installation failed with exit code $($bootLoaderInstall.ExitCode)."
                    }
                } -ArgumentList $token
                $session = Restart-Guest -Session $session -Target $vmIp -Credential $localAdminCred -TimeoutSec $WinRMTimeoutSec
                Write-Host "✅ [$vmName] AVD agents installed" -ForegroundColor Green
            }

            Remove-PSSession -Session $session -ErrorAction SilentlyContinue
            $session = $null
            $succeeded += $vmName
        }
        catch {
            Write-Host "❌ [$vmName] Failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($session) { Remove-PSSession -Session $session -ErrorAction SilentlyContinue }
            $failed += $vmName
        }
    }

    # 4) Verify session hosts appear in the host pool
    if ($succeeded.Count -gt 0) {
        Write-Host "`n🔍 Waiting for $($succeeded.Count) session host(s) to register in host pool '$HostPoolName' (timeout: $VerifyTimeoutSec s)..." -ForegroundColor Cyan
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $pending = @($succeeded)
        while ($pending.Count -gt 0 -and $sw.Elapsed.TotalSeconds -lt $VerifyTimeoutSec) {
            Start-Sleep -Seconds 30
            $sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $HostPoolResourceGroupName -HostPoolName $HostPoolName -ErrorAction SilentlyContinue
            $registeredNames = @()
            foreach ($sh in $sessionHosts) {
                $registeredNames += ($sh.Name -split '/')[-1] -replace '\..*$', ''
            }
            $pending = @($pending | Where-Object { $registeredNames -notcontains $_ })
        }
        foreach ($name in $succeeded) {
            if ($pending -contains $name) {
                Write-Host "⚠️  Session host '$name' has not appeared in the host pool yet - check the AVD agent state in the guest" -ForegroundColor Yellow
            }
            else {
                Write-Host "✅ Session host '$name' registered in host pool '$HostPoolName'" -ForegroundColor Green
            }
        }
    }

    # 5) Summary
    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "   Host pool:  $HostPoolName" -ForegroundColor Blue
    Write-Host "   Succeeded:  $($succeeded.Count) ($($succeeded -join ', '))" -ForegroundColor Blue
    Write-Host "   Failed:     $($failed.Count) ($($failed -join ', '))" -ForegroundColor Blue
    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   Configure FSLogix and RDP Shortpath in the guests with ps-configure-avd-session-host.ps1" -ForegroundColor Yellow
    Write-Host "   Assign users with az-ps-create-avd-control-plane.ps1 -AssignUserUpns / -AssignGroupObjectIds" -ForegroundColor Yellow

    if ($failed.Count -gt 0) {
        throw "$($failed.Count) session host(s) failed to deploy: $($failed -join ', ')"
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
