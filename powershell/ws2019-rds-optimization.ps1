<#
.SYNOPSIS
  Optimizes Windows Server 2019 for Remote Desktop Services (RDS) multi-user environments.

.DESCRIPTION
  This script performs comprehensive optimizations for Windows Server 2019 running in an RDS environment.
  Includes UI optimizations, service management, registry tweaks, scheduled task management, and security
  enhancements specifically designed for multi-user remote desktop scenarios.

.PARAMETER DisableServices
  List of additional services to disable beyond the default set.

.PARAMETER KeepServices
  List of services to keep enabled (overrides default disable list).

.PARAMETER HideLocalDrives
  Hide local drives from users in Explorer.

.PARAMETER DisableServerManager
  Disable automatic startup of Server Manager.

.PARAMETER EnableVerboseLogging
  Enable detailed logging of all operations.

.PARAMETER PersistentDriveLetter
  Drive letter for persistent storage (PVS/MCS scenarios).

.PARAMETER EventLogLocation
  Custom location for event logs (use with PersistentDriveLetter).

.PARAMETER RDSLicenseServer
  FQDN of the RDS License Server to configure in registry.

.PARAMETER RDSLicenseMode
  RDS licensing mode: 'PerUser', 'PerDevice', or 'NotConfigured'.

.PARAMETER UserProfilePath
  UNC path for roaming user profiles (e.g., \\server\profiles$).

.PARAMETER UserProfileDiskPath
  UNC path for User Profile Disks (e.g., \\server\upd$).

.PARAMETER ProfileDiskMaxSizeGB
  Maximum size in GB for User Profile Disks (1-1000).

.PARAMETER DryRun
  Preview changes without applying them.

.EXAMPLE
  .\ws2019-rds-optimization.ps1
  Runs with default optimizations (hides drives and disables Server Manager)

.EXAMPLE
  .\ws2019-rds-optimization.ps1 -HideLocalDrives -DisableServerManager -EnableVerboseLogging
  Explicitly enables drive hiding, Server Manager disabling, and verbose logging

.EXAMPLE
  .\ws2019-rds-optimization.ps1 -PersistentDriveLetter D -EventLogLocation "D:\EventLogs" -DryRun
  Preview mode with persistent drive configuration

.EXAMPLE
  .\ws2019-rds-optimization.ps1 -RDSLicenseServer "rds-lic.domain.com" -RDSLicenseMode "PerUser"
  Configure RDS licensing server and mode

.EXAMPLE
  .\ws2019-rds-optimization.ps1 -UserProfilePath "\\fileserver\profiles$" -UserProfileDiskPath "\\fileserver\upd$" -ProfileDiskMaxSizeGB 20
  Configure user profile settings with roaming profiles and UPD

.NOTES
  Script Name   : ws2019-rds-optimization.ps1
  Author        : Generated for RDS Optimization
  Tested On     : Windows Server 2019 (Build 17763+)

  IMPORTANT:
  - Run as Administrator
  - Take system backup/snapshot before running
  - Review all optimizations for your environment
  - Some optimizations may require reboot
#>

