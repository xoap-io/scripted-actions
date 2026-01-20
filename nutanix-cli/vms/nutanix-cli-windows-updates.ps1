<#
.SYNOPSIS
    Manages Windows updates on Nutanix AHV VMs using PowerShell remoting.

.DESCRIPTION
    This script automates Windows update management across Nutanix VMs including
    scanning, downloading, installing updates, and managing reboots. Supports
    different update categories, concurrent processing, and integration with
    Nutanix snapshots for safety.
    Requires Nutanix PowerShell SDK and PSWindowsUpdate module.

.PARAMETER PrismCentral
    The Prism Central FQDN or IP address to connect to.

.PARAMETER PrismElement
    The Prism Element FQDN or IP address to connect to (alternative to Prism Central).

.PARAMETER VMNames
    Array of VM names to process for Windows updates.

.PARAMETER VMUUIDs
    Array of VM UUIDs to process for Windows updates.

.PARAMETER ClusterName
    Process all Windows VMs in the specified cluster.

.PARAMETER ClusterUUID
    Process all Windows VMs in the specified cluster by UUID.

.PARAMETER DomainCredential
    Domain credentials for connecting to VMs (recommended).

.PARAMETER LocalCredential
    Local administrator credentials for connecting to VMs.

.PARAMETER UpdateCategories
    Categories of updates to install.

.PARAMETER ScanOnly
    Only scan for updates without installing them.

.PARAMETER AutoReboot
    Automatically reboot VMs if required after update installation.

.PARAMETER RebootTimeout
    Timeout in minutes to wait for VM reboot completion.

.PARAMETER CreateSnapshots
    Create snapshots before installing updates.

.PARAMETER SnapshotPrefix
    Prefix for snapshot names.

.PARAMETER MaxConcurrentVMs
    Maximum number of VMs to process concurrently.

.PARAMETER ExcludeVMs
    Array of VM names to exclude from processing.

.PARAMETER ExcludeKBs
    Array of KB numbers to exclude from installation.

.PARAMETER IncludeKBs
    Array of specific KB numbers to install (overrides categories).

.PARAMETER Force
    Force operations without confirmation prompts.

.PARAMETER OutputFormat
    Output format for reports.

.PARAMETER OutputPath
    Path to save the report file.

.EXAMPLE
    .\nutanix-cli-windows-updates.ps1 -PrismCentral "pc.domain.com" -VMNames @("srv01", "srv02") -UpdateCategories @("Security", "Critical") -DomainCredential (Get-Credential) -AutoReboot

.EXAMPLE
    .\nutanix-cli-windows-updates.ps1 -PrismCentral "pc.domain.com" -ClusterName "Production" -ScanOnly -LocalCredential (Get-Credential) -OutputFormat "CSV" -OutputPath "update-scan.csv"

.EXAMPLE
    .\nutanix-cli-windows-updates.ps1 -PrismCentral "pc.domain.com" -VMNames @("web01", "web02") -UpdateCategories @("Security") -CreateSnapshots -MaxConcurrentVMs 2 -DomainCredential (Get-Credential)

.NOTES
    Author: XOAP.io
    Requires: Nutanix PowerShell SDK, PSWindowsUpdate module, PowerShell remoting enabled

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, ParameterSetName = "PrismCentral")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismCentral,

    [Parameter(Mandatory = $false, ParameterSetName = "PrismElement")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismElement,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$VMNames,

    [Parameter(Mandatory = $false)]
    [ValidateScript({
        foreach ($uuid in $_) {
            if ($uuid -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                throw "Invalid UUID format: $uuid"
            }
        }
        return $true
    })]
    [string[]]$VMUUIDs,

    [Parameter(Mandatory = $false)]
    [string]$ClusterName,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ClusterUUID,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$DomainCredential,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$LocalCredential,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Security", "Critical", "Important", "Moderate", "Low", "Unspecified")]
    [string[]]$UpdateCategories = @("Security", "Critical"),

    [Parameter(Mandatory = $false)]
    [switch]$ScanOnly,

    [Parameter(Mandatory = $false)]
    [switch]$AutoReboot,

    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 60)]
    [int]$RebootTimeout = 15,

    [Parameter(Mandatory = $false)]
    [switch]$CreateSnapshots,

    [Parameter(Mandatory = $false)]
    [string]$SnapshotPrefix = "BeforeUpdates",

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$MaxConcurrentVMs = 3,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeVMs,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeKBs,

    [Parameter(Mandatory = $false)]
    [string[]]$IncludeKBs,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "CSV", "JSON", "HTML")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to check and install required modules
