<#
.SYNOPSIS
    Clones virtual machines in vSphere using PowerCLI.

.DESCRIPTION
    This script clones existing VMs or templates to create new virtual machines.
    Supports full clones, linked clones, and bulk cloning operations with customization.
    Includes options for resource modification, network configuration, and placement.
    Requires VMware PowerCLI and connection to vCenter Server.

.PARAMETER VCenterServer
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER SourceVM
    The name of the source VM or template to clone from.

.PARAMETER NewVMName
    The name for the new cloned VM.

.PARAMETER NewVMNames
    Array of names for multiple VM clones (for bulk operations).

.PARAMETER CloneCount
    Number of clones to create with auto-generated names.

.PARAMETER NamePrefix
    Prefix for auto-generated VM names (used with CloneCount).

.PARAMETER NameSuffix
    Suffix for auto-generated VM names (used with CloneCount).

.PARAMETER DatastoreName
    The datastore where the cloned VM(s) will be created.

.PARAMETER ClusterName
    The cluster where the cloned VM(s) will be created.

.PARAMETER ResourcePoolName
    The resource pool for the cloned VM(s) (optional).

.PARAMETER FolderName
    The folder where the cloned VM(s) will be placed (optional).

.PARAMETER LinkedClone
    Create linked clones instead of full clones (requires snapshot).

.PARAMETER SnapshotName
    Snapshot name to use for linked clone (optional, uses current if not specified).

.PARAMETER PowerOnAfterClone
    Power on the VM(s) after cloning.

.PARAMETER CPUCount
    Number of CPU cores for the cloned VM(s) (optional, overrides source).

.PARAMETER MemoryGB
    Memory in GB for the cloned VM(s) (optional, overrides source).

.PARAMETER NetworkName
    Network port group to connect the cloned VM(s) to (optional).

.PARAMETER OSCustomizationSpec
    OS customization specification to apply (optional).

.PARAMETER WaitForCompletion
    Wait for clone operations to complete.

.PARAMETER Force
    Force the operation without confirmation prompts.

.EXAMPLE
    .\vsphere-cli-clone-vm.ps1 -VCenterServer "vcenter.domain.com" -SourceVM "Template-Win2022" -NewVMName "WebServer01" -DatastoreName "Datastore1" -ClusterName "Production"

.EXAMPLE
    .\vsphere-cli-clone-vm.ps1 -VCenterServer "vcenter.domain.com" -SourceVM "BaseVM" -CloneCount 5 -NamePrefix "TestVM" -DatastoreName "TestDatastore" -ClusterName "Test-Cluster" -LinkedClone

.EXAMPLE
    .\vsphere-cli-clone-vm.ps1 -VCenterServer "vcenter.domain.com" -SourceVM "Template-Ubuntu" -NewVMNames @("Web01","Web02","Web03") -DatastoreName "Datastore2" -ClusterName "Production" -CPUCount 4 -MemoryGB 8 -PowerOnAfterClone

.NOTES
    Author: XOAP.io
    Requires: VMware PowerCLI 13.x or later, vSphere 7.0 or later

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VCenterServer,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceVM,

    [Parameter(Mandatory = $false, ParameterSetName = "SingleClone")]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9\-_\.]{0,62}[a-zA-Z0-9]$')]
    [string]$NewVMName,

    [Parameter(Mandatory = $false, ParameterSetName = "MultipleClones")]
    [ValidateNotNullOrEmpty()]
    [string[]]$NewVMNames,

    [Parameter(Mandatory = $false, ParameterSetName = "BulkClone")]
    [ValidateRange(1, 50)]
    [int]$CloneCount,

    [Parameter(Mandatory = $false, ParameterSetName = "BulkClone")]
    [ValidateNotNullOrEmpty()]
    [string]$NamePrefix = "VM",

    [Parameter(Mandatory = $false, ParameterSetName = "BulkClone")]
    [string]$NameSuffix,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DatastoreName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ClusterName,

    [Parameter(Mandatory = $false)]
    [string]$ResourcePoolName,

    [Parameter(Mandatory = $false)]
    [string]$FolderName,

    [Parameter(Mandatory = $false)]
    [switch]$LinkedClone,

    [Parameter(Mandatory = $false)]
    [string]$SnapshotName,

    [Parameter(Mandatory = $false)]
    [switch]$PowerOnAfterClone,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 128)]
    [int]$CPUCount,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 4096)]
    [int]$MemoryGB,

    [Parameter(Mandatory = $false)]
    [string]$NetworkName,

    [Parameter(Mandatory = $false)]
    [string]$OSCustomizationSpec,

    [Parameter(Mandatory = $false)]
    [switch]$WaitForCompletion,

    [Parameter(Mandatory = $false)]
    [switch]$Force
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

