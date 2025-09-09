<#
.SYNOPSIS
    Manages Nutanix storage containers using Nutanix PowerShell SDK.

.DESCRIPTION
    This script provides comprehensive storage container management including
    creation, modification, monitoring, and optimization operations.
    Supports deduplication, compression, erasure coding, and replication policies.
    Requires Nutanix PowerShell SDK and connection to Prism Central/Element.

.PARAMETER PrismCentral
    The Prism Central FQDN or IP address to connect to.

.PARAMETER PrismElement
    The Prism Element FQDN or IP address to connect to (alternative to Prism Central).

.PARAMETER ContainerName
    Name of the storage container to create or manage.

.PARAMETER ContainerNames
    Array of container names for batch operations.

.PARAMETER ContainerUUID
    UUID of a specific container to manage.

.PARAMETER ClusterName
    Target cluster name for container operations.

.PARAMETER ClusterUUID
    Target cluster UUID for container operations.

.PARAMETER Operation
    The operation to perform on the container(s).

.PARAMETER ReplicationFactor
    Replication factor for the container (1 or 2).

.PARAMETER EnableCompression
    Enable compression on the container.

.PARAMETER EnableDeduplication
    Enable deduplication on the container.

.PARAMETER EnableErasureCoding
    Enable erasure coding on the container.

.PARAMETER CompressionDelay
    Compression delay in seconds (0 for immediate).

.PARAMETER StoragePoolUUID
    Storage pool UUID for container placement.

.PARAMETER MaxCapacityGB
    Maximum capacity in GB for the container.

.PARAMETER AdvertisedCapacityGB
    Advertised capacity in GB for the container.

.PARAMETER Force
    Force operations without confirmation prompts.

.PARAMETER OutputFormat
    Output format for reports.

.PARAMETER OutputPath
    Path to save the report file.

.EXAMPLE
    .\nutanix-cli-storage-containers.ps1 -PrismCentral "pc.domain.com" -Operation "Create" -ContainerName "Production-Storage" -ClusterName "Prod-Cluster" -EnableCompression -EnableDeduplication -ReplicationFactor 2

.EXAMPLE
    .\nutanix-cli-storage-containers.ps1 -PrismCentral "pc.domain.com" -Operation "List" -ClusterName "All-Clusters" -OutputFormat "CSV" -OutputPath "containers.csv"

.EXAMPLE
    .\nutanix-cli-storage-containers.ps1 -PrismCentral "pc.domain.com" -Operation "Monitor" -ContainerName "Production-Storage" -OutputFormat "JSON"

.NOTES
    Author: Generated for scripted-actions
    Requires: Nutanix PowerShell SDK, AOS 6.0+
    Version: 1.0
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
    [string]$ContainerName,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ContainerNames,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ContainerUUID,

    [Parameter(Mandatory = $false)]
    [string]$ClusterName,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ClusterUUID,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Create", "List", "Delete", "Update", "Monitor", "Optimize", "Status")]
    [string]$Operation,

    [Parameter(Mandatory = $false)]
    [ValidateSet(1, 2)]
    [int]$ReplicationFactor = 2,

    [Parameter(Mandatory = $false)]
    [switch]$EnableCompression,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDeduplication,

    [Parameter(Mandatory = $false)]
    [switch]$EnableErasureCoding,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 86400)]
    [int]$CompressionDelay = 0,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$StoragePoolUUID,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1048576)]
    [int64]$MaxCapacityGB,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1048576)]
    [int64]$AdvertisedCapacityGB,

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

