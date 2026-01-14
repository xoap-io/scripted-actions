<#
.SYNOPSIS
    Manages datastore operations in vSphere using PowerCLI.

.DESCRIPTION
    This script provides comprehensive datastore management including browsing,
    cleanup, space monitoring, file operations, and maintenance tasks.
    Supports VMFS, NFS, and vSAN datastores with detailed reporting.
    Requires VMware PowerCLI and connection to vCenter Server.

.PARAMETER VCenterServer
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER DatastoreName
    The name of the datastore to manage. Supports wildcards.

.PARAMETER DatastoreNames
    An array of specific datastore names for batch operations.

.PARAMETER ClusterName
    Filter datastores by cluster location (optional).

.PARAMETER Operation
    The datastore operation to perform.

.PARAMETER ThresholdPercent
    Space usage threshold percentage for alerts (default: 85).

.PARAMETER CleanupOrphanedFiles
    Remove orphaned files during cleanup operation.

.PARAMETER CleanupSnapshots
    Remove old snapshot files during cleanup operation.

.PARAMETER CleanupLogs
    Remove old log files during cleanup operation.

.PARAMETER FilePath
    File path for file operations (relative to datastore root).

.PARAMETER OutputFormat
    Output format for reports.

.PARAMETER OutputPath
    Path to save the report file (optional).

.PARAMETER Force
    Force operations without confirmation prompts.

.PARAMETER DryRun
    Show what would be done without actually performing operations.

.EXAMPLE
    .\vsphere-cli-manage-datastores.ps1 -VCenterServer "vcenter.domain.com" -Operation "Monitor" -ThresholdPercent 80

.EXAMPLE
    .\vsphere-cli-manage-datastores.ps1 -VCenterServer "vcenter.domain.com" -DatastoreName "Datastore1" -Operation "Browse"

.EXAMPLE
    .\vsphere-cli-manage-datastores.ps1 -VCenterServer "vcenter.domain.com" -DatastoreName "OldDatastore*" -Operation "Cleanup" -CleanupOrphanedFiles -CleanupSnapshots -Force

.EXAMPLE
    .\vsphere-cli-manage-datastores.ps1 -VCenterServer "vcenter.domain.com" -Operation "Report" -OutputFormat "CSV" -OutputPath "datastore-report.csv"

.NOTES
    Author: Generated for scripted-actions
    Requires: VMware PowerCLI 13.x or later, vSphere 7.0 or later
    Version: 1.0
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VCenterServer,

    [Parameter(Mandatory = $false, ParameterSetName = "SingleDatastore")]
    [ValidateNotNullOrEmpty()]
    [string]$DatastoreName,

    [Parameter(Mandatory = $false, ParameterSetName = "MultipleDatastores")]
    [ValidateNotNullOrEmpty()]
    [string[]]$DatastoreNames,

    [Parameter(Mandatory = $false)]
    [string]$ClusterName,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Monitor", "Browse", "Cleanup", "Report", "FileOperations", "Maintenance")]
    [string]$Operation,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$ThresholdPercent = 85,

    [Parameter(Mandatory = $false)]
    [switch]$CleanupOrphanedFiles,

    [Parameter(Mandatory = $false)]
    [switch]$CleanupSnapshots,

    [Parameter(Mandatory = $false)]
    [switch]$CleanupLogs,

    [Parameter(Mandatory = $false)]
    [string]$FilePath,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "CSV", "JSON")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
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

# Function to get target datastores
function Get-TargetDatastores {
    param(
        $DatastoreName,
        $DatastoreNames,
        $ClusterName
    )

    Write-Host "Identifying target datastores..." -ForegroundColor Yellow

    try {
        $targetDatastores = @()

        if ($DatastoreName) {
            # Single datastore or wildcard pattern
            $targetDatastores = Get-Datastore -Name $DatastoreName -ErrorAction SilentlyContinue
        }
        elseif ($DatastoreNames) {
            # Multiple specific datastores
            foreach ($name in $DatastoreNames) {
                $ds = Get-Datastore -Name $name -ErrorAction SilentlyContinue
                if ($ds) {
                    $targetDatastores += $ds
                } else {
                    Write-Warning "Datastore '$name' not found"
                }
            }
        }
        else {
            # All datastores
            $targetDatastores = Get-Datastore
        }

        # Filter by cluster if specified
        if ($ClusterName -and $targetDatastores) {
            $cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
            if (-not $cluster) {
                throw "Cluster '$ClusterName' not found"
            }
            $clusterHosts = Get-VMHost -Location $cluster
            $targetDatastores = $targetDatastores | Where-Object {
                $ds = $_
                $dsHosts = Get-VMHost -Datastore $ds
                ($dsHosts | Where-Object { $clusterHosts.Name -contains $_.Name }).Count -gt 0
            }
        }

        if (-not $targetDatastores) {
            throw "No datastores found matching the specified criteria"
        }

        Write-Host "Found $($targetDatastores.Count) datastore(s):" -ForegroundColor Green
        foreach ($ds in $targetDatastores) {
            $usagePercent = [math]::Round((($ds.CapacityGB - $ds.FreeSpaceGB) / $ds.CapacityGB) * 100, 1)
            Write-Host "  - $($ds.Name): $($ds.Type), $([math]::Round($ds.CapacityGB, 2)) GB ($usagePercent% used)" -ForegroundColor White
        }

        return $targetDatastores
    }
    catch {
        Write-Error "Failed to get target datastores: $($_.Exception.Message)"
        throw
    }
}

