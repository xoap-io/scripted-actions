<#
.SYNOPSIS
    Creates new virtual machines in Nutanix AHV using Nutanix PowerShell SDK.

.DESCRIPTION
    This script creates new VMs with customizable specifications including CPU,
    memory, storage, and network configuration. Supports creation from scratch
    or cloning from existing VMs/images.
    Requires Nutanix PowerShell SDK and connection to Prism Central/Element.

.PARAMETER PrismCentral
    The Prism Central FQDN or IP address to connect to.

.PARAMETER PrismElement
    The Prism Element FQDN or IP address to connect to (alternative to Prism Central).

.PARAMETER VMName
    The name of the virtual machine to create.

.PARAMETER VMNames
    An array of VM names for bulk creation.

.PARAMETER VMCount
    Number of VMs to create with auto-generated names.

.PARAMETER NamePrefix
    Prefix for auto-generated VM names.

.PARAMETER ClusterName
    Target cluster name for VM creation.

.PARAMETER ClusterUUID
    Target cluster UUID for VM creation.

.PARAMETER ContainerName
    Storage container name for VM disks.

.PARAMETER ContainerUUID
    Storage container UUID for VM disks.

.PARAMETER NetworkName
    Network name for VM network adapter.

.PARAMETER NetworkUUID
    Network UUID for VM network adapter.

.PARAMETER CPUCores
    Number of CPU cores per VM.

.PARAMETER CPUSockets
    Number of CPU sockets per VM.

.PARAMETER MemoryGB
    Memory size in GB per VM.

.PARAMETER DiskSizeGB
    Primary disk size in GB.

.PARAMETER AdditionalDisks
    Array of additional disk sizes in GB.

.PARAMETER ImageName
    Base image name for VM creation.

.PARAMETER ImageUUID
    Base image UUID for VM creation.

.PARAMETER SourceVMName
    Source VM name for cloning.

.PARAMETER SourceVMUUID
    Source VM UUID for cloning.

.PARAMETER PowerOnAfterCreation
    Power on VMs after creation.

.PARAMETER InstallNGT
    Install Nutanix Guest Tools.

.PARAMETER Force
    Force operations without confirmation prompts.

.PARAMETER OutputFormat
    Output format for results.

.PARAMETER OutputPath
    Path to save the results file.

.EXAMPLE
    .\nutanix-cli-create-vm.ps1 -PrismCentral "pc.domain.com" -VMName "WebServer01" -ClusterName "Production" -ContainerName "Storage" -NetworkName "VLAN100" -CPUCores 4 -MemoryGB 8 -DiskSizeGB 100

.EXAMPLE
    .\nutanix-cli-create-vm.ps1 -PrismCentral "pc.domain.com" -VMCount 5 -NamePrefix "WebNode" -ClusterName "Production" -ContainerName "Storage" -NetworkName "VLAN100" -CPUCores 2 -MemoryGB 4 -DiskSizeGB 50 -PowerOnAfterCreation

.EXAMPLE
    .\nutanix-cli-create-vm.ps1 -PrismCentral "pc.domain.com" -VMName "ClonedVM" -SourceVMName "Template-VM" -ClusterName "Production" -PowerOnAfterCreation