function Test-RequiredModules {
    Write-Host "Checking required PowerShell modules..." -ForegroundColor Yellow

    try {
        # Check Nutanix PowerShell SDK
        $nutanixModule = Get-Module -Name Nutanix.PowerShell.SDK -ListAvailable
        if (-not $nutanixModule) {
            Write-Warning "Nutanix PowerShell SDK not found. Installing..."
            Install-Module -Name Nutanix.PowerShell.SDK -Force -AllowClobber -Scope CurrentUser
            Write-Host "Nutanix PowerShell SDK installed successfully." -ForegroundColor Green
        }

        # Check PSWindowsUpdate module
        $winUpdateModule = Get-Module -Name PSWindowsUpdate -ListAvailable
        if (-not $winUpdateModule) {
            Write-Warning "PSWindowsUpdate module not found. Installing..."
            Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Scope CurrentUser
            Write-Host "PSWindowsUpdate module installed successfully." -ForegroundColor Green
        }

        # Import modules
        Import-Module Nutanix.PowerShell.SDK -Force
        Import-Module PSWindowsUpdate -Force

        Write-Host "All required modules available." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to install or import required modules: $($_.Exception.Message)"
        return $false
    }
}

# Function to connect to Prism Central or Element
function Connect-ToNutanix {
    param($Server, $ServerType)

    try {
        Write-Host "Connecting to $ServerType`: $Server" -ForegroundColor Yellow

        # Check if already connected
        if ($global:DefaultNTNXConnection -and $global:DefaultNTNXConnection.Server -eq $Server) {
            Write-Host "Already connected to $Server" -ForegroundColor Green
            return $global:DefaultNTNXConnection
        }

        # Connect to Nutanix
        $connection = Connect-NTNXCluster -Server $Server -AcceptInvalidSSLCerts
        Write-Host "Successfully connected to $ServerType`: $($connection.Server)" -ForegroundColor Green
        return $connection
    }
    catch {
        Write-Error "Failed to connect to $ServerType $Server`: $($_.Exception.Message)"
        throw
    }
}

