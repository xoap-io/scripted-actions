<#
.SYNOPSIS
    Modify properties of an AWS WorkSpace.

.DESCRIPTION
    This script modifies the properties of an AWS WorkSpace using the Edit-WKSWorkspaceProperty cmdlet from AWS.Tools.WorkSpaces.
    Supports modifying compute type, root volume size, user volume size, running mode, and auto-stop timeout.

.PARAMETER WorkspaceId
    The ID of the WorkSpace to modify.

.PARAMETER ComputeTypeName
    (Optional) The new compute type for the WorkSpace.

.PARAMETER RootVolumeSizeGib
    (Optional) The new root volume size in GiB.

.PARAMETER UserVolumeSizeGib
    (Optional) The new user volume size in GiB.

.PARAMETER RunningMode
    (Optional) The new running mode: ALWAYS_ON or AUTO_STOP.

.PARAMETER RunningModeAutoStopTimeoutInMinutes
    (Optional) The auto-stop timeout in minutes when RunningMode is AUTO_STOP.

.EXAMPLE
    .\aws-ps-workspaces-modify-workspace-properties.ps1 -WorkspaceId ws-abc12345 -ComputeTypeName STANDARD

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpace to modify.")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceId,

    [Parameter(HelpMessage = "The new compute type for the WorkSpace.")]
    [ValidateSet('VALUE','STANDARD','PERFORMANCE','POWER','GRAPHICS','POWERPRO','GRAPHICSPRO')]
    [string]$ComputeTypeName,

    [Parameter(HelpMessage = "The new root volume size in GiB (80-2000).")]
    [ValidateRange(80, 2000)]
    [int]$RootVolumeSizeGib,

    [Parameter(HelpMessage = "The new user volume size in GiB (10-2000).")]
    [ValidateRange(10, 2000)]
    [int]$UserVolumeSizeGib,

    [Parameter(HelpMessage = "The new running mode: ALWAYS_ON or AUTO_STOP.")]
    [ValidateSet('ALWAYS_ON','AUTO_STOP')]
    [string]$RunningMode,

    [Parameter(HelpMessage = "The auto-stop timeout in minutes when RunningMode is AUTO_STOP (60-36000).")]
    [ValidateRange(60, 36000)]
    [int]$RunningModeAutoStopTimeoutInMinutes
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating WorkSpace $WorkspaceId exists..." -ForegroundColor Cyan
    $workspace = Get-WKSWorkspace -WorkspaceId $WorkspaceId
    if (-not $workspace) {
        throw "WorkSpace $WorkspaceId not found"
    }

    if ($workspace.State -ne 'AVAILABLE' -and $workspace.State -ne 'STOPPED') {
        throw "WorkSpace $WorkspaceId is in state '$($workspace.State)' and cannot be modified"
    }

    Write-Host "Modifying WorkSpace properties..." -ForegroundColor Cyan

    $modifyParams = @{
        WorkspaceId = $WorkspaceId
    }

    $properties = @{}

    if ($ComputeTypeName) {
        $properties['ComputeTypeName'] = $ComputeTypeName
        Write-Host "  Setting Compute Type to: $ComputeTypeName" -ForegroundColor Yellow
    }
    if ($RootVolumeSizeGib) {
        $properties['RootVolumeSizeGib'] = $RootVolumeSizeGib
        Write-Host "  Setting Root Volume Size to: $RootVolumeSizeGib GB" -ForegroundColor Yellow
    }
    if ($UserVolumeSizeGib) {
        $properties['UserVolumeSizeGib'] = $UserVolumeSizeGib
        Write-Host "  Setting User Volume Size to: $UserVolumeSizeGib GB" -ForegroundColor Yellow
    }
    if ($RunningMode) {
        $properties['RunningMode'] = $RunningMode
        Write-Host "  Setting Running Mode to: $RunningMode" -ForegroundColor Yellow
    }
    if ($RunningModeAutoStopTimeoutInMinutes -and $RunningMode -eq 'AUTO_STOP') {
        $properties['RunningModeAutoStopTimeoutInMinutes'] = $RunningModeAutoStopTimeoutInMinutes
        Write-Host "  Setting Auto Stop Timeout to: $RunningModeAutoStopTimeoutInMinutes minutes" -ForegroundColor Yellow
    }

    if ($properties.Count -eq 0) {
        Write-Warning "No properties specified for modification"
        exit 0
    }

    $modifyParams['WorkspaceProperties'] = $properties

    Edit-WKSWorkspaceProperty @modifyParams

    Write-Host "WorkSpace properties modified successfully" -ForegroundColor Green
    Write-Host "Note: Some changes may require a reboot to take effect" -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