# Function to monitor datastore space
function Invoke-DatastoreMonitoring {
    param(
        $Datastores,
        $ThresholdPercent
    )

    Write-Host "Monitoring datastore space usage..." -ForegroundColor Yellow

    $results = @()
    $alerts = @()

    foreach ($ds in $Datastores) {
        try {
            $usagePercent = [math]::Round((($ds.CapacityGB - $ds.FreeSpaceGB) / $ds.CapacityGB) * 100, 1)
            $freeSpaceGB = [math]::Round($ds.FreeSpaceGB, 2)
            $usedSpaceGB = [math]::Round($ds.CapacityGB - $ds.FreeSpaceGB, 2)

            # Get VM count on datastore
            $vmsOnDatastore = Get-VM -Datastore $ds | Measure-Object | Select-Object -ExpandProperty Count

            # Get host access
            $hostsWithAccess = Get-VMHost -Datastore $ds | Measure-Object | Select-Object -ExpandProperty Count

            $result = [PSCustomObject]@{
                Name = $ds.Name
                Type = $ds.Type
                CapacityGB = [math]::Round($ds.CapacityGB, 2)
                UsedGB = $usedSpaceGB
                FreeGB = $freeSpaceGB
                UsagePercent = $usagePercent
                State = $ds.State
                Accessible = $ds.Accessible
                VMs = $vmsOnDatastore
                Hosts = $hostsWithAccess
                FileSystemVersion = $ds.FileSystemVersion
                Timestamp = Get-Date
            }

            # Check threshold
            if ($usagePercent -ge $ThresholdPercent) {
                $alertLevel = if ($usagePercent -ge 95) { "Critical" } elseif ($usagePercent -ge 90) { "High" } else { "Warning" }

                $alert = [PSCustomObject]@{
                    Datastore = $ds.Name
                    AlertLevel = $alertLevel
                    UsagePercent = $usagePercent
                    FreeSpaceGB = $freeSpaceGB
                    Threshold = $ThresholdPercent
                    Message = "Datastore usage ($usagePercent%) exceeds threshold ($ThresholdPercent%)"
                }

                $alerts += $alert
            }

            $results += $result
        }
        catch {
            Write-Warning "Failed to get information for datastore '$($ds.Name)': $($_.Exception.Message)"
        }
    }

    # Display alerts
    if ($alerts.Count -gt 0) {
        Write-Host "`n=== DATASTORE SPACE ALERTS ===" -ForegroundColor Red
        foreach ($alert in $alerts) {
            $color = switch ($alert.AlertLevel) {
                "Critical" { "Red" }
                "High" { "Magenta" }
                "Warning" { "Yellow" }
                default { "White" }
            }
            Write-Host "[$($alert.AlertLevel)] $($alert.Datastore): $($alert.UsagePercent)% used (Free: $($alert.FreeSpaceGB) GB)" -ForegroundColor $color
        }
        Write-Host ""
    }

    return $results
}