[CmdletBinding()]
param(
    [string[]]$DisableServices = @(),
    [string[]]$KeepServices = @(),
    [switch]$HideLocalDrives,
    [switch]$DisableServerManager,
    [switch]$EnableVerboseLogging,
    [ValidatePattern('^[A-Z]$')][string]$PersistentDriveLetter = '',
    [string]$EventLogLocation = '',
    [ValidatePattern('^[a-zA-Z0-9.-]+$')][string]$RDSLicenseServer = '',
    [ValidateSet('PerUser','PerDevice','NotConfigured')][string]$RDSLicenseMode = 'NotConfigured',
    [ValidatePattern('^\\\\[a-zA-Z0-9.-]+\\[a-zA-Z0-9\$._-]+$')][string]$UserProfilePath = '',
    [ValidatePattern('^\\\\[a-zA-Z0-9.-]+\\[a-zA-Z0-9\$._-]+$')][string]$UserProfileDiskPath = '',
    [ValidateRange(1,1000)][int]$ProfileDiskMaxSizeGB = 30,
    [switch]$DryRun = $false
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($EnableVerboseLogging) { 'Continue' } else { 'SilentlyContinue' }

# ===========================
# LOGGING AND HELPER FUNCTIONS
# ===========================

$LogFile = Join-Path $env:TEMP "WS2019-RDS-Optimization-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$RebootRequired = $false

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

function Test-RDSConfiguration {
    Write-Log "Validating RDS and profile configuration parameters..." 'INFO'

    $configValid = $true

    # Validate RDS License Server accessibility
    if ($RDSLicenseServer) {
        Write-Log "Testing RDS License Server connectivity: $RDSLicenseServer" 'INFO'
        try {
            $testConnection = Test-NetConnection -ComputerName $RDSLicenseServer -Port 135 -WarningAction SilentlyContinue -ErrorAction Stop
            if ($testConnection.TcpTestSucceeded) {
                Write-Log "RDS License Server is accessible: $RDSLicenseServer" 'SUCCESS'
            } else {
                Write-Log "RDS License Server may not be accessible: $RDSLicenseServer (Port 135 test failed)" 'WARNING'
            }
        } catch {
            Write-Log "Could not test RDS License Server connectivity: $RDSLicenseServer ($_)" 'WARNING'
        }

        if ($DryRun) {
            Write-Log "DRY-RUN: Would configure RDS License Server: $RDSLicenseServer, Mode: $RDSLicenseMode" 'INFO'
        }
    }

    # Validate profile paths
    if ($UserProfilePath) {
        Write-Log "Validating roaming profile path: $UserProfilePath" 'INFO'
        try {
            if (Test-Path $UserProfilePath -ErrorAction SilentlyContinue) {
                Write-Log "Roaming profile path is accessible: $UserProfilePath" 'SUCCESS'
            } else {
                Write-Log "Roaming profile path not accessible (may need to be created): $UserProfilePath" 'WARNING'
                $configValid = $false
            }
        } catch {
            Write-Log "Could not test roaming profile path: $UserProfilePath ($_)" 'WARNING'
        }

        if ($DryRun) {
            Write-Log "DRY-RUN: Would configure roaming profiles to: $UserProfilePath" 'INFO'
        }
    }

    if ($UserProfileDiskPath) {
        Write-Log "Validating User Profile Disk path: $UserProfileDiskPath" 'INFO'
        try {
            if (Test-Path $UserProfileDiskPath -ErrorAction SilentlyContinue) {
                Write-Log "User Profile Disk path is accessible: $UserProfileDiskPath" 'SUCCESS'
            } else {
                Write-Log "User Profile Disk path not accessible (may need to be created): $UserProfileDiskPath" 'WARNING'
                $configValid = $false
            }
        } catch {
            Write-Log "Could not test User Profile Disk path: $UserProfileDiskPath ($_)" 'WARNING'
        }

        if ($DryRun) {
            Write-Log "DRY-RUN: Would configure UPD to: $UserProfileDiskPath (Max size: $ProfileDiskMaxSizeGB GB)" 'INFO'
        }
    }

    # Check for conflicting profile configurations
    if ($UserProfilePath -and $UserProfileDiskPath) {
        Write-Log "WARNING: Both roaming profiles and UPD are configured. UPD will take precedence." 'WARNING'
    }

    # Validate RDS role installation
    try {
        $rdsRole = Get-WindowsFeature -Name 'RDS-RD-Server' -ErrorAction SilentlyContinue
        if ($rdsRole -and $rdsRole.InstallState -eq 'Installed') {
            Write-Log "RDS Session Host role is installed" 'SUCCESS'
        } else {
            Write-Log "RDS Session Host role is not installed - some RDS optimizations may not apply" 'WARNING'
        }
    } catch {
        Write-Log "Could not check RDS Session Host role installation status" 'WARNING'
    }

    return $configValid
}

function Test-WindowsFeature {
    param(
        [string]$FeatureName,
        [string]$Action = 'check'  # 'check', 'remove'
    )

    try {
        $feature = Get-WindowsFeature -Name $FeatureName -ErrorAction SilentlyContinue
        if (-not $feature) {
            Write-Log "Windows Feature not found: $FeatureName (skipping)" 'WARNING'
            return $false
        }

        $currentState = $feature.InstallState

        if ($Action -eq 'remove') {
            if ($DryRun) {
                if ($feature.InstallState -eq 'Installed') {
                    Write-Log "DRY-RUN: Would remove Windows Feature: $FeatureName (Current state: $currentState)" 'INFO'
                } else {
                    Write-Log "DRY-RUN: Windows Feature already removed: $FeatureName (State: $currentState)" 'INFO'
                }
                return $true
            }

            # Skip if already removed
            if ($feature.InstallState -ne 'Installed') {
                Write-Log "Windows Feature already removed: $FeatureName (State: $currentState)" 'SUCCESS'
                return $true
            }

            Remove-WindowsFeature -Name $FeatureName -ErrorAction Stop
            Write-Log "Removed Windows Feature: $FeatureName (was: $currentState)" 'SUCCESS'
            return $true
        }

        return $feature.InstallState -eq 'Installed'
    } catch {
        Write-Log "Failed to process Windows Feature $FeatureName : $_" 'ERROR'
        return $false
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
        # Check current value
        $currentValue = $null
        $pathExists = Test-Path $Path
        if ($pathExists) {
            try {
                $currentValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Name -ErrorAction SilentlyContinue
            } catch {
                $currentValue = '<not set>'
            }
        } else {
            $currentValue = '<path does not exist>'
        }

        if ($DryRun) {
            Write-Log "DRY-RUN: Would set registry $Path\$Name = $Value (Current: $currentValue) ($Description)" 'INFO'
            return
        }

        # Skip if value is already set correctly
        if ($pathExists -and $currentValue -eq $Value) {
            Write-Log "Registry already set: $Path\$Name = $Value ($Description)" 'SUCCESS'
            return
        }

        if (-not $pathExists) {
            New-Item -Path $Path -Force | Out-Null
        }

        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        Write-Log "Set registry: $Path\$Name = $Value (was: $currentValue) ($Description)" 'SUCCESS'
    } catch {
        Write-Log "Failed to set registry $Path\$Name : $_" 'ERROR'
    }
}

function Remove-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Description = ''
    )

    try {
        # Check if registry path and value exist
        $pathExists = Test-Path $Path
        $currentValue = '<not found>'

        if ($pathExists) {
            try {
                $currentValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Name -ErrorAction SilentlyContinue
                if ($null -eq $currentValue) {
                    $currentValue = '<not set>'
                }
            } catch {
                $currentValue = '<not set>'
            }
        }

        if ($DryRun) {
            Write-Log "DRY-RUN: Would remove registry $Path\$Name (Current: $currentValue) ($Description)" 'INFO'
            return
        }

        # Skip if value doesn't exist
        if (-not $pathExists -or $currentValue -eq '<not set>') {
            Write-Log "Registry value already absent: $Path\$Name ($Description)" 'SUCCESS'
            return
        }

        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        Write-Log "Removed registry: $Path\$Name (was: $currentValue) ($Description)" 'SUCCESS'
    } catch {
        Write-Log "Failed to remove registry $Path\$Name : $_" 'ERROR'
    }
}