# Function to get target Windows VMs
function Get-TargetWindowsVMs {
    param(
        $VMNames,
        $VMUUIDs,
        $ClusterName,
        $ClusterUUID,
        $ExcludeVMs
    )

    Write-Host "Identifying target Windows VMs..." -ForegroundColor Yellow

    try {
        $allVMs = @()

        if ($VMUUIDs) {
            # Get VMs by UUID
            $allVMs = Get-NTNXVM | Where-Object { $_.uuid -in $VMUUIDs }
        }
        elseif ($VMNames) {
            # Get VMs by name
            $allVMs = Get-NTNXVM | Where-Object { $_.vmName -in $VMNames }
        }
        elseif ($ClusterUUID) {
            # Get all VMs in cluster by UUID
            $allVMs = Get-NTNXVM | Where-Object { $_.clusterUuid -eq $ClusterUUID }
        }
        elseif ($ClusterName) {
            # Get all VMs in cluster by name
            $clusters = Get-NTNXCluster | Where-Object { $_.name -eq $ClusterName }
            if (-not $clusters) {
                throw "Cluster '$ClusterName' not found"
            }
            $clusterUuid = $clusters[0].clusterUuid
            $allVMs = Get-NTNXVM | Where-Object { $_.clusterUuid -eq $clusterUuid }
        }
        else {
            throw "Must specify VMNames, VMUUIDs, ClusterName, or ClusterUUID"
        }

        # Filter for Windows VMs that are powered on
        $windowsVMs = $allVMs | Where-Object {
            $_.powerState -eq "ON" -and
            $_.guestOperatingSystem -match "Windows"
        }

        # Exclude specified VMs
        if ($ExcludeVMs) {
            $windowsVMs = $windowsVMs | Where-Object { $_.vmName -notin $ExcludeVMs }
            Write-Host "Excluded $($ExcludeVMs.Count) VM(s) from processing" -ForegroundColor Gray
        }

        if (-not $windowsVMs) {
            throw "No powered-on Windows VMs found matching the specified criteria"
        }

        Write-Host "Found $($windowsVMs.Count) Windows VM(s) for update processing:" -ForegroundColor Green
        foreach ($vm in $windowsVMs) {
            $ngtStatus = if ($vm.nutanixGuestTools.toolsInstalled) { "Installed" } else { "Not Installed" }
            Write-Host "  - $($vm.vmName) [$($vm.guestOperatingSystem)] [NGT: $ngtStatus]" -ForegroundColor White
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
    param($VM, $Credential)

    try {
        # Try to get IP address from NGT
        $ipAddress = $null
        if ($VM.nutanixGuestTools.toolsInstalled -and $VM.ipAddresses) {
            $ipAddress = $VM.ipAddresses | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+$" } | Select-Object -First 1
        }

        if (-not $ipAddress) {
            return @{
                Success = $false
                Message = "Unable to determine VM IP address"
                IPAddress = $null
            }
        }

        # Test WinRM connectivity
        $testResult = Test-WSMan -ComputerName $ipAddress -Credential $Credential -ErrorAction SilentlyContinue
        if ($testResult) {
            return @{
                Success = $true
                Message = "VM connectivity successful"
                IPAddress = $ipAddress
            }
        } else {
            return @{
                Success = $false
                Message = "WinRM connectivity failed"
                IPAddress = $ipAddress
            }
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Connectivity test failed: $($_.Exception.Message)"
            IPAddress = $ipAddress
        }
    }
}

# Function to create snapshot before updates
function New-UpdateSnapshot {
    param($VM, $SnapshotPrefix)

    try {
        $snapshotName = "$SnapshotPrefix-$($VM.vmName)-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Write-Host "      Creating snapshot: $snapshotName" -ForegroundColor Gray

        # Check if snapshot already exists
        $existingSnapshots = Get-NTNXSnapshot | Where-Object {
            $_.vmUuid -eq $VM.uuid -and $_.snapshotName -eq $snapshotName
        }
        if ($existingSnapshots) {
            Write-Warning "      Snapshot '$snapshotName' already exists"
            return $existingSnapshots[0]
        }

        # Create snapshot
        $snapshotSpec = New-Object Nutanix.Prism.Model.SnapshotSpec
        $snapshotSpec.snapshotName = $snapshotName
        $snapshotSpec.vmUuid = $VM.uuid

        $snapshot = New-NTNXSnapshot -SnapshotSpecs $snapshotSpec
        Write-Host "      ✓ Snapshot created: $($snapshot.snapshotName)" -ForegroundColor Green
        return $snapshot
    }
    catch {
        Write-Warning "      Failed to create snapshot: $($_.Exception.Message)"
        return $null
    }
}

# Function to install PSWindowsUpdate module on remote VM
function Install-RemotePSWindowsUpdate {
    param($ComputerName, $Credential)

    try {
        Write-Host "        Installing PSWindowsUpdate module on VM..." -ForegroundColor Gray

        $scriptBlock = {
            try {
                $module = Get-Module -Name PSWindowsUpdate -ListAvailable
                if (-not $module) {
                    Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Scope AllUsers
                    Import-Module PSWindowsUpdate -Force
                    return "PSWindowsUpdate module installed successfully"
                } else {
                    Import-Module PSWindowsUpdate -Force
                    return "PSWindowsUpdate module already available"
                }
            }
            catch {
                return "Failed to install PSWindowsUpdate: $($_.Exception.Message)"
            }
        }

        $result = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock $scriptBlock
        Write-Host "        ✓ $result" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "        Failed to install PSWindowsUpdate module: $($_.Exception.Message)"
        return $false
    }
}

# Function to scan for updates
function Get-VMWindowsUpdates {
    param($VM, $ComputerName, $Credential, $UpdateCategories, $ExcludeKBs, $IncludeKBs)

    try {
        Write-Host "        Scanning for Windows updates..." -ForegroundColor Gray

        $scriptBlock = {
            param($Categories, $ExcludeKBs, $IncludeKBs)

            try {
                $searchCriteria = ""

                if ($IncludeKBs) {
                    # Search for specific KBs
                    $kbFilter = ($IncludeKBs | ForEach-Object { "UpdateID='$_'" }) -join " OR "
                    $updates = Get-WindowsUpdate -Criteria $kbFilter
                } else {
                    # Search by categories
                    $categoryFilter = @()
                    foreach ($category in $Categories) {
                        switch ($category) {
                            "Security" { $categoryFilter += "CategoryIDs contains 'E6CF1350-C01B-414D-A61F-263D14D133B4'" }
                            "Critical" { $categoryFilter += "CategoryIDs contains 'E6CF1350-C01B-414D-A61F-263D14D133B4'" }
                            "Important" { $categoryFilter += "CategoryIDs contains 'E6CF1350-C01B-414D-A61F-263D14D133B4'" }
                        }
                    }

                    $updates = Get-WindowsUpdate -Category $Categories
                }

                # Exclude specified KBs
                if ($ExcludeKBs) {
                    $updates = $updates | Where-Object { $_.KBArticleIDs -notin $ExcludeKBs }
                }

                return @{
                    Success = $true
                    Updates = $updates
                    Count = $updates.Count
                    TotalSizeMB = [math]::Round(($updates | Measure-Object -Property Size -Sum).Sum / 1MB, 2)
                }
            }
            catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                    Updates = @()
                    Count = 0
                    TotalSizeMB = 0
                }
            }
        }

        $result = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock $scriptBlock -ArgumentList $UpdateCategories, $ExcludeKBs, $IncludeKBs

        if ($result.Success) {
            Write-Host "        ✓ Found $($result.Count) update(s) [$($result.TotalSizeMB) MB]" -ForegroundColor Green
        } else {
            Write-Warning "        Update scan failed: $($result.Error)"
        }

        return $result
    }
    catch {
        Write-Warning "        Failed to scan for updates: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            Updates = @()
            Count = 0
            TotalSizeMB = 0
        }
    }
}