.NOTES
    Author: XOAP.io
    Requires: Nutanix PowerShell SDK, AOS 6.0+

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, ParameterSetName = "PrismCentral")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismCentral,

    [Parameter(Mandatory = $false, ParameterSetName = "PrismElement")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismElement,

    [Parameter(Mandatory = $false, ParameterSetName = "SingleVM")]
    [ValidateNotNullOrEmpty()]
    [string]$VMName,

    [Parameter(Mandatory = $false, ParameterSetName = "MultipleVMs")]
    [ValidateNotNullOrEmpty()]
    [string[]]$VMNames,

    [Parameter(Mandatory = $false, ParameterSetName = "BulkCreation")]
    [ValidateRange(1, 50)]
    [int]$VMCount,

    [Parameter(Mandatory = $false)]
    [string]$NamePrefix = "VM",

    [Parameter(Mandatory = $false)]
    [string]$ClusterName,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ClusterUUID,

    [Parameter(Mandatory = $false)]
    [string]$ContainerName,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ContainerUUID,

    [Parameter(Mandatory = $false)]
    [string]$NetworkName,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$NetworkUUID,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 32)]
    [int]$CPUCores = 2,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 8)]
    [int]$CPUSockets = 1,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1024)]
    [int]$MemoryGB = 4,

    [Parameter(Mandatory = $false)]
    [ValidateRange(10, 2048)]
    [int]$DiskSizeGB = 50,

    [Parameter(Mandatory = $false)]
    [int[]]$AdditionalDisks,

    [Parameter(Mandatory = $false)]
    [string]$ImageName,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ImageUUID,

    [Parameter(Mandatory = $false)]
    [string]$SourceVMName,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$SourceVMUUID,

    [Parameter(Mandatory = $false)]
    [switch]$PowerOnAfterCreation,

    [Parameter(Mandatory = $false)]
    [switch]$InstallNGT,

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

        # Connect to Nutanix (will prompt for credentials if not provided)
        $connection = Connect-NTNXCluster -Server $Server -AcceptInvalidSSLCerts
        Write-Host "Successfully connected to $ServerType`: $($connection.Server)" -ForegroundColor Green
        return $connection
    }
    catch {
        Write-Error "Failed to connect to $ServerType $Server`: $($_.Exception.Message)"
        throw
    }
}

# Function to resolve cluster UUID
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

# Function to resolve storage container UUID
function Get-ContainerInfo {
    param($ContainerName, $ContainerUUID, $ClusterUUID)

    try {
        if ($ContainerUUID) {
            $container = Get-NTNXStorageContainer | Where-Object { $_.storageContainerUuid -eq $ContainerUUID }
            if (-not $container) {
                throw "Storage container with UUID '$ContainerUUID' not found"
            }
        } elseif ($ContainerName) {
            $containers = Get-NTNXStorageContainer | Where-Object { $_.name -eq $ContainerName }
            if ($ClusterUUID) {
                $container = $containers | Where-Object { $_.clusterUuid -eq $ClusterUUID } | Select-Object -First 1
            } else {
                $container = $containers | Select-Object -First 1
            }
            if (-not $container) {
                throw "Storage container '$ContainerName' not found"
            }
        } else {
            # Use default container for cluster
            $containers = Get-NTNXStorageContainer | Where-Object { $_.clusterUuid -eq $ClusterUUID }
            $container = $containers | Select-Object -First 1
            if (-not $container) {
                throw "No storage containers found for cluster"
            }
            Write-Warning "No container specified, using: $($container.name)"
        }

        return @{
            Name = $container.name
            UUID = $container.storageContainerUuid
            Object = $container
        }
    }
    catch {
        Write-Error "Failed to resolve storage container information: $($_.Exception.Message)"
        throw
    }
}

# Function to resolve network UUID
function Get-NetworkInfo {
    param($NetworkName, $NetworkUUID)

    try {
        if ($NetworkUUID) {
            $network = Get-NTNXNetwork | Where-Object { $_.uuid -eq $NetworkUUID }
            if (-not $network) {
                throw "Network with UUID '$NetworkUUID' not found"
            }
        } elseif ($NetworkName) {
            $network = Get-NTNXNetwork | Where-Object { $_.name -eq $NetworkName }
            if (-not $network) {
                throw "Network '$NetworkName' not found"
            }
        } else {
            # Use first available network
            $network = Get-NTNXNetwork | Select-Object -First 1
            if (-not $network) {
                throw "No networks found"
            }
            Write-Warning "No network specified, using: $($network.name)"
        }

        return @{
            Name = $network.name
            UUID = $network.uuid
            Object = $network
        }
    }
    catch {
        Write-Error "Failed to resolve network information: $($_.Exception.Message)"
        throw
    }
}

# Function to resolve image information
function Get-ImageInfo {
    param($ImageName, $ImageUUID)

    try {
        if ($ImageUUID) {
            $image = Get-NTNXImage | Where-Object { $_.uuid -eq $ImageUUID }
            if (-not $image) {
                throw "Image with UUID '$ImageUUID' not found"
            }
        } elseif ($ImageName) {
            $image = Get-NTNXImage | Where-Object { $_.name -eq $ImageName }
            if (-not $image) {
                throw "Image '$ImageName' not found"
            }
        } else {
            return $null
        }

        return @{
            Name = $image.name
            UUID = $image.uuid
            Object = $image
        }
    }
    catch {
        Write-Error "Failed to resolve image information: $($_.Exception.Message)"
        throw
    }
}

