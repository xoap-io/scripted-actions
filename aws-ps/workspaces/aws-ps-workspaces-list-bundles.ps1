<#
.SYNOPSIS
    List AWS WorkSpaces bundles.

.DESCRIPTION
    This script retrieves and lists AWS WorkSpaces bundles using the Get-WKSWorkspaceBundle cmdlet from AWS.Tools.WorkSpaces.
    Optionally filters by bundle ID or owner.

.PARAMETER BundleId
    (Optional) Filter by a specific bundle ID.

.PARAMETER Owner
    (Optional) Filter bundles by owner (e.g. AMAZON for AWS-managed bundles, or an AWS account ID).

.EXAMPLE
    .\aws-ps-workspaces-list-bundles.ps1

.EXAMPLE
    .\aws-ps-workspaces-list-bundles.ps1 -Owner AMAZON

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
    [Parameter(HelpMessage = "Optional bundle ID to filter results (e.g. wsb-abc12345).")]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$BundleId,

    [Parameter(HelpMessage = "Optional owner filter (e.g. AMAZON or an AWS account ID).")]
    [ValidateNotNullOrEmpty()]
    [string]$Owner
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving WorkSpaces bundles..." -ForegroundColor Cyan

    $params = @{}
    if ($BundleId) { $params['BundleId'] = $BundleId }
    if ($Owner) { $params['Owner'] = $Owner }

    $bundles = Get-WKSWorkspaceBundle @params

    if ($bundles) {
        Write-Host "Found $($bundles.Count) bundle(s):" -ForegroundColor Green

        foreach ($bundle in $bundles) {
            Write-Host ""
            Write-Host "Bundle ID: $($bundle.BundleId)" -ForegroundColor White
            Write-Host "  Name: $($bundle.Name)" -ForegroundColor White
            Write-Host "  Description: $($bundle.Description)" -ForegroundColor White
            Write-Host "  Owner: $($bundle.Owner)" -ForegroundColor White

            if ($bundle.RootStorage) {
                Write-Host "  Root Storage:" -ForegroundColor White
                Write-Host "    Capacity: $($bundle.RootStorage.Capacity)" -ForegroundColor Gray
            }

            if ($bundle.UserStorage) {
                Write-Host "  User Storage:" -ForegroundColor White
                Write-Host "    Capacity: $($bundle.UserStorage.Capacity)" -ForegroundColor Gray
            }

            if ($bundle.ComputeType) {
                Write-Host "  Compute Type:" -ForegroundColor White
                Write-Host "    Name: $($bundle.ComputeType.Name)" -ForegroundColor Gray
            }

            Write-Host "  Image ID: $($bundle.ImageId)" -ForegroundColor White
            Write-Host "  Last Updated: $($bundle.LastUpdatedTime)" -ForegroundColor White
            Write-Host "  Creation Time: $($bundle.CreationTime)" -ForegroundColor White
        }

        return $bundles
    } else {
        Write-Host "No bundles found matching the specified criteria" -ForegroundColor Yellow
        return @()
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
