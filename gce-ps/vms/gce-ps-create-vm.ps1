<#
.SYNOPSIS
    Create a Google Cloud VM instance using the Google Cloud PowerShell module.

.DESCRIPTION
    This script creates a Google Cloud VM instance using the Add-GceInstance cmdlet from the
    Google Cloud PowerShell module. It provides comprehensive parameter validation, error handling,
    and supports common VM configuration scenarios with sensible defaults.

.PARAMETER Project
    The Google Cloud project ID in which the VM will be created.
    Must follow GCP project ID naming conventions (6-30 characters, lowercase letters, digits, hyphens).

.PARAMETER Zone
    The zone where the virtual machine will be deployed. Must be a valid GCP zone format.
    Examples: us-central1-a, europe-west1-b, asia-east1-c

.PARAMETER Name
    The name of the VM instance. Must follow GCP naming conventions.
    Must be 1-63 characters, lowercase letters, digits, and hyphens only.

.PARAMETER MachineType
    The machine type for the virtual machine. Must be a valid GCP machine type.
    Examples: e2-micro, n1-standard-1, c2-standard-4, n2-highmem-2

.PARAMETER ImageFamily
    The image family to use for the boot disk. Commonly used alternative to BootDiskImage.
    Examples: debian-11, ubuntu-2004-lts, windows-2019, centos-7

.PARAMETER ImageProject
    The project where the image is stored. Required when using ImageFamily.
    Examples: debian-cloud, ubuntu-os-cloud, windows-cloud, centos-cloud

.PARAMETER DiskSizeGb
    The size of the boot disk in GB. Must be at least 10 GB.
    Default varies by image (typically 10 GB for Linux, 50 GB for Windows).

.PARAMETER DiskType
    The type of boot disk to create.
    Valid values: pd-standard, pd-ssd, pd-balanced

.PARAMETER CanIpForward
    Enables IP forwarding for the VM instance. Useful for VPN gateways or NAT instances.

.PARAMETER Description
    A description for the VM instance (optional).

.PARAMETER BootDisk
    Custom boot disk configuration object. Alternative to ImageFamily/ImageProject.

.PARAMETER BootDiskImage
    Custom boot disk image object. Alternative to ImageFamily/ImageProject.

.PARAMETER ExtraDisk
    Additional disks to attach to the VM instance.

.PARAMETER Disk
    All disk configurations for the VM instance.

.PARAMETER Metadata
    Metadata key-value pairs for the VM instance.
    Example: @{"startup-script" = "#!/bin/bash\necho 'Hello World'"}

.PARAMETER Network
    The network to attach the VM to. Defaults to "default".

.PARAMETER Region
    The region for the VM instance (derived from zone if not specified).

.PARAMETER Subnetwork
    The subnetwork to use for the VM (optional).

.PARAMETER NoExternalIp
    Disables external IP assignment for the VM instance.

.PARAMETER Preemptible
    Creates a preemptible instance that can be stopped by Google Cloud with 30 seconds notice.
    Preemptible instances are significantly cheaper but less reliable.

.PARAMETER AutomaticRestart
    Enables automatic restart for the VM instance on host maintenance (default: true).
    Must be false for preemptible instances.

.PARAMETER TerminateOnMaintenance
    Terminates the VM instance during host maintenance instead of migrating.

.PARAMETER ServiceAccount
    Service account configuration for the VM instance.

.PARAMETER Tag
    Network tags for the VM instance. Used for firewall rules and routing.
    Example: @("web-server", "https-server")

.PARAMETER Label
    Labels for the VM instance (key-value pairs for organization).
    Example: @{"environment" = "dev"; "team" = "backend"}

.PARAMETER Address
    Static external IP address for the VM instance.

.EXAMPLE
    .\gce-ps-create-vm.ps1 -Project "my-project-123" -Zone "us-central1-a" -Name "web-server-01" -MachineType "e2-medium"

    Create a basic VM with minimal configuration using default settings.

.EXAMPLE
    .\gce-ps-create-vm.ps1 -Project "my-project-123" -Zone "us-central1-a" -Name "app-server" `
    -MachineType "n1-standard-2" -ImageFamily "debian-11" -ImageProject "debian-cloud" `
    -DiskSizeGb 50 -Tag @("web-server","https-server") -Label @{"env"="prod";"team"="backend"}

    Create a production VM with specific image, larger disk, and tags/labels.

.EXAMPLE
    .\gce-ps-create-vm.ps1 -Project "my-project-123" -Zone "us-west1-b" -Name "dev-instance" `
    -MachineType "e2-micro" -ImageFamily "ubuntu-2004-lts" -ImageProject "ubuntu-os-cloud" `
    -Preemptible -NoExternalIp -Metadata @{"startup-script"="#!/bin/bash\napt update && apt install -y nginx"}

    Create a preemptible development VM with no external IP and startup script.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: GoogleCloud PowerShell Module

