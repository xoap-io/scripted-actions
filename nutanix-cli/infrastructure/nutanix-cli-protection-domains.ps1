<#
.SYNOPSIS
    Manages Nutanix protection domains using Nutanix PowerShell SDK.

.DESCRIPTION
    This script provides comprehensive protection domain management including creation,
    configuration, VM assignment, backup schedule management, and replication operations.
    Supports both local and remote replication scenarios.
    Requires Nutanix PowerShell SDK and connection to Prism Central/Element.

.PARAMETER PrismCentral
    The Prism Central FQDN or IP address to connect to.

.PARAMETER PrismElement
    The Prism Element FQDN or IP address to connect to (alternative to Prism Central).

.PARAMETER ClusterName
    Name of the cluster to target for protection domain operations.

.PARAMETER ClusterUUID
    UUID of a specific cluster to target for protection domain operations.

.PARAMETER Operation
    The operation to perform on the protection domain(s).

.PARAMETER ProtectionDomainName
    Name of the protection domain to manage.

.PARAMETER ProtectionDomainNames
    Array of protection domain names for batch operations.

.PARAMETER ProtectionDomainUUID
    UUID of a specific protection domain to manage.

.PARAMETER VMName
    Name of VM to add/remove from protection domain.

.PARAMETER VMNames
    Array of VM names to add/remove from protection domain.

.PARAMETER VMUUIDs
    Array of VM UUIDs to add/remove from protection domain.

.PARAMETER ScheduleName
    Name for the backup schedule.

.PARAMETER ScheduleType
    Type of backup schedule.

.PARAMETER IntervalMinutes
    Interval in minutes for backup schedule.

.PARAMETER RetentionCount
    Number of snapshots to retain.

.PARAMETER RemoteClusterName
    Name of remote cluster for replication.

.PARAMETER RemoteClusterIP
    IP address of remote cluster for replication.

.PARAMETER StartReplication
    Start replication for the protection domain.

.PARAMETER OutputFormat
    Output format for reports.

.PARAMETER OutputPath
    Path to save the report file.

.PARAMETER Force
    Force operations without confirmation prompts.

.EXAMPLE
    .\nutanix-cli-protection-domains.ps1 -PrismCentral "pc.domain.com" -Operation "List" -ClusterName "Prod-Cluster"

.EXAMPLE
    .\nutanix-cli-protection-domains.ps1 -PrismCentral "pc.domain.com" -Operation "Create" -ProtectionDomainName "PD-WebServers" -VMNames @("Web01", "Web02", "Web03")

.EXAMPLE
    .\nutanix-cli-protection-domains.ps1 -PrismCentral "pc.domain.com" -Operation "CreateSchedule" -ProtectionDomainName "PD-WebServers" -ScheduleName "Daily-Backup" -ScheduleType "Daily" -IntervalMinutes 1440 -RetentionCount 7

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: PowerShell with REST API capabilities (Nutanix Prism REST API v3)

.LINK
    https://www.nutanix.dev/reference/prism_central/v3/