# ===========================
# SYSTEM CHECKS
# ===========================

function Test-SystemRequirements {
    Write-Log "Performing system requirement checks..." 'INFO'

    if (-not (Test-IsAdmin)) {
        throw "This script must be run as Administrator"
    }

    $osVersion = Get-WmiObject -Class Win32_OperatingSystem
    $buildNumber = [int]$osVersion.BuildNumber

    if ($buildNumber -lt 17763) {
        throw "This script requires Windows Server 2019 (Build 17763) or later. Current: $buildNumber"
    }

    Write-Log "System check passed: Windows Server 2019 Build $buildNumber" 'SUCCESS'
}

function Test-SystemResources {
    Write-Log "Validating system resources availability..." 'INFO'

    $resourceCounts = @{
        ServicesFound = 0
        ServicesMissing = 0
        TasksFound = 0
        TasksMissing = 0
        FeaturesFound = 0
        FeaturesMissing = 0
    }

    # Check services
    $defaultDisableServices = @(
        'AJRouter',
        'ALG',
        'AppMgmt',
        'BITS',
        'bthserv',
        'DcpSvc',
        'defragsvc',
        'DiagTrack',
        'dmwappushservice',
        'DPS',
        'EFS',
        'Eaphost',
        'FDResPub',
        'lfsvc',
        'MapsBroker',
        'MSiSCSI',
        'NcaSvc',
        'NcbService',
        'PcaSvc',
        'QWAVE',
        'RasMan',
        'RmSvc',
        'SensorDataService',
        'SensorService',
        'SensrSvc',
        'SharedAccess',
        'SNMPTRAP',
        'SSDPSRV',
        'SstpSvc',
        'SysMain',
        'TieringEngineService',
        'TapiSrv',
        'UI0Detect',
        'UALSVC',
        'Wcmsvc',
        'WdiServiceHost',
        'WdiSystemHost',
        'WerSvc',
        'wisvc',
        'wlidsvc',
        'wuauserv',
        'XblAuthManager',
        'XblGameSave'
    )

    $servicesToCheck = $defaultDisableServices + $DisableServices | Where-Object { $_ -notin $KeepServices }

    Write-Log "Checking $($servicesToCheck.Count) services..." 'INFO'
    foreach ($serviceName in $servicesToCheck) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            $resourceCounts.ServicesFound++
            Write-Verbose "Service found: $serviceName (Status: $($service.Status), StartType: $($service.StartType))"
        } else {
            $resourceCounts.ServicesMissing++
            Write-Verbose "Service not found: $serviceName"
        }
    }

    # Check scheduled tasks (sample)
    $sampleTasks = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Defrag\ScheduledDefrag',
        '\Microsoft\Windows\WindowsUpdate\Automatic App Update'
    )

    Write-Log "Checking sample scheduled tasks..." 'INFO'
    foreach ($taskPath in $sampleTasks) {
        try {
            $task = Get-ScheduledTask | Where-Object { ($_.TaskPath + $_.TaskName) -eq $taskPath } | Select-Object -First 1
            if ($task) {
                $resourceCounts.TasksFound++
                Write-Verbose "Task found: $taskPath (State: $($task.State))"
            } else {
                $resourceCounts.TasksMissing++
                Write-Verbose "Task not found: $taskPath"
            }
        } catch {
            $resourceCounts.TasksMissing++
            Write-Verbose "Task check failed: $taskPath"
        }
    }

    # Check key Windows Features
    $featuresToCheck = @('Windows-Defender-Features')
    Write-Log "Checking Windows Features..." 'INFO'
    foreach ($featureName in $featuresToCheck) {
        try {
            $feature = Get-WindowsFeature -Name $featureName -ErrorAction SilentlyContinue
            if ($feature) {
                $resourceCounts.FeaturesFound++
                Write-Verbose "Feature found: $featureName (State: $($feature.InstallState))"
            } else {
                $resourceCounts.FeaturesMissing++
                Write-Verbose "Feature not found: $featureName"
            }
        } catch {
            $resourceCounts.FeaturesMissing++
            Write-Verbose "Feature check failed: $featureName"
        }
    }

    # Report findings
    Write-Log "Resource validation complete:" 'SUCCESS'
    Write-Log "  Services: $($resourceCounts.ServicesFound) found, $($resourceCounts.ServicesMissing) missing" 'INFO'
    Write-Log "  Tasks: $($resourceCounts.TasksFound) found, $($resourceCounts.TasksMissing) missing" 'INFO'
    Write-Log "  Features: $($resourceCounts.FeaturesFound) found, $($resourceCounts.FeaturesMissing) missing" 'INFO'

    if ($resourceCounts.ServicesMissing -gt ($servicesToCheck.Count / 2)) {
        Write-Log "WARNING: Many services are missing. This may not be a standard Windows Server 2019 installation." 'WARNING'
    }

    return $resourceCounts
}