.LINK
    https://cloud.google.com/powershell/docs/reference/GoogleCloudBeta/1.0.0.0/Add-GceInstance

.COMPONENT
    Google Cloud PowerShell Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The Google Cloud project ID in which the VM will be created.")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$Project,

    [Parameter(Mandatory = $true, HelpMessage = "The zone where the virtual machine will be deployed. Examples: us-central1-a, europe-west1-b.")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z]+-[a-z0-9]+-[a-z]$')]
    [string]$Zone,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the VM instance. Must follow GCP naming conventions (1-63 chars, lowercase letters, digits, hyphens).")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z][a-z0-9\-]{0,61}[a-z0-9]$')]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "The machine type for the virtual machine. Examples: e2-micro, n1-standard-1, c2-standard-4.")]
    [ValidateNotNullOrEmpty()]
    [string]$MachineType,

    [Parameter(Mandatory = $false, HelpMessage = "The image family to use for the boot disk. Examples: debian-11, ubuntu-2004-lts, windows-2019.")]
    [ValidateNotNullOrEmpty()]
    [string]$ImageFamily,

    [Parameter(Mandatory = $false, HelpMessage = "The project where the image is stored. Examples: debian-cloud, ubuntu-os-cloud, windows-cloud.")]
    [ValidateNotNullOrEmpty()]
    [string]$ImageProject,

    [Parameter(Mandatory = $false, HelpMessage = "The size of the boot disk in GB. Must be at least 10 GB.")]
    [ValidateRange(10, 65536)]
    [int]$DiskSizeGb,

    [Parameter(Mandatory = $false, HelpMessage = "The type of boot disk to create. Valid values: pd-standard, pd-ssd, pd-balanced.")]
    [ValidateSet("pd-standard", "pd-ssd", "pd-balanced")]
    [string]$DiskType = "pd-balanced",

    [Parameter(Mandatory = $false, HelpMessage = "Enables IP forwarding for the VM instance. Useful for VPN gateways or NAT instances.")]
    [switch]$CanIpForward,

    [Parameter(Mandatory = $false, HelpMessage = "A description for the VM instance.")]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "Custom boot disk configuration object. Alternative to ImageFamily/ImageProject.")]
    [PSObject]$BootDisk,

    [Parameter(Mandatory = $false, HelpMessage = "Custom boot disk image object. Alternative to ImageFamily/ImageProject.")]
    [PSObject]$BootDiskImage,

    [Parameter(Mandatory = $false, HelpMessage = "Additional disks to attach to the VM instance.")]
    [PSObject[]]$ExtraDisk,

    [Parameter(Mandatory = $false, HelpMessage = "All disk configurations for the VM instance.")]
    [PSObject[]]$Disk,

    [Parameter(Mandatory = $false, HelpMessage = "Metadata key-value pairs for the VM instance.")]
    [hashtable]$Metadata,

    [Parameter(Mandatory = $false, HelpMessage = "The network to attach the VM to. Defaults to 'default'.")]
    [string]$Network = "default",

    [Parameter(Mandatory = $false, HelpMessage = "The region for the VM instance (derived from zone if not specified).")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "The subnetwork to use for the VM.")]
    [string]$Subnetwork,

    [Parameter(Mandatory = $false, HelpMessage = "Disables external IP assignment for the VM instance.")]
    [switch]$NoExternalIp,

    [Parameter(Mandatory = $false, HelpMessage = "Creates a preemptible instance that can be stopped by Google Cloud with 30 seconds notice.")]
    [switch]$Preemptible,

    [Parameter(Mandatory = $false, HelpMessage = "Enables automatic restart for the VM instance on host maintenance. Must be false for preemptible instances.")]
    [bool]$AutomaticRestart = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Terminates the VM instance during host maintenance instead of migrating.")]
    [switch]$TerminateOnMaintenance,

    [Parameter(Mandatory = $false, HelpMessage = "Service account configuration for the VM instance.")]
    [PSObject[]]$ServiceAccount,

    [Parameter(Mandatory = $false, HelpMessage = "Network tags for the VM instance. Used for firewall rules and routing.")]
    [string[]]$Tag,

    [Parameter(Mandatory = $false, HelpMessage = "Labels for the VM instance as key-value pairs for organization.")]
    [hashtable]$Label,

    [Parameter(Mandatory = $false, HelpMessage = "Static external IP address for the VM instance.")]
    [string]$Address
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to test Google Cloud PowerShell module availability
function Test-GoogleCloudModule {
    try {
        $module = Get-Module -Name GoogleCloud -ListAvailable
        if (-not $module) {
            throw "GoogleCloud PowerShell module is not installed. Please install it using: Install-Module GoogleCloud"
        }

        # Import the module if not already loaded
        if (-not (Get-Module -Name GoogleCloud)) {
            Write-Output "Loading Google Cloud PowerShell module..."
            Import-Module GoogleCloud -ErrorAction Stop
        }

        Write-Output "Google Cloud PowerShell module is available."
        return $true
    }
    catch {
        throw "Failed to load Google Cloud PowerShell module: $($_.Exception.Message)"
    }
}

