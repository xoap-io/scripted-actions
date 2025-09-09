<#
.SYNOPSIS
    Migrates VMs using vMotion and Storage vMotion in vSphere using PowerCLI.

.DESCRIPTION
    This script performs VM migration operations including vMotion (compute migration)
    and Storage vMotion (storage migration). Supports single VM and bulk operations
    with pre-migration validation and monitoring.
    Requires VMware PowerCLI and connection to vCenter Server.

.PARAMETER VCenterServer
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER VMName
    The name of the virtual machine to migrate. Supports wildcards.

.PARAMETER VMNames
    An array of specific VM names for batch migrations.

.PARAMETER MigrationType
    The type of migration to perform.

.PARAMETER DestinationHost
    The destination ESXi host for vMotion (required for vMotion/Both).

.PARAMETER DestinationDatastore
    The destination datastore for Storage vMotion (required for Storage/Both).

.PARAMETER DestinationCluster
    The destination cluster (alternative to specific host).

.PARAMETER Priority
    Migration priority level.

.PARAMETER WaitForCompletion
    Wait for migration tasks to complete.

.PARAMETER Force
    Force migration without confirmation prompts.

.PARAMETER ValidateOnly
    Only validate migration compatibility without performing migration.

.PARAMETER DRSRecommendations
    Apply DRS recommendations before migration.

.PARAMETER MaintenanceMode
    Put source host in maintenance mode after migration (for evacuations).

.EXAMPLE
    .\vsphere-cli-migrate-vm.ps1 -VCenterServer "vcenter.domain.com" -VMName "WebServer01" -MigrationType "vMotion" -DestinationHost "esx02.domain.com"

.EXAMPLE
    .\vsphere-cli-migrate-vm.ps1 -VCenterServer "vcenter.domain.com" -VMName "DatabaseVM" -MigrationType "Storage" -DestinationDatastore "SSD-Datastore2"

.EXAMPLE
    .\vsphere-cli-migrate-vm.ps1 -VCenterServer "vcenter.domain.com" -VMNames @("VM01","VM02","VM03") -MigrationType "Both" -DestinationCluster "NewCluster" -DestinationDatastore "NewDatastore" -Priority "High"

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

    [Parameter(Mandatory = $false, ParameterSetName = "SingleVM")]
    [ValidateNotNullOrEmpty()]
    [string]$VMName,

    [Parameter(Mandatory = $false, ParameterSetName = "MultipleVMs")]
    [ValidateNotNullOrEmpty()]
    [string[]]$VMNames,

    [Parameter(Mandatory = $true)]
    [ValidateSet("vMotion", "Storage", "Both")]
    [string]$MigrationType,

    [Parameter(Mandatory = $false)]
    [string]$DestinationHost,

    [Parameter(Mandatory = $false)]
    [string]$DestinationDatastore,

    [Parameter(Mandatory = $false)]
    [string]$DestinationCluster,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Low", "Normal", "High")]
    [string]$Priority = "Normal",

    [Parameter(Mandatory = $false)]
    [switch]$WaitForCompletion,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$ValidateOnly,

    [Parameter(Mandatory = $false)]
    [switch]$DRSRecommendations,

    [Parameter(Mandatory = $false)]
    [switch]$MaintenanceMode
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

# Function to get target VMs
function Get-TargetVMs {
    param(
        $VMName,
        $VMNames
    )
    
    Write-Host "Identifying target VMs..." -ForegroundColor Yellow
    
    try {
        $targetVMs = @()
        
        if ($VMName) {
            # Single VM or wildcard pattern
            $targetVMs = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        }
        elseif ($VMNames) {
            # Multiple specific VMs
            foreach ($name in $VMNames) {
                $vm = Get-VM -Name $name -ErrorAction SilentlyContinue
                if ($vm) {
                    $targetVMs += $vm
                } else {
                    Write-Warning "VM '$name' not found"
                }
            }
        }
        
        if (-not $targetVMs) {
            throw "No VMs found matching the specified criteria"
        }
        
        # Filter powered-on VMs for migration
        $poweredOnVMs = $targetVMs | Where-Object { $_.PowerState -eq "PoweredOn" }
        
        Write-Host "Found $($targetVMs.Count) VM(s), $($poweredOnVMs.Count) powered on:" -ForegroundColor Green
        foreach ($vm in $targetVMs) {
            $status = if ($vm.PowerState -eq "PoweredOn") { "✓" } else { "⚠" }
            Write-Host "  $status $($vm.Name) [$($vm.PowerState)] on $($vm.VMHost.Name)" -ForegroundColor White
        }
        
        return $poweredOnVMs
    }
    catch {
        Write-Error "Failed to get target VMs: $($_.Exception.Message)"
        throw
    }
}