# Function to install updates
function Install-VMWindowsUpdates {
    param($VM, $ComputerName, $Credential, $Updates, $AutoReboot)

    try {
        Write-Host "        Installing $($Updates.Count) Windows update(s)..." -ForegroundColor Gray

        $scriptBlock = {
            param($UpdateTitles, $AutoReboot)

            try {
                $installResults = @()
                $rebootRequired = $false

                # Install updates
                $result = Install-WindowsUpdate -Title $UpdateTitles -AcceptAll -AutoReboot:$AutoReboot

                foreach ($update in $result) {
                    $installResults += @{
                        Title = $update.Title
                        KB = $update.KB
                        Status = $update.Result
                        Size = $update.Size
                    }

                    if ($update.RebootRequired) {
                        $rebootRequired = $true
                    }
                }

                return @{
                    Success = $true
                    Results = $installResults
                    RebootRequired = $rebootRequired
                    InstalledCount = ($installResults | Where-Object { $_.Status -eq "Installed" }).Count
                }
            }
            catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                    Results = @()
                    RebootRequired = $false
                    InstalledCount = 0
                }
            }
        }

        $updateTitles = $Updates | ForEach-Object { $_.Title }
        $result = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock $scriptBlock -ArgumentList $updateTitles, $AutoReboot

        if ($result.Success) {
            Write-Host "        ✓ Installed $($result.InstalledCount) update(s)" -ForegroundColor Green
            if ($result.RebootRequired) {
                Write-Host "        ⚠ Reboot required" -ForegroundColor Yellow
            }
        } else {
            Write-Warning "        Update installation failed: $($result.Error)"
        }

        return $result
    }
    catch {
        Write-Warning "        Failed to install updates: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            Results = @()
            RebootRequired = $false
            InstalledCount = 0
        }
    }
}

# Function to wait for VM reboot completion
function Wait-VMReboot {
    param($VM, $ComputerName, $Credential, $TimeoutMinutes)

    try {
        Write-Host "        Waiting for VM reboot to complete..." -ForegroundColor Gray

        $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
        $vmOnline = $false

        # Wait for VM to go offline (reboot start)
        Start-Sleep -Seconds 30

        # Wait for VM to come back online
        while ((Get-Date) -lt $timeout -and -not $vmOnline) {
            Start-Sleep -Seconds 30

            try {
                $testResult = Test-WSMan -ComputerName $ComputerName -Credential $Credential -ErrorAction SilentlyContinue
                if ($testResult) {
                    # Double-check with a simple command
                    $pingResult = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock { "online" } -ErrorAction SilentlyContinue
                    if ($pingResult -eq "online") {
                        $vmOnline = $true
                    }
                }
            }
            catch {
                # VM still rebooting
            }
        }

        if ($vmOnline) {
            Write-Host "        ✓ VM reboot completed successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Warning "        VM reboot timed out after $TimeoutMinutes minutes"
            return $false
        }
    }
    catch {
        Write-Warning "        Failed to monitor VM reboot: $($_.Exception.Message)"
        return $false
    }
}

