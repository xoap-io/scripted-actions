<#
.SYNOPSIS
    Remove one or more VM images from an Azure Local (Azure Stack HCI) cluster.

.DESCRIPTION
    This script deletes one or more Azure Local VM images. Before deleting, it checks
    whether any Arc-managed VM in the resource group was deployed from the image and
    refuses the deletion in that case (override with -Force). A typed 'YES' confirmation is
    required unless -Force is specified. Optionally the underlying VHDX file of gallery
    images is deleted as well (-DeleteVhdxFile, requires running on a cluster node with
    access to the CSV path).

    Failures on single images do not abort the batch; the script exits with code 1 if any
    image failed to delete.

    Uses Get/Remove-AzStackHCIVMImage and Get-AzStackHCIVMVirtualMachine.

    Removing an image never touches VMs that were already deployed from it.

.PARAMETER ImageNames
    One or more names of the Azure Local VM images to remove.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER Force
    Skip the typed 'YES' confirmation and the VM-reference safety check. Required for
    non-interactive execution (e.g. XOAP Scripted Actions).

.PARAMETER DeleteVhdxFile
    Also delete the underlying VHDX file of gallery images (requires cluster node / CSV
    access). Marketplace image downloads are cleaned up by the platform automatically.

.EXAMPLE
    .\az-ps-remove-azure-local-image.ps1 -ImageNames "win11-23h2-avd-gold"

    Removes a single image after typed confirmation.

.EXAMPLE
    .\az-ps-remove-azure-local-image.ps1 `
        -ImageNames "win11-old-1", "win11-old-2" `
        -DeleteVhdxFile `
        -Force

    Removes two images including their VHDX files without confirmation.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Accounts, Az.Resources, Az.StackHCIVM 1.1.0+ (Install-Module Az.StackHCIVM)

.LINK
    https://learn.microsoft.com/en-us/azure/azure-local/manage/virtual-machine-image-local-share

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.stackhcivm/

.COMPONENT
    Azure PowerShell Stack HCI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "One or more names of the Azure Local VM images to remove.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$ImageNames,

    [Parameter(Mandatory = $false, HelpMessage = "Azure resource group that represents your Azure Local instance scope.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName = "AzureLocal",

    [Parameter(Mandatory = $false, HelpMessage = "Skip the typed 'YES' confirmation and the VM-reference safety check.")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Also delete the underlying VHDX file of gallery images (requires CSV access).")]
    [switch]$DeleteVhdxFile
)

$ErrorActionPreference = 'Stop'

try {
    # 0) Preflight: module + Azure context
    if (-not (Get-Module -ListAvailable -Name Az.StackHCIVM)) {
        throw "The Az.StackHCIVM module is not installed. Run: Install-Module Az.StackHCIVM -Scope CurrentUser"
    }
    $context = Get-AzContext
    if (-not $context) {
        throw "No Azure context found. Run Connect-AzAccount (or sign in with your service principal) first."
    }
    Write-Host "🔍 Using subscription '$($context.Subscription.Name)' ($($context.Subscription.Id))" -ForegroundColor Cyan

    # 1) Collect image references of existing VMs once (safety check).
    #    Get-AzResource is used for the listing because
    #    Get-AzStackHCIVMVirtualMachine -ResourceGroupName fails on Arc machines with an
    #    empty Kind (e.g. Arc-enabled cluster nodes in the same resource group).
    $imageIdsInUse = @{}
    if (-not $Force) {
        Write-Host "🔍 Checking which images are referenced by existing VMs..." -ForegroundColor Cyan
        $machines = @(Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.HybridCompute/machines' -ErrorAction SilentlyContinue |
            Where-Object { "$($_.Kind)" -eq 'HCI' })
        foreach ($machine in $machines) {
            $vm = Get-AzStackHCIVMVirtualMachine -Name $machine.Name -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
            if ($vm -and $vm.ImageReferenceId) {
                $imageIdsInUse[$vm.ImageReferenceId.ToLower()] = $machine.Name
            }
        }
    }

    # 2) Confirmation
    if (-not $Force) {
        Write-Host "`n⚠️  The following image(s) will be deleted: $($ImageNames -join ', ')" -ForegroundColor Yellow
        $answer = Read-Host "Type 'YES' to confirm the deletion"
        if ($answer -cne 'YES') {
            Write-Host "ℹ️  Deletion cancelled" -ForegroundColor Yellow
            return
        }
    }

    # 3) Delete image by image
    $removed = @()
    $skipped = @()
    $failed  = @()

    foreach ($imageName in $ImageNames) {
        try {
            $image = Get-AzStackHCIVMImage -ResourceGroupName $ResourceGroupName -Name $imageName -ErrorAction SilentlyContinue
            if (-not $image) {
                Write-Host "⚠️  Image '$imageName' not found - skipping" -ForegroundColor Yellow
                $skipped += $imageName
                continue
            }

            if (-not $Force -and $image.Id -and $imageIdsInUse.ContainsKey($image.Id.ToLower())) {
                Write-Host "⚠️  Image '$imageName' is referenced by VM '$($imageIdsInUse[$image.Id.ToLower()])' - skipping (use -Force to delete anyway)" -ForegroundColor Yellow
                $skipped += $imageName
                continue
            }

            $vhdxPath = $image.ImagePath

            Write-Host "🔧 Removing image '$imageName'..." -ForegroundColor Cyan
            Remove-AzStackHCIVMImage -Name $imageName -ResourceGroupName $ResourceGroupName -Confirm:$false
            Write-Host "✅ Image '$imageName' removed" -ForegroundColor Green

            if ($DeleteVhdxFile -and $vhdxPath) {
                if (Test-Path $vhdxPath) {
                    Remove-Item -Path $vhdxPath -Force
                    Write-Host "✅ VHDX file '$vhdxPath' deleted" -ForegroundColor Green
                }
                else {
                    Write-Host "⚠️  VHDX file '$vhdxPath' is not accessible from this machine - delete it on a cluster node" -ForegroundColor Yellow
                }
            }

            $removed += $imageName
        }
        catch {
            Write-Host "❌ Failed to remove image '$($imageName)': $($_.Exception.Message)" -ForegroundColor Red
            $failed += $imageName
        }
    }

    # 4) Summary
    Write-Host "`n📊 Summary: $($removed.Count) removed, $($skipped.Count) skipped, $($failed.Count) failed" -ForegroundColor Blue
    if ($failed.Count -gt 0) {
        throw "The following images could not be removed: $($failed -join ', ')"
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