# Function to get source VM information
function Get-SourceVMInfo {
    param($SourceVMName, $SourceVMUUID)

    try {
        if ($SourceVMUUID) {
            $vm = Get-NTNXVM | Where-Object { $_.uuid -eq $SourceVMUUID }
            if (-not $vm) {
                throw "Source VM with UUID '$SourceVMUUID' not found"
            }
        } elseif ($SourceVMName) {
            $vm = Get-NTNXVM | Where-Object { $_.vmName -eq $SourceVMName }
            if (-not $vm) {
                throw "Source VM '$SourceVMName' not found"
            }
        } else {
            return $null
        }

        return @{
            Name = $vm.vmName
            UUID = $vm.uuid
            Object = $vm
        }
    }
    catch {
        Write-Error "Failed to resolve source VM information: $($_.Exception.Message)"
        throw
    }
}

# Function to generate VM names
function Get-VMNames {
    param($VMName, $VMNames, $VMCount, $NamePrefix)

    $names = @()

    if ($VMName) {
        $names += $VMName
    } elseif ($VMNames) {
        $names = $VMNames
    } elseif ($VMCount) {
        for ($i = 1; $i -le $VMCount; $i++) {
            $names += "$NamePrefix$('{0:D2}' -f $i)"
        }
    } else {
        throw "Must specify VMName, VMNames, or VMCount"
    }

    return $names
}

# Function to create VM specification
function New-VMSpecification {
    param(
        $VMName,
        $ClusterUUID,
        $ContainerUUID,
        $NetworkUUID,
        $CPUCores,
        $CPUSockets,
        $MemoryGB,
        $DiskSizeGB,
        $AdditionalDisks,
        $ImageInfo,
        $SourceVMInfo
    )

    try {
        Write-Host "    Creating VM specification for: $VMName" -ForegroundColor Gray

        # Create VM specification
        $vmSpec = New-Object Nutanix.Prism.Model.VmSpec
        $vmSpec.name = $VMName
        $vmSpec.numVcpus = $CPUCores
        $vmSpec.numCoresPerVcpu = $CPUSockets
        $vmSpec.memoryMb = $MemoryGB * 1024

        # VM disks
        $vmDisks = @()

        # Primary disk
        $primaryDisk = New-Object Nutanix.Prism.Model.VmDisk
        if ($ImageInfo) {
            # Clone from image
            $primaryDisk.vmDiskClone = New-Object Nutanix.Prism.Model.VmDiskSpecClone
            $primaryDisk.vmDiskClone.diskAddress = New-Object Nutanix.Prism.Model.DiskAddress
            $primaryDisk.vmDiskClone.diskAddress.deviceBus = "SCSI"
            $primaryDisk.vmDiskClone.diskAddress.deviceIndex = 0
            $primaryDisk.vmDiskClone.vmDiskUuid = $ImageInfo.UUID
        } elseif ($SourceVMInfo) {
            # Clone from VM - this will be handled differently
            Write-Host "    VM cloning from source VM will use different approach" -ForegroundColor Gray
        } else {
            # Create new disk
            $primaryDisk.vmDiskCreate = New-Object Nutanix.Prism.Model.VmDiskSpecCreate
            $primaryDisk.vmDiskCreate.size = $DiskSizeGB * 1024 * 1024 * 1024  # Convert GB to bytes
            $primaryDisk.vmDiskCreate.storageContainerUuid = $ContainerUUID
            $primaryDisk.vmDiskCreate.diskAddress = New-Object Nutanix.Prism.Model.DiskAddress
            $primaryDisk.vmDiskCreate.diskAddress.deviceBus = "SCSI"
            $primaryDisk.vmDiskCreate.diskAddress.deviceIndex = 0
        }

        $vmDisks += $primaryDisk

        # Additional disks
        if ($AdditionalDisks) {
            for ($i = 0; $i -lt $AdditionalDisks.Count; $i++) {
                $additionalDisk = New-Object Nutanix.Prism.Model.VmDisk
                $additionalDisk.vmDiskCreate = New-Object Nutanix.Prism.Model.VmDiskSpecCreate
                $additionalDisk.vmDiskCreate.size = $AdditionalDisks[$i] * 1024 * 1024 * 1024
                $additionalDisk.vmDiskCreate.storageContainerUuid = $ContainerUUID
                $additionalDisk.vmDiskCreate.diskAddress = New-Object Nutanix.Prism.Model.DiskAddress
                $additionalDisk.vmDiskCreate.diskAddress.deviceBus = "SCSI"
                $additionalDisk.vmDiskCreate.diskAddress.deviceIndex = $i + 1
                $vmDisks += $additionalDisk
            }
        }

        $vmSpec.vmDisks = $vmDisks

        # Network configuration
        $vmNics = @()
        $nic = New-Object Nutanix.Prism.Model.VmNic
        $nic.networkUuid = $NetworkUUID
        $nic.macAddress = ""  # Auto-generate MAC address
        $vmNics += $nic
        $vmSpec.vmNics = $vmNics

        return $vmSpec
    }
    catch {
        Write-Error "Failed to create VM specification: $($_.Exception.Message)"
        throw
    }
}

