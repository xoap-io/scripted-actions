<#
.SYNOPSIS
    Manages Windows updates on VMs in vSphere using PowerCLI and PowerShell remoting.

.DESCRIPTION
    This script provides comprehensive Windows update management for VMs including
    update scanning, installation, reboot management, and reporting. Supports
    single VMs, multiple VMs, and batch operations with safety checks.
    Requires VMware PowerCLI, PowerShell remoting, and appropriate credentials.

.PARAMETER VCenterServer
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER VMName
    The name of the virtual machine. Supports wildcards.

.PARAMETER VMNames
    An array of specific VM names for batch operations.

.PARAMETER ClusterName
    Target all Windows VMs in a specific cluster.

.PARAMETER ResourcePoolName
    Target all Windows VMs in a specific resource pool.

.PARAMETER Operation
    The Windows update operation to perform.

.PARAMETER UpdateCategory
    Categories of updates to install.

.PARAMETER ExcludeDrivers
    Exclude driver updates from installation.

.PARAMETER ExcludePreview
    Exclude preview updates from installation.

.PARAMETER AutoReboot
    Automatically reboot VMs after update installation if required.

.PARAMETER RebootTimeout
    Timeout in minutes to wait for reboot completion (default: 15).

.PARAMETER CreateSnapshot
    Create a snapshot before installing updates (recommended).

.PARAMETER SnapshotName
    Name for the snapshot (if CreateSnapshot is used).

.PARAMETER Credential
    PowerShell credential object for VM authentication.

.PARAMETER Username
    Username for VM authentication (alternative to Credential).

.PARAMETER Password
    Password for VM authentication (alternative to Credential).

.PARAMETER MaxConcurrency
    Maximum number of VMs to process concurrently (default: 5).

.PARAMETER WaitBetweenVMs
    Wait time in seconds between processing VMs (default: 30).

.PARAMETER UpdateSource
    Windows Update source to use.

.PARAMETER IncludeOptional
    Include optional updates in installation.

.PARAMETER Force
    Force operations without confirmation prompts.

.PARAMETER OutputFormat
    Output format for reports.

.PARAMETER OutputPath
    Path to save the report file (optional).

.EXAMPLE
    .\vsphere-cli-windows-updates.ps1 -VCenterServer "vcenter.domain.com" -VMName "WebServer01" -Operation "Scan" -Username "Administrator" -Password "Password123"

.EXAMPLE
    .\vsphere-cli-windows-updates.ps1 -VCenterServer "vcenter.domain.com" -VMNames @("Web01","Web02") -Operation "Install" -UpdateCategory @("Security","Critical") -AutoReboot -CreateSnapshot -Username ".\admin"

.EXAMPLE
    .\vsphere-cli-windows-updates.ps1 -VCenterServer "vcenter.domain.com" -ClusterName "Production" -Operation "InstallAndReboot" -ExcludeDrivers -CreateSnapshot -MaxConcurrency 3

.EXAMPLE
    .\vsphere-cli-windows-updates.ps1 -VCenterServer "vcenter.domain.com" -Operation "Report" -OutputFormat "CSV" -OutputPath "windows-updates-report.csv"

.NOTES
    Author: Generated for scripted-actions
    Requires: VMware PowerCLI 13.x or later, PowerShell 5.1+, PSWindowsUpdate module on target VMs
    Dependencies: Windows VMs must have PowerShell remoting enabled and PSWindowsUpdate module installed
    Version: 1.0
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VCenterServer,

    [Parameter(Mandatory = $false, ParameterSetName = "SingleVM")]
    [ValidateNotNullOrEmpty()]
    [string]$VMName,

    [Parameter(Mandatory = $false, ParameterSetName = "MultipleVMs")]
    [ValidateNotNullOrEmpty()]
    [string[]]$VMNames,

    [Parameter(Mandatory = $false)]
    [string]$ClusterName,

    [Parameter(Mandatory = $false)]
    [string]$ResourcePoolName,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Scan", "Install", "InstallAndReboot", "Report", "CheckRebootRequired", "InstallModule", "GetHistory")]
    [string]$Operation,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Security", "Critical", "Important", "Moderate", "Low", "Unspecified", "Definition")]
    [string[]]$UpdateCategory = @("Security", "Critical", "Important"),

    [Parameter(Mandatory = $false)]
    [switch]$ExcludeDrivers,

    [Parameter(Mandatory = $false)]
    [switch]$ExcludePreview,

    [Parameter(Mandatory = $false)]
    [switch]$AutoReboot,

    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 60)]
    [int]$RebootTimeout = 15,

    [Parameter(Mandatory = $false)]
    [switch]$CreateSnapshot,

    [Parameter(Mandatory = $false)]
    [string]$SnapshotName,

    [Parameter(Mandatory = $false)]
    [PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [SecureString]$Password,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$MaxConcurrency = 5,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 300)]
    [int]$WaitBetweenVMs = 30,

    [Parameter(Mandatory = $false)]
    [ValidateSet("WindowsUpdate", "MicrosoftUpdate", "WSUS", "Store")]
    [string]$UpdateSource = "MicrosoftUpdate",

    [Parameter(Mandatory = $false)]
    [switch]$IncludeOptional,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "CSV", "JSON")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to check and install PowerCLI if needed
function Test-PowerCLIInstallation {
    Write-Host "Checking PowerCLI installation..." -ForegroundColor Yellow
    
    try {
        $powerCLIModule = Get-Module -Name VMware.PowerCLI -ListAvailable
        if (-not $powerCLIModule) {
            Write-Warning "VMware PowerCLI not found. Installing..."
            Install-Module -Name VMware.PowerCLI -Force -AllowClobber -Scope CurrentUser
            Write-Host "PowerCLI installed successfully." -ForegroundColor Green
        } else {
            $version = $powerCLIModule | Sort-Object Version -Descending | Select-Object -First 1
            Write-Host "PowerCLI version $($version.Version) found." -ForegroundColor Green
        }
        
        # Import the module
        Import-Module VMware.PowerCLI -Force
        
        # Disable certificate warnings for lab environments
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope User | Out-Null
        Set-PowerCLIConfiguration -ParticipateInCEIP $false -Confirm:$false -Scope User | Out-Null
        
        return $true
    }
    catch {
        Write-Error "Failed to install or import PowerCLI: $($_.Exception.Message)"
        return $false
    }
}