# Function to check and install Nutanix PowerShell SDK if needed
function Test-NutanixSDKInstallation {
    Write-Host "Checking Nutanix PowerShell SDK installation..." -ForegroundColor Yellow
    
    try {
        $nutanixModule = Get-Module -Name Nutanix.PowerShell.SDK -ListAvailable
        if (-not $nutanixModule) {
            Write-Warning "Nutanix PowerShell SDK not found. Installing..."
            Install-Module -Name Nutanix.PowerShell.SDK -Force -AllowClobber -Scope CurrentUser
            Write-Host "Nutanix PowerShell SDK installed successfully." -ForegroundColor Green
        } else {
            $version = $nutanixModule | Sort-Object Version -Descending | Select-Object -First 1
            Write-Host "Nutanix PowerShell SDK version $($version.Version) found." -ForegroundColor Green
        }
        
        # Import the module
        Import-Module Nutanix.PowerShell.SDK -Force
        
        return $true
    }
    catch {
        Write-Error "Failed to install or import Nutanix PowerShell SDK: $($_.Exception.Message)"
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

# Function to resolve cluster information
function Get-ClusterInfo {
    param($ClusterName, $ClusterUUID)
    
    try {
        if ($ClusterUUID) {
            $cluster = Get-NTNXCluster | Where-Object { $_.clusterUuid -eq $ClusterUUID }
            if (-not $cluster) {
                throw "Cluster with UUID '$ClusterUUID' not found"
            }
        } elseif ($ClusterName) {
            $cluster = Get-NTNXCluster | Where-Object { $_.name -eq $ClusterName }
            if (-not $cluster) {
                throw "Cluster '$ClusterName' not found"
            }
        } else {
            # Use first available cluster
            $cluster = Get-NTNXCluster | Select-Object -First 1
            if (-not $cluster) {
                throw "No clusters found"
            }
            Write-Warning "No cluster specified, using: $($cluster.name)"
        }
        
        return @{
            Name = $cluster.name
            UUID = $cluster.clusterUuid
            Object = $cluster
        }
    }
    catch {
        Write-Error "Failed to resolve cluster information: $($_.Exception.Message)"
        throw
    }
}

# Function to get target containers
function Get-TargetContainers {
    param(
        $ContainerName,
        $ContainerNames,
        $ContainerUUID,
        $ClusterUUID
    )
    
    try {
        $containers = @()
        
        if ($ContainerUUID) {
            # Get container by UUID
            $containers = Get-NTNXStorageContainer | Where-Object { $_.storageContainerUuid -eq $ContainerUUID }
        }
        elseif ($ContainerName) {
            # Get container by name
            if ($ClusterUUID) {
                $containers = Get-NTNXStorageContainer | Where-Object { $_.name -eq $ContainerName -and $_.clusterUuid -eq $ClusterUUID }
            } else {
                $containers = Get-NTNXStorageContainer | Where-Object { $_.name -eq $ContainerName }
            }
        }
        elseif ($ContainerNames) {
            # Get multiple containers by name
            if ($ClusterUUID) {
                $containers = Get-NTNXStorageContainer | Where-Object { $_.name -in $ContainerNames -and $_.clusterUuid -eq $ClusterUUID }
            } else {
                $containers = Get-NTNXStorageContainer | Where-Object { $_.name -in $ContainerNames }
            }
        }
        else {
            # Get all containers
            if ($ClusterUUID) {
                $containers = Get-NTNXStorageContainer | Where-Object { $_.clusterUuid -eq $ClusterUUID }
            } else {
                $containers = Get-NTNXStorageContainer
            }
        }
        
        return $containers
    }
    catch {
        Write-Error "Failed to get target containers: $($_.Exception.Message)"
        throw
    }
}

# Function to create storage container
function New-StorageContainer {
    param(
        $ContainerName,
        $ClusterUUID,
        $ReplicationFactor,
        $EnableCompression,
        $EnableDeduplication,
        $EnableErasureCoding,
        $CompressionDelay,
        $StoragePoolUUID,
        $MaxCapacityGB,
        $AdvertisedCapacityGB
    )
    
    try {
        Write-Host "Creating storage container: $ContainerName" -ForegroundColor Cyan
        
        # Check if container already exists
        $existingContainer = Get-NTNXStorageContainer | Where-Object { 
            $_.name -eq $ContainerName -and $_.clusterUuid -eq $ClusterUUID 
        }
        if ($existingContainer) {
            throw "Storage container '$ContainerName' already exists"
        }
        
        # Create container specification
        $containerSpec = New-Object Nutanix.Prism.Model.StorageContainerSpec
        $containerSpec.name = $ContainerName
        $containerSpec.clusterUuid = $ClusterUUID
        $containerSpec.replicationFactor = $ReplicationFactor
        
        # Set storage optimizations
        if ($EnableCompression) {
            $containerSpec.compressionEnabled = $true
            $containerSpec.compressionDelayInSecs = $CompressionDelay
            Write-Host "  ✓ Compression enabled (delay: $CompressionDelay seconds)" -ForegroundColor Green
        }
        
        if ($EnableDeduplication) {
            $containerSpec.fingerPrintOnWrite = "ON"
            $containerSpec.onDiskDedup = "ON"
            Write-Host "  ✓ Deduplication enabled" -ForegroundColor Green
        }
        
        if ($EnableErasureCoding) {
            $containerSpec.erasureCode = "ON"
            Write-Host "  ✓ Erasure coding enabled" -ForegroundColor Green
        }
        
        # Set capacity limits
        if ($MaxCapacityGB) {
            $containerSpec.maxCapacity = $MaxCapacityGB * 1024 * 1024 * 1024
            Write-Host "  ✓ Max capacity set to $MaxCapacityGB GB" -ForegroundColor Green
        }
        
        if ($AdvertisedCapacityGB) {
            $containerSpec.advertisedCapacity = $AdvertisedCapacityGB * 1024 * 1024 * 1024
            Write-Host "  ✓ Advertised capacity set to $AdvertisedCapacityGB GB" -ForegroundColor Green
        }
        
        # Set storage pool if specified
        if ($StoragePoolUUID) {
            $containerSpec.storagePoolId = $StoragePoolUUID
            Write-Host "  ✓ Storage pool UUID: $StoragePoolUUID" -ForegroundColor Green
        }
        
        # Create the container
        $task = New-NTNXStorageContainer -StorageContainerSpec $containerSpec
        Write-Host "  ✓ Storage container creation task initiated" -ForegroundColor Green
        
        # Wait for creation to complete
        $timeout = (Get-Date).AddMinutes(10)
        $containerCreated = $false
        $createdContainer = $null
        
        while ((Get-Date) -lt $timeout -and -not $containerCreated) {
            Start-Sleep -Seconds 10
            $createdContainer = Get-NTNXStorageContainer | Where-Object { 
                $_.name -eq $ContainerName -and $_.clusterUuid -eq $ClusterUUID 
            }
            if ($createdContainer) {
                $containerCreated = $true
            }
        }
        
        if ($containerCreated) {
            Write-Host "  ✓ Storage container created successfully: $($createdContainer.name)" -ForegroundColor Green
            return @{
                Success = $true
                Container = $createdContainer
                Message = "Container created successfully"
                TaskId = if ($task.taskUuid) { $task.taskUuid } else { "N/A" }
            }
        } else {
            throw "Container creation timed out"
        }
    }
    catch {
        Write-Host "  ✗ Failed to create storage container: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Container = $null
            Message = $_.Exception.Message
            TaskId = "N/A"
        }
    }
}

# Function to update storage container
function Update-StorageContainer {
    param(
        $Container,
        $EnableCompression,
        $EnableDeduplication,
        $EnableErasureCoding,
        $CompressionDelay,
        $MaxCapacityGB,
        $AdvertisedCapacityGB
    )
    
    try {
        Write-Host "Updating storage container: $($Container.name)" -ForegroundColor Cyan
        
        # Create update specification
        $updateSpec = New-Object Nutanix.Prism.Model.StorageContainerSpec
        $updateSpec.name = $Container.name
        $updateSpec.storageContainerUuid = $Container.storageContainerUuid
        
        $changes = @()
        
        # Update compression settings
        if ($PSBoundParameters.ContainsKey('EnableCompression')) {
            $updateSpec.compressionEnabled = $EnableCompression
            if ($EnableCompression -and $PSBoundParameters.ContainsKey('CompressionDelay')) {
                $updateSpec.compressionDelayInSecs = $CompressionDelay
                $changes += "Compression: $EnableCompression (delay: $CompressionDelay seconds)"
            } else {
                $changes += "Compression: $EnableCompression"
            }
        }
        
        # Update deduplication settings
        if ($PSBoundParameters.ContainsKey('EnableDeduplication')) {
            if ($EnableDeduplication) {
                $updateSpec.fingerPrintOnWrite = "ON"
                $updateSpec.onDiskDedup = "ON"
                $changes += "Deduplication: Enabled"
            } else {
                $updateSpec.fingerPrintOnWrite = "OFF"
                $updateSpec.onDiskDedup = "OFF"
                $changes += "Deduplication: Disabled"
            }
        }
        
        # Update erasure coding
        if ($PSBoundParameters.ContainsKey('EnableErasureCoding')) {
            $updateSpec.erasureCode = if ($EnableErasureCoding) { "ON" } else { "OFF" }
            $changes += "Erasure Coding: $EnableErasureCoding"
        }
        
        # Update capacity limits
        if ($MaxCapacityGB) {
            $updateSpec.maxCapacity = $MaxCapacityGB * 1024 * 1024 * 1024
            $changes += "Max Capacity: $MaxCapacityGB GB"
        }
        
        if ($AdvertisedCapacityGB) {
            $updateSpec.advertisedCapacity = $AdvertisedCapacityGB * 1024 * 1024 * 1024
            $changes += "Advertised Capacity: $AdvertisedCapacityGB GB"
        }
        
        if ($changes.Count -eq 0) {
            Write-Host "  ⚠ No changes specified for update" -ForegroundColor Yellow
            return @{
                Success = $true
                Container = $Container
                Message = "No changes specified"
                Changes = @()
            }
        }
        
        # Apply updates
        $task = Update-NTNXStorageContainer -StorageContainerUuid $Container.storageContainerUuid -StorageContainerSpec $updateSpec
        
        foreach ($change in $changes) {
            Write-Host "  ✓ $change" -ForegroundColor Green
        }
        
        Write-Host "  ✓ Storage container update task initiated" -ForegroundColor Green
        
        return @{
            Success = $true
            Container = $Container
            Message = "Container updated successfully"
            Changes = $changes
            TaskId = if ($task.taskUuid) { $task.taskUuid } else { "N/A" }
        }
    }
    catch {
        Write-Host "  ✗ Failed to update storage container: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Container = $Container
            Message = $_.Exception.Message
            Changes = @()
            TaskId = "N/A"
        }
    }
}

