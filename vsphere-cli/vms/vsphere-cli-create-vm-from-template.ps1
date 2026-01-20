<#
.SYNOPSIS
    Creates a new VM from a vSphere template using PowerCLI.

.DESCRIPTION
    This script creates a new virtual machine from an existing template in vSphere.
    Includes guest OS customization, network configuration, and resource allocation.
    Requires VMware PowerCLI and connection to vCenter Server.

.PARAMETER VCenterServer
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER VMName
    The name for the new virtual machine.

.PARAMETER TemplateName
    The name of the VM template to use for creation.

.PARAMETER DatastoreName
    The datastore where the new VM will be created.

.PARAMETER ClusterName
    The cluster where the new VM will be created.

.PARAMETER ResourcePoolName
    The resource pool for the new VM (optional).

.PARAMETER FolderName
    The folder where the new VM will be placed (optional).

.PARAMETER PortGroupName
    The network port group to connect the VM to.

.PARAMETER CPUCount
    Number of CPU cores for the new VM (optional, defaults to template settings).

.PARAMETER MemoryGB
    Memory in GB for the new VM (optional, defaults to template settings).

.PARAMETER OSCustomizationSpec
    The OS customization specification name (optional).

.PARAMETER PowerOnAfterCreation
    Whether to power on the VM after creation (default: false).

.PARAMETER WaitForCompletion
    Whether to wait for the VM creation task to complete (default: true).

.EXAMPLE
    .\vsphere-cli-create-vm-from-template.ps1 -VCenterServer "vcenter.domain.com" -VMName "WebServer01" -TemplateName "Windows2022-Template" -DatastoreName "Datastore1" -ClusterName "Production-Cluster" -PortGroupName "VLAN100-Production"

.EXAMPLE
    .\vsphere-cli-create-vm-from-template.ps1 -VCenterServer "vcenter.domain.com" -VMName "TestVM01" -TemplateName "Ubuntu22-Template" -DatastoreName "Datastore2" -ClusterName "Test-Cluster" -PortGroupName "VLAN200-Test" -CPUCount 2 -MemoryGB 4 -PowerOnAfterCreation

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

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9\-_\.]{0,62}[a-zA-Z0-9]$')]
    [string]$VMName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TemplateName,

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

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PortGroupName,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 128)]
    [int]$CPUCount,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 4096)]
    [int]$MemoryGB,

    [Parameter(Mandatory = $false)]
    [string]$OSCustomizationSpec,

    [Parameter(Mandatory = $false)]
    [switch]$PowerOnAfterCreation,

    [Parameter(Mandatory = $false)]
    [switch]$WaitForCompletion
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

# Function to validate required vSphere objects exist
function Test-VSphereObjects {
    param(
        $TemplateName,
        $DatastoreName,
        $ClusterName,
        $ResourcePoolName,
        $FolderName,
        $PortGroupName,
        $OSCustomizationSpec
    )

    Write-Host "Validating vSphere objects..." -ForegroundColor Yellow

    # Check template
    $template = Get-Template -Name $TemplateName -ErrorAction SilentlyContinue
    if (-not $template) {
        throw "Template '$TemplateName' not found"
    }
    Write-Host "✓ Template '$TemplateName' found" -ForegroundColor Green

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

    # Check port group
    $portGroup = Get-VirtualPortGroup -Name $PortGroupName -ErrorAction SilentlyContinue
    if (-not $portGroup) {
        throw "Port Group '$PortGroupName' not found"
    }
    Write-Host "✓ Port Group '$PortGroupName' found" -ForegroundColor Green

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
        Template = $template
        Datastore = $datastore
        Cluster = $cluster
        ResourcePool = $resourcePool
        Folder = $folder
        PortGroup = $portGroup
        OSSpec = $osSpec
    }
}

