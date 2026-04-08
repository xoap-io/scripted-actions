<#
.SYNOPSIS
    Delete old versions of each image definition in an Azure Shared Image Gallery,
    keeping only the most recent N versions.

.DESCRIPTION
    This script enumerates all image definitions in a Shared Image Gallery, then for
    each definition sorts its versions by publish date (descending) and removes any
    versions beyond the configured retention count.
    Writes a detailed log file recording every version that was removed.
    Includes post-operation verification to confirm that no excess versions remain.

.PARAMETER ResourceGroupName
    Name of the resource group containing the Shared Image Gallery.

.PARAMETER GalleryName
    Name of the Shared Image Gallery.

.PARAMETER VersionsToKeep
    Number of most-recent versions to retain per image definition. Defaults to 3.

.PARAMETER WhatIf
    Show which image versions would be deleted without making any changes.

.PARAMETER Force
    Skip confirmation prompts.

.EXAMPLE
    .\az-ps-delete-image-revisions.ps1 -ResourceGroupName myRG -GalleryName myGallery -WhatIf
    Shows which image versions would be deleted without making any changes.

.EXAMPLE
    .\az-ps-delete-image-revisions.ps1 -ResourceGroupName myRG -GalleryName myGallery -Force
    Deletes old image versions using the default retention of 3 without a prompt.

.EXAMPLE
    .\az-ps-delete-image-revisions.ps1 -ResourceGroupName myRG -GalleryName myGallery -VersionsToKeep 5 -Force
    Keeps the 5 most-recent versions per definition and deletes the rest.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Compute (Install-Module Az.Compute)

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.compute/remove-azgalleryimageversion

.COMPONENT
    Azure PowerShell Compute Gallery
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Resource group containing the Shared Image Gallery")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Shared Image Gallery")]
    [ValidateNotNullOrEmpty()]
    [string]$GalleryName,

    [Parameter(HelpMessage = "Number of most-recent versions to keep per image definition")]
    [ValidateRange(1, 100)]
    [int]$VersionsToKeep = 3,

    [Parameter(HelpMessage = "Show what would be deleted without making changes")]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Skip confirmation prompts")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$LogFile = "az-ps-delete-image-revisions-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $LogFile -Value "[$timestamp] $Message"
    Write-Host $Message -ForegroundColor $Color
}