# ===========================
# SERVICE OPTIMIZATION
# ===========================

function Optimize-Services {
    Write-Log "Optimizing Windows services for RDS environment..." 'INFO'

    # Default services to disable for RDS optimization
    $defaultDisableServices = @(
        'AJRouter',                   # AllJoyn Router Service
        'ALG',                        # Application Layer Gateway Service
        'AppMgmt',                    # Application Management
        'BITS',                       # Background Intelligent Transfer Service
        'bthserv',                    # Bluetooth Support Service
        'DcpSvc',                     # DataCollectionPublishingService
        'defragsvc',                  # Optimize drives
        'DiagTrack',                  # Connected User Experiences and Telemetry
        'dmwappushservice',           # dmwappushsvc
        'DPS',                        # Diagnostic Policy Service
        'EFS',                        # Encrypting File System
        'Eaphost',                    # Extensible Authentication Protocol
        'FDResPub',                   # Function Discovery Resource Publication
        'lfsvc',                      # Geolocation Service
        'MapsBroker',                 # Downloaded Maps Manager
        'MSiSCSI',                    # Microsoft iSCSI Initiator Service
        'NcaSvc',                     # Network Connectivity Assistant
        'NcbService',                 # Network Connection Broker
        'PcaSvc',                     # Program Compatibility Assistant Service
        'QWAVE',                      # Quality Windows Audio Video Experience
        'RasMan',                     # Remote Access Connection Manager
        'RmSvc',                      # Radio Management Service
        'SensorDataService',          # Sensor Data Service
        'SensorService',              # Sensor Service
        'SensrSvc',                   # Sensor Monitoring Service
        'SharedAccess',               # Internet Connection Sharing (ICS)
        'SNMPTRAP',                   # SNMP Trap
        'SSDPSRV',                    # SSDP Discovery
        'SstpSvc',                    # Secure Socket Tunneling Protocol Service
        'SysMain',                    # Superfetch
        'TieringEngineService',       # Storage Tiers Management
        'TapiSrv',                    # Telephony
        'UI0Detect',                  # Interactive Services Detection
        'UALSVC',                     # User Access Logging Service
        'Wcmsvc',                     # Windows Connection Manager
        'WdiServiceHost',             # Diagnostic Service Host
        'WdiSystemHost',              # Diagnostic System Host
        'WerSvc',                     # Windows Error Reporting Service
        'wisvc',                      # Windows Insider Service
        'wlidsvc',                    # Microsoft Account Sign-in Assistant
        'wuauserv',                   # Windows Update
        'XblAuthManager',             # Xbox Live Auth Manager
        'XblGameSave'                 # Xbox Live Game Save
    )

    # Combine default and additional services to disable
    $servicesToDisable = $defaultDisableServices + $DisableServices | Where-Object { $_ -notin $KeepServices }

    foreach ($serviceName in $servicesToDisable) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if (-not $service) {
                Write-Log "Service not found: $serviceName (skipping)" 'WARNING'
                continue
            }

            $currentStatus = $service.Status
            $currentStartType = $service.StartType

            if ($DryRun) {
                if ($service.StartType -ne 'Disabled') {
                    Write-Log "DRY-RUN: Would disable service: $serviceName (Current: $currentStartType, Status: $currentStatus)" 'INFO'
                } else {
                    Write-Log "DRY-RUN: Service already disabled: $serviceName (Status: $currentStatus)" 'INFO'
                }
                continue
            }

            # Skip if already disabled
            if ($service.StartType -eq 'Disabled') {
                Write-Log "Service already disabled: $serviceName (Status: $currentStatus)" 'SUCCESS'
                continue
            }

            Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
            if ($service.Status -eq 'Running') {
                Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            }
            Write-Log "Disabled service: $serviceName (was: $currentStartType, Status was: $currentStatus)" 'SUCCESS'
        } catch {
            Write-Log "Failed to disable service $serviceName : $_" 'ERROR'
        }
    }
}

# ===========================
# SCHEDULED TASK OPTIMIZATION
# ===========================