# Function to connect to vCenter
function Connect-ToVCenter {
    param($Server)
    
    try {
        Write-Host "Connecting to vCenter Server: $Server" -ForegroundColor Yellow
        
        # Check if already connected
        $connection = $global:DefaultVIServers | Where-Object { $_.Name -eq $Server -and $_.IsConnected }
        if ($connection) {
            Write-Host "Already connected to $Server" -ForegroundColor Green
            return $connection
        }
        
        # Connect to vCenter (will prompt for credentials if not cached)
        $connection = Connect-VIServer -Server $Server -Force
        Write-Host "Successfully connected to vCenter: $($connection.Name)" -ForegroundColor Green
        return $connection
    }
    catch {
        Write-Error "Failed to connect to vCenter Server $Server`: $($_.Exception.Message)"
        throw
    }
}

# Function to create credential object
function Get-VMCredential {
    param(
        $Credential,
        $Username,
        $Password
    )
    
    if ($Credential) {
        return $Credential
    }
    elseif ($Username) {
        if ($Password) {
            return New-Object System.Management.Automation.PSCredential($Username, $Password)
        } else {
            return Get-Credential -UserName $Username -Message "Enter password for VM authentication"
        }
    }
    else {
        return Get-Credential -Message "Enter credentials for VM authentication"
    }
}

# Function to get target Windows VMs
function Get-TargetWindowsVMs {
    param(
        $VMName,
        $VMNames,
        $ClusterName,
        $ResourcePoolName
    )
    
    Write-Host "Identifying target Windows VMs..." -ForegroundColor Yellow
    
    try {
        $allVMs = @()
        
        if ($VMName) {
            # Single VM or wildcard pattern
            $allVMs = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        }
        elseif ($VMNames) {
            # Multiple specific VMs
            foreach ($name in $VMNames) {
                $vm = Get-VM -Name $name -ErrorAction SilentlyContinue
                if ($vm) {
                    $allVMs += $vm
                } else {
                    Write-Warning "VM '$name' not found"
                }
            }
        }
        elseif ($ClusterName) {
            # All VMs in cluster
            $cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
            if (-not $cluster) {
                throw "Cluster '$ClusterName' not found"
            }
            $allVMs = Get-VM -Location $cluster
        }
        elseif ($ResourcePoolName) {
            # All VMs in resource pool
            $resourcePool = Get-ResourcePool -Name $ResourcePoolName -ErrorAction SilentlyContinue
            if (-not $resourcePool) {
                throw "Resource pool '$ResourcePoolName' not found"
            }
            $allVMs = Get-VM -Location $resourcePool
        }
        else {
            # All VMs (use with caution)
            $allVMs = Get-VM
        }
        
        # Filter for Windows VMs that are powered on
        $windowsVMs = $allVMs | Where-Object { 
            $_.PowerState -eq "PoweredOn" -and 
            $_.Guest.OSFullName -match "Windows" 
        }
        
        if (-not $windowsVMs) {
            throw "No Windows VMs found matching the specified criteria (must be powered on)"
        }
        
        Write-Host "Found $($windowsVMs.Count) Windows VM(s) matching criteria:" -ForegroundColor Green
        foreach ($vm in $windowsVMs) {
            $toolsStatus = if ($vm.ExtensionData.Guest.ToolsStatus) { $vm.ExtensionData.Guest.ToolsStatus } else { "Unknown" }
            Write-Host "  - $($vm.Name) [$($vm.Guest.OSFullName)] [Tools: $toolsStatus]" -ForegroundColor White
        }
        
        return $windowsVMs
    }
    catch {
        Write-Error "Failed to get target Windows VMs: $($_.Exception.Message)"
        throw
    }
}

# Function to test VM connectivity
function Test-VMConnectivity {
    param(
        $VM,
        $Credential
    )
    
    try {
        $vmIP = $VM.Guest.IPAddress | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+" } | Select-Object -First 1
        
        if (-not $vmIP) {
            return @{
                Success = $false
                Message = "No IP address found"
                IP = $null
                PSRemoting = $false
            }
        }
        
        # Test basic connectivity
        $pingResult = Test-Connection -ComputerName $vmIP -Count 1 -Quiet
        if (-not $pingResult) {
            return @{
                Success = $false
                Message = "VM not reachable via ping"
                IP = $vmIP
                PSRemoting = $false
            }
        }
        
        # Test PowerShell remoting
        try {
            $session = New-PSSession -ComputerName $vmIP -Credential $Credential -ErrorAction Stop
            Remove-PSSession -Session $session
            
            return @{
                Success = $true
                Message = "VM connectivity verified"
                IP = $vmIP
                PSRemoting = $true
            }
        }
        catch {
            return @{
                Success = $false
                Message = "PowerShell remoting failed: $($_.Exception.Message)"
                IP = $vmIP
                PSRemoting = $false
            }
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Connectivity test failed: $($_.Exception.Message)"
            IP = $null
            PSRemoting = $false
        }
    }
}