# Function to validate vSphere objects
function Test-VSphereObjects {
    param(
        $SourceVM,
        $DatastoreName,
        $ClusterName,
        $ResourcePoolName,
        $FolderName,
        $NetworkName,
        $OSCustomizationSpec,
        $SnapshotName,
        $LinkedClone
    )

    Write-Host "Validating vSphere objects..." -ForegroundColor Yellow

    # Check source VM or template
    $sourceObject = $null
    $sourceObject = Get-VM -Name $SourceVM -ErrorAction SilentlyContinue
    if (-not $sourceObject) {
        $sourceObject = Get-Template -Name $SourceVM -ErrorAction SilentlyContinue
        if (-not $sourceObject) {
            throw "Source VM or template '$SourceVM' not found"
        }
        Write-Host "✓ Source template '$SourceVM' found" -ForegroundColor Green
    } else {
        Write-Host "✓ Source VM '$SourceVM' found" -ForegroundColor Green
    }

    # Check snapshot for linked clone
    $snapshot = $null
    if ($LinkedClone) {
        if ($sourceObject -is [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]) {
            if ($SnapshotName) {
                $snapshot = Get-Snapshot -VM $sourceObject -Name $SnapshotName -ErrorAction SilentlyContinue
                if (-not $snapshot) {
                    throw "Snapshot '$SnapshotName' not found on VM '$SourceVM'"
                }
            } else {
                # Use the current snapshot
                $snapshot = Get-Snapshot -VM $sourceObject | Sort-Object Created -Descending | Select-Object -First 1
                if (-not $snapshot) {
                    throw "No snapshots found on VM '$SourceVM' for linked clone operation"
                }
            }
            Write-Host "✓ Snapshot '$($snapshot.Name)' found for linked clone" -ForegroundColor Green
        } else {
            throw "Linked clone is only supported with VMs, not templates"
        }
    }

    # Check datastore
    $datastore = Get-Datastore -Name $DatastoreName -ErrorAction SilentlyContinue
    if (-not $datastore) {
        throw "Datastore '$DatastoreName' not found"
    }
    $freeSpaceGB = [math]::Round($datastore.FreeSpaceGB, 2)
    Write-Host "✓ Datastore '$DatastoreName' found (Free: $freeSpaceGB GB)" -ForegroundColor Green

    # Check cluster
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
    if (-not $cluster) {
        throw "Cluster '$ClusterName' not found"
    }
    Write-Host "✓ Cluster '$ClusterName' found" -ForegroundColor Green

    # Check resource pool if specified
    $resourcePool = $null
    if ($ResourcePoolName) {
        $resourcePool = Get-ResourcePool -Name $ResourcePoolName -Location $cluster -ErrorAction SilentlyContinue
        if (-not $resourcePool) {
            throw "Resource Pool '$ResourcePoolName' not found in cluster '$ClusterName'"
        }
        Write-Host "✓ Resource Pool '$ResourcePoolName' found" -ForegroundColor Green
    } else {
        $resourcePool = Get-ResourcePool -Location $cluster | Where-Object { $_.Name -eq "Resources" }
        Write-Host "✓ Using default resource pool" -ForegroundColor Green
    }

    # Check folder if specified
    $folder = $null
    if ($FolderName) {
        $folder = Get-Folder -Name $FolderName -Type VM -ErrorAction SilentlyContinue
        if (-not $folder) {
            throw "VM Folder '$FolderName' not found"
        }
        Write-Host "✓ VM Folder '$FolderName' found" -ForegroundColor Green
    }

    # Check network if specified
    $network = $null
    if ($NetworkName) {
        $network = Get-VirtualPortGroup -Name $NetworkName -ErrorAction SilentlyContinue
        if (-not $network) {
            throw "Network '$NetworkName' not found"
        }
        Write-Host "✓ Network '$NetworkName' found" -ForegroundColor Green
    }

    # Check OS customization spec if specified
    $osSpec = $null
    if ($OSCustomizationSpec) {
        $osSpec = Get-OSCustomizationSpec -Name $OSCustomizationSpec -ErrorAction SilentlyContinue
        if (-not $osSpec) {
            throw "OS Customization Spec '$OSCustomizationSpec' not found"
        }
        Write-Host "✓ OS Customization Spec '$OSCustomizationSpec' found" -ForegroundColor Green
    }

    return @{
        SourceObject = $sourceObject
        Snapshot = $snapshot
        Datastore = $datastore
        Cluster = $cluster
        ResourcePool = $resourcePool
        Folder = $folder
        Network = $network
        OSSpec = $osSpec
    }
}