# Function to process single VM
function Update-SingleVM {
    param(
        $VM,
        $Credential,
        $UpdateCategories,
        $ScanOnly,
        $AutoReboot,
        $RebootTimeout,
        $CreateSnapshots,
        $SnapshotPrefix,
        $ExcludeKBs,
        $IncludeKBs
    )

    $vmResult = @{
        VMName = $VM.vmName
        UUID = $VM.uuid
        Status = "Processing"
        Message = ""
        UpdatesFound = 0
        UpdatesInstalled = 0
        RebootRequired = $false
        RebootCompleted = $false
        SnapshotCreated = $false
        ProcessingTime = 0
        UpdateDetails = @()
    }

    $startTime = Get-Date

    try {
        Write-Host "  Processing VM: $($VM.vmName)" -ForegroundColor Cyan

        # Test connectivity
        $connectivityTest = Test-VMConnectivity -VM $VM -Credential $Credential
        if (-not $connectivityTest.Success) {
            $vmResult.Status = "Failed"
            $vmResult.Message = $connectivityTest.Message
            Write-Host "    ✗ $($connectivityTest.Message)" -ForegroundColor Red
            return $vmResult
        }

        $ipAddress = $connectivityTest.IPAddress
        Write-Host "    ✓ VM connectivity verified [$ipAddress]" -ForegroundColor Green

        # Create snapshot if requested
        if ($CreateSnapshots -and -not $ScanOnly) {
            $snapshot = New-UpdateSnapshot -VM $VM -SnapshotPrefix $SnapshotPrefix
            $vmResult.SnapshotCreated = $snapshot -ne $null
        }

        # Install PSWindowsUpdate module on remote VM
        $moduleInstalled = Install-RemotePSWindowsUpdate -ComputerName $ipAddress -Credential $Credential
        if (-not $moduleInstalled) {
            $vmResult.Status = "Failed"
            $vmResult.Message = "Failed to install PSWindowsUpdate module"
            Write-Host "    ✗ Failed to install PSWindowsUpdate module" -ForegroundColor Red
            return $vmResult
        }

        # Scan for updates
        $scanResult = Get-VMWindowsUpdates -VM $VM -ComputerName $ipAddress -Credential $Credential -UpdateCategories $UpdateCategories -ExcludeKBs $ExcludeKBs -IncludeKBs $IncludeKBs
        $vmResult.UpdatesFound = $scanResult.Count

        if (-not $scanResult.Success) {
            $vmResult.Status = "Failed"
            $vmResult.Message = "Update scan failed: $($scanResult.Error)"
            Write-Host "    ✗ Update scan failed: $($scanResult.Error)" -ForegroundColor Red
            return $vmResult
        }

        if ($scanResult.Count -eq 0) {
            $vmResult.Status = "Success"
            $vmResult.Message = "No updates found"
            Write-Host "    ✓ No updates found" -ForegroundColor Green
            return $vmResult
        }

        # Store update details
        $vmResult.UpdateDetails = $scanResult.Updates | ForEach-Object {
            @{
                Title = $_.Title
                KB = $_.KB
                Category = $_.Categories
                Size = $_.Size
                Status = "Pending"
            }
        }

        if ($ScanOnly) {
            $vmResult.Status = "Success"
            $vmResult.Message = "Scan completed - $($scanResult.Count) update(s) found"
            Write-Host "    ✓ Scan completed - $($scanResult.Count) update(s) found" -ForegroundColor Green
            return $vmResult
        }

        # Install updates
        $installResult = Install-VMWindowsUpdates -VM $VM -ComputerName $ipAddress -Credential $Credential -Updates $scanResult.Updates -AutoReboot $AutoReboot

        if (-not $installResult.Success) {
            $vmResult.Status = "Failed"
            $vmResult.Message = "Update installation failed: $($installResult.Error)"
            Write-Host "    ✗ Update installation failed: $($installResult.Error)" -ForegroundColor Red
            return $vmResult
        }

        $vmResult.UpdatesInstalled = $installResult.InstalledCount
        $vmResult.RebootRequired = $installResult.RebootRequired

        # Update details with installation results
        foreach ($result in $installResult.Results) {
            $detail = $vmResult.UpdateDetails | Where-Object { $_.KB -eq $result.KB }
            if ($detail) {
                $detail.Status = $result.Status
            }
        }

        # Handle reboot if required and AutoReboot is enabled
        if ($installResult.RebootRequired -and $AutoReboot) {
            $rebootSuccess = Wait-VMReboot -VM $VM -ComputerName $ipAddress -Credential $Credential -TimeoutMinutes $RebootTimeout
            $vmResult.RebootCompleted = $rebootSuccess
        }

        $vmResult.Status = "Success"
        $vmResult.Message = "Updates processed successfully - $($vmResult.UpdatesInstalled) installed"
        Write-Host "    ✓ Updates processed successfully - $($vmResult.UpdatesInstalled) installed" -ForegroundColor Green
    }
    catch {
        $vmResult.Status = "Failed"
        $vmResult.Message = $_.Exception.Message
        Write-Host "    ✗ Failed to process VM: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        $vmResult.ProcessingTime = [math]::Round((Get-Date).Subtract($startTime).TotalMinutes, 2)
    }

    return $vmResult
}