# Function to install PSWindowsUpdate module on VM
function Install-PSWindowsUpdateModule {
    param(
        $VM,
        $Credential
    )
    
    try {
        Write-Host "    Installing PSWindowsUpdate module..." -ForegroundColor Gray
        
        $vmIP = $VM.Guest.IPAddress | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+" } | Select-Object -First 1
        
        $installScript = {
            try {
                # Check if module is already installed
                $module = Get-Module -Name PSWindowsUpdate -ListAvailable
                if ($module) {
                    return @{
                        Success = $true
                        Message = "PSWindowsUpdate module already installed (version $($module.Version))"
                        AlreadyInstalled = $true
                    }
                }
                
                # Install the module
                Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Scope AllUsers
                Import-Module PSWindowsUpdate -Force
                
                # Verify installation
                $installedModule = Get-Module -Name PSWindowsUpdate -ListAvailable
                if ($installedModule) {
                    return @{
                        Success = $true
                        Message = "PSWindowsUpdate module installed successfully (version $($installedModule.Version))"
                        AlreadyInstalled = $false
                    }
                } else {
                    return @{
                        Success = $false
                        Message = "Failed to verify PSWindowsUpdate module installation"
                        AlreadyInstalled = $false
                    }
                }
            }
            catch {
                return @{
                    Success = $false
                    Message = "Error installing PSWindowsUpdate module: $($_.Exception.Message)"
                    AlreadyInstalled = $false
                }
            }
        }
        
        $result = Invoke-Command -ComputerName $vmIP -Credential $Credential -ScriptBlock $installScript
        
        if ($result.Success) {
            Write-Host "    ✓ $($result.Message)" -ForegroundColor Green
        } else {
            Write-Warning "    $($result.Message)"
        }
        
        return $result
    }
    catch {
        $errorMessage = "Failed to install PSWindowsUpdate module: $($_.Exception.Message)"
        Write-Warning "    $errorMessage"
        return @{
            Success = $false
            Message = $errorMessage
            AlreadyInstalled = $false
        }
    }
}

# Function to scan for Windows updates
function Get-WindowsUpdates {
    param(
        $VM,
        $Credential,
        $UpdateCategory,
        $ExcludeDrivers,
        $ExcludePreview,
        $UpdateSource
    )
    
    try {
        Write-Host "    Scanning for Windows updates..." -ForegroundColor Gray
        
        $vmIP = $VM.Guest.IPAddress | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+" } | Select-Object -First 1
        
        $scanScript = {
            param($Categories, $ExcludeDrivers, $ExcludePreview, $Source)
            
            try {
                Import-Module PSWindowsUpdate -Force
                
                # Build parameters for Get-WindowsUpdate
                $params = @{
                    MicrosoftUpdate = ($Source -eq "MicrosoftUpdate")
                    WindowsUpdate = ($Source -eq "WindowsUpdate")
                }
                
                # Add category filter if specified
                if ($Categories -and $Categories.Count -gt 0) {
                    $params.Category = $Categories
                }
                
                # Get available updates
                $updates = Get-WindowsUpdate @params
                
                # Apply filters
                if ($ExcludeDrivers) {
                    $updates = $updates | Where-Object { $_.Categories -notmatch "Driver" }
                }
                
                if ($ExcludePreview) {
                    $updates = $updates | Where-Object { $_.Title -notmatch "Preview" }
                }
                
                $updateInfo = @()
                foreach ($update in $updates) {
                    $updateInfo += @{
                        Title = $update.Title
                        KB = $update.KB
                        Size = $update.Size
                        Categories = ($update.Categories -join ", ")
                        Severity = $update.MsrcSeverity
                        RebootRequired = $update.RebootRequired
                        IsDownloaded = $update.IsDownloaded
                    }
                }
                
                return @{
                    Success = $true
                    Updates = $updateInfo
                    Count = $updates.Count
                    TotalSize = ($updates | Measure-Object -Property Size -Sum).Sum
                    CriticalCount = ($updates | Where-Object { $_.MsrcSeverity -eq "Critical" }).Count
                    SecurityCount = ($updates | Where-Object { $_.Categories -match "Security" }).Count
                }
            }
            catch {
                return @{
                    Success = $false
                    Message = "Error scanning for updates: $($_.Exception.Message)"
                    Updates = @()
                    Count = 0
                }
            }
        }
        
        $result = Invoke-Command -ComputerName $vmIP -Credential $Credential -ScriptBlock $scanScript -ArgumentList $UpdateCategory, $ExcludeDrivers, $ExcludePreview, $UpdateSource
        
        if ($result.Success) {
            Write-Host "    ✓ Found $($result.Count) available update(s)" -ForegroundColor Green
            if ($result.Count -gt 0) {
                Write-Host "      Critical: $($result.CriticalCount), Security: $($result.SecurityCount)" -ForegroundColor Gray
                if ($result.TotalSize -gt 0) {
                    $sizeMB = [math]::Round($result.TotalSize / 1MB, 1)
                    Write-Host "      Total size: $sizeMB MB" -ForegroundColor Gray
                }
            }
        } else {
            Write-Warning "    $($result.Message)"
        }
        
        return $result
    }
    catch {
        $errorMessage = "Failed to scan for updates: $($_.Exception.Message)"
        Write-Warning "    $errorMessage"
        return @{
            Success = $false
            Message = $errorMessage
            Updates = @()
            Count = 0
        }
    }
}

