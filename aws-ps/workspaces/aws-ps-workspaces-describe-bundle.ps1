<#
.SYNOPSIS
    Describe an AWS WorkSpaces bundle.

.DESCRIPTION
    This script retrieves and displays details of an AWS WorkSpaces bundle using the Get-WKSWorkspaceBundle cmdlet from AWS.Tools.WorkSpaces.

.PARAMETER BundleId
    The ID of the WorkSpaces bundle to describe.

.EXAMPLE
    .\aws-ps-workspaces-describe-bundle.ps1 -BundleId wsb-abc12345

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.WorkSpaces

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/

.COMPONENT
    AWS PowerShell WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpaces bundle to describe (e.g. wsb-abc12345).")]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$BundleId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving bundle details for $BundleId..." -ForegroundColor Cyan

    $bundle = Get-WKSWorkspaceBundle -BundleId $BundleId

    if ($bundle) {
        Write-Host "Bundle Details:" -ForegroundColor Green
        Write-Host "  Bundle ID: $($bundle.BundleId)" -ForegroundColor White
        Write-Host "  Name: $($bundle.Name)" -ForegroundColor White
        Write-Host "  Description: $($bundle.Description)" -ForegroundColor White
        Write-Host "  Owner: $($bundle.Owner)" -ForegroundColor White
        Write-Host "  Image ID: $($bundle.ImageId)" -ForegroundColor White
        Write-Host "  Creation Time: $($bundle.CreationTime)" -ForegroundColor White
        Write-Host "  Last Updated: $($bundle.LastUpdatedTime)" -ForegroundColor White

        if ($bundle.RootStorage) {
            Write-Host "  Root Storage:" -ForegroundColor White
            Write-Host "    Capacity: $($bundle.RootStorage.Capacity) GB" -ForegroundColor Gray
        }

        if ($bundle.UserStorage) {
            Write-Host "  User Storage:" -ForegroundColor White
            Write-Host "    Capacity: $($bundle.UserStorage.Capacity) GB" -ForegroundColor Gray
        }

        if ($bundle.ComputeType) {
            Write-Host "  Compute Type:" -ForegroundColor White
            Write-Host "    Name: $($bundle.ComputeType.Name)" -ForegroundColor Gray
        }

        return $bundle
    } else {
        Write-Host "❌ Bundle $BundleId not found" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
