<#
.SYNOPSIS
  Reverses Windows Server 2019 RDS optimizations applied by ws2019-rds-optimization.ps1.

.DESCRIPTION
  This script provides the ability to selectively reverse optimizations made by the main
  optimization script. Useful for troubleshooting or adjusting the optimization level.

.PARAMETER RestoreServices
  List of services to restore to their original startup type.

.PARAMETER RestoreLocalDrives
  Restore visibility of local drives to users.

.PARAMETER RestoreServerManager
  Re-enable automatic startup of Server Manager.

.PARAMETER RestoreScheduledTasks
  List of scheduled tasks to re-enable.

.PARAMETER RestoreRDSSettings
  Restore RDS license server and profile configurations to defaults.

.PARAMETER DryRun
  Preview changes without applying them.

.EXAMPLE
  .\ws2019-rds-optimization-restore.ps1 -RestoreLocalDrives -RestoreServerManager

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: PowerShell 5.1 or later

    Script Name   : ws2019-rds-optimization-restore.ps1
    Tested On     : Windows Server 2019 (Build 17763+)

.LINK
    https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds-roles

.COMPONENT
    Windows PowerShell Server Management
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "List of services to restore to their original startup type.")][string[]]$RestoreServices = @(),
    [Parameter(HelpMessage = "Restore visibility of local drives to users.")][switch]$RestoreLocalDrives,
    [Parameter(HelpMessage = "Re-enable automatic startup of Server Manager.")][switch]$RestoreServerManager,
    [Parameter(HelpMessage = "List of scheduled tasks to re-enable.")][string[]]$RestoreScheduledTasks = @(),
    [Parameter(HelpMessage = "Restore RDS license server and profile configurations to defaults.")][switch]$RestoreRDSSettings,
    [Parameter(HelpMessage = "Preview changes without applying them.")][switch]$DryRun = $false
)

$ErrorActionPreference = 'Stop'

# ===========================
# LOGGING AND HELPER FUNCTIONS
# ===========================

$LogFile = Join-Path $env:TEMP "WS2019-RDS-Restore-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'INFO'    { Write-Host $logEntry -ForegroundColor Cyan }
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
        'WARNING' { Write-Host $logEntry -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logEntry -ForegroundColor Red }
    }

    Add-Content -Path $LogFile -Value $logEntry -Force
}

function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Remove-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Description = ''
    )

    try {
        if ($DryRun) {
            Write-Log "DRY-RUN: Would remove registry $Path\$Name ($Description)" 'INFO'
            return
        }

        if (Test-Path $Path) {
            Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            Write-Log "Removed registry: $Path\$Name ($Description)" 'SUCCESS'
        }
    } catch {
        Write-Log "Failed to remove registry $Path\$Name : $_" 'ERROR'
    }
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [Microsoft.Win32.RegistryValueKind]$Type = 'DWord',
        [string]$Description = ''
    )

    try {
        if ($DryRun) {
            Write-Log "DRY-RUN: Would set registry $Path\$Name = $Value ($Description)" 'INFO'
            return
        }

        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        Write-Log "Set registry: $Path\$Name = $Value ($Description)" 'SUCCESS'
    } catch {
        Write-Log "Failed to set registry $Path\$Name : $_" 'ERROR'
    }
}

# ===========================
# RESTORATION FUNCTIONS
# ===========================

function Restore-Services {
    Write-Log "Restoring specified services..." 'INFO'

    if ($RestoreServices.Count -eq 0) {
        Write-Log "No services specified for restoration" 'WARNING'
        return
    }

    foreach ($serviceName in $RestoreServices) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if (-not $service) {
                Write-Log "Service not found: $serviceName (skipping)" 'WARNING'
                continue
            }

            $currentStartType = $service.StartType
            $currentStatus = $service.Status

            if ($DryRun) {
                if ($service.StartType -eq 'Disabled') {
                    Write-Log "DRY-RUN: Would restore service: $serviceName to Manual (Current: $currentStartType, Status: $currentStatus)" 'INFO'
                } else {
                    Write-Log "DRY-RUN: Service already enabled: $serviceName (StartType: $currentStartType, Status: $currentStatus)" 'INFO'
                }
                continue
            }

            # Skip if not disabled
            if ($service.StartType -ne 'Disabled') {
                Write-Log "Service already enabled: $serviceName (StartType: $currentStartType, Status: $currentStatus)" 'SUCCESS'
                continue
            }

            # Restore to Manual startup (safest default)
            Set-Service -Name $serviceName -StartupType Manual -ErrorAction Stop
            Write-Log "Restored service: $serviceName to Manual (was: $currentStartType)" 'SUCCESS'
        } catch {
            Write-Log "Failed to restore service $serviceName : $_" 'ERROR'
        }
    }
}