# Function to create VM
function New-NutanixVM {
    param(
        $VMSpec,
        $ClusterUUID,
        $PowerOnAfterCreation,
        $InstallNGT
    )

    try {
        Write-Host "    Creating VM: $($VMSpec.name)" -ForegroundColor Cyan

        # Create the VM
        $createTask = New-NTNXVM -VmSpec $VMSpec

        Write-Host "    ✓ VM creation task initiated" -ForegroundColor Green

        # Wait for VM creation to complete
        $timeout = (Get-Date).AddMinutes(10)
        $vmCreated = $false
        $createdVM = $null

        while ((Get-Date) -lt $timeout -and -not $vmCreated) {
            Start-Sleep -Seconds 10
            $createdVM = Get-NTNXVM | Where-Object { $_.vmName -eq $VMSpec.name }
            if ($createdVM) {
                $vmCreated = $true
            }
        }

        if (-not $vmCreated) {
            throw "VM creation timed out"
        }

        Write-Host "    ✓ VM created successfully: $($createdVM.vmName)" -ForegroundColor Green

        # Install NGT if requested
        if ($InstallNGT) {
            try {
                Write-Host "    Installing Nutanix Guest Tools..." -ForegroundColor Gray
                Install-NTNXGuestTools -Vmid $createdVM.uuid
                Write-Host "    ✓ NGT installation initiated" -ForegroundColor Green
            }
            catch {
                Write-Warning "    Failed to install NGT: $($_.Exception.Message)"
            }
        }

        # Power on if requested
        if ($PowerOnAfterCreation) {
            try {
                Write-Host "    Powering on VM..." -ForegroundColor Gray
                Set-NTNXVMPowerState -Vmid $createdVM.uuid -Transition "ON" | Out-Null
                Write-Host "    ✓ VM powered on" -ForegroundColor Green
            }
            catch {
                Write-Warning "    Failed to power on VM: $($_.Exception.Message)"
            }
        }

        return @{
            VM = $createdVM
            Status = "Success"
            Message = "VM created successfully"
            TaskId = if ($createTask.taskUuid) { $createTask.taskUuid } else { "N/A" }
        }
    }
    catch {
        return @{
            VM = $null
            Status = "Failed"
            Message = $_.Exception.Message
            TaskId = "N/A"
        }
    }
}