function Optimize-ScheduledTasks {
    Write-Log "Disabling unnecessary scheduled tasks..." 'INFO'

    $tasksToDisable = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
        '\Microsoft\Windows\Application Experience\StartupAppTask',
        '\Microsoft\Windows\ApplicationData\CleanupTemporaryState',
        '\Microsoft\Windows\ApplicationData\DsSvcCleanup',
        '\Microsoft\Windows\Autochk\Proxy',
        '\Microsoft\Windows\Bluetooth\UninstallDeviceTask',
        '\Microsoft\Windows\CertificateServicesClient\AikCertEnrollTask',
        '\Microsoft\Windows\CertificateServicesClient\CryptoPolicyTask',
        '\Microsoft\Windows\CertificateServicesClient\KeyPreGenTask',
        '\Microsoft\Windows\CloudExperienceHost\CreateObjectTask',
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
        '\Microsoft\Windows\Data Integrity Scan\Data Integrity Scan',
        '\Microsoft\Windows\Data Integrity Scan\Data Integrity Scan for Crash Recovery',
        '\Microsoft\Windows\Defrag\ScheduledDefrag',
        '\Microsoft\Windows\Device Information\Device',
        '\Microsoft\Windows\Diagnosis\Scheduled',
        '\Microsoft\Windows\DiskCleanup\SilentCleanup',
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
        '\Microsoft\Windows\Location\Notifications',
        '\Microsoft\Windows\Location\WindowsActionDialog',
        '\Microsoft\Windows\Maintenance\WinSAT',
        '\Microsoft\Windows\Maps\MapsToastTask',
        '\Microsoft\Windows\Mobile Broadband Accounts\MNO Metadata Parser',
        '\Microsoft\Windows\MUI\LPRemove',
        '\Microsoft\Windows\NetTrace\GatherNetworkInfo',
        '\Microsoft\Windows\PI\Secure-Boot-Update',
        '\Microsoft\Windows\PI\Sqm-Tasks',
        '\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem',
        '\Microsoft\Windows\Ras\MobilityManager',
        '\Microsoft\Windows\RecoveryEnvironment\VerifyWinRE',
        '\Microsoft\Windows\Registry\RegIdleBackup',
        '\Microsoft\Windows\Server Manager\CleanupOldPerfLogs',
        '\Microsoft\Windows\Servicing\StartComponentCleanup',
        '\Microsoft\Windows\Shell\IndexerAutomaticMaintenance',
        '\Microsoft\Windows\Software Inventory Logging\Configuration',
        '\Microsoft\Windows\Speech\SpeechModelDownloadTask',
        '\Microsoft\Windows\Storage Tiers Management\Storage Tiers Management Initialization',
        '\Microsoft\Windows\TPM\Tpm-HASCertRetr',
        '\Microsoft\Windows\TPM\Tpm-Maintenance',
        '\Microsoft\Windows\UpdateOrchestrator\Schedule Scan',
        '\Microsoft\Windows\WDI\ResolutionHost',
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting',
        '\Microsoft\Windows\Windows Filtering Platform\BfeOnServiceStartTypeChange',
        '\Microsoft\Windows\WindowsUpdate\Automatic App Update',
        '\Microsoft\Windows\WindowsUpdate\Scheduled Start',
        '\Microsoft\Windows\WindowsUpdate\sih',
        '\Microsoft\Windows\WindowsUpdate\sihboot'
    )

    foreach ($taskPath in $tasksToDisable) {
        try {
            # Try to find the task using a more flexible approach
            $task = $null
            $taskName = ''
            $taskPathOnly = ''

            # Parse the full task path
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
                # If specific path fails, try broader search
                $task = Get-ScheduledTask | Where-Object { ($_.TaskPath + $_.TaskName) -eq $taskPath }
            }

            if (-not $task) {
                Write-Log "Scheduled task not found: $taskPath (skipping)" 'WARNING'
                continue
            }

            $currentState = $task.State

            if ($DryRun) {
                if ($task.State -ne 'Disabled') {
                    Write-Log "DRY-RUN: Would disable scheduled task: $taskPath (Current state: $currentState)" 'INFO'
                } else {
                    Write-Log "DRY-RUN: Scheduled task already disabled: $taskPath (State: $currentState)" 'INFO'
                }
                continue
            }

            # Skip if already disabled
            if ($task.State -eq 'Disabled') {
                Write-Log "Scheduled task already disabled: $taskPath (State: $currentState)" 'SUCCESS'
                continue
            }

            Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null
            Write-Log "Disabled scheduled task: $taskPath (was: $currentState)" 'SUCCESS'
        } catch {
            Write-Log "Failed to disable scheduled task $taskPath : $_" 'ERROR'
        }
    }
}

# ===========================
# UI AND PERFORMANCE OPTIMIZATIONS
# ===========================