# Function to validate preemptible instance configuration
function Test-PreemptibleConfiguration {
    param([bool]$IsPreemptible, [bool]$AutoRestart)

    if ($IsPreemptible -and $AutoRestart) {
        throw "Preemptible instances cannot have AutomaticRestart enabled. Set AutomaticRestart to false for preemptible instances."
    }
}

# Function to create boot disk configuration when using ImageFamily
function New-BootDiskFromImage {
    param(
        [string]$ImageFamily,
        [string]$ImageProject,
        [int]$SizeGb,
        [string]$Type
    )

    if (-not $ImageFamily -or -not $ImageProject) {
        return $null
    }

    try {
        # Get the latest image from the family
        $image = Get-GceImage -Family $ImageFamily -Project $ImageProject
        if (-not $image) {
            throw "Could not find image in family '$ImageFamily' from project '$ImageProject'"
        }

        Write-Output "Using image: $($image.Name) from family: $ImageFamily"

        # Create boot disk configuration
        $bootDiskConfig = New-Object Google.Apis.Compute.v1.Data.AttachedDisk
        $bootDiskConfig.Boot = $true
        $bootDiskConfig.AutoDelete = $true
        $bootDiskConfig.InitializeParams = New-Object Google.Apis.Compute.v1.Data.AttachedDiskInitializeParams
        $bootDiskConfig.InitializeParams.SourceImage = $image.SelfLink
        $bootDiskConfig.InitializeParams.DiskType = "zones/$Zone/diskTypes/$Type"

        if ($SizeGb) {
            $bootDiskConfig.InitializeParams.DiskSizeGb = $SizeGb
        }

        return $bootDiskConfig
    }
    catch {
        throw "Failed to create boot disk configuration: $($_.Exception.Message)"
    }
}

# Function to build parameters for Add-GceInstance
function Build-GceInstanceParameters {
    param($InputParameters)

    # Start with core parameters
    $gceParams = @{
        Project     = $InputParameters.Project
        Zone        = $InputParameters.Zone
        Name        = $InputParameters.Name
        MachineType = $InputParameters.MachineType
    }

    # Add optional parameters only if they have values
    if ($InputParameters.CanIpForward) { $gceParams.CanIpForward = $InputParameters.CanIpForward }
    if ($InputParameters.Description) { $gceParams.Description = $InputParameters.Description }
    if ($InputParameters.Network) { $gceParams.Network = $InputParameters.Network }
    if ($InputParameters.Region) { $gceParams.Region = $InputParameters.Region }
    if ($InputParameters.Subnetwork) { $gceParams.Subnetwork = $InputParameters.Subnetwork }
    if ($InputParameters.NoExternalIp) { $gceParams.NoExternalIp = $InputParameters.NoExternalIp }
    if ($InputParameters.Preemptible) { $gceParams.Preemptible = $InputParameters.Preemptible }
    if ($InputParameters.TerminateOnMaintenance) { $gceParams.TerminateOnMaintenance = $InputParameters.TerminateOnMaintenance }
    if ($InputParameters.ServiceAccount) { $gceParams.ServiceAccount = $InputParameters.ServiceAccount }
    if ($InputParameters.Tag) { $gceParams.Tag = $InputParameters.Tag }
    if ($InputParameters.Label) { $gceParams.Label = $InputParameters.Label }
    if ($InputParameters.Address) { $gceParams.Address = $InputParameters.Address }
    if ($InputParameters.Metadata) { $gceParams.Metadata = $InputParameters.Metadata }
    if ($InputParameters.ExtraDisk) { $gceParams.ExtraDisk = $InputParameters.ExtraDisk }
    if ($InputParameters.Disk) { $gceParams.Disk = $InputParameters.Disk }

    # Handle AutomaticRestart (explicit false handling)
    $gceParams.AutomaticRestart = $InputParameters.AutomaticRestart

    # Handle boot disk configuration
    if ($InputParameters.BootDisk) {
        $gceParams.BootDisk = $InputParameters.BootDisk
    }
    elseif ($InputParameters.BootDiskImage) {
        $gceParams.BootDiskImage = $InputParameters.BootDiskImage
    }
    elseif ($InputParameters.ImageFamily -and $InputParameters.ImageProject) {
        $bootDisk = New-BootDiskFromImage -ImageFamily $InputParameters.ImageFamily -ImageProject $InputParameters.ImageProject -SizeGb $InputParameters.DiskSizeGb -Type $InputParameters.DiskType
        if ($bootDisk) {
            $gceParams.BootDisk = $bootDisk
        }
    }

    return $gceParams
}