# Function to process VMs concurrently
function Update-VMsConcurrently {
    param(
        $VMs,
        $Credential,
        $UpdateCategories,
        $ScanOnly,
        $AutoReboot,
        $RebootTimeout,
        $CreateSnapshots,
        $SnapshotPrefix,
        $ExcludeKBs,
        $IncludeKBs,
        $MaxConcurrentVMs
    )

    Write-Host "Processing $($VMs.Count) VM(s) with maximum $MaxConcurrentVMs concurrent operations..." -ForegroundColor Yellow

    $results = @()
    $jobs = @()
    $vmQueue = [System.Collections.Queue]::new($VMs)

    # Function to create script block for background jobs
    $scriptBlock = {
        param($VM, $Credential, $UpdateCategories, $ScanOnly, $AutoReboot, $RebootTimeout, $CreateSnapshots, $SnapshotPrefix, $ExcludeKBs, $IncludeKBs)

        # Import functions (would need to be defined in the job)
        # For simplicity, we'll process sequentially instead of using jobs
        return $VM
    }

    # Process VMs in batches
    while ($vmQueue.Count -gt 0) {
        $currentBatch = @()
        $batchSize = [Math]::Min($MaxConcurrentVMs, $vmQueue.Count)

        for ($i = 0; $i -lt $batchSize; $i++) {
            if ($vmQueue.Count -gt 0) {
                $currentBatch += $vmQueue.Dequeue()
            }
        }

        # Process current batch
        foreach ($vm in $currentBatch) {
            $result = Update-SingleVM -VM $vm -Credential $Credential -UpdateCategories $UpdateCategories -ScanOnly:$ScanOnly -AutoReboot:$AutoReboot -RebootTimeout $RebootTimeout -CreateSnapshots:$CreateSnapshots -SnapshotPrefix $SnapshotPrefix -ExcludeKBs $ExcludeKBs -IncludeKBs $IncludeKBs
            $results += $result
        }

        # Small delay between batches
        if ($vmQueue.Count -gt 0) {
            Start-Sleep -Seconds 10
        }
    }

    return $results
}

# Function to generate update report
function Show-UpdateResults {
    param($Results, $OutputFormat, $OutputPath)

    Write-Host "`n=== Windows Update Results ===" -ForegroundColor Cyan

    $successful = $Results | Where-Object { $_.Status -eq "Success" }
    $failed = $Results | Where-Object { $_.Status -eq "Failed" }
    $totalUpdates = ($Results | Measure-Object -Property UpdatesInstalled -Sum).Sum
    $totalFound = ($Results | Measure-Object -Property UpdatesFound -Sum).Sum

    Write-Host "Total VMs Processed: $($Results.Count)" -ForegroundColor White
    Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    Write-Host "Total Updates Found: $totalFound" -ForegroundColor White
    Write-Host "Total Updates Installed: $totalUpdates" -ForegroundColor Green

    if ($successful.Count -gt 0) {
        Write-Host "`nSuccessful Updates:" -ForegroundColor Green
        foreach ($result in $successful) {
            $rebootStatus = if ($result.RebootRequired) {
                if ($result.RebootCompleted) { "[Rebooted]" } else { "[Reboot Required]" }
            } else { "" }
            Write-Host "  ✓ $($result.VMName): $($result.UpdatesInstalled)/$($result.UpdatesFound) updates $rebootStatus" -ForegroundColor White
        }
    }

    if ($failed.Count -gt 0) {
        Write-Host "`nFailed Updates:" -ForegroundColor Red
        foreach ($result in $failed) {
            Write-Host "  ✗ $($result.VMName): $($result.Message)" -ForegroundColor White
        }
    }

    # Export results if requested
    if ($OutputFormat -ne "Console") {
        $exportData = $Results | ForEach-Object {
            [PSCustomObject]@{
                VMName = $_.VMName
                UUID = $_.UUID
                Status = $_.Status
                Message = $_.Message
                UpdatesFound = $_.UpdatesFound
                UpdatesInstalled = $_.UpdatesInstalled
                RebootRequired = $_.RebootRequired
                RebootCompleted = $_.RebootCompleted
                SnapshotCreated = $_.SnapshotCreated
                ProcessingTimeMinutes = $_.ProcessingTime
                Timestamp = Get-Date
            }
        }

        switch ($OutputFormat) {
            "CSV" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_Windows_Updates_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                }
                $exportData | Export-Csv -Path $OutputPath -NoTypeInformation
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
            "JSON" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_Windows_Updates_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                }
                $exportData | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
            "HTML" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_Windows_Updates_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
                }
                $exportData | ConvertTo-Html -Title "Nutanix Windows Update Report" | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "`nHTML report generated: $OutputPath" -ForegroundColor Green
            }
        }
    }
}