function Restore-UserInterface {
    Write-Log "Restoring UI settings..." 'INFO'

    if ($RestoreServerManager) {
        Remove-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\ServerManager' -Name 'DoNotOpenServerManagerAtLogon' -Description 'Re-enable Server Manager auto-start'
        Remove-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\ServerManager\Oobe' -Name 'DoNotOpenInitialConfigurationTasksAtLogon' -Description 'Re-enable initial configuration tasks'
    }

    if ($RestoreLocalDrives) {
        Remove-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDrives' -Description 'Restore local drive visibility'
        Remove-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoViewOnDrive' -Description 'Restore local drive access'
    }
}

function Restore-ScheduledTasks {
    Write-Log "Restoring specified scheduled tasks..." 'INFO'

    if ($RestoreScheduledTasks.Count -eq 0) {
        Write-Log "No scheduled tasks specified for restoration" 'WARNING'
        return
    }

    foreach ($taskPath in $RestoreScheduledTasks) {
        try {
            # Parse task path similar to main script
            $task = $null
            $taskName = ''
            $taskPathOnly = ''

            if ($taskPath.Contains('\')) {
                $lastSlash = $taskPath.LastIndexOf('\')
                $taskPathOnly = $taskPath.Substring(0, $lastSlash + 1)
                $taskName = $taskPath.Substring($lastSlash + 1)
            } else {
                $taskName = $taskPath
                $taskPathOnly = '\'
            }

            # Try to get the task
            try {
                $task = Get-ScheduledTask -TaskPath $taskPathOnly -TaskName $taskName -ErrorAction SilentlyContinue
            } catch {
                $task = Get-ScheduledTask | Where-Object { ($_.TaskPath + $_.TaskName) -eq $taskPath }
            }

            if (-not $task) {
                Write-Log "Scheduled task not found: $taskPath (skipping)" 'WARNING'
                continue
            }

            $currentState = $task.State

            if ($DryRun) {
                if ($task.State -eq 'Disabled') {
                    Write-Log "DRY-RUN: Would enable scheduled task: $taskPath (Current state: $currentState)" 'INFO'
                } else {
                    Write-Log "DRY-RUN: Scheduled task already enabled: $taskPath (State: $currentState)" 'INFO'
                }
                continue
            }

            # Skip if not disabled
            if ($task.State -ne 'Disabled') {
                Write-Log "Scheduled task already enabled: $taskPath (State: $currentState)" 'SUCCESS'
                continue
            }

            Enable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null
            Write-Log "Enabled scheduled task: $taskPath (was: $currentState)" 'SUCCESS'
        } catch {
            Write-Log "Failed to enable scheduled task $taskPath : $_" 'ERROR'
        }
    }
}

function Restore-RDSConfiguration {
    Write-Log "Restoring RDS license server and profile configurations..." 'INFO'

    if (-not $RestoreRDSSettings) {
        Write-Log "RDS settings restoration not requested" 'INFO'
        return
    }

    # RDS License Server settings
    $rdsLicenseKeys = @(
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Services\TermService\Parameters\LicenseServers'; Name='SpecifiedLicenseServers'; Description='Clear RDS License Server'},
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Services\TermService\Parameters'; Name='LicensingMode'; Description='Reset RDS Licensing Mode'},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name='LicenseServers'; Description='Clear policy license server'},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name='LicensingMode'; Description='Clear policy licensing mode'}
    )

    foreach ($keyInfo in $rdsLicenseKeys) {
        Remove-RegistryValue -Path $keyInfo.Path -Name $keyInfo.Name -Description $keyInfo.Description
    }

    # User Profile settings
    $profileKeys = @(
        @{Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'; Name='DefaultUserProfile'; Description='Reset default user profile path'},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name='fEnableUPD'; Description='Disable User Profile Disks'},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name='UPDPath'; Description='Clear UPD path'},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name='UPDMaxSize'; Description='Clear UPD max size'},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name='UPDExcludeList'; Description='Clear UPD exclusion list'},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name='UPDIncludeList'; Description='Clear UPD inclusion list'}
    )

    foreach ($keyInfo in $profileKeys) {
        Remove-RegistryValue -Path $keyInfo.Path -Name $keyInfo.Name -Description $keyInfo.Description
    }

    Write-Log "RDS configuration restoration completed" 'SUCCESS'
}

# ===========================
# MAIN EXECUTION
# ===========================

function Start-Restoration {
    Write-Log "Starting Windows Server 2019 RDS optimization restoration..." 'INFO'
    Write-Log "Log file: $LogFile" 'INFO'

    if ($DryRun) {
        Write-Log "RUNNING IN DRY-RUN MODE - No changes will be applied" 'WARNING'
    }

    if (-not (Test-IsAdmin)) {
        throw "This script must be run as Administrator"
    }

    try {
        Restore-Services
        Restore-UserInterface
        Restore-ScheduledTasks
        Restore-RDSConfiguration

        Write-Log "Restoration completed successfully!" 'SUCCESS'

    } catch {
        Write-Log "Restoration failed: $_" 'ERROR'
        throw
    }
}

# ===========================
# EXECUTION
# ===========================

try {
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "Windows Server 2019 RDS Optimization Restoration" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host ""

    Start-Restoration

    Write-Host ""
    Write-Host "Restoration complete. Log saved to: $LogFile" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
