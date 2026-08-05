<# 
.SYNOPSIS
    Azure Automatic Cleanup Script for Unused Images.

.DESCRIPTION
    This script creates a new Azure Resource Group with the Azure PowerShell.
    The script uses the following Azure PowerShell command:
    New-AzResourceGroup -Name $AzResourceGroup -Location $AzLocation

.PARAMETER DryRun
    It allows you to simulate the execution of a script or command without actually making any changes to the system.

.PARAMETER ResourceGroup
    Defines the Azure Resource Group that a particular command or operation should target.

.PARAMETER ImageId
    Defines the unique identifier of an image resource in Azure. 

.EXAMPLE
    param(
    [string]$ResourceGroup,      # Name of the target resource group
    [string]$ImageId,            # Unique ID of the image to check or remove
    [switch]$DryRun              # Simulate the process without making changes
)

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

# Variables
# Specify the subscription ID and resource group(s)
param (
    [switch]$DryRun,
    [string]$ResourceGroup
)
  # Set to $false to actually delete the images

# Function to check if an image is in use
function Is-ImageInUse {
    param (
        [string]$ImageId
    )

    # Get all VMs and check if any reference the image
    $vms = Get-AzVM -Status
    foreach ($vm in $vms) {
        if ($vm.StorageProfile.ImageReference.Id -eq $ImageId) {
            return $true
        }
    }
    return $false
}
    if($ResourceGroup) {
        $images = Get-AzImage -ResourceGroupName $ResourceGroup

    foreach ($image in $images) {
        Write-Host "Processing image: $($image.Name)"

        if (-not (Is-ImageInUse -ImageId $image.Id)) {
            Write-Host "Image $($image.Name) is not in use."

            if (-not $DryRun) {
                # Delete the unused image
                Write-Host "Deleting image: $($image.Name)"
                Remove-AzImage -ResourceGroupName $image.ResourceGroupName -Name $image.Name -Force
            } else {
                Write-Host "Dry Run: Image $($image.Name) would be deleted."
            }
        } else {
            Write-Host "Image $($image.Name) is in use by one or more VMs."
        }
}
    }
    else {

$images = Get-AzImage

    foreach ($image in $images) {
        Write-Host "Processing image: $($image.Name)"

        if (-not (Is-ImageInUse -ImageId $image.Id)) {
            Write-Host "Image $($image.Name) is not in use."

            if (-not $DryRun) {
                # Delete the unused image
                Write-Host "Deleting image: $($image.Name)"
                Remove-AzImage -ResourceGroupName $image.ResourceGroupName -Name $image.Name -Force
            } else {
                Write-Host "Dry Run: Image $($image.Name) would be deleted."
            }
        } else {
            Write-Host "Image $($image.Name) is in use by one or more VMs."
        }
}
    }
    # Get all images in the resource group
    

Write-Host "Image cleanup completed."