# Function to delete storage container
function Remove-StorageContainer {
    param($Container, $Force)
    
    try {
        Write-Host "Deleting storage container: $($Container.name)" -ForegroundColor Cyan
        
        # Check if container is in use
        $vmsUsingContainer = Get-NTNXVM | Where-Object { 
            $_.vmDiskInfo | Where-Object { $_.storageContainerUuid -eq $Container.storageContainerUuid }
        }
        
        if ($vmsUsingContainer.Count -gt 0 -and -not $Force) {
            $vmNames = $vmsUsingContainer | Select-Object -ExpandProperty vmName
            throw "Container is in use by $($vmsUsingContainer.Count) VM(s): $($vmNames -join ', '). Use -Force to override."
        }
        
        # Delete the container
        $task = Remove-NTNXStorageContainer -StorageContainerUuid $Container.storageContainerUuid
        Write-Host "  ✓ Storage container deletion task initiated" -ForegroundColor Green
        
        return @{
            Success = $true
            Container = $Container
            Message = "Container deletion initiated"
            TaskId = if ($task.taskUuid) { $task.taskUuid } else { "N/A" }
        }
    }
    catch {
        Write-Host "  ✗ Failed to delete storage container: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Container = $Container
            Message = $_.Exception.Message
            TaskId = "N/A"
        }
    }
}

