<#
.SYNOPSIS
    Configure Windows Update settings and optionally point clients at a WSUS server.

.DESCRIPTION
    Configures Windows Update behaviour on the local machine using the PSWindowsUpdate
    module or the built-in Windows Update Agent (WUA) COM interface. Supports configuring
    a WSUS server URL, enabling automatic updates on a daily or weekly schedule, and
    triggering an immediate update check and install.

.PARAMETER WsusServer
    URL of the WSUS server (e.g. http://wsus.corp.local:8530). If omitted, Windows Update
    communicates directly with Microsoft Update.

.PARAMETER WsusPort
    TCP port used by the WSUS server. Default is 8530.

.PARAMETER EnableAutomaticUpdate
    Enable automatic downloading and installation of updates.

.PARAMETER AutoUpdateSchedule
    Frequency for automatic updates: Daily or Weekly. Default is Daily.

.PARAMETER InstallUpdatesNow
    Trigger an immediate update check and install all available updates.

.PARAMETER AcceptEula
    Automatically accept EULAs for updates that require one.

.PARAMETER RestartIfRequired
    Automatically restart the computer if an update requires it.

.EXAMPLE
    .\ps-configure-windows-update.ps1 -EnableAutomaticUpdate -AutoUpdateSchedule Daily

.EXAMPLE
    .\ps-configure-windows-update.ps1 -WsusServer "http://wsus.corp.local" -WsusPort 8530 -EnableAutomaticUpdate -InstallUpdatesNow -AcceptEula

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: PSWindowsUpdate module (Install-Module PSWindowsUpdate) or built-in WUA COM

.LINK
    https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-overview

.COMPONENT
    Windows PowerShell Server Management
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "URL of the WSUS server (e.g. http://wsus.corp.local:8530).")]
    [string]$WsusServer,

    [Parameter(Mandatory = $false, HelpMessage = "TCP port used by the WSUS server. Default is 8530.")]
    [ValidateRange(1, 65535)]
    [int]$WsusPort = 8530,

    [Parameter(Mandatory = $false, HelpMessage = "Enable automatic downloading and installation of updates.")]
    [switch]$EnableAutomaticUpdate,

    [Parameter(Mandatory = $false, HelpMessage = "Frequency for automatic updates: Daily or Weekly.")]
    [ValidateSet('Daily', 'Weekly')]
    [string]$AutoUpdateSchedule = 'Daily',

    [Parameter(Mandatory = $false, HelpMessage = "Trigger an immediate update check and install all available updates.")]
    [switch]$InstallUpdatesNow,

    [Parameter(Mandatory = $false, HelpMessage = "Automatically accept EULAs for updates that require one.")]
    [switch]$AcceptEula,

    [Parameter(Mandatory = $false, HelpMessage = "Automatically restart the computer if an update requires it.")]
    [switch]$RestartIfRequired
)

$ErrorActionPreference = 'Stop'

# Must run as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must be run as Administrator."
}