try {
    Write-Log '===== Azure Shared Image Gallery Cleanup Script Started =====' -Color Blue
    Write-Log "Log file:        $LogFile" -Color Cyan
    Write-Log "ResourceGroup:   $ResourceGroupName" -Color Cyan
    Write-Log "Gallery:         $GalleryName" -Color Cyan
    Write-Log "VersionsToKeep:  $VersionsToKeep" -Color Cyan

    # Verify module
    Import-Module Az.Compute -ErrorAction Stop

    # Discover gallery and image definitions
    Write-Log '🔍 Discovering image definitions...' -Color Cyan
    $imageDefinitions = @(Get-AzGalleryImageDefinition -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName)

    if ($imageDefinitions.Count -eq 0) {
        Write-Log 'ℹ️ No image definitions found in this gallery.' -Color Yellow
        exit 0
    }

    Write-Log "Found $($imageDefinitions.Count) image definition(s)." -Color Cyan

    # Inventory: collect all versions to delete across all definitions
    $deletionPlan = @()

    foreach ($imgDef in $imageDefinitions) {
        $versions = @(
            Get-AzGalleryImageVersion `
                -ResourceGroupName $ResourceGroupName `
                -GalleryName $GalleryName `
                -GalleryImageDefinitionName $imgDef.Name |
            Sort-Object -Property PublishingProfile.PublishedDate -Descending
        )

        Write-Log "   $($imgDef.Name): $($versions.Count) version(s) found" -Color White

        $versionsToDelete = $versions | Select-Object -Skip $VersionsToKeep

        foreach ($ver in $versionsToDelete) {
            $published = $ver.PublishingProfile.PublishedDate
            Write-Log "      • Would delete: $($ver.Name) (Published: $published)" -Color Gray
            $deletionPlan += [PSCustomObject]@{
                DefinitionName = $imgDef.Name
                VersionName    = $ver.Name
                Published      = $published
                Version        = $ver
            }
        }

        if ($versionsToDelete.Count -eq 0) {
            Write-Log "      ℹ️ No excess versions — $VersionsToKeep or fewer exist." -Color Yellow
        }
    }

    if ($deletionPlan.Count -eq 0) {
        Write-Log 'ℹ️ No image versions to delete. All definitions are within retention limit.' -Color Yellow
        exit 0
    }

    Write-Log '' -Color White
    Write-Log "Total versions to delete: $($deletionPlan.Count)" -Color Cyan

    if ($WhatIf) {
        Write-Log '🔍 WhatIf mode — no changes will be made.' -Color Cyan
        exit 0
    }

    if (-not $Force) {
        Write-Log '' -Color White
        Write-Log "⚠️  About to delete $($deletionPlan.Count) image version(s) from gallery '$GalleryName'" -Color Yellow
        $confirmation = Read-Host "Type 'YES' to confirm"
        if ($confirmation -ne 'YES') {
            Write-Log 'Operation cancelled by user.' -Color Yellow
            exit 0
        }
    }

    # Delete versions
    Write-Log '' -Color White
    Write-Log '🗑️ Deleting old image versions...' -Color Cyan
    $succeeded = 0
    $failed    = 0

    foreach ($entry in $deletionPlan) {
        try {
            Remove-AzGalleryImageVersion `
                -ResourceGroupName $ResourceGroupName `
                -GalleryName $GalleryName `
                -GalleryImageDefinitionName $entry.DefinitionName `
                -Name $entry.VersionName `
                -Force | Out-Null

            Write-Log "   ✅ Deleted: $($entry.DefinitionName) / $($entry.VersionName)" -Color Green
            $succeeded++
        }
        catch {
            Write-Log "   ❌ Failed to delete $($entry.DefinitionName) / $($entry.VersionName): $($_.Exception.Message)" -Color Red
            $failed++
        }
    }

    # Post-operation verification
    Write-Log '' -Color White
    Write-Log '🔎 Verifying retention compliance...' -Color Cyan
    $violations = 0

    foreach ($imgDef in $imageDefinitions) {
        $remaining = @(
            Get-AzGalleryImageVersion `
                -ResourceGroupName $ResourceGroupName `
                -GalleryName $GalleryName `
                -GalleryImageDefinitionName $imgDef.Name
        )

        if ($remaining.Count -gt $VersionsToKeep) {
            Write-Log "   ⚠️  $($imgDef.Name): $($remaining.Count) versions remain (expected <= $VersionsToKeep)" -Color Yellow
            $violations++
        }
        else {
            Write-Log "   ✅ $($imgDef.Name): $($remaining.Count) version(s) — within limit" -Color Green
        }
    }

    Write-Log '' -Color White
    Write-Log '===== Operation Complete =====' -Color White
    Write-Log "Gallery:        $GalleryName" -Color White
    Write-Log "ResourceGroup:  $ResourceGroupName" -Color White
    Write-Log "Deleted:        $succeeded version(s)" -Color White
    Write-Log "Failed:         $failed version(s)" -Color White
    if ($violations -gt 0) {
        Write-Log "⚠️  Definitions exceeding retention limit: $violations" -Color Yellow
    }
    Write-Log "Log file: $LogFile" -Color Gray
    Write-Log '=============================' -Color White
}
catch {
    Write-Log "❌ Script failed: $($_.Exception.Message)" -Color Red
    exit 1
}
finally {
    Write-Log '' -Color White
    Write-Log '🏁 Script execution completed' -Color Green
}
