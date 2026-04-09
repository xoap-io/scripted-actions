<#
.SYNOPSIS
    Apply CIS Windows Server 2019/2022 baseline hardening settings.

.DESCRIPTION
    Applies security hardening controls based on the CIS Microsoft Windows Server
    Benchmark. Covers account lockout policy, password complexity, audit policy,
    SMBv1 disablement, NTLMv2 enforcement, RDP security hardening, Windows Firewall
    profile configuration, and disabling unnecessary services. Level 1 controls are
    universally recommended; Level 2 controls provide deeper hardening for environments
    that tolerate reduced functionality.

.PARAMETER Profile
    CIS hardening profile to apply: Level1 (recommended) or Level2 (higher security).
    Default is Level1.

.PARAMETER WhatIf
    Show which settings would be changed without actually applying them.

.PARAMETER BackupCurrentSettings
    Export a snapshot of current relevant settings to a JSON file before making changes.

.PARAMETER Force
    Skip the confirmation prompt before applying changes.

.EXAMPLE
    .\ps-harden-windows-server.ps1 -Profile Level1 -BackupCurrentSettings

.EXAMPLE
    .\ps-harden-windows-server.ps1 -Profile Level2 -Force -WhatIf

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: PowerShell 5.1+; must be run as Administrator; based on CIS Windows Server Benchmark

.LINK
    https://www.cisecurity.org/benchmark/microsoft_windows_server

.COMPONENT
    Windows PowerShell Server Management
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "CIS hardening profile to apply: Level1 or Level2.")]
    [ValidateSet('Level1', 'Level2')]
    [string]$Profile = 'Level1',

    [Parameter(Mandatory = $false, HelpMessage = "Show changes without applying them.")]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false, HelpMessage = "Export current settings to JSON before making changes.")]
    [switch]$BackupCurrentSettings,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompt before applying changes.")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Must run as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must be run as Administrator."
}

function Set-RegValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord', [switch]$Simulate)
    if ($Simulate) {
        Write-Host "  [WhatIf] Set '$Path\$Name' = $Value ($Type)" -ForegroundColor Yellow
        return
    }
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}

function Invoke-SeceditChange {
    param([string]$Setting, [string]$Value, [switch]$Simulate)
    if ($Simulate) {
        Write-Host "  [WhatIf] secedit: $Setting = $Value" -ForegroundColor Yellow
        return
    }
    $tmpInf = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.inf'
    $tmpDb  = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.sdb'
    @"
[Unicode]
Unicode=yes
[System Access]
$Setting = $Value
[Version]
signature="`$CHICAGO`$"
Revision=1
"@ | Set-Content -Path $tmpInf -Encoding Unicode
    secedit /configure /db $tmpDb /cfg $tmpInf /quiet | Out-Null
    Remove-Item $tmpInf, $tmpDb -Force -ErrorAction SilentlyContinue
}

