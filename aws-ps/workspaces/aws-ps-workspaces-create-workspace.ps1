<#
.SYNOPSIS
    Create an AWS WorkSpace for a user with detailed configuration options.

.DESCRIPTION
    This script creates an AWS WorkSpace for a user using the New-WKSWorkspace cmdlet from AWS.Tools.WorkSpaces.
    It validates that the directory and bundle exist before creating the WorkSpace, and supports compute type, storage, and running mode configuration.

.PARAMETER DirectoryId
    The ID of the WorkSpaces directory.

.PARAMETER UserName
    The user name to assign the WorkSpace to.

.PARAMETER BundleId
    The bundle ID to use for the WorkSpace.

.PARAMETER ComputeTypeName
    The compute type for the WorkSpace (default: VALUE).

.PARAMETER RootVolumeSizeGib
    The root volume size in GiB (default: 80).

.PARAMETER UserVolumeSizeGib
    The user volume size in GiB (default: 10).

.PARAMETER RunningMode
    The running mode for the WorkSpace: ALWAYS_ON or AUTO_STOP (default: AUTO_STOP).

.PARAMETER RunningModeAutoStopTimeoutInMinutes
    The auto-stop timeout in minutes when RunningMode is AUTO_STOP (default: 60).

.PARAMETER Tags
    Hashtable of tags to apply to the WorkSpace.

.EXAMPLE
    .\aws-ps-workspaces-create-workspace.ps1 -DirectoryId d-1234567890 -UserName jdoe -BundleId wsb-abc12345

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpaces directory.")]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryId,

    [Parameter(Mandatory = $true, HelpMessage = "The user name to assign the WorkSpace to (alphanumeric, dots, dashes, up to 64 characters).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName,

    [Parameter(Mandatory = $true, HelpMessage = "The bundle ID to use for the WorkSpace (e.g. wsb-abc12345).")]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$BundleId,

    [Parameter(HelpMessage = "The compute type for the WorkSpace.")]
    [ValidateSet('VALUE','STANDARD','PERFORMANCE','POWER','GRAPHICS','POWERPRO','GRAPHICSPRO')]
    [string]$ComputeTypeName = 'VALUE',

    [Parameter(HelpMessage = "The root volume size in GiB (80-2000).")]
    [ValidateRange(80, 2000)]
    [int]$RootVolumeSizeGib = 80,

    [Parameter(HelpMessage = "The user volume size in GiB (10-2000).")]
    [ValidateRange(10, 2000)]
    [int]$UserVolumeSizeGib = 10,

    [Parameter(HelpMessage = "The running mode for the WorkSpace: ALWAYS_ON or AUTO_STOP.")]
    [ValidateSet('ALWAYS_ON','AUTO_STOP')]
    [string]$RunningMode = 'AUTO_STOP',

    [Parameter(HelpMessage = "The auto-stop timeout in minutes when RunningMode is AUTO_STOP (60-36000).")]
    [ValidateRange(60, 36000)]
    [int]$RunningModeAutoStopTimeoutInMinutes = 60,

    [Parameter(HelpMessage = "Hashtable of tags to apply to the WorkSpace.")]
    [hashtable]$Tags = @{}
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating directory exists..." -ForegroundColor Cyan
    $directory = Get-WKSDirectory -DirectoryId $DirectoryId
    if (-not $directory) {
        throw "Directory $DirectoryId not found"
    }

    Write-Host "Validating bundle exists..." -ForegroundColor Cyan
    $bundle = Get-WKSWorkspaceBundle -BundleId $BundleId
    if (-not $bundle) {
        throw "Bundle $BundleId not found"
    }

    Write-Host "Creating WorkSpace for user $UserName..." -ForegroundColor Cyan

    $workspaceRequest = @{
        DirectoryId = $DirectoryId
        UserName = $UserName
        BundleId = $BundleId
        WorkspaceProperties_ComputeTypeName = $ComputeTypeName
        WorkspaceProperties_RootVolumeSizeGib = $RootVolumeSizeGib
        WorkspaceProperties_UserVolumeSizeGib = $UserVolumeSizeGib
        WorkspaceProperties_RunningMode = $RunningMode
    }

    if ($RunningMode -eq 'AUTO_STOP') {
        $workspaceRequest['WorkspaceProperties_RunningModeAutoStopTimeoutInMinutes'] = $RunningModeAutoStopTimeoutInMinutes
    }

    if ($Tags.Count -gt 0) {
        $workspaceRequest['Tags'] = $Tags.GetEnumerator() | ForEach-Object { @{Key=$_.Key; Value=$_.Value} }
    }

    $workspace = New-WKSWorkspace @workspaceRequest

    Write-Host "WorkSpace created successfully:" -ForegroundColor Green
    Write-Host "  WorkSpace ID: $($workspace.WorkspaceId)" -ForegroundColor Green
    Write-Host "  State: $($workspace.State)" -ForegroundColor Green
    Write-Host "  User Name: $($workspace.UserName)" -ForegroundColor Green
    Write-Host "  Bundle ID: $($workspace.BundleId)" -ForegroundColor Green

    return $workspace
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