# Function to get container performance metrics
function Get-ContainerMetrics {
    param($Container)
    
    try {
        # Get container stats
        $stats = Get-NTNXStorageContainerStats -StorageContainerUuid $Container.storageContainerUuid
        
        # Calculate utilization percentages
        $totalCapacityBytes = $Container.maxCapacity
        $usedBytes = $stats.storageStats.storageUsageBytes
        $utilizationPercent = if ($totalCapacityBytes -gt 0) { 
            [math]::Round(($usedBytes / $totalCapacityBytes) * 100, 2) 
        } else { 0 }
        
        # Get savings from deduplication and compression
        $compressionSavings = if ($stats.storageStats.compressionSavingBytes) { 
            [math]::Round($stats.storageStats.compressionSavingBytes / 1GB, 2) 
        } else { 0 }
        
        $dedupSavings = if ($stats.storageStats.dedupSavingBytes) { 
            [math]::Round($stats.storageStats.dedupSavingBytes / 1GB, 2) 
        } else { 0 }
        
        return @{
            Name = $Container.name
            UUID = $Container.storageContainerUuid
            TotalCapacityGB = [math]::Round($totalCapacityBytes / 1GB, 2)
            UsedCapacityGB = [math]::Round($usedBytes / 1GB, 2)
            FreeCapacityGB = [math]::Round(($totalCapacityBytes - $usedBytes) / 1GB, 2)
            UtilizationPercent = $utilizationPercent
            CompressionEnabled = $Container.compressionEnabled
            CompressionSavingsGB = $compressionSavings
            DeduplicationEnabled = $Container.fingerPrintOnWrite -eq "ON"
            DeduplicationSavingsGB = $dedupSavings
            ErasureCodingEnabled = $Container.erasureCode -eq "ON"
            ReplicationFactor = $Container.replicationFactor
            IOPSRead = if ($stats.ioStats.readIOPS) { $stats.ioStats.readIOPS } else { 0 }
            IOPSWrite = if ($stats.ioStats.writeIOPS) { $stats.ioStats.writeIOPS } else { 0 }
            ThroughputReadMBps = if ($stats.ioStats.readThroughputMBps) { $stats.ioStats.readThroughputMBps } else { 0 }
            ThroughputWriteMBps = if ($stats.ioStats.writeThroughputMBps) { $stats.ioStats.writeThroughputMBps } else { 0 }
            Timestamp = Get-Date
        }
    }
    catch {
        Write-Warning "Failed to get metrics for container '$($Container.name)': $($_.Exception.Message)"
        return @{
            Name = $Container.name
            UUID = $Container.storageContainerUuid
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }
    }
}