# Function to validate migration targets
function Test-MigrationTargets {
    param(
        $MigrationType,
        $DestinationHost,
        $DestinationDatastore,
        $DestinationCluster
    )
    
    Write-Host "Validating migration targets..." -ForegroundColor Yellow
    
    $destHost = $null
    $destDatastore = $null
    $destCluster = $null
    
    # Validate destination host for vMotion
    if ($MigrationType -in @("vMotion", "Both")) {
        if ($DestinationHost) {
            $destHost = Get-VMHost -Name $DestinationHost -ErrorAction SilentlyContinue
            if (-not $destHost) {
                throw "Destination host '$DestinationHost' not found"
            }
            if ($destHost.ConnectionState -ne "Connected") {
                throw "Destination host '$DestinationHost' is not connected (State: $($destHost.ConnectionState))"
            }
            Write-Host "✓ Destination host '$DestinationHost' validated" -ForegroundColor Green
        }
        elseif ($DestinationCluster) {
            $destCluster = Get-Cluster -Name $DestinationCluster -ErrorAction SilentlyContinue
            if (-not $destCluster) {
                throw "Destination cluster '$DestinationCluster' not found"
            }
            Write-Host "✓ Destination cluster '$DestinationCluster' validated" -ForegroundColor Green
        }
        else {
            throw "Destination host or cluster required for vMotion migration"
        }
    }
    
    # Validate destination datastore for Storage vMotion
    if ($MigrationType -in @("Storage", "Both")) {
        if (-not $DestinationDatastore) {
            throw "Destination datastore required for Storage migration"
        }
        
        $destDatastore = Get-Datastore -Name $DestinationDatastore -ErrorAction SilentlyContinue
        if (-not $destDatastore) {
            throw "Destination datastore '$DestinationDatastore' not found"
        }
        
        $freeSpaceGB = [math]::Round($destDatastore.FreeSpaceGB, 2)
        Write-Host "✓ Destination datastore '$DestinationDatastore' validated (Free: $freeSpaceGB GB)" -ForegroundColor Green
    }
    
    return @{
        Host = $destHost
        Datastore = $destDatastore
        Cluster = $destCluster
    }
}

# Function to validate VM migration compatibility
function Test-VMMigrationCompatibility {
    param(
        $VM,
        $Targets,
        $MigrationType
    )
    
    $issues = @()
    
    try {
        # Check if VM is powered on
        if ($VM.PowerState -ne "PoweredOn") {
            $issues += "VM is not powered on"
        }
        
        # Check for snapshots (can affect some migrations)
        $snapshots = Get-Snapshot -VM $VM -ErrorAction SilentlyContinue
        if ($snapshots) {
            $issues += "VM has $($snapshots.Count) snapshot(s) which may affect migration"
        }
        
        # Check for CD/DVD connected
        $cdDrives = Get-CDDrive -VM $VM | Where-Object { $_.ConnectionState.Connected }
        if ($cdDrives) {
            $issues += "VM has connected CD/DVD drives"
        }
        
        # Check destination host compatibility (for vMotion)
        if ($MigrationType -in @("vMotion", "Both") -and $Targets.Host) {
            # Check CPU compatibility
            $sourceHost = $VM.VMHost
            if ($sourceHost.ProcessorType -ne $Targets.Host.ProcessorType) {
                $issues += "CPU types differ between source and destination hosts"
            }
            
            # Check if destination host has enough resources
            $vmMemoryMB = $VM.MemoryGB * 1024
            $hostFreeMemoryMB = $Targets.Host.MemoryTotalMB - $Targets.Host.MemoryUsageMB
            if ($vmMemoryMB -gt $hostFreeMemoryMB) {
                $issues += "Insufficient memory on destination host"
            }
        }
        
        # Check destination datastore space (for Storage vMotion)
        if ($MigrationType -in @("Storage", "Both") -and $Targets.Datastore) {
            $vmSizeGB = $VM.ProvisionedSpaceGB
            if ($vmSizeGB -gt $Targets.Datastore.FreeSpaceGB) {
                $issues += "Insufficient space on destination datastore"
            }
        }
        
        return $issues
    }
    catch {
        return @("Error validating migration compatibility: $($_.Exception.Message)")
    }
}

