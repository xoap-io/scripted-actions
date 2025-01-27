<#
.SYNOPSIS
    Create a Google Cloud VM instance using Google Cloud CLI (gcloud).

.DESCRIPTION
    This script creates a Google Cloud VM instance with customizable options like machine type, image family, region, and more using parameters.

.PARAMETER Project
    The Google Cloud project in which the VM will be created.

.PARAMETER Zone
    The zone where the virtual machine will be deployed (e.g., us-central1-a).

.PARAMETER MachineType
    The machine type for the virtual machine (e.g., n1-standard-1).

.PARAMETER ImageFamily
    The image family to use (e.g., debian-10).

.PARAMETER ImageProject
    The project where the image is stored (e.g., debian-cloud).

.PARAMETER InstanceName
    The name of the virtual machine instance.

.PARAMETER DiskSize
    The size of the boot disk in GB (e.g., 10).

.PARAMETER Network
    The network to attach the VM to (default: default).

.PARAMETER Subnet
    The subnet to use for the VM (optional).

.PARAMETER Tags
    Comma-separated tags for the VM (optional).

.PARAMETER Preemptible
    Option to create a preemptible instance (default: $false).

.PARAMETER AzDebug
    Increase logging verbosity to show all debug logs.

.PARAMETER AzOnlyShowErrors
    Only show errors, suppressing warnings.

.PARAMETER AzOutput
    Output format.

.PARAMETER AzQuery
    JMESPath query string.

.PARAMETER AzVerbose
    Increase logging verbosity.

.PARAMETER WhatIf
    Shows what would happen if the cmdlet runs. The cmdlet is not run.

.PARAMETER Confirm
    Prompts you for confirmation before running the cmdlet.

.EXAMPLE
    .\Create-GCPVM.ps1 -Project "my-project" -Zone "us-central1-a" -MachineType "n1-standard-1" `
    -ImageFamily "debian-10" -ImageProject "debian-cloud" -InstanceName "my-vm" -DiskSize 10

.NOTES
    Ensure that Google Cloud CLI is installed and authenticated before running the script.
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Google Cloud SDK
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
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
    [string]$InstanceName,

    [Parameter(Mandatory = $true)]
    [int]$DiskSize,

    [Parameter(Mandatory = $false)]
    [string]$Network = "default",

    [Parameter(Mandatory = $false)]
    [string]$Subnet = $null,

    [Parameter(Mandatory = $false)]
    [string]$Tags = $null,

    [Parameter(Mandatory = $false)]
    [switch]$Preemptible,

    [Parameter(Mandatory=$false)]
    [switch]$AzDebug,

    [Parameter(Mandatory=$false)]
    [switch]$AzOnlyShowErrors,

    [Parameter(Mandatory=$false)]
    [string]$AzOutput,

    [Parameter(Mandatory=$false)]
    [string]$AzQuery,

    [Parameter(Mandatory=$false)]
    [switch]$AzVerbose,


)

# Splatting parameters for better readability
$parameters = @{
    Project                = $Project
    Zone                   = $Zone
    MachineType            = $MachineType
    ImageFamily            = $ImageFamily
    ImageProject           = $ImageProject
    InstanceName           = $InstanceName
    DiskSize               = $DiskSize
    Network                = $Network
    Subnet                 = $Subnet
    Tags                   = $Tags
    Preemptible            = $Preemptible
    AzDebug                = $AzDebug
    AzOnlyShowErrors       = $AzOnlyShowErrors
    AzOutput               = $AzOutput
    AzQuery                = $AzQuery
    AzVerbose              = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Set gcloud project
    & gcloud config set project $parameters.Project

    # Build the gcloud command for VM creation
    $gcloudCommand = "gcloud compute instances create $($parameters.InstanceName) --zone $($parameters.Zone) --machine-type $($parameters.MachineType) --boot-disk-size $($parameters.DiskSize) --image-family $($parameters.ImageFamily) --image-project $($parameters.ImageProject) --network $($parameters.Network)"

    # Add optional subnet if specified
    if ($parameters.Subnet) {
        $gcloudCommand += " --subnet $($parameters.Subnet)"
    }

    # Add optional tags if specified
    if ($parameters.Tags) {
        $gcloudCommand += " --tags $($parameters.Tags)"
    }

    # Add preemptible flag if specified
    if ($parameters.Preemptible.IsPresent) {
        $gcloudCommand += " --preemptible"
    }

    # Execute the gcloud command
    Write-Host "Executing: $gcloudCommand"
    & $gcloudCommand

    # Check if the command was successful
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Virtual machine '$($parameters.InstanceName)' created successfully in project '$($parameters.Project)'."
    } else {
        throw "Error creating virtual machine. Please check your parameters."
    }
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to create Google Cloud VM instance: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}