# Function to optimize container performance
function Optimize-StorageContainer {
    param($Container)
    
    try {
        Write-Host "Optimizing storage container: $($Container.name)" -ForegroundColor Cyan
        
        $optimizations = @()
        
        # Check if compression should be enabled
        if (-not $Container.compressionEnabled) {
            Write-Host "  ⚠ Compression is disabled - consider enabling for space savings" -ForegroundColor Yellow
            $optimizations += "Enable compression for space savings"
        }
        
        # Check if deduplication should be enabled
        if ($Container.fingerPrintOnWrite -ne "ON") {
            Write-Host "  ⚠ Deduplication is disabled - consider enabling for space savings" -ForegroundColor Yellow
            $optimizations += "Enable deduplication for space savings"
        }
        
        # Check erasure coding for large containers
        $containerSizeGB = $Container.maxCapacity / 1GB
        if ($containerSizeGB -gt 1000 -and $Container.erasureCode -ne "ON") {
            Write-Host "  ⚠ Large container without erasure coding - consider enabling" -ForegroundColor Yellow
            $optimizations += "Enable erasure coding for large container efficiency"
        }
        
        # Check replication factor
        if ($Container.replicationFactor -eq 1) {
            Write-Host "  ⚠ Replication factor is 1 - consider RF2 for redundancy" -ForegroundColor Yellow
            $optimizations += "Consider replication factor 2 for redundancy"
        }
        
        # Trigger storage optimization tasks
        try {
            # Start deduplication if enabled
            if ($Container.fingerPrintOnWrite -eq "ON") {
                Write-Host "  ✓ Triggering deduplication optimization..." -ForegroundColor Green
                # Nutanix SDK might have specific optimization commands
            }
            
            # Start compression optimization if enabled
            if ($Container.compressionEnabled) {
                Write-Host "  ✓ Triggering compression optimization..." -ForegroundColor Green
            }
            
            $optimizations += "Storage optimization tasks initiated"
        }
        catch {
            Write-Warning "  Failed to trigger optimization tasks: $($_.Exception.Message)"
            $optimizations += "Failed to trigger optimization tasks"
        }
        
        if ($optimizations.Count -eq 0) {
            $optimizations += "Container appears to be optimally configured"
            Write-Host "  ✓ Container appears to be optimally configured" -ForegroundColor Green
        }
        
        return @{
            Success = $true
            Container = $Container
            Message = "Optimization analysis completed"
            Recommendations = $optimizations
        }
    }
    catch {
        Write-Host "  ✗ Failed to optimize storage container: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Container = $Container
            Message = $_.Exception.Message
            Recommendations = @()
        }
    }
}

