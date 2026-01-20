<#
.SYNOPSIS
Keeps only the last three versions of each image definition in a Shared Image Gallery, deleting older versions.

.PARAMETER ResourceGroupName
Name of the resource group containing the Shared Image Gallery.

.PARAMETER GalleryName
Name of the Shared Image Gallery.

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string]$GalleryName
)

$ErrorActionPreference = 'Stop'

try {
    $imageDefinitions = Get-AzGalleryImageDefinition -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName
    foreach ($imgDef in $imageDefinitions) {
        Write-Host "Processing image definition: $($imgDef.Name)"
        $versions = Get-AzGalleryImageVersion -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName -GalleryImageDefinitionName $imgDef.Name |
            Sort-Object -Property PublishedDate -Descending
        $versionsToKeep = $versions | Select-Object -First 3
        $versionsToDelete = $versions | Where-Object { $versionsToKeep -notcontains $_ }
        foreach ($ver in $versionsToDelete) {
            Write-Host "Deleting image version: $($ver.Name) (Published: $($ver.PublishedDate))"
            Remove-AzGalleryImageVersion -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName -GalleryImageDefinitionName $imgDef.Name -Name $ver.Name -Force
        }
        if ($versionsToDelete) {
            Write-Host "Deleted $($versionsToDelete.Count) old versions for $($imgDef.Name)"
        } else {
            Write-Host "No old versions to delete for $($imgDef.Name)"
        }
    }
    Write-Host "Cleanup complete."
}
catch {
    Write-Error \"Error occurred: $_\"
    exit 1
}