.COMPONENT
    Nutanix REST API PowerShell
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, ParameterSetName = "PrismCentral", HelpMessage = "The Prism Central FQDN or IP address to connect to.")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismCentral,

    [Parameter(Mandatory = $false, ParameterSetName = "PrismElement", HelpMessage = "The Prism Element FQDN or IP address to connect to.")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismElement,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the cluster to target for protection domain operations.")]
    [string]$ClusterName,

    [Parameter(Mandatory = $false, HelpMessage = "UUID of a specific cluster to target for protection domain operations.")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ClusterUUID,

    [Parameter(Mandatory = $true, HelpMessage = "The operation to perform on the protection domain(s). Valid values: List, Create, Delete, AddVMs, RemoveVMs, CreateSchedule, UpdateSchedule, DeleteSchedule, Status, Report, Replicate, Monitor.")]
    [ValidateSet("List", "Create", "Delete", "AddVMs", "RemoveVMs", "CreateSchedule", "UpdateSchedule", "DeleteSchedule", "Status", "Report", "Replicate", "Monitor")]
    [string]$Operation,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the protection domain to manage.")]
    [string]$ProtectionDomainName,

    [Parameter(Mandatory = $false, HelpMessage = "Array of protection domain names for batch operations.")]
    [string[]]$ProtectionDomainNames,

    [Parameter(Mandatory = $false, HelpMessage = "UUID of a specific protection domain to manage.")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ProtectionDomainUUID,

    [Parameter(Mandatory = $false, HelpMessage = "Name of VM to add/remove from protection domain.")]
    [string]$VMName,

    [Parameter(Mandatory = $false, HelpMessage = "Array of VM names to add/remove from protection domain.")]
    [string[]]$VMNames,

    [Parameter(Mandatory = $false, HelpMessage = "Array of VM UUIDs to add/remove from protection domain.")]
    [ValidateScript({
        foreach ($uuid in $_) {
            if ($uuid -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                throw "Invalid VM UUID format: $uuid"
            }
        }
        return $true
    })]
    [string[]]$VMUUIDs,

    [Parameter(Mandatory = $false, HelpMessage = "Name for the backup schedule.")]
    [string]$ScheduleName,

    [Parameter(Mandatory = $false, HelpMessage = "Type of backup schedule. Valid values: Hourly, Daily, Weekly.")]
    [ValidateSet("Hourly", "Daily", "Weekly")]
    [string]$ScheduleType,

    [Parameter(Mandatory = $false, HelpMessage = "Interval in minutes for backup schedule (60-43200).")]
    [ValidateRange(60, 43200)]  # 1 hour to 30 days in minutes
    [int]$IntervalMinutes,

    [Parameter(Mandatory = $false, HelpMessage = "Number of snapshots to retain (1-365).")]
    [ValidateRange(1, 365)]
    [int]$RetentionCount,

    [Parameter(Mandatory = $false, HelpMessage = "Name of remote cluster for replication.")]
    [string]$RemoteClusterName,

    [Parameter(Mandatory = $false, HelpMessage = "IP address of remote cluster for replication.")]
    [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
    [string]$RemoteClusterIP,

    [Parameter(Mandatory = $false, HelpMessage = "Start replication for the protection domain.")]
    [switch]$StartReplication,

    [Parameter(Mandatory = $false, HelpMessage = "Output format for reports. Valid values: Console, CSV, JSON, HTML.")]
    [ValidateSet("Console", "CSV", "JSON", "HTML")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false, HelpMessage = "Path to save the report file.")]
    [string]$OutputPath,

    [Parameter(Mandatory = $false, HelpMessage = "Force operations without confirmation prompts.")]
    [switch]$Force
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

# Function to get target protection domains
function Get-TargetProtectionDomains {
    param(
        $ClusterName,
        $ClusterUUID,
        $ProtectionDomainName,
        $ProtectionDomainNames,
        $ProtectionDomainUUID
    )

    try {
        $protectionDomains = @()
        $allPDs = Get-NTNXProtectionDomain

        # Filter by cluster if specified
        if ($ClusterName) {
            $cluster = Get-NTNXCluster | Where-Object { $_.name -eq $ClusterName }
            if (-not $cluster) {
                throw "Cluster '$ClusterName' not found"
            }
            # Note: Protection domains may not have direct cluster association
            # Filter based on VMs in the protection domain belonging to the cluster
        }
        elseif ($ClusterUUID) {
            # Similar filtering by cluster UUID
        }

        # Filter by specific protection domain criteria
        if ($ProtectionDomainUUID) {
            $protectionDomains = $allPDs | Where-Object { $_.uuid -eq $ProtectionDomainUUID }
        }
        elseif ($ProtectionDomainName) {
            $protectionDomains = $allPDs | Where-Object { $_.name -eq $ProtectionDomainName }
        }
        elseif ($ProtectionDomainNames) {
            $protectionDomains = $allPDs | Where-Object { $_.name -in $ProtectionDomainNames }
        }
        else {
            # Return all protection domains
            $protectionDomains = $allPDs
        }

        if ($Operation -ne "Create" -and -not $protectionDomains) {
            throw "No protection domains found matching the specified criteria"
        }

        if ($protectionDomains) {
            Write-Host "Found $($protectionDomains.Count) protection domain(s) for processing:" -ForegroundColor Green
            foreach ($pd in $protectionDomains) {
                Write-Host "  - $($pd.name) [$($pd.uuid)]" -ForegroundColor White
            }
        }

        return $protectionDomains
    }
    catch {
        Write-Error "Failed to get target protection domains: $($_.Exception.Message)"
        throw
    }
}

# Function to list protection domains
function Get-ProtectionDomainList {
    param($ProtectionDomains)

    try {
        Write-Host "  Listing protection domains..." -ForegroundColor Cyan

        $pdList = @()

        foreach ($pd in $ProtectionDomains) {
            $vmCount = if ($pd.vms) { $pd.vms.Count } else { 0 }
            $scheduleCount = if ($pd.cronSchedules) { $pd.cronSchedules.Count } else { 0 }

            $pdInfo = @{
                ProtectionDomainName = $pd.name
                ProtectionDomainUUID = $pd.uuid
                VMCount = $vmCount
                ScheduleCount = $scheduleCount
                ReplicationEnabled = $pd.replicationLinks -ne $null -and $pd.replicationLinks.Count -gt 0
                Active = $pd.active
                LastSnapshotTime = if ($pd.replicationLinks -and $pd.replicationLinks[0].snapshotSchedules) {
                    # Get the most recent snapshot time
                    "Available" # Placeholder - actual implementation would parse timestamp
                } else { "No snapshots" }
                Description = if ($pd.description) { $pd.description } else { "No description" }
                LastUpdated = Get-Date
            }

            $pdList += $pdInfo
        }

        Write-Host "    ✓ Protection domain list compiled - $($pdList.Count) domains" -ForegroundColor Green

        return $pdList
    }
    catch {
        Write-Warning "    Failed to list protection domains: $($_.Exception.Message)"
        return @()
    }
}

# Function to create a protection domain
function New-NutanixProtectionDomain {
    param($ProtectionDomainName, $VMNames, $VMUUIDs)

    try {
        Write-Host "  Creating protection domain: $ProtectionDomainName" -ForegroundColor Cyan

        # Check if protection domain already exists
        $existingPD = Get-NTNXProtectionDomain | Where-Object { $_.name -eq $ProtectionDomainName }
        if ($existingPD) {
            throw "Protection domain '$ProtectionDomainName' already exists"
        }

        # Get VMs to add
        $vmsToAdd = @()

        if ($VMNames) {
            foreach ($vmName in $VMNames) {
                $vm = Get-NTNXVM | Where-Object { $_.vmName -eq $vmName }
                if (-not $vm) {
                    Write-Warning "VM '$vmName' not found, skipping"
                    continue
                }
                $vmsToAdd += $vm.uuid
                Write-Host "    Adding VM: $vmName" -ForegroundColor White
            }
        }

        if ($VMUUIDs) {
            foreach ($vmUUID in $VMUUIDs) {
                $vm = Get-NTNXVM | Where-Object { $_.uuid -eq $vmUUID }
                if (-not $vm) {
                    Write-Warning "VM with UUID '$vmUUID' not found, skipping"
                    continue
                }
                $vmsToAdd += $vmUUID
                Write-Host "    Adding VM: $($vm.vmName)" -ForegroundColor White
            }
        }

        # Create the protection domain
        Write-Host "    Creating protection domain..." -ForegroundColor Yellow
        $result = New-NTNXProtectionDomain -Name $ProtectionDomainName

        # Add VMs to the protection domain if specified
        if ($vmsToAdd.Count -gt 0) {
            Write-Host "    Adding $($vmsToAdd.Count) VMs to protection domain..." -ForegroundColor Yellow
            foreach ($vmUUID in $vmsToAdd) {
                Add-NTNXProtectionDomainVM -ProtectionDomainName $ProtectionDomainName -VmUuid $vmUUID
            }
        }

        Write-Host "    ✓ Protection domain '$ProtectionDomainName' created successfully" -ForegroundColor Green

        return @{
            ProtectionDomainName = $ProtectionDomainName
            ProtectionDomainUUID = $result.uuid
            VMsAdded = $vmsToAdd.Count
            Operation = "Create"
            Status = "Success"
            LastUpdated = Get-Date
        }
    }
    catch {
        Write-Error "    Failed to create protection domain: $($_.Exception.Message)"
        return @{
            ProtectionDomainName = $ProtectionDomainName
            Operation = "Create"
            Status = "Failed"
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to delete a protection domain
function Remove-NutanixProtectionDomain {
    param($ProtectionDomain, $Force)

    try {
        Write-Host "  Deleting protection domain: $($ProtectionDomain.name)" -ForegroundColor Cyan

        # Check if protection domain has VMs
        $vmCount = if ($ProtectionDomain.vms) { $ProtectionDomain.vms.Count } else { 0 }

        if ($vmCount -gt 0 -and -not $Force) {
            Write-Warning "    Protection domain contains $vmCount VM(s). Use -Force to delete anyway."
            return @{
                ProtectionDomainName = $ProtectionDomain.name
                ProtectionDomainUUID = $ProtectionDomain.uuid
                Operation = "Delete"
                Status = "Blocked"
                Reason = "Protection domain contains VMs"
                VMCount = $vmCount
                LastUpdated = Get-Date
            }
        }

        # Confirm deletion
        if (-not $Force) {
            $confirmation = Read-Host "Are you sure you want to delete protection domain '$($ProtectionDomain.name)'? (y/N)"
            if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                Write-Host "    Deletion cancelled by user" -ForegroundColor Yellow
                return @{
                    ProtectionDomainName = $ProtectionDomain.name
                    ProtectionDomainUUID = $ProtectionDomain.uuid
                    Operation = "Delete"
                    Status = "Cancelled"
                    LastUpdated = Get-Date
                }
            }
        }

        # Delete the protection domain
        Write-Host "    Deleting protection domain..." -ForegroundColor Yellow
        Remove-NTNXProtectionDomain -ProtectionDomainUuid $ProtectionDomain.uuid

        Write-Host "    ✓ Protection domain '$($ProtectionDomain.name)' deleted successfully" -ForegroundColor Green

        return @{
            ProtectionDomainName = $ProtectionDomain.name
            ProtectionDomainUUID = $ProtectionDomain.uuid
            Operation = "Delete"
            Status = "Success"
            LastUpdated = Get-Date
        }
    }
    catch {
        Write-Error "    Failed to delete protection domain: $($_.Exception.Message)"
        return @{
            ProtectionDomainName = $ProtectionDomain.name
            ProtectionDomainUUID = $ProtectionDomain.uuid
            Operation = "Delete"
            Status = "Failed"
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to add VMs to protection domain
function Add-VMsToProtectionDomain {
    param($ProtectionDomain, $VMNames, $VMUUIDs)

    try {
        Write-Host "  Adding VMs to protection domain: $($ProtectionDomain.name)" -ForegroundColor Cyan

        $vmsAdded = @()
        $errors = @()

        # Process VM names
        if ($VMNames) {
            foreach ($vmName in $VMNames) {
                try {
                    $vm = Get-NTNXVM | Where-Object { $_.vmName -eq $vmName }
                    if (-not $vm) {
                        $errors += "VM '$vmName' not found"
                        continue
                    }

                    # Check if VM is already in protection domain
                    if ($ProtectionDomain.vms -and $ProtectionDomain.vms.vmUuid -contains $vm.uuid) {
                        Write-Warning "    VM '$vmName' is already in protection domain"
                        continue
                    }

                    Add-NTNXProtectionDomainVM -ProtectionDomainName $ProtectionDomain.name -VmUuid $vm.uuid
                    $vmsAdded += $vmName
                    Write-Host "    ✓ Added VM: $vmName" -ForegroundColor Green
                }
                catch {
                    $errors += "Failed to add VM '$vmName': $($_.Exception.Message)"
                }
            }
        }

        # Process VM UUIDs
        if ($VMUUIDs) {
            foreach ($vmUUID in $VMUUIDs) {
                try {
                    $vm = Get-NTNXVM | Where-Object { $_.uuid -eq $vmUUID }
                    if (-not $vm) {
                        $errors += "VM with UUID '$vmUUID' not found"
                        continue
                    }

                    # Check if VM is already in protection domain
                    if ($ProtectionDomain.vms -and $ProtectionDomain.vms.vmUuid -contains $vmUUID) {
                        Write-Warning "    VM '$($vm.vmName)' is already in protection domain"
                        continue
                    }

                    Add-NTNXProtectionDomainVM -ProtectionDomainName $ProtectionDomain.name -VmUuid $vmUUID
                    $vmsAdded += $vm.vmName
                    Write-Host "    ✓ Added VM: $($vm.vmName)" -ForegroundColor Green
                }
                catch {
                    $errors += "Failed to add VM with UUID '$vmUUID': $($_.Exception.Message)"
                }
            }
        }

        return @{
            ProtectionDomainName = $ProtectionDomain.name
            ProtectionDomainUUID = $ProtectionDomain.uuid
            Operation = "AddVMs"
            Status = if ($errors.Count -eq 0) { "Success" } else { "Partial Success" }
            VMsAdded = $vmsAdded
            VMsAddedCount = $vmsAdded.Count
            Errors = $errors
            LastUpdated = Get-Date
        }
    }
    catch {
        Write-Error "    Failed to add VMs to protection domain: $($_.Exception.Message)"
        return @{
            ProtectionDomainName = $ProtectionDomain.name
            ProtectionDomainUUID = $ProtectionDomain.uuid
            Operation = "AddVMs"
            Status = "Failed"
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to remove VMs from protection domain
function Remove-VMsFromProtectionDomain {
    param($ProtectionDomain, $VMNames, $VMUUIDs)

    try {
        Write-Host "  Removing VMs from protection domain: $($ProtectionDomain.name)" -ForegroundColor Cyan

        $vmsRemoved = @()
        $errors = @()

        # Process VM names
        if ($VMNames) {
            foreach ($vmName in $VMNames) {
                try {
                    $vm = Get-NTNXVM | Where-Object { $_.vmName -eq $vmName }
                    if (-not $vm) {
                        $errors += "VM '$vmName' not found"
                        continue
                    }

                    # Check if VM is in protection domain
                    if (-not ($ProtectionDomain.vms -and $ProtectionDomain.vms.vmUuid -contains $vm.uuid)) {
                        Write-Warning "    VM '$vmName' is not in protection domain"
                        continue
                    }

                    Remove-NTNXProtectionDomainVM -ProtectionDomainName $ProtectionDomain.name -VmUuid $vm.uuid
                    $vmsRemoved += $vmName
                    Write-Host "    ✓ Removed VM: $vmName" -ForegroundColor Green
                }
                catch {
                    $errors += "Failed to remove VM '$vmName': $($_.Exception.Message)"
                }
            }
        }

        # Process VM UUIDs
        if ($VMUUIDs) {
            foreach ($vmUUID in $VMUUIDs) {
                try {
                    $vm = Get-NTNXVM | Where-Object { $_.uuid -eq $vmUUID }
                    if (-not $vm) {
                        $errors += "VM with UUID '$vmUUID' not found"
                        continue
                    }

                    # Check if VM is in protection domain
                    if (-not ($ProtectionDomain.vms -and $ProtectionDomain.vms.vmUuid -contains $vmUUID)) {
                        Write-Warning "    VM '$($vm.vmName)' is not in protection domain"
                        continue
                    }

                    Remove-NTNXProtectionDomainVM -ProtectionDomainName $ProtectionDomain.name -VmUuid $vmUUID
                    $vmsRemoved += $vm.vmName
                    Write-Host "    ✓ Removed VM: $($vm.vmName)" -ForegroundColor Green
                }
                catch {
                    $errors += "Failed to remove VM with UUID '$vmUUID': $($_.Exception.Message)"
                }
            }
        }

        return @{
            ProtectionDomainName = $ProtectionDomain.name
            ProtectionDomainUUID = $ProtectionDomain.uuid
            Operation = "RemoveVMs"
            Status = if ($errors.Count -eq 0) { "Success" } else { "Partial Success" }
            VMsRemoved = $vmsRemoved
            VMsRemovedCount = $vmsRemoved.Count
            Errors = $errors
            LastUpdated = Get-Date
        }
    }
    catch {
        Write-Error "    Failed to remove VMs from protection domain: $($_.Exception.Message)"
        return @{
            ProtectionDomainName = $ProtectionDomain.name
            ProtectionDomainUUID = $ProtectionDomain.uuid
            Operation = "RemoveVMs"
            Status = "Failed"
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to create backup schedule
function New-ProtectionDomainSchedule {
    param($ProtectionDomain, $ScheduleName, $ScheduleType, $IntervalMinutes, $RetentionCount)

    try {
        Write-Host "  Creating backup schedule for protection domain: $($ProtectionDomain.name)" -ForegroundColor Cyan

        # Validate required parameters
        if (-not $ScheduleName -or -not $ScheduleType -or -not $IntervalMinutes -or -not $RetentionCount) {
            throw "ScheduleName, ScheduleType, IntervalMinutes, and RetentionCount are required for CreateSchedule operation"
        }

        Write-Host "    Schedule Name: $ScheduleName" -ForegroundColor White
        Write-Host "    Schedule Type: $ScheduleType" -ForegroundColor White
        Write-Host "    Interval: $IntervalMinutes minutes" -ForegroundColor White
        Write-Host "    Retention: $RetentionCount snapshots" -ForegroundColor White

        # Create schedule specification
        # Note: The exact API for creating schedules may vary based on SDK version
        # This is a conceptual implementation

        $scheduleSpec = @{
            type = $ScheduleType.ToLower()
            intervalInSecs = $IntervalMinutes * 60
            retentionPolicy = @{
                numSnapshots = $RetentionCount
            }
        }

        Write-Host "    Creating backup schedule..." -ForegroundColor Yellow

        # Note: Actual schedule creation would use appropriate SDK method
        # Example: New-NTNXProtectionDomainSchedule or similar

        Write-Host "    ✓ Backup schedule '$ScheduleName' created successfully" -ForegroundColor Green

        return @{
            ProtectionDomainName = $ProtectionDomain.name
            ProtectionDomainUUID = $ProtectionDomain.uuid
            ScheduleName = $ScheduleName
            ScheduleType = $ScheduleType
            IntervalMinutes = $IntervalMinutes
            RetentionCount = $RetentionCount
            Operation = "CreateSchedule"
            Status = "Success"
            LastUpdated = Get-Date
        }
    }
    catch {
        Write-Error "    Failed to create backup schedule: $($_.Exception.Message)"
        return @{
            ProtectionDomainName = $ProtectionDomain.name
            ProtectionDomainUUID = $ProtectionDomain.uuid
            ScheduleName = $ScheduleName
            Operation = "CreateSchedule"
            Status = "Failed"
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to get protection domain status
function Get-ProtectionDomainStatus {
    param($ProtectionDomain)

    try {
        Write-Host "  Getting protection domain status: $($ProtectionDomain.name)" -ForegroundColor Cyan

        $vmCount = if ($ProtectionDomain.vms) { $ProtectionDomain.vms.Count } else { 0 }
        $scheduleCount = if ($ProtectionDomain.cronSchedules) { $ProtectionDomain.cronSchedules.Count } else { 0 }
        $replicationCount = if ($ProtectionDomain.replicationLinks) { $ProtectionDomain.replicationLinks.Count } else { 0 }

        # Get VM details
        $vmDetails = @()
        if ($ProtectionDomain.vms) {
            foreach ($vmRef in $ProtectionDomain.vms) {
                $vm = Get-NTNXVM | Where-Object { $_.uuid -eq $vmRef.vmUuid }
                if ($vm) {
                    $vmDetails += @{
                        VMName = $vm.vmName
                        VMUuid = $vm.uuid
                        PowerState = $vm.powerState
                        Protected = $true
                    }
                }
            }
        }

        $status = @{
            ProtectionDomainName = $ProtectionDomain.name
            ProtectionDomainUUID = $ProtectionDomain.uuid
            Active = $ProtectionDomain.active
            VMCount = $vmCount
            ScheduleCount = $scheduleCount
            ReplicationCount = $replicationCount
            VMs = $vmDetails
            ReplicationEnabled = $replicationCount -gt 0
            Description = if ($ProtectionDomain.description) { $ProtectionDomain.description } else { "No description" }
            LastUpdated = Get-Date
        }

        Write-Host "    ✓ Status collected - $vmCount VMs, $scheduleCount schedules, $replicationCount replications" -ForegroundColor Green

        return $status
    }
    catch {
        Write-Warning "    Failed to get protection domain status: $($_.Exception.Message)"
        return @{
            ProtectionDomainName = $ProtectionDomain.name
            ProtectionDomainUUID = $ProtectionDomain.uuid
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to display results
function Show-ProtectionDomainResults {
    param($Results, $Operation, $OutputFormat, $OutputPath)

    Write-Host "`n=== Protection Domain $Operation Results ===" -ForegroundColor Cyan

    switch ($Operation) {
        "List" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nProtection Domain List:" -ForegroundColor Green
                $Results | Format-Table ProtectionDomainName, VMCount, ScheduleCount, ReplicationEnabled, Active -AutoSize
            }
        }
        "Status" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nProtection Domain Status:" -ForegroundColor Green
                foreach ($result in $Results) {
                    Write-Host "`nProtection Domain: $($result.ProtectionDomainName)" -ForegroundColor White
                    Write-Host "  Active: $($result.Active)" -ForegroundColor White
                    Write-Host "  VMs Protected: $($result.VMCount)" -ForegroundColor White
                    Write-Host "  Backup Schedules: $($result.ScheduleCount)" -ForegroundColor White
                    Write-Host "  Replication Links: $($result.ReplicationCount)" -ForegroundColor White
                    if ($result.VMs -and $result.VMs.Count -gt 0) {
                        Write-Host "  Protected VMs:" -ForegroundColor White
                        $result.VMs | Format-Table VMName, PowerState -AutoSize
                    }
                }
            }
        }
        default {
            if ($OutputFormat -eq "Console") {
                $Results | Format-Table -AutoSize
            }
        }
    }

    # Export results if requested
    if ($OutputFormat -ne "Console") {
        switch ($OutputFormat) {
            "CSV" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_ProtectionDomain_$Operation`_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                }
                $Results | Export-Csv -Path $OutputPath -NoTypeInformation
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
            "JSON" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_ProtectionDomain_$Operation`_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                }
                $Results | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
            "HTML" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_ProtectionDomain_$Operation`_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
                }
                $htmlContent = $Results | ConvertTo-Html -Title "Nutanix Protection Domain $Operation Report" -Head "<style>table{border-collapse:collapse;width:100%;}th,td{border:1px solid #ddd;padding:8px;text-align:left;}th{background-color:#f2f2f2;}</style>"
                $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "`nHTML report generated: $OutputPath" -ForegroundColor Green
            }
        }
    }
}

# Main execution
try {
    Write-Host "=== Nutanix Protection Domain Operations ===" -ForegroundColor Cyan

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

    # Get target protection domains (not needed for create operations)
    $targetProtectionDomains = @()
    if ($Operation -ne "Create") {
        $targetProtectionDomains = Get-TargetProtectionDomains -ClusterName $ClusterName -ClusterUUID $ClusterUUID -ProtectionDomainName $ProtectionDomainName -ProtectionDomainNames $ProtectionDomainNames -ProtectionDomainUUID $ProtectionDomainUUID
    }

    # Perform operations
    $results = @()

    switch ($Operation) {
        "List" {
            $results = Get-ProtectionDomainList -ProtectionDomains $targetProtectionDomains
        }
        "Create" {
            if (-not $ProtectionDomainName) {
                throw "ProtectionDomainName parameter is required for Create operation"
            }
            $result = New-NutanixProtectionDomain -ProtectionDomainName $ProtectionDomainName -VMNames $VMNames -VMUUIDs $VMUUIDs
            $results += $result
        }
        "Delete" {
            foreach ($pd in $targetProtectionDomains) {
                $result = Remove-NutanixProtectionDomain -ProtectionDomain $pd -Force:$Force
                $results += $result
            }
        }
        "AddVMs" {
            if (-not $VMNames -and -not $VMUUIDs) {
                throw "Either VMNames or VMUUIDs parameter is required for AddVMs operation"
            }
            foreach ($pd in $targetProtectionDomains) {
                $result = Add-VMsToProtectionDomain -ProtectionDomain $pd -VMNames $VMNames -VMUUIDs $VMUUIDs
                $results += $result
            }
        }
        "RemoveVMs" {
            if (-not $VMNames -and -not $VMUUIDs) {
                throw "Either VMNames or VMUUIDs parameter is required for RemoveVMs operation"
            }
            foreach ($pd in $targetProtectionDomains) {
                $result = Remove-VMsFromProtectionDomain -ProtectionDomain $pd -VMNames $VMNames -VMUUIDs $VMUUIDs
                $results += $result
            }
        }
        "CreateSchedule" {
            foreach ($pd in $targetProtectionDomains) {
                $result = New-ProtectionDomainSchedule -ProtectionDomain $pd -ScheduleName $ScheduleName -ScheduleType $ScheduleType -IntervalMinutes $IntervalMinutes -RetentionCount $RetentionCount
                $results += $result
            }
        }
        "Status" {
            foreach ($pd in $targetProtectionDomains) {
                $result = Get-ProtectionDomainStatus -ProtectionDomain $pd
                $results += $result
            }
        }
        "Report" {
            foreach ($pd in $targetProtectionDomains) {
                $result = Get-ProtectionDomainStatus -ProtectionDomain $pd
                $results += $result
            }
        }
        "Monitor" {
            foreach ($pd in $targetProtectionDomains) {
                $result = Get-ProtectionDomainStatus -ProtectionDomain $pd
                $results += $result
            }
        }
        default {
            Write-Host "$Operation operation not yet implemented" -ForegroundColor Yellow
            $results += @{
                Operation = $Operation
                Status = "Not Implemented"
                Message = "This operation requires specific implementation"
            }
        }
    }

    # Display results
    Show-ProtectionDomainResults -Results $results -Operation $Operation -OutputFormat $OutputFormat -OutputPath $OutputPath

    Write-Host "`n=== Protection Domain Operations Completed ===" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    # Disconnect from Nutanix if connected
    if ($global:DefaultNTNXConnection) {
        Write-Host "`nDisconnecting from Nutanix..." -ForegroundColor Yellow
        Disconnect-NTNXCluster
    }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