try {
    Write-Output "Starting Google Cloud VM creation process..."

    # Test Google Cloud PowerShell module
    Test-GoogleCloudModule

    # Validate configuration
    Test-PreemptibleConfiguration -IsPreemptible $Preemptible.IsPresent -AutoRestart $AutomaticRestart

    # Check for required ImageProject when ImageFamily is specified
    if ($ImageFamily -and -not $ImageProject) {
        throw "ImageProject is required when ImageFamily is specified. Common values: debian-cloud, ubuntu-os-cloud, windows-cloud, centos-cloud"
    }

    # Set current project context
    Write-Output "Setting active project to: $Project"
    try {
        Set-GcpProject -ProjectId $Project
        Write-Output "Project context set successfully."
    }
    catch {
        Write-Warning "Could not set project context, but will continue with explicit project parameter."
    }

    # Prepare parameters
    $instanceParams = @{
        Project                = $Project
        Zone                   = $Zone
        Name                   = $Name
        MachineType            = $MachineType
        ImageFamily            = $ImageFamily
        ImageProject           = $ImageProject
        DiskSizeGb             = $DiskSizeGb
        DiskType               = $DiskType
        CanIpForward           = $CanIpForward
        Description            = $Description
        BootDisk               = $BootDisk
        BootDiskImage          = $BootDiskImage
        ExtraDisk              = $ExtraDisk
        Disk                   = $Disk
        Metadata               = $Metadata
        Network                = $Network
        Region                 = $Region
        Subnetwork             = $Subnetwork
        NoExternalIp           = $NoExternalIp
        Preemptible            = $Preemptible
        AutomaticRestart       = $AutomaticRestart
        TerminateOnMaintenance = $TerminateOnMaintenance
        ServiceAccount         = $ServiceAccount
        Tag                    = $Tag
        Label                  = $Label
        Address                = $Address
    }

    # Build final parameters for Add-GceInstance
    $gceParameters = Build-GceInstanceParameters -InputParameters $instanceParams

    # Display configuration summary
    Write-Output "VM Configuration:"
    Write-Output "  • Instance Name: $Name"
    Write-Output "  • Project: $Project"
    Write-Output "  • Zone: $Zone"
    Write-Output "  • Machine Type: $MachineType"
    if ($ImageFamily) { Write-Output "  • Image Family: $ImageFamily ($ImageProject)" }
    if ($DiskSizeGb) { Write-Output "  • Boot Disk Size: $DiskSizeGb GB ($DiskType)" }
    Write-Output "  • Network: $Network"
    if ($Preemptible) { Write-Output "  • Instance Type: Preemptible" }
    if ($Tag) { Write-Output "  • Tags: $($Tag -join ', ')" }
    if ($Label) { Write-Output "  • Labels: $($Label.Keys | ForEach-Object { "$_=$($Label[$_])" } | Join-String -Separator ', ')" }

    # Create the VM instance
    Write-Output "`n🚀 Creating VM instance..."
    $result = Add-GceInstance @gceParameters

    if ($result) {
        Write-Output "Virtual machine '$Name' created successfully in project '$Project'!"
        Write-Output "Zone: $Zone"
        Write-Output "Machine Type: $MachineType"

        # Display instance details if available
        if ($result.SelfLink) {
            Write-Output "Instance URL: $($result.SelfLink)"
        }

        # Get and display network information
        try {
            Start-Sleep -Seconds 2  # Wait for instance to be fully created
            $instance = Get-GceInstance -Project $Project -Zone $Zone -Name $Name
            if ($instance.NetworkInterfaces) {
                $networkInterface = $instance.NetworkInterfaces[0]
                Write-Output "Internal IP: $($networkInterface.NetworkIP)"

                if ($networkInterface.AccessConfigs) {
                    $externalIP = $networkInterface.AccessConfigs[0].NatIP
                    if ($externalIP) {
                        Write-Output "External IP: $externalIP"
                    }
                }
            }
        }
        catch {
            Write-Warning "Could not retrieve network information: $($_.Exception.Message)"
        }
    }
    else {
        throw "VM creation completed but no result object was returned."
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
