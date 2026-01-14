<#
.SYNOPSIS
    Create a Google Cloud VM instance using Google Cloud CLI (gcloud).

.DESCRIPTION
    This script creates a Google Cloud VM instance with customizable options like machine type,
    image family, zone, and more using parameters. The script validates inputs and provides
    robust error handling for reliable automation.

.PARAMETER Project
    The Google Cloud project ID in which the VM will be created.

.PARAMETER Zone
    The zone where the virtual machine will be deployed. Must be a valid GCP zone format.
    Examples: us-central1-a, europe-west1-b, asia-east1-c

.PARAMETER MachineType
    The machine type for the virtual machine. Must be a valid GCP machine type.
    Examples: e2-micro, n1-standard-1, c2-standard-4

.PARAMETER ImageFamily
    The image family to use for the boot disk.
    Examples: debian-11, ubuntu-2004-lts, windows-2019

.PARAMETER ImageProject
    The project where the image is stored.
    Examples: debian-cloud, ubuntu-os-cloud, windows-cloud

.PARAMETER InstanceName
    The name of the virtual machine instance. Must follow GCP naming conventions.

.PARAMETER DiskSize
    The size of the boot disk in GB. Must be between 10 and 65536 GB.

.PARAMETER Network
    The network to attach the VM to (default: default).

.PARAMETER Subnet
    The subnet to use for the VM (optional). If specified, must be a valid subnet name.

.PARAMETER Tags
    Comma-separated network tags for the VM (optional).
    Example: "web-server,https-server"

.PARAMETER Preemptible
    Create a preemptible instance that can be stopped by Google Cloud with 30 seconds notice.

.PARAMETER Labels
    Key-value pairs for labeling the instance (optional).
    Example: "environment=dev,team=backend"

.PARAMETER ServiceAccount
    Service account email to attach to the instance (optional).

.PARAMETER Scopes
    Comma-separated list of access scopes for the service account (optional).
    Example: "https://www.googleapis.com/auth/cloud-platform"

.EXAMPLE
    .\gce-cli-create-vm.ps1 -Project "my-project-123" -Zone "us-central1-a" -MachineType "e2-medium" `
    -ImageFamily "debian-11" -ImageProject "debian-cloud" -InstanceName "web-server-01" -DiskSize 20

.EXAMPLE
    .\gce-cli-create-vm.ps1 -Project "my-project-123" -Zone "us-west1-b" -MachineType "n1-standard-2" `
    -ImageFamily "ubuntu-2004-lts" -ImageProject "ubuntu-os-cloud" -InstanceName "app-server" `
    -DiskSize 50 -Preemptible -Tags "web-server,https-server" -Labels "env=prod,team=backend"

.NOTES
    Prerequisites:
    - Google Cloud CLI (gcloud) must be installed and authenticated
    - User must have compute.instances.create permission in the target project

    Author: XOAP
    Date: 2025-08-06
    Version: 2.0
    Requires: Google Cloud SDK
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z]+-[a-z0-9]+-[a-z]$')]
    [string]$Zone,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$MachineType,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ImageFamily,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ImageProject,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z][a-z0-9\-]{0,61}[a-z0-9]$')]
    [string]$InstanceName,

    [Parameter(Mandatory = $true)]
    [ValidateRange(10, 65536)]
    [int]$DiskSize,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Network = "default",

    [Parameter(Mandatory = $false)]
    [string]$Subnet,

    [Parameter(Mandatory = $false)]
    [string]$Tags,

    [Parameter(Mandatory = $false)]
    [switch]$Preemptible,

    [Parameter(Mandatory = $false)]
    [string]$Labels,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-z0-9\-]+@[a-z0-9\-\.]+\.iam\.gserviceaccount\.com$')]
    [string]$ServiceAccount,

    [Parameter(Mandatory = $false)]
    [string]$Scopes
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to test gcloud authentication and availability
function Test-GCloudAuth {
    try {
        $authResult = & gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null
        if (-not $authResult) {
            throw "No active gcloud authentication found. Please run 'gcloud auth login' first."
        }
        Write-Output "Authenticated as: $authResult"
        return $true
    }
    catch {
        throw "gcloud CLI is not available or not authenticated. Please install gcloud and authenticate."
    }
}

# Function to build gcloud command arguments
function Build-GCloudArguments {
    param($Parameters)

    $arguments = @(
        'compute', 'instances', 'create', $Parameters.InstanceName,
        '--zone', $Parameters.Zone,
        '--machine-type', $Parameters.MachineType,
        '--boot-disk-size', $Parameters.DiskSize,
        '--image-family', $Parameters.ImageFamily,
        '--image-project', $Parameters.ImageProject,
        '--network', $Parameters.Network
    )

    # Add optional parameters
    if ($Parameters.Subnet) {
        $arguments += '--subnet', $Parameters.Subnet
    }

    if ($Parameters.Tags) {
        $arguments += '--tags', $Parameters.Tags
    }

    if ($Parameters.Labels) {
        $arguments += '--labels', $Parameters.Labels
    }

    if ($Parameters.ServiceAccount) {
        $arguments += '--service-account', $Parameters.ServiceAccount
    }

    if ($Parameters.Scopes) {
        $arguments += '--scopes', $Parameters.Scopes
    }

    if ($Parameters.Preemptible) {
        $arguments += '--preemptible'
    }

    return $arguments
}

try {
    Write-Output "Starting Google Cloud VM creation process..."

    # Test gcloud authentication
    Test-GCloudAuth

    # Set the active project
    Write-Output "Setting active project to: $Project"
    $setProjectResult = & gcloud config set project $Project 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set project '$Project'. Error: $setProjectResult"
    }

    # Prepare parameters for the function
    $gcloudParams = @{
        InstanceName   = $InstanceName
        Zone           = $Zone
        MachineType    = $MachineType
        DiskSize       = $DiskSize
        ImageFamily    = $ImageFamily
        ImageProject   = $ImageProject
        Network        = $Network
        Subnet         = $Subnet
        Tags           = $Tags
        Labels         = $Labels
        ServiceAccount = $ServiceAccount
        Scopes         = $Scopes
        Preemptible    = $Preemptible.IsPresent
    }

    # Build command arguments
    $arguments = Build-GCloudArguments -Parameters $gcloudParams

    # Display the command for transparency
    Write-Output "Executing: gcloud $($arguments -join ' ')"

    # Execute the gcloud command
    $result = & gcloud @arguments 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Output "✅ Virtual machine '$InstanceName' created successfully in project '$Project'."
        Write-Output "Zone: $Zone"
        Write-Output "Machine Type: $MachineType"
        Write-Output "Boot Disk Size: $DiskSize GB"

        # Display additional configuration if provided
        if ($Tags) { Write-Output "Tags: $Tags" }
        if ($Labels) { Write-Output "Labels: $Labels" }
        if ($Preemptible) { Write-Output "Instance Type: Preemptible" }
    }
    else {
        $errorMessage = $result -join "`n"
        throw "Failed to create VM instance. gcloud exit code: $LASTEXITCODE. Error: $errorMessage"
    }
}
catch {
    Write-Error "❌ Failed to create Google Cloud VM instance: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Output "Script execution completed."
}