try {
    Write-Host "🚀 Starting Windows Update Configuration" -ForegroundColor Green

    # Configure WSUS via registry if WsusServer is provided
    if ($WsusServer) {
        Write-Host "🔧 Configuring WSUS server: $WsusServer (port $WsusPort)..." -ForegroundColor Cyan
        $wuRegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        $auRegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
        foreach ($path in @($wuRegPath, $auRegPath)) {
            if (-not (Test-Path $path)) {
                New-Item -Path $path -Force | Out-Null
            }
        }
        Set-ItemProperty -Path $wuRegPath -Name 'WUServer'       -Value $WsusServer -Type String
        Set-ItemProperty -Path $wuRegPath -Name 'WUStatusServer' -Value $WsusServer -Type String
        Set-ItemProperty -Path $auRegPath -Name 'UseWUServer'     -Value 1 -Type DWord
        Write-Host "✅ WSUS configured: $WsusServer" -ForegroundColor Green
    }

    # Configure automatic updates
    if ($EnableAutomaticUpdate) {
        Write-Host "🔧 Enabling automatic updates (Schedule: $AutoUpdateSchedule)..." -ForegroundColor Cyan
        $auRegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
        if (-not (Test-Path $auRegPath)) {
            New-Item -Path $auRegPath -Force | Out-Null
        }
        # AUOptions: 4 = Auto download and install
        Set-ItemProperty -Path $auRegPath -Name 'NoAutoUpdate'          -Value 0 -Type DWord
        Set-ItemProperty -Path $auRegPath -Name 'AUOptions'             -Value 4 -Type DWord
        Set-ItemProperty -Path $auRegPath -Name 'ScheduledInstallDay'   -Value $(if ($AutoUpdateSchedule -eq 'Daily') { 0 } else { 1 }) -Type DWord
        Set-ItemProperty -Path $auRegPath -Name 'ScheduledInstallTime'  -Value 3 -Type DWord  # 3 AM
        Set-ItemProperty -Path $auRegPath -Name 'NoAutoRebootWithLoggedOnUsers' -Value $(if ($RestartIfRequired) { 0 } else { 1 }) -Type DWord
        Write-Host "✅ Automatic updates enabled ($AutoUpdateSchedule, 3 AM)." -ForegroundColor Green
    }

    # Trigger immediate install using PSWindowsUpdate if available, else WUA COM
    if ($InstallUpdatesNow) {
        Write-Host "🔧 Checking for and installing available updates..." -ForegroundColor Cyan

        $psWU = Get-Module -ListAvailable -Name PSWindowsUpdate
        if ($psWU) {
            Import-Module PSWindowsUpdate -ErrorAction Stop
            $installParams = @{
                AcceptAll  = $true
                Install    = $true
                AutoReboot = $RestartIfRequired
                Verbose    = $false
            }
            if ($AcceptEula) {
                $installParams['AcceptEula'] = $true
            }
            $updates = Get-WindowsUpdate @installParams
            if ($updates) {
                Write-Host "✅ $($updates.Count) update(s) installed via PSWindowsUpdate." -ForegroundColor Green
            } else {
                Write-Host "ℹ️  No updates available." -ForegroundColor Yellow
            }
        } else {
            Write-Host "ℹ️  PSWindowsUpdate not found. Using WUA COM interface..." -ForegroundColor Yellow
            $updateSession  = New-Object -ComObject Microsoft.Update.Session
            $updateSearcher = $updateSession.CreateUpdateSearcher()
            Write-Host "🔍 Searching for updates..." -ForegroundColor Cyan
            $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
            $updates = $searchResult.Updates

            if ($updates.Count -eq 0) {
                Write-Host "ℹ️  No updates available." -ForegroundColor Yellow
            } else {
                Write-Host "ℹ️  Found $($updates.Count) update(s). Downloading..." -ForegroundColor Yellow
                $downloader = $updateSession.CreateUpdateDownloader()
                $downloader.Updates = $updates
                $downloader.Download() | Out-Null

                $installer = $updateSession.CreateUpdateInstaller()
                $installer.Updates = $updates
                $result = $installer.Install()
                Write-Host "✅ Install result code: $($result.ResultCode) (2=Succeeded)" -ForegroundColor Green

                if ($result.RebootRequired -and $RestartIfRequired) {
                    Write-Host "⚠️  Reboot required. Restarting in 30 seconds..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 30
                    Restart-Computer -Force
                } elseif ($result.RebootRequired) {
                    Write-Host "⚠️  Reboot required to complete installation. Use -RestartIfRequired to automate." -ForegroundColor Yellow
                }
            }
        }
    }

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  WSUS Server:         $(if ($WsusServer) { $WsusServer } else { 'Not configured (using Microsoft Update)' })" -ForegroundColor Cyan
    Write-Host "  Automatic Updates:   $(if ($EnableAutomaticUpdate) { "Enabled ($AutoUpdateSchedule)" } else { 'Not changed' })" -ForegroundColor Cyan
    Write-Host "  Install Now:         $(if ($InstallUpdatesNow) { 'Triggered' } else { 'No' })" -ForegroundColor Cyan
    Write-Host "  Auto Restart:        $RestartIfRequired" -ForegroundColor Cyan
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