# Function to clone VM
function Copy-NutanixVM {
    param(
        $SourceVMInfo,
        $NewVMName,
        $PowerOnAfterCreation
    )

    try {
        Write-Host "    Cloning VM from: $($SourceVMInfo.Name)" -ForegroundColor Cyan

        # Create clone specification
        $cloneSpec = New-Object Nutanix.Prism.Model.CloneSpec
        $cloneSpec.name = $NewVMName
        $cloneSpec.uuid = $SourceVMInfo.UUID

        # Clone the VM
        $cloneTask = Copy-NTNXVM -Vmid $SourceVMInfo.UUID -CloneSpec $cloneSpec

        Write-Host "    ✓ VM clone task initiated" -ForegroundColor Green

        # Wait for clone to complete
        $timeout = (Get-Date).AddMinutes(15)
        $vmCloned = $false
        $clonedVM = $null

        while ((Get-Date) -lt $timeout -and -not $vmCloned) {
            Start-Sleep -Seconds 10
            $clonedVM = Get-NTNXVM | Where-Object { $_.vmName -eq $NewVMName }
            if ($clonedVM) {
                $vmCloned = $true
            }
        }

        if (-not $vmCloned) {
            throw "VM clone timed out"
        }

        Write-Host "    ✓ VM cloned successfully: $($clonedVM.vmName)" -ForegroundColor Green

        # Power on if requested
        if ($PowerOnAfterCreation) {
            try {
                Write-Host "    Powering on cloned VM..." -ForegroundColor Gray
                Set-NTNXVMPowerState -Vmid $clonedVM.uuid -Transition "ON" | Out-Null
                Write-Host "    ✓ Cloned VM powered on" -ForegroundColor Green
            }
            catch {
                Write-Warning "    Failed to power on cloned VM: $($_.Exception.Message)"
            }
        }

        return @{
            VM = $clonedVM
            Status = "Success"
            Message = "VM cloned successfully"
            TaskId = if ($cloneTask.taskUuid) { $cloneTask.taskUuid } else { "N/A" }
        }
    }
    catch {
        return @{
            VM = $null
            Status = "Failed"
            Message = $_.Exception.Message
            TaskId = "N/A"
        }
    }
}

# Function to display creation results
function Show-CreationResults {
    param($Results, $OutputFormat, $OutputPath)

    Write-Host "`n=== VM Creation Results ===" -ForegroundColor Cyan

    $successful = $Results | Where-Object { $_.Status -eq "Success" }
    $failed = $Results | Where-Object { $_.Status -eq "Failed" }

    Write-Host "Total VMs: $($Results.Count)" -ForegroundColor White
    Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red

    if ($successful.Count -gt 0) {
        Write-Host "`nSuccessfully Created VMs:" -ForegroundColor Green
        foreach ($result in $successful) {
            $vm = $result.VM
            Write-Host "  ✓ $($vm.vmName) [UUID: $($vm.uuid)] [State: $($vm.powerState)]" -ForegroundColor White
        }
    }

    if ($failed.Count -gt 0) {
        Write-Host "`nFailed VM Creations:" -ForegroundColor Red
        foreach ($result in $failed) {
            Write-Host "  ✗ $($result.VMName): $($result.Message)" -ForegroundColor White
        }
    }

    # Export results if requested
    if ($OutputFormat -ne "Console") {
        $exportData = $Results | ForEach-Object {
            [PSCustomObject]@{
                VMName = if ($_.VM) { $_.VM.vmName } else { $_.VMName }
                UUID = if ($_.VM) { $_.VM.uuid } else { "N/A" }
                Status = $_.Status
                Message = $_.Message
                PowerState = if ($_.VM) { $_.VM.powerState } else { "N/A" }
                CPUCores = if ($_.VM) { $_.VM.numVcpus } else { "N/A" }
                MemoryMB = if ($_.VM) { $_.VM.memoryMb } else { "N/A" }
                TaskId = $_.TaskId
                Timestamp = Get-Date
            }
        }

        switch ($OutputFormat) {
            "CSV" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_VM_Creation_Results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                }
                $exportData | Export-Csv -Path $OutputPath -NoTypeInformation
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
            "JSON" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_VM_Creation_Results_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                }
                $exportData | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
        }
    }
}