# Function to generate VM names for bulk operations
function New-VMNameList {
    param(
        $CloneCount,
        $NamePrefix,
        $NameSuffix,
        $NewVMNames,
        $NewVMName
    )

    $vmNames = @()

    if ($NewVMName) {
        # Single clone
        $vmNames += $NewVMName
    }
    elseif ($NewVMNames) {
        # Multiple specific names
        $vmNames = $NewVMNames
    }
    elseif ($CloneCount) {
        # Bulk clone with generated names
        for ($i = 1; $i -le $CloneCount; $i++) {
            $paddedNumber = $i.ToString().PadLeft(2, '0')
            $vmName = "${NamePrefix}${paddedNumber}"
            if ($NameSuffix) {
                $vmName += $NameSuffix
            }
            $vmNames += $vmName
        }
    }

    # Check for existing VMs with same names
    $existingVMs = @()
    foreach ($name in $vmNames) {
        $existingVM = Get-VM -Name $name -ErrorAction SilentlyContinue
        if ($existingVM) {
            $existingVMs += $name
        }
    }

    if ($existingVMs.Count -gt 0) {
        throw "The following VM names already exist: $($existingVMs -join ', ')"
    }

    return $vmNames
}

# Function to clone a single VM
function New-ClonedVM {
    param(
        $Objects,
        $VMName,
        $LinkedClone,
        $CPUCount,
        $MemoryGB,
        $NetworkName,
        $PowerOnAfterClone,
        $WaitForCompletion
    )

    try {
        Write-Host "  Creating clone '$VMName'..." -ForegroundColor Cyan

        # Build clone parameters
        $cloneParams = @{
            Name = $VMName
            Datastore = $Objects.Datastore
            ResourcePool = $Objects.ResourcePool
        }

        # Add source (VM or Template)
        if ($Objects.SourceObject -is [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]) {
            if ($LinkedClone) {
                $cloneParams.VM = $Objects.SourceObject
                $cloneParams.LinkedClone = $true
                $cloneParams.ReferenceSnapshot = $Objects.Snapshot
            } else {
                $cloneParams.VM = $Objects.SourceObject
            }
        } else {
            # Template
            $cloneParams.Template = $Objects.SourceObject
        }

        # Add folder if specified
        if ($Objects.Folder) {
            $cloneParams.Location = $Objects.Folder
        }

        # Add OS customization if specified
        if ($Objects.OSSpec) {
            $cloneParams.OSCustomizationSpec = $Objects.OSSpec
        }

        # Create the clone
        if ($WaitForCompletion) {
            $clonedVM = New-VM @cloneParams
        } else {
            $cloneTask = New-VM @cloneParams -RunAsync
            Write-Host "    ✓ Clone task initiated (running asynchronously)" -ForegroundColor Green
            return @{
                VM = $VMName
                Task = $cloneTask
                Status = "InProgress"
            }
        }

        Write-Host "    ✓ VM '$VMName' cloned successfully" -ForegroundColor Green

        # Modify CPU count if specified
        if ($CPUCount) {
            Write-Host "    Setting CPU count to $CPUCount..." -ForegroundColor Yellow
            $clonedVM | Set-VM -NumCpu $CPUCount -Confirm:$false
            Write-Host "    ✓ CPU count set to $CPUCount" -ForegroundColor Green
        }

        # Modify memory if specified
        if ($MemoryGB) {
            Write-Host "    Setting memory to $MemoryGB GB..." -ForegroundColor Yellow
            $clonedVM | Set-VM -MemoryGB $MemoryGB -Confirm:$false
            Write-Host "    ✓ Memory set to $MemoryGB GB" -ForegroundColor Green
        }

        # Configure network if specified
        if ($Objects.Network) {
            Write-Host "    Configuring network adapter..." -ForegroundColor Yellow
            $networkAdapter = $clonedVM | Get-NetworkAdapter | Select-Object -First 1
            if ($networkAdapter) {
                $networkAdapter | Set-NetworkAdapter -Portgroup $Objects.Network -Confirm:$false
                Write-Host "    ✓ Network adapter configured for '$NetworkName'" -ForegroundColor Green
            }
        }

        # Power on VM if requested
        if ($PowerOnAfterClone) {
            Write-Host "    Powering on VM..." -ForegroundColor Yellow
            $clonedVM | Start-VM | Out-Null
            Write-Host "    ✓ VM '$VMName' powered on" -ForegroundColor Green
        }

        # Get final VM info
        $vmInfo = Get-VM -Name $VMName

        return @{
            VM = $vmInfo.Name
            PowerState = $vmInfo.PowerState
            CPUs = $vmInfo.NumCpu
            MemoryGB = $vmInfo.MemoryGB
            ProvisionedSpaceGB = [math]::Round($vmInfo.ProvisionedSpaceGB, 2)
            Host = $vmInfo.VMHost.Name
            Status = "Completed"
        }
    }
    catch {
        Write-Host "    ✗ Failed to clone VM '$VMName': $($_.Exception.Message)" -ForegroundColor Red
        return @{
            VM = $VMName
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
}

# Function to display clone summary
function Show-CloneSummary {
    param($Results)

    Write-Host "`n=== Clone Operation Summary ===" -ForegroundColor Cyan

    $successful = $Results | Where-Object { $_.Status -eq "Completed" }
    $failed = $Results | Where-Object { $_.Status -eq "Failed" }
    $inProgress = $Results | Where-Object { $_.Status -eq "InProgress" }

    Write-Host "Total VMs: $($Results.Count)" -ForegroundColor White
    Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    Write-Host "In Progress: $($inProgress.Count)" -ForegroundColor Yellow

    if ($successful.Count -gt 0) {
        Write-Host "`nSuccessfully Cloned VMs:" -ForegroundColor Green
        foreach ($result in $successful) {
            Write-Host "  - $($result.VM): $($result.PowerState), $($result.CPUs) CPUs, $($result.MemoryGB) GB RAM" -ForegroundColor White
        }

        $totalStorage = ($successful | Measure-Object -Property ProvisionedSpaceGB -Sum).Sum
        Write-Host "`nTotal provisioned storage: $([math]::Round($totalStorage, 2)) GB" -ForegroundColor Cyan
    }

    if ($failed.Count -gt 0) {
        Write-Host "`nFailed Clones:" -ForegroundColor Red
        foreach ($result in $failed) {
            Write-Host "  - $($result.VM): $($result.Error)" -ForegroundColor White
        }
    }

    if ($inProgress.Count -gt 0) {
        Write-Host "`nClones In Progress:" -ForegroundColor Yellow
        foreach ($result in $inProgress) {
            Write-Host "  - $($result.VM): Task ID $($result.Task.Id)" -ForegroundColor White
        }
    }
}

# Main execution
try {
    Write-Host "=== vSphere VM Clone Operation ===" -ForegroundColor Cyan
    Write-Host "Target vCenter: $VCenterServer" -ForegroundColor White
    Write-Host "Source VM/Template: $SourceVM" -ForegroundColor White
    Write-Host "Target Datastore: $DatastoreName" -ForegroundColor White
    Write-Host "Target Cluster: $ClusterName" -ForegroundColor White

    if ($LinkedClone) { Write-Host "Clone Type: Linked Clone" -ForegroundColor White }
    else { Write-Host "Clone Type: Full Clone" -ForegroundColor White }

    Write-Host ""

    # Check and install PowerCLI
    if (-not (Test-PowerCLIInstallation)) {
        throw "PowerCLI installation failed"
    }

    # Connect to vCenter
    $connection = Connect-ToVCenter -Server $VCenterServer

    # Generate VM names list
    $vmNames = New-VMNameList -CloneCount $CloneCount -NamePrefix $NamePrefix -NameSuffix $NameSuffix -NewVMNames $NewVMNames -NewVMName $NewVMName

    Write-Host "VMs to create: $($vmNames -join ', ')" -ForegroundColor White
    Write-Host ""

    # Validate vSphere objects
    $objects = Test-VSphereObjects -SourceVM $SourceVM -DatastoreName $DatastoreName -ClusterName $ClusterName -ResourcePoolName $ResourcePoolName -FolderName $FolderName -NetworkName $NetworkName -OSCustomizationSpec $OSCustomizationSpec -SnapshotName $SnapshotName -LinkedClone:$LinkedClone

    # Confirm operation if not using Force
    if (-not $Force) {
        $confirmation = Read-Host "`nProceed with cloning $($vmNames.Count) VM(s)? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "Clone operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Perform clone operations
    Write-Host "Starting clone operations..." -ForegroundColor Yellow
    $results = @()

    foreach ($vmName in $vmNames) {
        $result = New-ClonedVM -Objects $objects -VMName $vmName -LinkedClone:$LinkedClone -CPUCount $CPUCount -MemoryGB $MemoryGB -NetworkName $NetworkName -PowerOnAfterClone:$PowerOnAfterClone -WaitForCompletion:$WaitForCompletion
        $results += $result
    }

    # Display summary
    Show-CloneSummary -Results $results

    Write-Host "`n=== Clone Operation Completed ===" -ForegroundColor Green
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