# Function to create VM from template
function New-VMFromTemplate {
    param(
        $Objects,
        $VMName,
        $CPUCount,
        $MemoryGB,
        $PowerOnAfterCreation,
        $WaitForCompletion
    )

    # Set default for WaitForCompletion if not specified
    if (-not $PSBoundParameters.ContainsKey('WaitForCompletion')) {
        $WaitForCompletion = $true
    }

    try {
        Write-Host "Creating VM '$VMName' from template '$($Objects.Template.Name)'..." -ForegroundColor Yellow

        # Build VM creation parameters
        $vmParams = @{
            Name = $VMName
            Template = $Objects.Template
            Datastore = $Objects.Datastore
            ResourcePool = $Objects.ResourcePool
        }

        # Add folder if specified
        if ($Objects.Folder) {
            $vmParams.Location = $Objects.Folder
        }

        # Add OS customization if specified
        if ($Objects.OSSpec) {
            $vmParams.OSCustomizationSpec = $Objects.OSSpec
        }

        # Create the VM
        $vm = New-VM @vmParams
        Write-Host "✓ VM '$VMName' created successfully" -ForegroundColor Green

        # Modify CPU count if specified
        if ($CPUCount) {
            Write-Host "Setting CPU count to $CPUCount..." -ForegroundColor Yellow
            $vm | Set-VM -NumCpu $CPUCount -Confirm:$false
            Write-Host "✓ CPU count set to $CPUCount" -ForegroundColor Green
        }

        # Modify memory if specified
        if ($MemoryGB) {
            Write-Host "Setting memory to $MemoryGB GB..." -ForegroundColor Yellow
            $vm | Set-VM -MemoryGB $MemoryGB -Confirm:$false
            Write-Host "✓ Memory set to $MemoryGB GB" -ForegroundColor Green
        }

        # Configure network adapter
        Write-Host "Configuring network adapter..." -ForegroundColor Yellow
        $networkAdapter = $vm | Get-NetworkAdapter
        $networkAdapter | Set-NetworkAdapter -Portgroup $Objects.PortGroup -Confirm:$false
        Write-Host "✓ Network adapter configured for port group '$($Objects.PortGroup.Name)'" -ForegroundColor Green

        # Power on VM if requested
        if ($PowerOnAfterCreation) {
            Write-Host "Powering on VM..." -ForegroundColor Yellow
            $powerOnTask = $vm | Start-VM -RunAsync

            if ($WaitForCompletion) {
                Wait-Task -Task $powerOnTask
                Write-Host "✓ VM '$VMName' powered on successfully" -ForegroundColor Green
            } else {
                Write-Host "✓ VM '$VMName' power-on initiated (running asynchronously)" -ForegroundColor Green
            }
        }

        # Display VM information
        $vmInfo = Get-VM -Name $VMName
        Write-Host "`nVM Creation Summary:" -ForegroundColor Cyan
        Write-Host "Name: $($vmInfo.Name)" -ForegroundColor White
        Write-Host "PowerState: $($vmInfo.PowerState)" -ForegroundColor White
        Write-Host "CPUs: $($vmInfo.NumCpu)" -ForegroundColor White
        Write-Host "Memory: $($vmInfo.MemoryGB) GB" -ForegroundColor White
        Write-Host "Guest OS: $($vmInfo.GuestId)" -ForegroundColor White
        Write-Host "VMware Tools: $($vmInfo.ExtensionData.Guest.ToolsStatus)" -ForegroundColor White

        return $vmInfo
    }
    catch {
        Write-Error "Failed to create VM: $($_.Exception.Message)"
        throw
    }
}

# Main execution
try {
    Write-Host "=== vSphere VM Creation from Template ===" -ForegroundColor Cyan
    Write-Host "Target vCenter: $VCenterServer" -ForegroundColor White
    Write-Host "VM Name: $VMName" -ForegroundColor White
    Write-Host "Template: $TemplateName" -ForegroundColor White
    Write-Host "Datastore: $DatastoreName" -ForegroundColor White
    Write-Host "Cluster: $ClusterName" -ForegroundColor White
    Write-Host ""

    # Check and install PowerCLI
    if (-not (Test-PowerCLIInstallation)) {
        throw "PowerCLI installation failed"
    }

    # Connect to vCenter
    $connection = Connect-ToVCenter -Server $VCenterServer

    # Check if VM already exists
    $existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if ($existingVM) {
        Write-Warning "VM '$VMName' already exists with PowerState: $($existingVM.PowerState)"
        Write-Host "VM Details:" -ForegroundColor Yellow
        Write-Host "  CPUs: $($existingVM.NumCpu)" -ForegroundColor White
        Write-Host "  Memory: $($existingVM.MemoryGB) GB" -ForegroundColor White
        Write-Host "  Guest OS: $($existingVM.GuestId)" -ForegroundColor White
        return
    }

    # Validate vSphere objects
    $objects = Test-VSphereObjects -TemplateName $TemplateName -DatastoreName $DatastoreName -ClusterName $ClusterName -ResourcePoolName $ResourcePoolName -FolderName $FolderName -PortGroupName $PortGroupName -OSCustomizationSpec $OSCustomizationSpec

    # Create VM from template
    New-VMFromTemplate -Objects $objects -VMName $VMName -CPUCount $CPUCount -MemoryGB $MemoryGB -PowerOnAfterCreation:$PowerOnAfterCreation -WaitForCompletion:$WaitForCompletion

    Write-Host "`n=== VM Creation Completed Successfully ===" -ForegroundColor Green
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
