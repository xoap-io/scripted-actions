<#
.SYNOPSIS
    Configure an AVD session host guest: FSLogix profile containers, RDP Shortpath
    for managed networks, and time zone redirection.

.DESCRIPTION
    This script runs INSIDE an Azure Virtual Desktop session host (for example as a
    XOAP Scripted Action targeting the VM, or remotely via WinRM) and applies the
    guest-side configuration that the AVD control plane cannot manage:

    - FSLogix profile containers: optionally installs the FSLogix apps agent
      (download from https://aka.ms/fslogix_download) and configures profile
      containers against an SMB share (Enabled, VHDLocations, VHDX format, size,
      FlipFlop naming, delete-local-profile). This is the recommended profile
      solution for pooled host pools; on Azure Local the share is typically a file
      server VM or SoFS on the same cluster network.

    - RDP Shortpath for managed networks: enables the UDP port redirector (port 3390)
      and adds the required Windows Firewall rule. On Azure Local this keeps session
      traffic on the local network instead of routing it through the AVD gateway,
      which is the single most important performance setting for on-premises session
      hosts (connection brokering still goes through Azure).

    - Time zone redirection: lets the session use the client's local time zone.

    All settings are registry-based and idempotent; re-running the script updates the
    values in place. Settings only take full effect after a reboot (or service
    restart); use -Restart to reboot immediately at the end.

.PARAMETER ProfileSharePath
    UNC path of the SMB share for FSLogix profile containers, e.g.
    "\\fs01.corp.contoso.com\avd-profiles". If omitted, FSLogix is not configured.

.PARAMETER InstallFsLogix
    Download and install the latest FSLogix apps agent before configuring it. Skip
    this if your golden image already contains FSLogix (multi-session marketplace
    images do).

.PARAMETER ProfileSizeMB
    Maximum size of each profile VHDX in MB. Defaults to 30000 (30 GB, thin
    provisioned).

.PARAMETER DeleteLocalProfileWhenVHDShouldApply
    Delete an existing local Windows profile when a FSLogix container should apply
    for the user. Recommended for pooled host pools.

.PARAMETER EnableRdpShortpath
    Enable RDP Shortpath for managed networks (UDP port redirector on port 3390 plus
    the Windows Firewall rule).

.PARAMETER RdpShortpathPort
    UDP port for RDP Shortpath. Defaults to 3390.

.PARAMETER EnableTimeZoneRedirection
    Redirect the client time zone into the session.

.PARAMETER Restart
    Reboot the session host at the end so all settings take effect immediately.

.EXAMPLE
    .\ps-configure-avd-session-host.ps1 `
        -ProfileSharePath "\\fs01.corp.contoso.com\avd-profiles" `
        -EnableRdpShortpath `
        -EnableTimeZoneRedirection `
        -Restart

    Configures FSLogix against the file share, enables RDP Shortpath and time zone
    redirection, then reboots.

.EXAMPLE
    .\ps-configure-avd-session-host.ps1 -EnableRdpShortpath

    Only enables RDP Shortpath for managed networks (no FSLogix changes, no reboot).

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Elevated session inside the AVD session host; internet access for -InstallFsLogix

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-desktop/rdp-shortpath

.LINK
    https://learn.microsoft.com/en-us/fslogix/tutorial-configure-profile-containers

.COMPONENT
    Windows Server
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "UNC path of the SMB share for FSLogix profile containers (omit to skip FSLogix configuration).")]
    [ValidatePattern('^\\\\[^\\]+\\.+$')]
    [string]$ProfileSharePath,

    [Parameter(Mandatory = $false, HelpMessage = "Download and install the latest FSLogix apps agent before configuring it.")]
    [switch]$InstallFsLogix,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum size of each profile VHDX in MB.")]
    [ValidateRange(1024, 1048576)]
    [int]$ProfileSizeMB = 30000,

    [Parameter(Mandatory = $false, HelpMessage = "Delete an existing local Windows profile when a FSLogix container should apply.")]
    [switch]$DeleteLocalProfileWhenVHDShouldApply,

    [Parameter(Mandatory = $false, HelpMessage = "Enable RDP Shortpath for managed networks (UDP port redirector plus firewall rule).")]
    [switch]$EnableRdpShortpath,

    [Parameter(Mandatory = $false, HelpMessage = "UDP port for RDP Shortpath.")]
    [ValidateRange(1024, 65535)]
    [int]$RdpShortpathPort = 3390,

    [Parameter(Mandatory = $false, HelpMessage = "Redirect the client time zone into the session.")]
    [switch]$EnableTimeZoneRedirection,

    [Parameter(Mandatory = $false, HelpMessage = "Reboot the session host at the end so all settings take effect.")]
    [switch]$Restart
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Configuring AVD session host '$env:COMPUTERNAME'" -ForegroundColor Green

    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must run in an elevated (Administrator) session inside the session host."
    }
    if (-not $ProfileSharePath -and -not $EnableRdpShortpath -and -not $EnableTimeZoneRedirection -and -not $InstallFsLogix) {
        throw "Nothing to do. Provide -ProfileSharePath and/or -EnableRdpShortpath / -EnableTimeZoneRedirection."
    }

    # 1) Optionally install FSLogix
    if ($InstallFsLogix) {
        $fslogixService = Get-Service -Name 'frxsvc' -ErrorAction SilentlyContinue
        if ($fslogixService) {
            Write-Host "ℹ️  FSLogix is already installed (service 'frxsvc' present) - skipping installation" -ForegroundColor Yellow
        }
        else {
            Write-Host "🔧 Downloading and installing FSLogix..." -ForegroundColor Cyan
            $zipPath     = Join-Path $env:TEMP "FSLogix.zip"
            $extractPath = Join-Path $env:TEMP "FSLogix"
            Invoke-WebRequest -Uri 'https://aka.ms/fslogix_download' -OutFile $zipPath -UseBasicParsing
            if (Test-Path $extractPath) { Remove-Item -Path $extractPath -Recurse -Force }
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

            $setup = Get-ChildItem -Path $extractPath -Recurse -Filter 'FSLogixAppsSetup.exe' |
                Where-Object { $_.FullName -match '\\x64\\' } | Select-Object -First 1
            if (-not $setup) {
                throw "FSLogixAppsSetup.exe (x64) not found in the downloaded package."
            }
            $install = Start-Process -FilePath $setup.FullName -ArgumentList '/install', '/quiet', '/norestart' -Wait -PassThru
            if ($install.ExitCode -ne 0 -and $install.ExitCode -ne 3010) {
                throw "FSLogix installation failed with exit code $($install.ExitCode)."
            }
            Write-Host "✅ FSLogix installed" -ForegroundColor Green
        }
    }

    # 2) FSLogix profile container configuration
    if ($ProfileSharePath) {
        Write-Host "🔧 Configuring FSLogix profile containers -> '$ProfileSharePath'..." -ForegroundColor Cyan
        $profilesKey = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        if (-not (Test-Path $profilesKey)) {
            $null = New-Item -Path $profilesKey -Force
        }
        Set-ItemProperty -Path $profilesKey -Name 'Enabled'                     -Value 1 -Type DWord
        Set-ItemProperty -Path $profilesKey -Name 'VHDLocations'                -Value @($ProfileSharePath) -Type MultiString
        Set-ItemProperty -Path $profilesKey -Name 'VolumeType'                  -Value 'VHDX' -Type String
        Set-ItemProperty -Path $profilesKey -Name 'SizeInMBs'                   -Value $ProfileSizeMB -Type DWord
        Set-ItemProperty -Path $profilesKey -Name 'IsDynamic'                   -Value 1 -Type DWord
        Set-ItemProperty -Path $profilesKey -Name 'FlipFlopProfileDirectoryName' -Value 1 -Type DWord
        Set-ItemProperty -Path $profilesKey -Name 'LockedRetryCount'            -Value 3 -Type DWord
        Set-ItemProperty -Path $profilesKey -Name 'LockedRetryInterval'         -Value 15 -Type DWord
        if ($DeleteLocalProfileWhenVHDShouldApply) {
            Set-ItemProperty -Path $profilesKey -Name 'DeleteLocalProfileWhenVHDShouldApply' -Value 1 -Type DWord
        }
        Write-Host "✅ FSLogix profile containers configured (max $ProfileSizeMB MB, dynamic VHDX)" -ForegroundColor Green
        Write-Host "ℹ️  Make sure session host computer accounts and users have the required NTFS/share permissions on the profile share" -ForegroundColor Yellow
    }

    # 3) RDP Shortpath for managed networks
    if ($EnableRdpShortpath) {
        Write-Host "🔧 Enabling RDP Shortpath for managed networks (UDP $RdpShortpathPort)..." -ForegroundColor Cyan
        $winStationsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations'
        Set-ItemProperty -Path $winStationsKey -Name 'fUseUdpPortRedirector' -Value 1 -Type DWord
        Set-ItemProperty -Path $winStationsKey -Name 'UdpPortNumber'         -Value $RdpShortpathPort -Type DWord

        $ruleName = 'Remote Desktop - RDP Shortpath (UDP-In)'
        $rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        if (-not $rule) {
            $null = New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol UDP `
                -LocalPort $RdpShortpathPort -Action Allow -Program '%SystemRoot%\system32\svchost.exe' -Service 'TermService'
            Write-Host "✅ Firewall rule '$ruleName' created" -ForegroundColor Green
        }
        else {
            Write-Host "ℹ️  Firewall rule '$ruleName' already exists" -ForegroundColor Yellow
        }
        Write-Host "✅ RDP Shortpath enabled - session traffic can stay on the local network" -ForegroundColor Green
    }

    # 4) Time zone redirection
    if ($EnableTimeZoneRedirection) {
        Write-Host "🔧 Enabling time zone redirection..." -ForegroundColor Cyan
        $tsPoliciesKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
        if (-not (Test-Path $tsPoliciesKey)) {
            $null = New-Item -Path $tsPoliciesKey -Force
        }
        Set-ItemProperty -Path $tsPoliciesKey -Name 'fEnableTimeZoneRedirection' -Value 1 -Type DWord
        Write-Host "✅ Time zone redirection enabled" -ForegroundColor Green
    }

    # 5) Summary + optional reboot
    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    if ($ProfileSharePath)          { Write-Host "   FSLogix profiles:  $ProfileSharePath" -ForegroundColor Blue }
    if ($EnableRdpShortpath)        { Write-Host "   RDP Shortpath:     enabled (UDP $RdpShortpathPort)" -ForegroundColor Blue }
    if ($EnableTimeZoneRedirection) { Write-Host "   TZ redirection:    enabled" -ForegroundColor Blue }

    if ($Restart) {
        Write-Host "`n⚠️  Rebooting session host in 10 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
    else {
        Write-Host "`n💡 Next Steps: reboot the session host (or restart the Remote Desktop Services service) for all settings to take effect" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