try {
    Write-Host "🚀 Starting CIS Windows Server Hardening (Profile: $Profile)" -ForegroundColor Green

    if ($WhatIf) {
        Write-Host "⚠️  WhatIf mode active — no changes will be applied." -ForegroundColor Yellow
    }

    # Backup current settings
    if ($BackupCurrentSettings -and -not $WhatIf) {
        $backupFile = ".\harden-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        Write-Host "🔧 Backing up current settings to $backupFile..." -ForegroundColor Cyan
        $backup = @{
            Timestamp   = (Get-Date -Format 'o')
            ComputerName = $env:COMPUTERNAME
            SMBv1       = (Get-WindowsOptionalFeature -Online -FeatureName 'SMB1Protocol' -ErrorAction SilentlyContinue)?.State
            WinFirewall = (Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction)
            Services    = (Get-Service | Where-Object { $_.StartType -ne 'Disabled' } | Select-Object Name, StartType, Status)
        }
        $backup | ConvertTo-Json -Depth 5 | Set-Content -Path $backupFile
        Write-Host "✅ Backup saved: $backupFile" -ForegroundColor Green
    }

    # Confirm unless -Force or -WhatIf
    if (-not $Force -and -not $WhatIf) {
        $confirm = Read-Host "Apply CIS $Profile hardening to $env:COMPUTERNAME? (yes/no)"
        if ($confirm -notmatch '^(yes|y)$') {
            Write-Host "⚠️  Hardening cancelled by user." -ForegroundColor Yellow
            return
        }
    }

    # ---- LEVEL 1 CONTROLS ----
    Write-Host "`n🔧 Applying CIS Level 1 controls..." -ForegroundColor Cyan

    # Account lockout policy
    Write-Host "  🔧 Account lockout policy..." -ForegroundColor Cyan
    Invoke-SeceditChange -Setting 'LockoutBadCount'         -Value 5  -Simulate:$WhatIf
    Invoke-SeceditChange -Setting 'LockoutDuration'         -Value 15 -Simulate:$WhatIf
    Invoke-SeceditChange -Setting 'ResetLockoutCount'       -Value 15 -Simulate:$WhatIf

    # Password policy
    Write-Host "  🔧 Password complexity and age..." -ForegroundColor Cyan
    Invoke-SeceditChange -Setting 'PasswordComplexity'      -Value 1  -Simulate:$WhatIf
    Invoke-SeceditChange -Setting 'MinimumPasswordLength'   -Value 14 -Simulate:$WhatIf
    Invoke-SeceditChange -Setting 'MaximumPasswordAge'      -Value 60 -Simulate:$WhatIf
    Invoke-SeceditChange -Setting 'MinimumPasswordAge'      -Value 1  -Simulate:$WhatIf
    Invoke-SeceditChange -Setting 'PasswordHistorySize'     -Value 24 -Simulate:$WhatIf

    # Disable SMBv1
    Write-Host "  🔧 Disabling SMBv1..." -ForegroundColor Cyan
    if (-not $WhatIf) {
        Disable-WindowsOptionalFeature -Online -FeatureName 'SMB1Protocol' -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "  [WhatIf] Disable-WindowsOptionalFeature SMB1Protocol" -ForegroundColor Yellow
    }
    Write-Host "  ✅ SMBv1 disabled." -ForegroundColor Green

    # Enforce NTLMv2
    Write-Host "  🔧 Enforcing NTLMv2 (LAN Manager authentication level = 5)..." -ForegroundColor Cyan
    Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'LmCompatibilityLevel' -Value 5 -Simulate:$WhatIf

    # RDP security: require NLA and high encryption
    Write-Host "  🔧 Hardening RDP security..." -ForegroundColor Cyan
    Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'UserAuthentication'   -Value 1 -Simulate:$WhatIf
    Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'MinEncryptionLevel'  -Value 3 -Simulate:$WhatIf
    Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'SecurityLayer'       -Value 2 -Simulate:$WhatIf

    # Enable Windows Firewall on all profiles
    Write-Host "  🔧 Enabling Windows Firewall on all profiles..." -ForegroundColor Cyan
    if (-not $WhatIf) {
        Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True
    } else {
        Write-Host "  [WhatIf] Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True" -ForegroundColor Yellow
    }
    Write-Host "  ✅ Firewall enabled on all profiles." -ForegroundColor Green

    # Audit policy — enable success and failure for key categories
    Write-Host "  🔧 Configuring audit policy..." -ForegroundColor Cyan
    $auditCategories = @(
        'Account Logon', 'Account Management', 'Logon/Logoff',
        'Policy Change', 'Privilege Use', 'System'
    )
    foreach ($cat in $auditCategories) {
        if (-not $WhatIf) {
            auditpol /set /category:"$cat" /success:enable /failure:enable | Out-Null
        } else {
            Write-Host "  [WhatIf] auditpol /set /category:'$cat' /success:enable /failure:enable" -ForegroundColor Yellow
        }
    }
    Write-Host "  ✅ Audit policy configured." -ForegroundColor Green

    # Disable unnecessary services (Level 1)
    $level1Services = @('Browser', 'IISADMIN', 'RemoteRegistry')
    Write-Host "  🔧 Disabling unnecessary services (Level 1): $($level1Services -join ', ')..." -ForegroundColor Cyan
    foreach ($svc in $level1Services) {
        if (-not $WhatIf) {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s) {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            }
        } else {
            Write-Host "  [WhatIf] Disable-Service $svc" -ForegroundColor Yellow
        }
    }
    Write-Host "  ✅ Level 1 services disabled." -ForegroundColor Green

    # ---- LEVEL 2 CONTROLS ----
    if ($Profile -eq 'Level2') {
        Write-Host "`n🔧 Applying CIS Level 2 controls..." -ForegroundColor Cyan

        # Disable additional services
        $level2Services = @('Fax', 'PrintSpooler', 'TelnetClient', 'SNMP', 'XblGameSave', 'WMPNetworkSvc')
        Write-Host "  🔧 Disabling additional services (Level 2): $($level2Services -join ', ')..." -ForegroundColor Cyan
        foreach ($svc in $level2Services) {
            if (-not $WhatIf) {
                $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
                if ($s) {
                    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
                }
            } else {
                Write-Host "  [WhatIf] Disable-Service $svc" -ForegroundColor Yellow
            }
        }

        # Restrict anonymous access
        Write-Host "  🔧 Restricting anonymous access..." -ForegroundColor Cyan
        Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RestrictAnonymous'      -Value 1 -Simulate:$WhatIf
        Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RestrictAnonymousSAM'   -Value 1 -Simulate:$WhatIf
        Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'EveryoneIncludesAnonymous' -Value 0 -Simulate:$WhatIf

        # Disable autoplay/autorun
        Write-Host "  🔧 Disabling AutoPlay and AutoRun..." -ForegroundColor Cyan
        Set-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDriveTypeAutoRun' -Value 255 -Simulate:$WhatIf
        Set-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoAutorun'          -Value 1   -Simulate:$WhatIf

        Write-Host "  ✅ Level 2 controls applied." -ForegroundColor Green
    }

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  Profile applied:    $Profile" -ForegroundColor Cyan
    Write-Host "  WhatIf mode:        $WhatIf" -ForegroundColor Cyan
    Write-Host "  Backup created:     $BackupCurrentSettings" -ForegroundColor Cyan
    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "  - Review audit policy with: auditpol /get /category:*" -ForegroundColor Yellow
    Write-Host "  - Test application compatibility before deploying to production." -ForegroundColor Yellow
    Write-Host "  - Schedule a restart to complete SMBv1 disablement if prompted." -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