# Main execution
try {
    Write-Host "=== Nutanix AHV VM Creation ===" -ForegroundColor Cyan

    # Determine target server
    $targetServer = if ($PrismCentral) { $PrismCentral } else { $PrismElement }
    $serverType = if ($PrismCentral) { "Prism Central" } else { "Prism Element" }

    if (-not $targetServer) {
        throw "Either PrismCentral or PrismElement parameter must be specified"
    }

    Write-Host "Target $serverType`: $targetServer" -ForegroundColor White
    Write-Host ""

    # Check and install Nutanix PowerShell SDK
    if (-not (Test-NutanixSDKInstallation)) {
        throw "Nutanix PowerShell SDK installation failed"
    }

    # Connect to Nutanix
    $connection = Connect-ToNutanix -Server $targetServer -ServerType $serverType

    # Resolve cluster information
    $clusterInfo = Get-ClusterInfo -ClusterName $ClusterName -ClusterUUID $ClusterUUID
    Write-Host "Target Cluster: $($clusterInfo.Name) [$($clusterInfo.UUID)]" -ForegroundColor White

    # Resolve storage container information
    $containerInfo = Get-ContainerInfo -ContainerName $ContainerName -ContainerUUID $ContainerUUID -ClusterUUID $clusterInfo.UUID
    Write-Host "Storage Container: $($containerInfo.Name) [$($containerInfo.UUID)]" -ForegroundColor White

    # Resolve network information
    $networkInfo = Get-NetworkInfo -NetworkName $NetworkName -NetworkUUID $NetworkUUID
    Write-Host "Network: $($networkInfo.Name) [$($networkInfo.UUID)]" -ForegroundColor White

    # Resolve image information if specified
    $imageInfo = Get-ImageInfo -ImageName $ImageName -ImageUUID $ImageUUID
    if ($imageInfo) {
        Write-Host "Base Image: $($imageInfo.Name) [$($imageInfo.UUID)]" -ForegroundColor White
    }

    # Resolve source VM information if specified
    $sourceVMInfo = Get-SourceVMInfo -SourceVMName $SourceVMName -SourceVMUUID $SourceVMUUID
    if ($sourceVMInfo) {
        Write-Host "Source VM: $($sourceVMInfo.Name) [$($sourceVMInfo.UUID)]" -ForegroundColor White
    }

    # Generate VM names
    $vmNames = Get-VMNames -VMName $VMName -VMNames $VMNames -VMCount $VMCount -NamePrefix $NamePrefix
    Write-Host "VMs to create: $($vmNames.Count)" -ForegroundColor White
    Write-Host "VM Names: $($vmNames -join ', ')" -ForegroundColor White
    Write-Host ""

    # Confirm operation if not using Force and creating multiple VMs
    if (-not $Force -and $vmNames.Count -gt 1) {
        $confirmation = Read-Host "Proceed with creating $($vmNames.Count) VM(s)? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Create VMs
    Write-Host "Creating VMs..." -ForegroundColor Yellow
    $results = @()

    foreach ($vmName in $vmNames) {
        try {
            Write-Host "  Processing VM: $vmName" -ForegroundColor Cyan

            if ($sourceVMInfo) {
                # Clone from existing VM
                $result = Copy-NutanixVM -SourceVMInfo $sourceVMInfo -NewVMName $vmName -PowerOnAfterCreation:$PowerOnAfterCreation
                $result.VMName = $vmName
                $results += $result
            } else {
                # Create new VM
                $vmSpec = New-VMSpecification -VMName $vmName -ClusterUUID $clusterInfo.UUID -ContainerUUID $containerInfo.UUID -NetworkUUID $networkInfo.UUID -CPUCores $CPUCores -CPUSockets $CPUSockets -MemoryGB $MemoryGB -DiskSizeGB $DiskSizeGB -AdditionalDisks $AdditionalDisks -ImageInfo $imageInfo -SourceVMInfo $sourceVMInfo

                $result = New-NutanixVM -VMSpec $vmSpec -ClusterUUID $clusterInfo.UUID -PowerOnAfterCreation:$PowerOnAfterCreation -InstallNGT:$InstallNGT
                $result.VMName = $vmName
                $results += $result
            }
        }
        catch {
            $results += @{
                VM = $null
                VMName = $vmName
                Status = "Failed"
                Message = $_.Exception.Message
                TaskId = "N/A"
            }
            Write-Host "    ✗ Failed to create VM: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Display results
    Show-CreationResults -Results $results -OutputFormat $OutputFormat -OutputPath $OutputPath

    Write-Host "`n=== VM Creation Completed ===" -ForegroundColor Green
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