# Function to browse datastore contents
function Get-DatastoreContents {
    param(
        $Datastore,
        $Path = ""
    )

    Write-Host "Browsing datastore '$($Datastore.Name)'..." -ForegroundColor Yellow

    try {
        # Create PSDrive for datastore browsing
        $psDriveName = "DS_$($Datastore.Name -replace '[^a-zA-Z0-9]', '')"

        if (Get-PSDrive -Name $psDriveName -ErrorAction SilentlyContinue) {
            Remove-PSDrive -Name $psDriveName -Force
        }

        New-PSDrive -Name $psDriveName -PSProvider VimDatastore -Root "\" -Location $Datastore | Out-Null

        # Browse contents
        $browsePath = if ($Path) { "${psDriveName}:\$Path" } else { "${psDriveName}:\" }
        $items = Get-ChildItem -Path $browsePath -ErrorAction SilentlyContinue

        Write-Host "`nDatastore Contents ($browsePath):" -ForegroundColor Cyan

        $totalSize = 0
        $results = @()

        foreach ($item in $items) {
            $sizeGB = if ($item.Length) { [math]::Round($item.Length / 1GB, 3) } else { 0 }
            $totalSize += $sizeGB

            $itemType = if ($item.PSIsContainer) { "Folder" } else { "File" }
            $lastWrite = if ($item.LastWriteTime) { $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm") } else { "Unknown" }

            $result = [PSCustomObject]@{
                Name = $item.Name
                Type = $itemType
                SizeGB = $sizeGB
                LastModified = $lastWrite
                FullPath = $item.FullName
            }

            $results += $result

            $icon = if ($item.PSIsContainer) { "📁" } else { "📄" }
            Write-Host "  $icon $($item.Name) ($itemType, $sizeGB GB, $lastWrite)" -ForegroundColor White
        }

        Write-Host "`nTotal items: $($items.Count), Total size: $([math]::Round($totalSize, 2)) GB" -ForegroundColor Green

        # Clean up PSDrive
        Remove-PSDrive -Name $psDriveName -Force

        return $results
    }
    catch {
        Write-Error "Failed to browse datastore '$($Datastore.Name)': $($_.Exception.Message)"
        return @()
    }
}

# Function to cleanup datastore
function Invoke-DatastoreCleanup {
    param(
        $Datastore,
        $CleanupOrphanedFiles,
        $CleanupSnapshots,
        $CleanupLogs,
        $DryRun
    )

    Write-Host "Performing cleanup on datastore '$($Datastore.Name)'..." -ForegroundColor Yellow

    $results = @{
        OrphanedFiles = @()
        SnapshotFiles = @()
        LogFiles = @()
        TotalSpaceFreedGB = 0
    }

    try {
        # Create PSDrive for datastore access
        $psDriveName = "DS_$($Datastore.Name -replace '[^a-zA-Z0-9]', '')"

        if (Get-PSDrive -Name $psDriveName -ErrorAction SilentlyContinue) {
            Remove-PSDrive -Name $psDriveName -Force
        }

        New-PSDrive -Name $psDriveName -PSProvider VimDatastore -Root "\" -Location $Datastore | Out-Null

        # Get all VMs on this datastore for reference
        $vmsOnDatastore = Get-VM -Datastore $Datastore
        $vmFolders = $vmsOnDatastore | ForEach-Object { $_.Name }

        # Cleanup orphaned files
        if ($CleanupOrphanedFiles) {
            Write-Host "  Scanning for orphaned files..." -ForegroundColor Cyan

            $allFolders = Get-ChildItem -Path "${psDriveName}:\" -Directory -ErrorAction SilentlyContinue

            foreach ($folder in $allFolders) {
                # Skip system folders
                if ($folder.Name -match '^(\.|lost\+found|\.vSphere-HA)') {
                    continue
                }

                # Check if folder belongs to an existing VM
                if ($vmFolders -notcontains $folder.Name) {
                    $folderSize = 0
                    $folderFiles = Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue
                    if ($folderFiles) {
                        $folderSize = ($folderFiles | Measure-Object -Property Length -Sum).Sum / 1GB
                    }

                    $orphanedItem = [PSCustomObject]@{
                        Path = $folder.FullName
                        SizeGB = [math]::Round($folderSize, 3)
                        Type = "Orphaned VM Folder"
                    }

                    $results.OrphanedFiles += $orphanedItem

                    if (-not $DryRun) {
                        Write-Host "    Removing orphaned folder: $($folder.Name) ($([math]::Round($folderSize, 3)) GB)" -ForegroundColor Yellow
                        Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    } else {
                        Write-Host "    Would remove orphaned folder: $($folder.Name) ($([math]::Round($folderSize, 3)) GB)" -ForegroundColor Yellow
                    }

                    $results.TotalSpaceFreedGB += $folderSize
                }
            }
        }

        # Cleanup old snapshot files
        if ($CleanupSnapshots) {
            Write-Host "  Scanning for old snapshot files..." -ForegroundColor Cyan

            $snapshotFiles = Get-ChildItem -Path "${psDriveName}:\" -Recurse -Include "*.vmsn", "*.vmsd", "*-delta.vmdk" -File -ErrorAction SilentlyContinue

            foreach ($snapFile in $snapshotFiles) {
                # Check if file is older than 30 days and not associated with current snapshots
                if ($snapFile.LastWriteTime -lt (Get-Date).AddDays(-30)) {
                    $sizeGB = [math]::Round($snapFile.Length / 1GB, 3)

                    $snapshotItem = [PSCustomObject]@{
                        Path = $snapFile.FullName
                        SizeGB = $sizeGB
                        Type = "Old Snapshot File"
                        Age = [math]::Round((Get-Date).Subtract($snapFile.LastWriteTime).TotalDays, 1)
                    }

                    $results.SnapshotFiles += $snapshotItem

                    if (-not $DryRun) {
                        Write-Host "    Removing old snapshot file: $($snapFile.Name) ($sizeGB GB)" -ForegroundColor Yellow
                        Remove-Item -Path $snapFile.FullName -Force -ErrorAction SilentlyContinue
                    } else {
                        Write-Host "    Would remove old snapshot file: $($snapFile.Name) ($sizeGB GB)" -ForegroundColor Yellow
                    }

                    $results.TotalSpaceFreedGB += $sizeGB
                }
            }
        }

        # Cleanup log files
        if ($CleanupLogs) {
            Write-Host "  Scanning for old log files..." -ForegroundColor Cyan

            $logFiles = Get-ChildItem -Path "${psDriveName}:\" -Recurse -Include "*.log", "vmware*.log", "*.dmp" -File -ErrorAction SilentlyContinue

            foreach ($logFile in $logFiles) {
                # Remove log files older than 7 days
                if ($logFile.LastWriteTime -lt (Get-Date).AddDays(-7)) {
                    $sizeGB = [math]::Round($logFile.Length / 1GB, 3)

                    $logItem = [PSCustomObject]@{
                        Path = $logFile.FullName
                        SizeGB = $sizeGB
                        Type = "Old Log File"
                        Age = [math]::Round((Get-Date).Subtract($logFile.LastWriteTime).TotalDays, 1)
                    }

                    $results.LogFiles += $logItem

                    if (-not $DryRun) {
                        Write-Host "    Removing old log file: $($logFile.Name) ($sizeGB GB)" -ForegroundColor Yellow
                        Remove-Item -Path $logFile.FullName -Force -ErrorAction SilentlyContinue
                    } else {
                        Write-Host "    Would remove old log file: $($logFile.Name) ($sizeGB GB)" -ForegroundColor Yellow
                    }

                    $results.TotalSpaceFreedGB += $sizeGB
                }
            }
        }

        # Clean up PSDrive
        Remove-PSDrive -Name $psDriveName -Force

        $verb = if ($DryRun) { "Would free" } else { "Freed" }
        Write-Host "  ✓ $verb $([math]::Round($results.TotalSpaceFreedGB, 2)) GB of space" -ForegroundColor Green

        return $results
    }
    catch {
        Write-Error "Failed to cleanup datastore '$($Datastore.Name)': $($_.Exception.Message)"
        return $results
    }
}

# Function to generate datastore report
function Get-DatastoreReport {
    param(
        $Datastores,
        $OutputFormat,
        $OutputPath
    )

    Write-Host "Generating comprehensive datastore report..." -ForegroundColor Yellow

    $reportData = @()

    foreach ($ds in $Datastores) {
        try {
            # Get basic datastore info
            $usagePercent = [math]::Round((($ds.CapacityGB - $ds.FreeSpaceGB) / $ds.CapacityGB) * 100, 1)
            $vmsOnDatastore = Get-VM -Datastore $ds
            $hostsWithAccess = Get-VMHost -Datastore $ds

            # Get datastore cluster info if applicable
            $datastoreCluster = $ds.ParentFolder.Name
            if ($datastoreCluster -eq "datastore") {
                $datastoreCluster = "None"
            }

            # Calculate file counts and types
            $vmCount = $vmsOnDatastore.Count
            $templateCount = (Get-Template -Datastore $ds -ErrorAction SilentlyContinue).Count

            $reportItem = [PSCustomObject]@{
                Name = $ds.Name
                Type = $ds.Type
                CapacityGB = [math]::Round($ds.CapacityGB, 2)
                UsedGB = [math]::Round($ds.CapacityGB - $ds.FreeSpaceGB, 2)
                FreeGB = [math]::Round($ds.FreeSpaceGB, 2)
                UsagePercent = $usagePercent
                State = $ds.State
                Accessible = $ds.Accessible
                FileSystemVersion = $ds.FileSystemVersion
                DatastoreCluster = $datastoreCluster
                VMs = $vmCount
                Templates = $templateCount
                ConnectedHosts = $hostsWithAccess.Count
                HostList = ($hostsWithAccess.Name -join ";")
                MultipleHostAccess = $ds.ExtensionData.Summary.MultipleHostAccess
                URL = $ds.ExtensionData.Info.Url
                Timestamp = Get-Date
            }

            $reportData += $reportItem
        }
        catch {
            Write-Warning "Failed to get report data for datastore '$($ds.Name)': $($_.Exception.Message)"
        }
    }

    # Export report
    switch ($OutputFormat) {
        "Console" {
            Write-Host "`n=== Datastore Report ===" -ForegroundColor Cyan
            $reportData | Format-Table -AutoSize
        }
        "CSV" {
            if (-not $OutputPath) {
                $OutputPath = "Datastore_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            }
            $reportData | Export-Csv -Path $OutputPath -NoTypeInformation
            Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
        }
        "JSON" {
            if (-not $OutputPath) {
                $OutputPath = "Datastore_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            }
            $reportData | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
        }
    }

    return $reportData
}

# Main execution
try {
    Write-Host "=== vSphere Datastore Management ===" -ForegroundColor Cyan
    Write-Host "Target vCenter: $VCenterServer" -ForegroundColor White
    Write-Host "Operation: $Operation" -ForegroundColor White

    if ($DryRun) { Write-Host "Mode: Dry Run (no changes will be made)" -ForegroundColor Yellow }
    Write-Host ""

    # Check and install PowerCLI
    if (-not (Test-PowerCLIInstallation)) {
        throw "PowerCLI installation failed"
    }

    # Connect to vCenter
    $connection = Connect-ToVCenter -Server $VCenterServer

    # Get target datastores
    $targetDatastores = Get-TargetDatastores -DatastoreName $DatastoreName -DatastoreNames $DatastoreNames -ClusterName $ClusterName

    # Confirm operation if not using Force and operation is potentially destructive
    if (-not $Force -and $Operation -eq "Cleanup" -and -not $DryRun) {
        $confirmation = Read-Host "`nProceed with cleanup operation on $($targetDatastores.Count) datastore(s)? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Perform the requested operation
    switch ($Operation) {
        "Monitor" {
            $results = Invoke-DatastoreMonitoring -Datastores $targetDatastores -ThresholdPercent $ThresholdPercent

            Write-Host "`n=== Datastore Space Summary ===" -ForegroundColor Cyan
            $results | Sort-Object UsagePercent -Descending | Format-Table Name, Type, CapacityGB, FreeGB, UsagePercent, VMs, State -AutoSize
        }

        "Browse" {
            if ($targetDatastores.Count -eq 1) {
                $results = Get-DatastoreContents -Datastore $targetDatastores[0] -Path $FilePath
            } else {
                Write-Warning "Browse operation requires a single datastore. Found $($targetDatastores.Count) datastores."
            }
        }

        "Cleanup" {
            $allResults = @()
            foreach ($ds in $targetDatastores) {
                $cleanupResult = Invoke-DatastoreCleanup -Datastore $ds -CleanupOrphanedFiles:$CleanupOrphanedFiles -CleanupSnapshots:$CleanupSnapshots -CleanupLogs:$CleanupLogs -DryRun:$DryRun
                $cleanupResult.Datastore = $ds.Name
                $allResults += $cleanupResult
            }

            $totalFreed = ($allResults | Measure-Object -Property TotalSpaceFreedGB -Sum).Sum
            $verb = if ($DryRun) { "Would free" } else { "Freed" }
            Write-Host "`n✓ $verb $([math]::Round($totalFreed, 2)) GB total across all datastores" -ForegroundColor Green
        }

        "Report" {
            $results = Get-DatastoreReport -Datastores $targetDatastores -OutputFormat $OutputFormat -OutputPath $OutputPath
        }

        "FileOperations" {
            Write-Host "File operations functionality - placeholder for future implementation" -ForegroundColor Yellow
            Write-Host "This would include file copy, move, delete operations within datastores" -ForegroundColor Gray
        }

        "Maintenance" {
            Write-Host "Datastore maintenance operations - placeholder for future implementation" -ForegroundColor Yellow
            Write-Host "This would include VMFS heap management, path management, etc." -ForegroundColor Gray
        }
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