function Optimize-UserInterface {
    Write-Log "Applying UI and performance optimizations..." 'INFO'

    # Hide Server Manager at startup (default behavior unless explicitly disabled)
    if ($DisableServerManager -or (-not $PSBoundParameters.ContainsKey('DisableServerManager'))) {
        Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\ServerManager' -Name 'DoNotOpenServerManagerAtLogon' -Value 1 -Description 'Disable Server Manager auto-start'
        Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\ServerManager\Oobe' -Name 'DoNotOpenInitialConfigurationTasksAtLogon' -Value 1 -Description 'Disable initial configuration tasks'
    }

    # Hide local drives from users (default behavior unless explicitly disabled)
    if ($HideLocalDrives -or (-not $PSBoundParameters.ContainsKey('HideLocalDrives'))) {
        Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDrives' -Value 67108863 -Description 'Hide local drives A-Z except network drives'
        Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoViewOnDrive' -Value 67108863 -Description 'Prevent viewing local drives'
    }

    # Action Center and notification optimizations
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'HideSCAHealth' -Value 1 -Description 'Hide Action Center icon'
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter' -Value 1 -Description 'Disable notification center'

    # Performance optimizations
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'DisablePagingExecutive' -Value 1 -Description 'Keep drivers and kernel in physical memory'
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'ClearPageFileAtShutdown' -Value 0 -Description 'Disable clear page file at shutdown'

    # Disable Windows Search indexing for better performance
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowIndexingEncryptedStoresOrItems' -Value 0 -Description 'Disable search indexing'
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows Search' -Name 'EnablePerUserCatalog' -Value 0 -Description 'Disable per-user search catalog'

    # Disable Windows Defender real-time protection for VDI (if appropriate)
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name 'DisableRealtimeMonitoring' -Value 1 -Description 'Disable Windows Defender real-time monitoring'

    # Power management optimizations
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled' -Value 0 -Description 'Disable hibernation'
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel\NameSpace\{025A5937-A6BE-4686-A844-36FE4BEC8B6D}' -Name 'PreferredPlan' -Value '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' -Type String -Description 'Set High Performance power plan'

    # Network optimizations
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'TcpAckFrequency' -Value 1 -Description 'TCP ACK frequency optimization'
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'TCPNoDelay' -Value 1 -Description 'Disable TCP Nagle algorithm'

    # Visual effects optimizations
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 2 -Description 'Optimize visual effects for performance'

    # Disable logon background image
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'DisableLogonBackgroundImage' -Value 1 -Description 'Disable logon background image'

    # Crash dump optimizations
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name 'CrashDumpEnabled' -Value 0 -Description 'Disable crash dumps'
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name 'LogEvent' -Value 0 -Description 'Disable crash logging to event log'
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name 'SendAlert' -Value 0 -Description 'Disable administrative alert during crash'

    # Services timeout optimization
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'ServicesPipeTimeout' -Value 45000 -Description 'Increase services startup timeout to 45 seconds'

    # Error reporting optimizations
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Windows' -Name 'ErrorMode' -Value 2 -Description 'Hide hard error messages'
}

# ===========================
# EVENT LOG OPTIMIZATION
# ===========================

function Optimize-EventLogs {
    Write-Log "Optimizing event log settings..." 'INFO'

    $eventLogs = @('Application', 'Security', 'System')

    foreach ($logName in $eventLogs) {
        try {
            # Check current event log size
            $currentSize = $null
            $currentLocation = $null

            try {
                $logKey = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\$logName"
                if (Test-Path $logKey) {
                    $currentSize = Get-ItemProperty -Path $logKey -Name 'MaxSize' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty 'MaxSize' -ErrorAction SilentlyContinue
                    $currentLocation = Get-ItemProperty -Path $logKey -Name 'File' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty 'File' -ErrorAction SilentlyContinue

                    if ($null -eq $currentSize) { $currentSize = '<not set>' }
                    if ($null -eq $currentLocation) { $currentLocation = '<default>' }
                }
            } catch {
                $currentSize = '<error reading>'
                $currentLocation = '<error reading>'
            }

            if ($DryRun) {
                Write-Log "DRY-RUN: Would set $logName event log MaxSize to 65536 (Current: $currentSize)" 'INFO'
                if ($PersistentDriveLetter -and $EventLogLocation) {
                    $logPath = "$EventLogLocation\$logName.evtx"
                    Write-Log "DRY-RUN: Would move $logName event log to $logPath (Current: $currentLocation)" 'INFO'
                }
                continue
            }

            # Reduce event log sizes
            Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\$logName" -Name 'MaxSize' -Value 65536 -Description "Reduce $logName event log size to 64KB"

            # Configure event log location if persistent drive is specified
            if ($PersistentDriveLetter -and $EventLogLocation) {
                $logPath = "$EventLogLocation\$logName.evtx"
                Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\$logName" -Name 'File' -Value $logPath -Type ExpandString -Description "Move $logName event log to persistent drive"
            }
        } catch {
            Write-Log "Failed to optimize $logName event log: $_" 'ERROR'
        }
    }
}

# ===========================
# INTERNET EXPLORER OPTIMIZATION
# ===========================

function Optimize-InternetExplorer {
    Write-Log "Optimizing Internet Explorer settings..." 'INFO'

    # Disable IE first-run customization wizard
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main' -Name 'DisableFirstRunCustomize' -Value 1 -Description 'Disable IE first-run wizard'

    # Optimize IE temporary files
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Cache\Paths' -Name 'Paths' -Value 4 -Description 'Set IE temp file paths'

    for ($i = 1; $i -le 4; $i++) {
        Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Cache\Paths\path$i" -Name 'CacheLimit' -Value 256 -Description "Set IE temp file cache limit for path$i"
    }

    # Remove Active Setup entries to speed up logon
    $activeSetupEntries = @(
        '{2C7339CF-2B09-4501-B3F3-F3508C9228ED}',  # Themes Setup
        '{44BBA840-CC51-11CF-AAFA-00AA00B6015C}',  # WinMail
        '{6BF52A52-394A-11d3-B153-00C04F79FAA6}',  # Windows Media Player
        '{89820200-ECBD-11cf-8B85-00AA005B4340}',  # Windows Desktop Update
        '{89820200-ECBD-11cf-8B85-00AA005B4383}',  # Web Platform Customizations
        '{89B4C1CD-B018-4511-B0A1-5476DBF70820}',  # DotNetFrameworks
        '>{22d6f312-b0f6-11d0-94ab-0080c74c7e95}', # Windows Media Player
        '{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}',  # IE ESC for Admins
        '{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}'   # IE ESC for Users
    )

    foreach ($entry in $activeSetupEntries) {
        Remove-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\$entry" -Name 'StubPath' -Description "Remove Active Setup entry $entry"
        Remove-RegistryValue -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components\$entry" -Name 'StubPath' -Description "Remove Active Setup entry $entry (WOW6432)"
    }
}