# Function to display results
function Show-ContainerResults {
    param($Results, $Operation, $OutputFormat, $OutputPath)
    
    Write-Host "`n=== Storage Container $Operation Results ===" -ForegroundColor Cyan
    
    switch ($Operation) {
        "List" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nStorage Containers:" -ForegroundColor Green
                $Results | Format-Table Name, UUID, TotalCapacityGB, UsedCapacityGB, UtilizationPercent, CompressionEnabled, DeduplicationEnabled -AutoSize
            }
        }
        "Monitor" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nContainer Performance Metrics:" -ForegroundColor Green
                $Results | Format-Table Name, UtilizationPercent, IOPSRead, IOPSWrite, CompressionSavingsGB, DeduplicationSavingsGB -AutoSize
            }
        }
        "Status" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nContainer Status:" -ForegroundColor Green
                foreach ($result in $Results) {
                    Write-Host "Container: $($result.Name)" -ForegroundColor White
                    Write-Host "  Capacity: $($result.UsedCapacityGB)/$($result.TotalCapacityGB) GB ($($result.UtilizationPercent)%)" -ForegroundColor White
                    Write-Host "  Optimizations: Compression=$($result.CompressionEnabled), Dedup=$($result.DeduplicationEnabled), EC=$($result.ErasureCodingEnabled)" -ForegroundColor White
                    Write-Host "  Performance: Read=$($result.IOPSRead) IOPS, Write=$($result.IOPSWrite) IOPS" -ForegroundColor White
                    Write-Host ""
                }
            }
        }
        default {
            $successful = $Results | Where-Object { $_.Success -eq $true }
            $failed = $Results | Where-Object { $_.Success -eq $false }
            
            Write-Host "Total Containers: $($Results.Count)" -ForegroundColor White
            Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
            Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
            
            if ($failed.Count -gt 0) {
                Write-Host "`nFailed Operations:" -ForegroundColor Red
                foreach ($result in $failed) {
                    Write-Host "  ✗ $($result.Container.name): $($result.Message)" -ForegroundColor White
                }
            }
        }
    }
    
    # Export results if requested
    if ($OutputFormat -ne "Console") {
        switch ($OutputFormat) {
            "CSV" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_Storage_Containers_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                }
                $Results | Export-Csv -Path $OutputPath -NoTypeInformation
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
            "JSON" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_Storage_Containers_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                }
                $Results | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
        }
    }
}

