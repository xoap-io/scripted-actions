<#
.SYNOPSIS
    Describe an AWS WorkSpace.

.DESCRIPTION
    This script retrieves and displays detailed information about an AWS WorkSpace using the Get-WKSWorkspace cmdlet from AWS.Tools.WorkSpaces.

.PARAMETER WorkspaceId
    The ID of the WorkSpace to describe.

.EXAMPLE
    .\aws-ps-workspaces-describe-workspace.ps1 -WorkspaceId ws-abc12345

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpace to describe.")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving WorkSpace details for $WorkspaceId..." -ForegroundColor Cyan

    $workspace = Get-WKSWorkspace -WorkspaceId $WorkspaceId

    if ($workspace) {
        Write-Host "WorkSpace Details:" -ForegroundColor Green
        Write-Host "  WorkSpace ID: $($workspace.WorkspaceId)" -ForegroundColor White
        Write-Host "  User Name: $($workspace.UserName)" -ForegroundColor White
        Write-Host "  Directory ID: $($workspace.DirectoryId)" -ForegroundColor White
        Write-Host "  State: $($workspace.State)" -ForegroundColor White
        Write-Host "  Bundle ID: $($workspace.BundleId)" -ForegroundColor White
        Write-Host "  Computer Name: $($workspace.ComputerName)" -ForegroundColor White
        Write-Host "  IP Address: $($workspace.IpAddress)" -ForegroundColor White
        Write-Host "  Subnet ID: $($workspace.SubnetId)" -ForegroundColor White
        Write-Host "  Error Code: $($workspace.ErrorCode)" -ForegroundColor White
        Write-Host "  Error Message: $($workspace.ErrorMessage)" -ForegroundColor White

        if ($workspace.WorkspaceProperties) {
            Write-Host "  Properties:" -ForegroundColor White
            Write-Host "    Compute Type: $($workspace.WorkspaceProperties.ComputeTypeName)" -ForegroundColor White
            Write-Host "    Root Volume Size: $($workspace.WorkspaceProperties.RootVolumeSizeGib) GB" -ForegroundColor White
            Write-Host "    User Volume Size: $($workspace.WorkspaceProperties.UserVolumeSizeGib) GB" -ForegroundColor White
            Write-Host "    Running Mode: $($workspace.WorkspaceProperties.RunningMode)" -ForegroundColor White
            if ($workspace.WorkspaceProperties.RunningModeAutoStopTimeoutInMinutes) {
                Write-Host "    Auto Stop Timeout: $($workspace.WorkspaceProperties.RunningModeAutoStopTimeoutInMinutes) minutes" -ForegroundColor White
            }
        }

        if ($workspace.ModificationStates) {
            Write-Host "  Modification States:" -ForegroundColor White
            foreach ($state in $workspace.ModificationStates) {
                Write-Host "    $($state.Resource): $($state.State)" -ForegroundColor White
            }
        }

        return $workspace
    } else {
        Write-Host "❌ WorkSpace $WorkspaceId not found" -ForegroundColor Red
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