# Function to install Windows updates
function Install-WindowsUpdates {
    param(
        $VM,
        $Credential,
        $UpdateCategory,
        $ExcludeDrivers,
        $ExcludePreview,
        $UpdateSource,
        $AutoReboot
    )
    
    try {
        Write-Host "    Installing Windows updates..." -ForegroundColor Gray
        
        $vmIP = $VM.Guest.IPAddress | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+" } | Select-Object -First 1
        
        $installScript = {
            param($Categories, $ExcludeDrivers, $ExcludePreview, $Source, $AutoReboot)
            
            try {
                Import-Module PSWindowsUpdate -Force
                
                # Build parameters for Install-WindowsUpdate
                $params = @{
                    MicrosoftUpdate = ($Source -eq "MicrosoftUpdate")
                    WindowsUpdate = ($Source -eq "WindowsUpdate")
                    AcceptAll = $true
                    AutoReboot = $AutoReboot
                    Verbose = $true
                }
                
                # Add category filter if specified
                if ($Categories -and $Categories.Count -gt 0) {
                    $params.Category = $Categories
                }
                
                # Apply driver filter
                if ($ExcludeDrivers) {
                    $params.NotCategory = "Drivers"
                }
                
                # Get and install updates
                $installResult = Install-WindowsUpdate @params
                
                $installedUpdates = @()
                foreach ($update in $installResult) {
                    $installedUpdates += @{
                        Title = $update.Title
                        KB = $update.KB
                        Size = $update.Size
                        Result = $update.Result
                        RebootRequired = $update.RebootRequired
                    }
                }
                
                # Check if reboot is required
                $rebootRequired = $false
                try {
                    $rebootRequired = (Get-WURebootStatus -Silent).RebootRequired
                } catch {
                    # Fallback check
                    $rebootRequired = $installResult | Where-Object { $_.RebootRequired } | Measure-Object | Select-Object -ExpandProperty Count -gt 0
                }
                
                return @{
                    Success = $true
                    InstalledUpdates = $installedUpdates
                    Count = $installResult.Count
                    RebootRequired = $rebootRequired
                    TotalSize = ($installResult | Measure-Object -Property Size -Sum).Sum
                }
            }
            catch {
                return @{
                    Success = $false
                    Message = "Error installing updates: $($_.Exception.Message)"
                    InstalledUpdates = @()
                    Count = 0
                    RebootRequired = $false
                }
            }
        }
        
        # Start the update installation (this can take a long time)
        $startTime = Get-Date
        $result = Invoke-Command -ComputerName $vmIP -Credential $Credential -ScriptBlock $installScript -ArgumentList $UpdateCategory, $ExcludeDrivers, $ExcludePreview, $UpdateSource, $AutoReboot
        $duration = [math]::Round((Get-Date).Subtract($startTime).TotalMinutes, 1)
        
        if ($result.Success) {
            Write-Host "    ✓ Installed $($result.Count) update(s) [$duration minutes]" -ForegroundColor Green
            if ($result.RebootRequired) {
                Write-Host "      ⚠ Reboot required" -ForegroundColor Yellow
            }
        } else {
            Write-Warning "    $($result.Message)"
        }
        
        return $result
    }
    catch {
        $errorMessage = "Failed to install updates: $($_.Exception.Message)"
        Write-Warning "    $errorMessage"
        return @{
            Success = $false
            Message = $errorMessage
            InstalledUpdates = @()
            Count = 0
            RebootRequired = $false
        }
    }
}

# Function to check reboot status
function Test-RebootRequired {
    param(
        $VM,
        $Credential
    )
    
    try {
        $vmIP = $VM.Guest.IPAddress | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+" } | Select-Object -First 1
        
        $rebootScript = {
            try {
                Import-Module PSWindowsUpdate -Force -ErrorAction SilentlyContinue
                
                # Try PSWindowsUpdate method first
                try {
                    $rebootStatus = Get-WURebootStatus -Silent
                    return @{
                        Success = $true
                        RebootRequired = $rebootStatus.RebootRequired
                        Method = "PSWindowsUpdate"
                        Message = if ($rebootStatus.RebootRequired) { "Reboot required" } else { "No reboot required" }
                    }
                } catch {
                    # Fallback to registry check
                    $regPaths = @(
                        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
                        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
                        "HKLM:\SOFTWARE\Microsoft\Updates\UpdateExeVolatile"
                    )
                    
                    $rebootPending = $false
                    foreach ($path in $regPaths) {
                        if (Test-Path $path) {
                            $rebootPending = $true
                            break
                        }
                    }
                    
                    return @{
                        Success = $true
                        RebootRequired = $rebootPending
                        Method = "Registry"
                        Message = if ($rebootPending) { "Reboot required" } else { "No reboot required" }
                    }
                }
            }
            catch {
                return @{
                    Success = $false
                    Message = "Error checking reboot status: $($_.Exception.Message)"
                    RebootRequired = $false
                }
            }
        }
        
        $result = Invoke-Command -ComputerName $vmIP -Credential $Credential -ScriptBlock $rebootScript
        
        if ($result.Success) {
            $status = if ($result.RebootRequired) { "Required" } else { "Not Required" }
            Write-Host "    Reboot Status: $status [$($result.Method)]" -ForegroundColor $(if ($result.RebootRequired) { "Yellow" } else { "Green" })
        } else {
            Write-Warning "    $($result.Message)"
        }
        
        return $result
    }
    catch {
        $errorMessage = "Failed to check reboot status: $($_.Exception.Message)"
        Write-Warning "    $errorMessage"
        return @{
            Success = $false
            Message = $errorMessage
            RebootRequired = $false
        }
    }
}