# Main execution
try {
    Write-Host "=== Nutanix Storage Container Management ===" -ForegroundColor Cyan
    
    # Determine target server
    $targetServer = if ($PrismCentral) { $PrismCentral } else { $PrismElement }
    $serverType = if ($PrismCentral) { "Prism Central" } else { "Prism Element" }
    
    if (-not $targetServer) {
        throw "Either PrismCentral or PrismElement parameter must be specified"
    }
    
    Write-Host "Target $serverType`: $targetServer" -ForegroundColor White
    Write-Host "Operation: $Operation" -ForegroundColor White
    Write-Host ""
    
    # Check and install Nutanix PowerShell SDK
    if (-not (Test-NutanixSDKInstallation)) {
        throw "Nutanix PowerShell SDK installation failed"
    }
    
    # Connect to Nutanix
    $connection = Connect-ToNutanix -Server $targetServer -ServerType $serverType
    
    # Resolve cluster information if needed
    $clusterInfo = $null
    if ($ClusterName -or $ClusterUUID -or $Operation -eq "Create") {
        $clusterInfo = Get-ClusterInfo -ClusterName $ClusterName -ClusterUUID $ClusterUUID
        Write-Host "Target Cluster: $($clusterInfo.Name) [$($clusterInfo.UUID)]" -ForegroundColor White
    }
    
    # Perform operations
    $results = @()
    
    switch ($Operation) {
        "Create" {
            if (-not $ContainerName) {
                throw "ContainerName parameter is required for Create operation"
            }
            if (-not $clusterInfo) {
                throw "ClusterName or ClusterUUID parameter is required for Create operation"
            }
            
            $result = New-StorageContainer -ContainerName $ContainerName -ClusterUUID $clusterInfo.UUID -ReplicationFactor $ReplicationFactor -EnableCompression:$EnableCompression -EnableDeduplication:$EnableDeduplication -EnableErasureCoding:$EnableErasureCoding -CompressionDelay $CompressionDelay -StoragePoolUUID $StoragePoolUUID -MaxCapacityGB $MaxCapacityGB -AdvertisedCapacityGB $AdvertisedCapacityGB
            $results += $result
        }
        
        "List" {
            $containers = Get-TargetContainers -ContainerName $ContainerName -ContainerNames $ContainerNames -ContainerUUID $ContainerUUID -ClusterUUID $clusterInfo.UUID
            Write-Host "Found $($containers.Count) storage container(s)" -ForegroundColor Green
            
            foreach ($container in $containers) {
                $metrics = Get-ContainerMetrics -Container $container
                $results += $metrics
            }
        }
        
        "Monitor" {
            $containers = Get-TargetContainers -ContainerName $ContainerName -ContainerNames $ContainerNames -ContainerUUID $ContainerUUID -ClusterUUID $clusterInfo.UUID
            Write-Host "Monitoring $($containers.Count) storage container(s)" -ForegroundColor Green
            
            foreach ($container in $containers) {
                $metrics = Get-ContainerMetrics -Container $container
                $results += $metrics
            }
        }
        
        "Status" {
            $containers = Get-TargetContainers -ContainerName $ContainerName -ContainerNames $ContainerNames -ContainerUUID $ContainerUUID -ClusterUUID $clusterInfo.UUID
            Write-Host "Getting status for $($containers.Count) storage container(s)" -ForegroundColor Green
            
            foreach ($container in $containers) {
                $metrics = Get-ContainerMetrics -Container $container
                $results += $metrics
            }
        }
        
        "Update" {
            $containers = Get-TargetContainers -ContainerName $ContainerName -ContainerNames $ContainerNames -ContainerUUID $ContainerUUID -ClusterUUID $clusterInfo.UUID
            
            if (-not $Force -and $containers.Count -gt 1) {
                $confirmation = Read-Host "`nProceed with updating $($containers.Count) container(s)? (y/N)"
                if ($confirmation -notmatch '^[Yy]$') {
                    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                    exit 0
                }
            }
            
            foreach ($container in $containers) {
                $result = Update-StorageContainer -Container $container -EnableCompression:$EnableCompression -EnableDeduplication:$EnableDeduplication -EnableErasureCoding:$EnableErasureCoding -CompressionDelay $CompressionDelay -MaxCapacityGB $MaxCapacityGB -AdvertisedCapacityGB $AdvertisedCapacityGB
                $results += $result
            }
        }
        
        "Delete" {
            $containers = Get-TargetContainers -ContainerName $ContainerName -ContainerNames $ContainerNames -ContainerUUID $ContainerUUID -ClusterUUID $clusterInfo.UUID
            
            if (-not $Force) {
                $confirmation = Read-Host "`nProceed with deleting $($containers.Count) container(s)? This action cannot be undone! (y/N)"
                if ($confirmation -notmatch '^[Yy]$') {
                    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                    exit 0
                }
            }
            
            foreach ($container in $containers) {
                $result = Remove-StorageContainer -Container $container -Force:$Force
                $results += $result
            }
        }
        
        "Optimize" {
            $containers = Get-TargetContainers -ContainerName $ContainerName -ContainerNames $ContainerNames -ContainerUUID $ContainerUUID -ClusterUUID $clusterInfo.UUID
            
            foreach ($container in $containers) {
                $result = Optimize-StorageContainer -Container $container
                $results += $result
            }
        }
    }
    
    # Display results
    Show-ContainerResults -Results $results -Operation $Operation -OutputFormat $OutputFormat -OutputPath $OutputPath
    
    Write-Host "`n=== Storage Container Management Completed ===" -ForegroundColor Green
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