# Function to perform VM migration
function Invoke-VMMigration {
    param(
        $VMs,
        $Targets,
        $MigrationType,
        $Priority,
        $WaitForCompletion,
        $ValidateOnly
    )
    
    $results = @()
    
    foreach ($vm in $VMs) {
        try {
            Write-Host "`nProcessing VM: $($vm.Name)" -ForegroundColor Cyan
            
            # Validate migration compatibility
            $issues = Test-VMMigrationCompatibility -VM $vm -Targets $Targets -MigrationType $MigrationType
            
            if ($issues.Count -gt 0) {
                Write-Host "  Migration compatibility issues:" -ForegroundColor Yellow
                foreach ($issue in $issues) {
                    Write-Host "    - $issue" -ForegroundColor Yellow
                }
                
                if ($ValidateOnly) {
                    $results += @{
                        VM = $vm.Name
                        Operation = "Validation"
                        Status = "Issues Found"
                        Issues = $issues
                        SourceHost = $vm.VMHost.Name
                        SourceDatastore = ($vm | Get-Datastore)[0].Name
                    }
                    continue
                }
            }
            
            if ($ValidateOnly) {
                $results += @{
                    VM = $vm.Name
                    Operation = "Validation"
                    Status = "Compatible"
                    Issues = @()
                    SourceHost = $vm.VMHost.Name
                    SourceDatastore = ($vm | Get-Datastore)[0].Name
                }
                Write-Host "  ✓ Migration validation passed" -ForegroundColor Green
                continue
            }
            
            # Perform migration based on type
            $migrationTask = $null
            $migrationParams = @{
                VM = $vm
                RunAsync = $true
            }
            
            # Set priority
            if ($Priority -ne "Normal") {
                $migrationParams.Priority = $Priority
            }
            
            switch ($MigrationType) {
                "vMotion" {
                    if ($Targets.Host) {
                        $migrationParams.Destination = $Targets.Host
                    } else {
                        # Let DRS choose host in cluster
                        $migrationParams.Destination = $Targets.Cluster
                    }
                    Write-Host "  Initiating vMotion to $($migrationParams.Destination.Name)..." -ForegroundColor Yellow
                    $migrationTask = Move-VM @migrationParams
                }
                "Storage" {
                    $migrationParams.Datastore = $Targets.Datastore
                    Write-Host "  Initiating Storage vMotion to $($Targets.Datastore.Name)..." -ForegroundColor Yellow
                    $migrationTask = Move-VM @migrationParams
                }
                "Both" {
                    if ($Targets.Host) {
                        $migrationParams.Destination = $Targets.Host
                    } else {
                        $migrationParams.Destination = $Targets.Cluster
                    }
                    $migrationParams.Datastore = $Targets.Datastore
                    Write-Host "  Initiating combined migration..." -ForegroundColor Yellow
                    $migrationTask = Move-VM @migrationParams
                }
            }
            
            $result = @{
                VM = $vm.Name
                Operation = $MigrationType
                Status = "InProgress"
                Task = $migrationTask
                StartTime = Get-Date
                SourceHost = $vm.VMHost.Name
                SourceDatastore = ($vm | Get-Datastore)[0].Name
                DestinationHost = if ($Targets.Host) { $Targets.Host.Name } else { $Targets.Cluster.Name }
                DestinationDatastore = if ($Targets.Datastore) { $Targets.Datastore.Name } else { "N/A" }
            }
            
            # Wait for completion if requested
            if ($WaitForCompletion) {
                Write-Host "  Waiting for migration to complete..." -ForegroundColor Yellow
                
                try {
                    $taskResult = Wait-Task -Task $migrationTask
                    
                    if ($taskResult.State -eq "Success") {
                        $result.Status = "Completed"
                        $result.EndTime = Get-Date
                        $duration = ($result.EndTime - $result.StartTime).TotalMinutes
                        Write-Host "  ✓ Migration completed successfully ($([math]::Round($duration, 1)) minutes)" -ForegroundColor Green
                    } else {
                        $result.Status = "Failed"
                        $result.Error = $taskResult.Result
                        Write-Host "  ✗ Migration failed: $($taskResult.Result)" -ForegroundColor Red
                    }
                }
                catch {
                    $result.Status = "Failed"
                    $result.Error = $_.Exception.Message
                    Write-Host "  ✗ Migration failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "  ✓ Migration task initiated (Task ID: $($migrationTask.Id))" -ForegroundColor Green
            }
            
            $results += $result
        }
        catch {
            $results += @{
                VM = $vm.Name
                Operation = $MigrationType
                Status = "Failed"
                Error = $_.Exception.Message
                SourceHost = $vm.VMHost.Name
                SourceDatastore = ($vm | Get-Datastore)[0].Name
            }
            Write-Host "  ✗ Failed to initiate migration: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return $results
}

# Function to display migration summary
function Show-MigrationSummary {
    param(
        $Results,
        $MigrationType,
        $ValidateOnly
    )
    
    $operation = if ($ValidateOnly) { "Migration Validation" } else { "$MigrationType Migration" }
    Write-Host "`n=== $operation Summary ===" -ForegroundColor Cyan
    
    if ($ValidateOnly) {
        $compatible = $Results | Where-Object { $_.Status -eq "Compatible" }
        $issues = $Results | Where-Object { $_.Status -eq "Issues Found" }
        
        Write-Host "Total VMs: $($Results.Count)" -ForegroundColor White
        Write-Host "Compatible: $($compatible.Count)" -ForegroundColor Green
        Write-Host "Issues Found: $($issues.Count)" -ForegroundColor Yellow
        
        if ($issues.Count -gt 0) {
            Write-Host "`nVMs with Issues:" -ForegroundColor Yellow
            foreach ($result in $issues) {
                Write-Host "  $($result.VM):" -ForegroundColor White
                foreach ($issue in $result.Issues) {
                    Write-Host "    - $issue" -ForegroundColor Gray
                }
            }
        }
    } else {
        $successful = $Results | Where-Object { $_.Status -eq "Completed" }
        $failed = $Results | Where-Object { $_.Status -eq "Failed" }
        $inProgress = $Results | Where-Object { $_.Status -eq "InProgress" }
        
        Write-Host "Total VMs: $($Results.Count)" -ForegroundColor White
        Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
        Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
        Write-Host "In Progress: $($inProgress.Count)" -ForegroundColor Yellow
        
        if ($successful.Count -gt 0) {
            Write-Host "`nSuccessful Migrations:" -ForegroundColor Green
            foreach ($result in $successful) {
                $duration = if ($result.EndTime) { 
                    " ($([math]::Round(($result.EndTime - $result.StartTime).TotalMinutes, 1)) min)"
                } else { "" }
                Write-Host "  - $($result.VM): $($result.SourceHost) → $($result.DestinationHost)$duration" -ForegroundColor White
            }
        }
        
        if ($failed.Count -gt 0) {
            Write-Host "`nFailed Migrations:" -ForegroundColor Red
            foreach ($result in $failed) {
                Write-Host "  - $($result.VM): $($result.Error)" -ForegroundColor White
            }
        }
        
        if ($inProgress.Count -gt 0) {
            Write-Host "`nMigrations In Progress:" -ForegroundColor Yellow
            foreach ($result in $inProgress) {
                Write-Host "  - $($result.VM): Task ID $($result.Task.Id)" -ForegroundColor White
            }
        }
    }
}

# Main execution
try {
    Write-Host "=== vSphere VM Migration ===" -ForegroundColor Cyan
    Write-Host "Target vCenter: $VCenterServer" -ForegroundColor White
    Write-Host "Migration Type: $MigrationType" -ForegroundColor White
    
    if ($ValidateOnly) { Write-Host "Mode: Validation Only" -ForegroundColor White }
    if ($DestinationHost) { Write-Host "Destination Host: $DestinationHost" -ForegroundColor White }
    if ($DestinationCluster) { Write-Host "Destination Cluster: $DestinationCluster" -ForegroundColor White }
    if ($DestinationDatastore) { Write-Host "Destination Datastore: $DestinationDatastore" -ForegroundColor White }
    Write-Host ""
    
    # Check and install PowerCLI
    if (-not (Test-PowerCLIInstallation)) {
        throw "PowerCLI installation failed"
    }
    
    # Connect to vCenter
    $connection = Connect-ToVCenter -Server $VCenterServer
    
    # Get target VMs
    $targetVMs = Get-TargetVMs -VMName $VMName -VMNames $VMNames
    
    # Validate migration targets
    $targets = Test-MigrationTargets -MigrationType $MigrationType -DestinationHost $DestinationHost -DestinationDatastore $DestinationDatastore -DestinationCluster $DestinationCluster
    
    # Confirm operation if not using Force and not validation only
    if (-not $Force -and -not $ValidateOnly) {
        $confirmation = Read-Host "`nProceed with $MigrationType migration of $($targetVMs.Count) VM(s)? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "Migration cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Perform migration or validation
    $results = Invoke-VMMigration -VMs $targetVMs -Targets $targets -MigrationType $MigrationType -Priority $Priority -WaitForCompletion:$WaitForCompletion -ValidateOnly:$ValidateOnly
    
    # Display summary
    Show-MigrationSummary -Results $results -MigrationType $MigrationType -ValidateOnly:$ValidateOnly
    
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