# ===========================
# WINDOWS UPDATE OPTIMIZATION
# ===========================

function Optimize-WindowsUpdate {
    Write-Log "Configuring Windows Update settings for RDS..." 'INFO'

    # Disable automatic Windows updates in RDS environment
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'NoAutoUpdate' -Value 1 -Description 'Disable Windows Auto Update'
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'AUOptions' -Value 1 -Description 'Set Windows Update to notify only'
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'ScheduleInstallDay' -Value 0 -Description 'Disable scheduled installation'
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'ScheduleInstallTime' -Value 3 -Description 'Set installation time to 3 AM if needed'

    # Disable Windows Update delivery optimization
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' -Name 'DODownloadMode' -Value 0 -Description 'Disable delivery optimization'
}

# ===========================
# TELEMETRY AND PRIVACY
# ===========================

function Optimize-TelemetryAndPrivacy {
    Write-Log "Disabling telemetry and privacy-invasive features..." 'INFO'

    # Disable telemetry
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -Description 'Disable telemetry'
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Name 'AllowTelemetry' -Value 0 -Description 'Disable telemetry (secondary location)'

    # Disable offline files
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\NetCache' -Name 'Enabled' -Value 0 -Description 'Disable offline files'

    # Disable background layout service
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OptimalLayout' -Name 'EnableAutoLayout' -Value 0 -Description 'Disable background layout service'

    # Disable automatic defragmentation
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction' -Name 'Enable' -Value 'N' -Type String -Description 'Disable defrag'

    # Disable change notify events for better performance
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoRemoteRecursiveEvents' -Value 1 -Description 'Turn off change notify events'
}

# ===========================
# RDS-SPECIFIC OPTIMIZATIONS
# ===========================

function Optimize-RDSSpecific {
    Write-Log "Applying RDS-specific optimizations..." 'INFO'

    # Optimize RDS session settings
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'KeepAliveEnable' -Value 1 -Description 'Enable RDS keep-alive'
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'KeepAliveInterval' -Value 1 -Description 'Set RDS keep-alive interval'

    # Optimize printer redirection
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Wds\rdpwd' -Name 'MaxInstanceCount' -Value 50 -Description 'Increase max RDS instances'

    # Disable RDS printer auto-creation delay
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'RedirectionGUIDisabled' -Value 1 -Description 'Disable printer redirection GUI'

    # Configure RDS License Server if specified
    if ($RDSLicenseServer) {
        Write-Log "Configuring RDS License Server: $RDSLicenseServer" 'INFO'

        # Set license server
        Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\TermService\Parameters\LicenseServers' -Name 'SpecifiedLicenseServers' -Value $RDSLicenseServer -Type String -Description "Set RDS License Server to $RDSLicenseServer"

        # Set licensing mode if specified
        if ($RDSLicenseMode -ne 'NotConfigured') {
            $licenseMode = switch ($RDSLicenseMode) {
                'PerUser' { 4 }
                'PerDevice' { 2 }
                default { 0 }
            }
            Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\TermService\Parameters' -Name 'LicensingMode' -Value $licenseMode -Description "Set RDS licensing mode to $RDSLicenseMode"
        }

        # Configure license discovery
        Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'LicenseServers' -Value $RDSLicenseServer -Type String -Description 'Set license server for discovery'
        Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'LicensingMode' -Value $RDSLicenseMode -Type String -Description "Set policy licensing mode to $RDSLicenseMode"
    } else {
        # Clear cached license servers if not specified
        Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\TermService\Parameters\LicenseServers' -Name 'SpecifiedLicenseServers' -Value '' -Type String -Description 'Clear specified license servers'
    }

    # Set RDS user limit (unlimited)
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'MaxInstanceCount' -Value 4294967295 -Description 'Set RDS max concurrent sessions to unlimited'

    # Disable RDS camera redirection (security)
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'fDisableCameraRedir' -Value 1 -Description 'Disable camera redirection'

    # Optimize RDS timeouts
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'MaxIdleTime' -Value 0 -Description 'Disable idle timeout'
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'MaxDisconnectionTime' -Value 0 -Description 'Disable disconnection timeout'

    # Configure User Profiles if specified
    if ($UserProfilePath -or $UserProfileDiskPath) {
        Write-Log "Configuring RDS user profile settings..." 'INFO'

        if ($UserProfilePath) {
            Write-Log "Setting roaming profiles path: $UserProfilePath" 'INFO'

            # Enable roaming profiles
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -Name 'DefaultUserProfile' -Value $UserProfilePath -Type String -Description "Set default roaming profile path"

            # Configure profile settings
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'SlowLinkProfileDefault' -Value 0 -Description 'Disable slow link detection for profiles'
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'WaitForNetworkBeforeUserProfile' -Value 1 -Description 'Wait for network before loading user profile'

            # RDS-specific roaming profile settings
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'fTempFoldersPerSession' -Value 1 -Description 'Use temp folders per session'
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'DeleteTempDirsOnExit' -Value 1 -Description 'Delete temp directories on exit'
        }

        if ($UserProfileDiskPath) {
            Write-Log "Setting User Profile Disk path: $UserProfileDiskPath (Max size: $ProfileDiskMaxSizeGB GB)" 'INFO'

            # Configure UPD settings
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'fEnableUPD' -Value 1 -Description 'Enable User Profile Disks'
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'UPDPath' -Value $UserProfileDiskPath -Type String -Description "Set UPD path to $UserProfileDiskPath"
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'UPDMaxSize' -Value ($ProfileDiskMaxSizeGB * 1024) -Description "Set UPD max size to $ProfileDiskMaxSizeGB GB"

            # UPD optimization settings
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'UPDExcludeList' -Value "AppData\Local;AppData\LocalLow;$Recycle.Bin;System Volume Information" -Type String -Description 'Set UPD exclusion list'
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'UPDIncludeList' -Value "*" -Type String -Description 'Set UPD inclusion list to all'

            # Disable roaming profiles when UPD is used
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'fTempFoldersPerSession' -Value 1 -Description 'Use temp folders per session with UPD'
        }

        # Common profile optimizations for RDS
        Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'VerboseStatus' -Value 0 -Description 'Disable verbose status messages during logon'
        Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'DelayedDesktopSwitchTimeout' -Value 0 -Description 'Disable delayed desktop switch timeout'
    }
}

