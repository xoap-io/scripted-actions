<#
.SYNOPSIS
    Create a Google Cloud VM instance.

.DESCRIPTION
    This script creates a Google Cloud VM instance using the `Add-GceInstance` cmdlet.

.PARAMETER Project
    Defines the Google Cloud project ID.

.PARAMETER Zone
    Defines the zone where the VM instance will be created.

.PARAMETER Name
    Defines the name of the VM instance.

.PARAMETER MachineType
    Defines the machine type for the VM instance.

.PARAMETER CanIpForward
    Enables IP forwarding for the VM instance.

.PARAMETER Description
    Provides a description for the VM instance.

.PARAMETER BootDisk
    Specifies the boot disk for the VM instance.

.PARAMETER BootDiskImage
    Specifies the boot disk image for the VM instance.

.PARAMETER ExtraDisk
    Specifies additional disks for the VM instance.

.PARAMETER Disk
    Specifies attached disks for the VM instance.

.PARAMETER Metadata
    Specifies metadata for the VM instance.

.PARAMETER Network
    Specifies the network for the VM instance.

.PARAMETER Region
    Specifies the region for the VM instance.

.PARAMETER Subnetwork
    Specifies the subnetwork for the VM instance.

.PARAMETER NoExternalIp
    Disables external IP for the VM instance.

.PARAMETER Preemptible
    Makes the VM instance preemptible.

.PARAMETER AutomaticRestart
    Enables automatic restart for the VM instance.

.PARAMETER TerminateOnMaintenance
    Terminates the VM instance on maintenance.

.PARAMETER ServiceAccount
    Specifies the service account for the VM instance.

.PARAMETER Tag
    Specifies tags for the VM instance.

.PARAMETER Label
    Specifies labels for the VM instance.

.PARAMETER Address
    Specifies the address for the VM instance.

.EXAMPLE
    .\gce-ps-create-vm.ps1 -Project "my-project" -Zone "us-central1-a" -Name "my-vm" -MachineType "n1-standard-1"

.NOTES
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Google Cloud SDK

.LINK
    https://cloud.google.com/sdk/gcloud/reference/compute/instances/create
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Project,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Zone,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$MachineType,

    [Parameter(Mandatory=$false)]
    [switch]$CanIpForward,

    [Parameter(Mandatory=$false)]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [PSObject]$BootDisk,

    [Parameter(Mandatory=$false)]
    [PSObject]$BootDiskImage,

    [Parameter(Mandatory=$false)]
    [PSObject[]]$ExtraDisk,

    [Parameter(Mandatory=$false)]
    [PSObject[]]$Disk,

    [Parameter(Mandatory=$false)]
    [hashtable]$Metadata,

    [Parameter(Mandatory=$false)]
    [string]$Network,

    [Parameter(Mandatory=$false)]
    [string]$Region,

    [Parameter(Mandatory=$false)]
    [string]$Subnetwork,

    [Parameter(Mandatory=$false)]
    [switch]$NoExternalIp,

    [Parameter(Mandatory=$false)]
    [switch]$Preemptible,

    [Parameter(Mandatory=$false)]
    [bool]$AutomaticRestart = $true,

    [Parameter(Mandatory=$false)]
    [switch]$TerminateOnMaintenance,

    [Parameter(Mandatory=$false)]
    [PSObject[]]$ServiceAccount,

    [Parameter(Mandatory=$false)]
    [string[]]$Tag,

    [Parameter(Mandatory=$false)]
    [hashtable]$Label,

    [Parameter(Mandatory=$false)]
    [string]$Address
)

# Splatting parameters for better readability
$parameters = @{
    Project                = $Project
    Zone                   = $Zone
    Name                   = $Name
    MachineType            = $MachineType
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

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the VM instance
    Add-GceInstance @parameters

    # Output the result
    Write-Output "Google Cloud VM instance created successfully."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to create Google Cloud VM instance: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}