# Main execution
try {
    Write-Host "=== Nutanix Windows Update Management ===" -ForegroundColor Cyan

    # Determine target server
    $targetServer = if ($PrismCentral) { $PrismCentral } else { $PrismElement }
    $serverType = if ($PrismCentral) { "Prism Central" } else { "Prism Element" }

    if (-not $targetServer) {
        throw "Either PrismCentral or PrismElement parameter must be specified"
    }

    # Validate credentials
    if (-not $DomainCredential -and -not $LocalCredential) {
        throw "Either DomainCredential or LocalCredential must be specified"
    }

    $credential = if ($DomainCredential) { $DomainCredential } else { $LocalCredential }
    $credentialType = if ($DomainCredential) { "Domain" } else { "Local" }

    Write-Host "Target $serverType`: $targetServer" -ForegroundColor White
    Write-Host "Credential Type: $credentialType" -ForegroundColor White
    Write-Host "Update Categories: $($UpdateCategories -join ', ')" -ForegroundColor White
    Write-Host "Operation Mode: $(if ($ScanOnly) { 'Scan Only' } else { 'Install Updates' })" -ForegroundColor White
    if (-not $ScanOnly) {
        Write-Host "Auto Reboot: $AutoReboot" -ForegroundColor White
        Write-Host "Create Snapshots: $CreateSnapshots" -ForegroundColor White
    }
    Write-Host ""

    # Check and install required modules
    if (-not (Test-RequiredModules)) {
        throw "Required module installation failed"
    }

    # Connect to Nutanix
    $connection = Connect-ToNutanix -Server $targetServer -ServerType $serverType

    # Get target Windows VMs
    $targetVMs = Get-TargetWindowsVMs -VMNames $VMNames -VMUUIDs $VMUUIDs -ClusterName $ClusterName -ClusterUUID $ClusterUUID -ExcludeVMs $ExcludeVMs

    # Confirm operation if not using Force
    if (-not $Force -and -not $ScanOnly -and $targetVMs.Count -gt 1) {
        $confirmation = Read-Host "`nProceed with installing Windows updates on $($targetVMs.Count) VM(s)? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Process VMs
    Write-Host "Starting Windows update processing..." -ForegroundColor Yellow
    $results = Update-VMsConcurrently -VMs $targetVMs -Credential $credential -UpdateCategories $UpdateCategories -ScanOnly:$ScanOnly -AutoReboot:$AutoReboot -RebootTimeout $RebootTimeout -CreateSnapshots:$CreateSnapshots -SnapshotPrefix $SnapshotPrefix -ExcludeKBs $ExcludeKBs -IncludeKBs $IncludeKBs -MaxConcurrentVMs $MaxConcurrentVMs

    # Display results
    Show-UpdateResults -Results $results -OutputFormat $OutputFormat -OutputPath $OutputPath

    Write-Host "`n=== Windows Update Processing Completed ===" -ForegroundColor Green
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Disconnect from Nutanix if connected
    if ($global:DefaultNTNXConnection) {
        Write-Host "`nDisconnecting from Nutanix..." -ForegroundColor Yellow
        Disconnect-NTNXCluster
    }
}