# ===========================
# SECURITY OPTIMIZATIONS
# ===========================

function Optimize-Security {
    Write-Log "Applying security optimizations for multi-user environment..." 'INFO'

    # Disable machine account password changes
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' -Name 'DisablePasswordChange' -Value 1 -Description 'Disable machine account password changes'

    # Restrict CD/DVD access
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AllocateCDRoms' -Value 0 -Description 'Restrict CD/DVD access to console user only'

    # Restrict floppy access (legacy)
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AllocateFloppies' -Value 0 -Description 'Restrict floppy access to console user only'

    # Disable USB storage for regular users
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR' -Name 'Start' -Value 4 -Description 'Disable USB storage service'

    # Enhance audit policy
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value 1 -Description 'Enable command line auditing'
}

# ===========================
# MAIN EXECUTION
# ===========================

function Start-Optimization {
    Write-Log "Starting Windows Server 2019 RDS optimization..." 'INFO'
    Write-Log "Log file: $LogFile" 'INFO'

    if ($DryRun) {
        Write-Log "RUNNING IN DRY-RUN MODE - No changes will be applied" 'WARNING'
    }

    try {
        # System checks
        Test-SystemRequirements

        # Resource validation
        $resourceValidation = Test-SystemResources

        # RDS and profile configuration validation
        if ($RDSLicenseServer -or $UserProfilePath -or $UserProfileDiskPath) {
            $rdsConfigValid = Test-RDSConfiguration
            if (-not $rdsConfigValid -and -not $DryRun) {
                Write-Log "WARNING: Some RDS/profile paths are not accessible. Continuing with optimization..." 'WARNING'
            }
        }

        if ($DryRun) {
            Write-Log "Dry-run mode: Showing what would be changed with current values..." 'INFO'
        }

        # Main optimization functions
        Optimize-Services
        Optimize-ScheduledTasks
        Optimize-UserInterface
        Optimize-EventLogs
        Optimize-InternetExplorer
        Optimize-WindowsUpdate
        Optimize-TelemetryAndPrivacy
        Optimize-RDSSpecific
        Optimize-Security

        Write-Log "Optimization completed successfully!" 'SUCCESS'

        if ($DryRun) {
            Write-Log "This was a dry-run. No actual changes were made to the system." 'INFO'
            Write-Log "Re-run without -DryRun to apply these changes." 'INFO'
        } else {
            if ($RebootRequired) {
                Write-Log "A system reboot is recommended to complete the optimization." 'WARNING'
            }
        }

        return $resourceValidation

    } catch {
        Write-Log "Optimization failed: $_" 'ERROR'
        throw
    }
}

# ===========================
# EXECUTION
# ===========================

Write-Host "=============================================" -ForegroundColor Green
Write-Host "Windows Server 2019 RDS Optimization Script" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""

$validationResults = Start-Optimization

Write-Host ""
Write-Host "Optimization complete. Log saved to: $LogFile" -ForegroundColor Green

if ($DryRun) {
    Write-Host ""
    Write-Host "=== DRY-RUN SUMMARY ===" -ForegroundColor Cyan
    Write-Host "This was a preview run showing current values and proposed changes." -ForegroundColor White
    Write-Host "Services found: $($validationResults.ServicesFound), missing: $($validationResults.ServicesMissing)" -ForegroundColor White
    Write-Host "Tasks found: $($validationResults.TasksFound), missing: $($validationResults.TasksMissing)" -ForegroundColor White
    Write-Host "Features found: $($validationResults.FeaturesFound), missing: $($validationResults.FeaturesMissing)" -ForegroundColor White
    Write-Host ""
    Write-Host "To apply these changes, re-run the script without -DryRun parameter." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Recommended next steps:" -ForegroundColor Yellow
    Write-Host "1. Review the log file for any errors or warnings" -ForegroundColor White
    Write-Host "2. Test the RDS environment thoroughly" -ForegroundColor White
    Write-Host "3. Consider a reboot to complete all optimizations" -ForegroundColor White
    Write-Host "4. Monitor system performance and adjust as needed" -ForegroundColor White
}
Write-Host ""