# Function to create snapshot before updates
function New-UpdateSnapshot {
    param(
        $VM,
        $SnapshotName
    )
    
    try {
        if (-not $SnapshotName) {
            $SnapshotName = "BeforeUpdates-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        }
        
        Write-Host "    Creating snapshot '$SnapshotName'..." -ForegroundColor Gray
        
        # Check if snapshot already exists
        $existingSnapshot = Get-Snapshot -VM $VM -Name $SnapshotName -ErrorAction SilentlyContinue
        if ($existingSnapshot) {
            Write-Warning "    Snapshot '$SnapshotName' already exists"
            return $existingSnapshot
        }
        
        $snapshot = New-Snapshot -VM $VM -Name $SnapshotName -Description "Auto-created before Windows updates" -Memory:$true -Quiesce:$true
        Write-Host "    ✓ Snapshot created: $($snapshot.Name)" -ForegroundColor Green
        return $snapshot
    }
    catch {
        Write-Warning "    Failed to create snapshot: $($_.Exception.Message)"
        return $null
    }
}

# Function to reboot VM and wait for completion
function Restart-VMAndWait {
    param(
        $VM,
        $Credential,
        $RebootTimeout
    )
    
    try {
        Write-Host "    Rebooting VM and waiting for completion..." -ForegroundColor Gray
        
        # Initiate graceful reboot
        Restart-VMGuest -VM $VM -Confirm:$false
        
        # Wait for VM to start rebooting
        Start-Sleep -Seconds 30
        
        # Wait for VM to come back online
        $timeout = (Get-Date).AddMinutes($RebootTimeout)
        $vmOnline = $false
        
        while ((Get-Date) -lt $timeout -and -not $vmOnline) {
            Start-Sleep -Seconds 15
            
            try {
                # Refresh VM object
                $refreshedVM = Get-VM -Name $VM.Name
                
                # Check if VM tools are responding
                if ($refreshedVM.ExtensionData.Guest.ToolsRunningStatus -eq "guestToolsRunning") {
                    # Test PowerShell connectivity
                    $vmIP = $refreshedVM.Guest.IPAddress | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+" } | Select-Object -First 1
                    if ($vmIP) {
                        try {
                            $testSession = New-PSSession -ComputerName $vmIP -Credential $Credential -ErrorAction Stop
                            Remove-PSSession -Session $testSession
                            $vmOnline = $true
                            Write-Host "    ✓ VM reboot completed successfully" -ForegroundColor Green
                        } catch {
                            # Still waiting for PS remoting
                        }
                    }
                }
            } catch {
                # Still waiting for VM
            }
        }
        
        if (-not $vmOnline) {
            Write-Warning "    VM reboot timed out after $RebootTimeout minutes"
            return @{
                Success = $false
                Message = "Reboot timed out"
                Duration = $RebootTimeout
            }
        }
        
        $actualDuration = [math]::Round((Get-Date).Subtract((Get-Date).AddMinutes(-$RebootTimeout)).TotalMinutes, 1)
        return @{
            Success = $true
            Message = "Reboot completed successfully"
            Duration = $actualDuration
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Reboot failed: $($_.Exception.Message)"
            Duration = 0
        }
    }
}

# Function to get Windows update history
function Get-WindowsUpdateHistory {
    param(
        $VM,
        $Credential,
        $Days = 30
    )
    
    try {
        $vmIP = $VM.Guest.IPAddress | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+" } | Select-Object -First 1
        
        $historyScript = {
            param($DaysBack)
            
            try {
                Import-Module PSWindowsUpdate -Force -ErrorAction SilentlyContinue
                
                # Try PSWindowsUpdate method first
                try {
                    $history = Get-WUHistory | Where-Object { $_.Date -gt (Get-Date).AddDays(-$DaysBack) }
                    
                    $historyInfo = @()
                    foreach ($item in $history) {
                        $historyInfo += @{
                            Title = $item.Title
                            Date = $item.Date
                            Result = $item.Result
                            KB = $item.KB
                            Size = $item.Size
                        }
                    }
                    
                    return @{
                        Success = $true
                        History = $historyInfo
                        Count = $history.Count
                    }
                } catch {
                    # Fallback to Windows Update API
                    $session = New-Object -ComObject "Microsoft.Update.Session"
                    $searcher = $session.CreateUpdateSearcher()
                    $historyCount = $searcher.GetTotalHistoryCount()
                    
                    if ($historyCount -gt 0) {
                        $history = $searcher.QueryHistory(0, [Math]::Min($historyCount, 100))
                        $recentHistory = $history | Where-Object { $_.Date -gt (Get-Date).AddDays(-$DaysBack) }
                        
                        $historyInfo = @()
                        foreach ($item in $recentHistory) {
                            $historyInfo += @{
                                Title = $item.Title
                                Date = $item.Date
                                Result = $item.ResultCode
                                KB = ""
                                Size = 0
                            }
                        }
                        
                        return @{
                            Success = $true
                            History = $historyInfo
                            Count = $recentHistory.Count
                        }
                    } else {
                        return @{
                            Success = $true
                            History = @()
                            Count = 0
                        }
                    }
                }
            }
            catch {
                return @{
                    Success = $false
                    Message = "Error getting update history: $($_.Exception.Message)"
                    History = @()
                    Count = 0
                }
            }
        }
        
        $result = Invoke-Command -ComputerName $vmIP -Credential $Credential -ScriptBlock $historyScript -ArgumentList $Days
        
        if ($result.Success) {
            Write-Host "    ✓ Found $($result.Count) update(s) in last $Days days" -ForegroundColor Green
        } else {
            Write-Warning "    $($result.Message)"
        }
        
        return $result
    }
    catch {
        $errorMessage = "Failed to get update history: $($_.Exception.Message)"
        Write-Warning "    $errorMessage"
        return @{
            Success = $false
            Message = $errorMessage
            History = @()
            Count = 0
        }
    }
}

# Function to process VMs concurrently
function Invoke-ConcurrentVMProcessing {
    param(
        $VMs,
        $ScriptBlock,
        $MaxConcurrency,
        $WaitBetweenVMs
    )
    
    $results = @()
    $batches = @()
    
    # Split VMs into batches
    for ($i = 0; $i -lt $VMs.Count; $i += $MaxConcurrency) {
        $batch = $VMs[$i..[math]::Min($i + $MaxConcurrency - 1, $VMs.Count - 1)]
        $batches += ,$batch
    }
    
    foreach ($batch in $batches) {
        Write-Host "`nProcessing batch of $($batch.Count) VM(s)..." -ForegroundColor Cyan
        
        $jobs = @()
        foreach ($vm in $batch) {
            $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $vm
            $jobs += @{
                Job = $job
                VM = $vm
            }
        }
        
        # Wait for all jobs in batch to complete
        foreach ($jobInfo in $jobs) {
            try {
                $result = Receive-Job -Job $jobInfo.Job -Wait
                $results += $result
                Remove-Job -Job $jobInfo.Job
            }
            catch {
                Write-Warning "Job failed for VM '$($jobInfo.VM.Name)': $($_.Exception.Message)"
                $results += @{
                    VM = $jobInfo.VM.Name
                    Status = "Failed"
                    Message = $_.Exception.Message
                }
                Remove-Job -Job $jobInfo.Job -Force
            }
        }
        
        # Wait between batches
        if ($batch -ne $batches[-1] -and $WaitBetweenVMs -gt 0) {
            Write-Host "Waiting $WaitBetweenVMs seconds before next batch..." -ForegroundColor Gray
            Start-Sleep -Seconds $WaitBetweenVMs
        }
    }
    
    return $results
}

# Function to generate Windows update report
function Get-WindowsUpdateReport {
    param(
        $VMs,
        $Credential,
        $OutputFormat,
        $OutputPath
    )
    
    Write-Host "Generating Windows update report..." -ForegroundColor Yellow
    
    $reportData = @()
    
    foreach ($vm in $VMs) {
        try {
            Write-Host "  Processing VM: $($vm.Name)" -ForegroundColor Cyan
            
            # Test connectivity
            $connectivity = Test-VMConnectivity -VM $vm -Credential $Credential
            if (-not $connectivity.Success) {
                $reportData += [PSCustomObject]@{
                    VMName = $vm.Name
                    IPAddress = $connectivity.IP
                    OSName = $vm.Guest.OSFullName
                    Connectivity = "Failed"
                    ConnectivityMessage = $connectivity.Message
                    AvailableUpdates = "N/A"
                    RebootRequired = "N/A"
                    LastUpdateCheck = "N/A"
                    Timestamp = Get-Date
                }
                continue
            }
            
            # Install PSWindowsUpdate module if needed
            $moduleResult = Install-PSWindowsUpdateModule -VM $vm -Credential $Credential
            
            # Scan for updates
            $scanResult = Get-WindowsUpdates -VM $vm -Credential $Credential -UpdateCategory @("Security", "Critical", "Important") -ExcludeDrivers:$false -ExcludePreview:$true -UpdateSource "MicrosoftUpdate"
            
            # Check reboot status
            $rebootResult = Test-RebootRequired -VM $vm -Credential $Credential
            
            # Get recent update history
            $historyResult = Get-WindowsUpdateHistory -VM $vm -Credential $Credential -Days 30
            
            $reportData += [PSCustomObject]@{
                VMName = $vm.Name
                IPAddress = $connectivity.IP
                OSName = $vm.Guest.OSFullName
                Connectivity = "Success"
                ConnectivityMessage = $connectivity.Message
                PSWindowsUpdateModule = if ($moduleResult.Success) { "Installed" } else { "Failed" }
                AvailableUpdates = if ($scanResult.Success) { $scanResult.Count } else { "Error" }
                CriticalUpdates = if ($scanResult.Success) { $scanResult.CriticalCount } else { "N/A" }
                SecurityUpdates = if ($scanResult.Success) { $scanResult.SecurityCount } else { "N/A" }
                RebootRequired = if ($rebootResult.Success) { $rebootResult.RebootRequired } else { "Unknown" }
                RecentUpdatesCount = if ($historyResult.Success) { $historyResult.Count } else { "N/A" }
                LastUpdateCheck = Get-Date
                Timestamp = Get-Date
            }
        }
        catch {
            Write-Warning "Failed to process VM '$($vm.Name)': $($_.Exception.Message)"
            $reportData += [PSCustomObject]@{
                VMName = $vm.Name
                IPAddress = "Unknown"
                OSName = $vm.Guest.OSFullName
                Connectivity = "Error"
                ConnectivityMessage = $_.Exception.Message
                AvailableUpdates = "Error"
                RebootRequired = "Unknown"
                LastUpdateCheck = Get-Date
                Timestamp = Get-Date
            }
        }
    }
    
    # Export report
    switch ($OutputFormat) {
        "Console" {
            Write-Host "`n=== Windows Update Report ===" -ForegroundColor Cyan
            $reportData | Format-Table VMName, OSName, AvailableUpdates, CriticalUpdates, RebootRequired, Connectivity -AutoSize
        }
        "CSV" {
            if (-not $OutputPath) {
                $OutputPath = "Windows_Update_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            }
            $reportData | Export-Csv -Path $OutputPath -NoTypeInformation
            Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
        }
        "JSON" {
            if (-not $OutputPath) {
                $OutputPath = "Windows_Update_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            }
            $reportData | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
        }
    }
    
    return $reportData
}

# Function to display operation summary
function Show-UpdateOperationSummary {
    param(
        $Results,
        $Operation
    )
    
    Write-Host "`n=== Windows Update $Operation Summary ===" -ForegroundColor Cyan
    
    $successful = $Results | Where-Object { $_.Status -eq "Success" -or $_.Success -eq $true }
    $failed = $Results | Where-Object { $_.Status -eq "Failed" -or $_.Success -eq $false }
    $rebootRequired = $Results | Where-Object { $_.RebootRequired -eq $true }
    
    Write-Host "Total VMs: $($Results.Count)" -ForegroundColor White
    Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    
    if ($Operation -eq "Install" -or $Operation -eq "InstallAndReboot") {
        Write-Host "Requiring Reboot: $($rebootRequired.Count)" -ForegroundColor Yellow
        
        $totalUpdates = ($successful | Measure-Object -Property UpdatesInstalled -Sum -ErrorAction SilentlyContinue).Sum
        if ($totalUpdates) {
            Write-Host "Total Updates Installed: $totalUpdates" -ForegroundColor Cyan
        }
    }
    
    if ($failed.Count -gt 0) {
        Write-Host "`nFailed Operations:" -ForegroundColor Red
        foreach ($result in $failed) {
            $vmName = if ($result.VM) { $result.VM } elseif ($result.VMName) { $result.VMName } else { "Unknown" }
            $message = if ($result.Message) { $result.Message } else { "Unknown error" }
            Write-Host "  - $vmName`: $message" -ForegroundColor White
        }
    }
}

# Main execution
try {
    Write-Host "=== vSphere Windows Update Management ===" -ForegroundColor Cyan
    Write-Host "Target vCenter: $VCenterServer" -ForegroundColor White
    Write-Host "Operation: $Operation" -ForegroundColor White
    
    if ($VMName) { Write-Host "Target VM Pattern: $VMName" -ForegroundColor White }
    if ($VMNames) { Write-Host "Target VMs: $($VMNames -join ', ')" -ForegroundColor White }
    if ($ClusterName) { Write-Host "Target Cluster: $ClusterName" -ForegroundColor White }
    if ($ResourcePoolName) { Write-Host "Target Resource Pool: $ResourcePoolName" -ForegroundColor White }
    if ($UpdateCategory) { Write-Host "Update Categories: $($UpdateCategory -join ', ')" -ForegroundColor White }
    Write-Host ""
    
    # Check and install PowerCLI
    if (-not (Test-PowerCLIInstallation)) {
        throw "PowerCLI installation failed"
    }
    
    # Connect to vCenter
    $connection = Connect-ToVCenter -Server $VCenterServer
    
    # Get credentials for VM authentication
    $vmCredential = Get-VMCredential -Credential $Credential -Username $Username -Password $Password
    
    # Get target Windows VMs
    $targetVMs = Get-TargetWindowsVMs -VMName $VMName -VMNames $VMNames -ClusterName $ClusterName -ResourcePoolName $ResourcePoolName
    
    # Confirm operation if not using Force and operation is potentially disruptive
    if (-not $Force -and $Operation -in @("Install", "InstallAndReboot") -and $targetVMs.Count -gt 1) {
        $confirmation = Read-Host "`nProceed with $Operation operation on $($targetVMs.Count) Windows VM(s)? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Perform the Windows update operation
    $results = @()
    
    switch ($Operation) {
        "InstallModule" {
            foreach ($vm in $targetVMs) {
                Write-Host "`nProcessing VM: $($vm.Name)" -ForegroundColor Cyan
                
                # Test connectivity
                $connectivity = Test-VMConnectivity -VM $vm -Credential $vmCredential
                if (-not $connectivity.Success) {
                    $results += @{
                        VM = $vm.Name
                        Status = "Failed"
                        Message = $connectivity.Message
                    }
                    Write-Host "  ✗ $($connectivity.Message)" -ForegroundColor Red
                    continue
                }
                
                # Install PSWindowsUpdate module
                $moduleResult = Install-PSWindowsUpdateModule -VM $vm -Credential $vmCredential
                $results += @{
                    VM = $vm.Name
                    Status = if ($moduleResult.Success) { "Success" } else { "Failed" }
                    Message = $moduleResult.Message
                    ModuleInstalled = $moduleResult.Success
                }
            }
        }
        
        "Scan" {
            foreach ($vm in $targetVMs) {
                Write-Host "`nProcessing VM: $($vm.Name)" -ForegroundColor Cyan
                
                # Test connectivity
                $connectivity = Test-VMConnectivity -VM $vm -Credential $vmCredential
                if (-not $connectivity.Success) {
                    $results += @{
                        VM = $vm.Name
                        Status = "Failed"
                        Message = $connectivity.Message
                    }
                    Write-Host "  ✗ $($connectivity.Message)" -ForegroundColor Red
                    continue
                }
                
                # Install module if needed
                Install-PSWindowsUpdateModule -VM $vm -Credential $vmCredential | Out-Null
                
                # Scan for updates
                $scanResult = Get-WindowsUpdates -VM $vm -Credential $vmCredential -UpdateCategory $UpdateCategory -ExcludeDrivers:$ExcludeDrivers -ExcludePreview:$ExcludePreview -UpdateSource $UpdateSource
                
                $results += @{
                    VM = $vm.Name
                    Status = if ($scanResult.Success) { "Success" } else { "Failed" }
                    Message = if ($scanResult.Success) { "Scan completed" } else { $scanResult.Message }
                    AvailableUpdates = $scanResult.Count
                    CriticalUpdates = $scanResult.CriticalCount
                    SecurityUpdates = $scanResult.SecurityCount
                    TotalSizeMB = if ($scanResult.TotalSize) { [math]::Round($scanResult.TotalSize / 1MB, 1) } else { 0 }
                }
            }
        }
        
        "Install" {
            foreach ($vm in $targetVMs) {
                Write-Host "`nProcessing VM: $($vm.Name)" -ForegroundColor Cyan
                
                # Test connectivity
                $connectivity = Test-VMConnectivity -VM $vm -Credential $vmCredential
                if (-not $connectivity.Success) {
                    $results += @{
                        VM = $vm.Name
                        Status = "Failed"
                        Message = $connectivity.Message
                    }
                    Write-Host "  ✗ $($connectivity.Message)" -ForegroundColor Red
                    continue
                }
                
                # Create snapshot if requested
                if ($CreateSnapshot) {
                    New-UpdateSnapshot -VM $vm -SnapshotName $SnapshotName | Out-Null
                }
                
                # Install module if needed
                Install-PSWindowsUpdateModule -VM $vm -Credential $vmCredential | Out-Null
                
                # Install updates
                $installResult = Install-WindowsUpdates -VM $vm -Credential $vmCredential -UpdateCategory $UpdateCategory -ExcludeDrivers:$ExcludeDrivers -ExcludePreview:$ExcludePreview -UpdateSource $UpdateSource -AutoReboot:$AutoReboot
                
                $results += @{
                    VM = $vm.Name
                    Status = if ($installResult.Success) { "Success" } else { "Failed" }
                    Message = if ($installResult.Success) { "Updates installed" } else { $installResult.Message }
                    UpdatesInstalled = $installResult.Count
                    RebootRequired = $installResult.RebootRequired
                    TotalSizeMB = if ($installResult.TotalSize) { [math]::Round($installResult.TotalSize / 1MB, 1) } else { 0 }
                }
                
                # Wait between VMs
                if ($vm -ne $targetVMs[-1] -and $WaitBetweenVMs -gt 0) {
                    Write-Host "  Waiting $WaitBetweenVMs seconds before next VM..." -ForegroundColor Gray
                    Start-Sleep -Seconds $WaitBetweenVMs
                }
            }
        }
        
        "InstallAndReboot" {
            foreach ($vm in $targetVMs) {
                Write-Host "`nProcessing VM: $($vm.Name)" -ForegroundColor Cyan
                
                # Test connectivity
                $connectivity = Test-VMConnectivity -VM $vm -Credential $vmCredential
                if (-not $connectivity.Success) {
                    $results += @{
                        VM = $vm.Name
                        Status = "Failed"
                        Message = $connectivity.Message
                    }
                    Write-Host "  ✗ $($connectivity.Message)" -ForegroundColor Red
                    continue
                }
                
                # Create snapshot if requested
                if ($CreateSnapshot) {
                    New-UpdateSnapshot -VM $vm -SnapshotName $SnapshotName | Out-Null
                }
                
                # Install module if needed
                Install-PSWindowsUpdateModule -VM $vm -Credential $vmCredential | Out-Null
                
                # Install updates without auto-reboot
                $installResult = Install-WindowsUpdates -VM $vm -Credential $vmCredential -UpdateCategory $UpdateCategory -ExcludeDrivers:$ExcludeDrivers -ExcludePreview:$ExcludePreview -UpdateSource $UpdateSource -AutoReboot:$false
                
                $rebootResult = @{ Success = $true; Message = "No reboot required" }
                
                # Manual reboot if required
                if ($installResult.Success -and $installResult.RebootRequired) {
                    $rebootResult = Restart-VMAndWait -VM $vm -Credential $vmCredential -RebootTimeout $RebootTimeout
                }
                
                $results += @{
                    VM = $vm.Name
                    Status = if ($installResult.Success -and $rebootResult.Success) { "Success" } else { "Failed" }
                    Message = if ($installResult.Success) { 
                        if ($installResult.RebootRequired) { $rebootResult.Message } else { "Updates installed, no reboot required" }
                    } else { 
                        $installResult.Message 
                    }
                    UpdatesInstalled = $installResult.Count
                    RebootRequired = $installResult.RebootRequired
                    RebootCompleted = $rebootResult.Success
                    TotalSizeMB = if ($installResult.TotalSize) { [math]::Round($installResult.TotalSize / 1MB, 1) } else { 0 }
                }
                
                # Wait between VMs
                if ($vm -ne $targetVMs[-1] -and $WaitBetweenVMs -gt 0) {
                    Write-Host "  Waiting $WaitBetweenVMs seconds before next VM..." -ForegroundColor Gray
                    Start-Sleep -Seconds $WaitBetweenVMs
                }
            }
        }
        
        "CheckRebootRequired" {
            foreach ($vm in $targetVMs) {
                Write-Host "`nProcessing VM: $($vm.Name)" -ForegroundColor Cyan
                
                # Test connectivity
                $connectivity = Test-VMConnectivity -VM $vm -Credential $vmCredential
                if (-not $connectivity.Success) {
                    $results += @{
                        VM = $vm.Name
                        Status = "Failed"
                        Message = $connectivity.Message
                    }
                    Write-Host "  ✗ $($connectivity.Message)" -ForegroundColor Red
                    continue
                }
                
                # Check reboot status
                $rebootResult = Test-RebootRequired -VM $vm -Credential $vmCredential
                
                $results += @{
                    VM = $vm.Name
                    Status = if ($rebootResult.Success) { "Success" } else { "Failed" }
                    Message = $rebootResult.Message
                    RebootRequired = $rebootResult.RebootRequired
                    Method = $rebootResult.Method
                }
            }
        }
        
        "GetHistory" {
            foreach ($vm in $targetVMs) {
                Write-Host "`nProcessing VM: $($vm.Name)" -ForegroundColor Cyan
                
                # Test connectivity
                $connectivity = Test-VMConnectivity -VM $vm -Credential $vmCredential
                if (-not $connectivity.Success) {
                    $results += @{
                        VM = $vm.Name
                        Status = "Failed"
                        Message = $connectivity.Message
                    }
                    Write-Host "  ✗ $($connectivity.Message)" -ForegroundColor Red
                    continue
                }
                
                # Get update history
                $historyResult = Get-WindowsUpdateHistory -VM $vm -Credential $vmCredential -Days 30
                
                $results += @{
                    VM = $vm.Name
                    Status = if ($historyResult.Success) { "Success" } else { "Failed" }
                    Message = if ($historyResult.Success) { "History retrieved" } else { $historyResult.Message }
                    UpdateCount = $historyResult.Count
                    History = $historyResult.History
                }
            }
        }
        
        "Report" {
            $results = Get-WindowsUpdateReport -VMs $targetVMs -Credential $vmCredential -OutputFormat $OutputFormat -OutputPath $OutputPath
        }
    }
    
    # Display summary (except for Report operation which already displays results)
    if ($Operation -ne "Report") {
        Show-UpdateOperationSummary -Results $results -Operation $Operation
    }
    
    Write-Host "`n=== Operation Completed ===" -ForegroundColor Green
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Disconnect from vCenter if connected
    if ($global:DefaultVIServers) {
        Write-Host "`nDisconnecting from vCenter..." -ForegroundColor Yellow
        Disconnect-VIServer -Server * -Confirm:$false -Force
    }
}
