<#
.SYNOPSIS
    Reboots an AWS WorkSpace using AWS.Tools.WorkSpaces.

.DESCRIPTION
    This script reboots an AWS WorkSpace using the Restart-WKSWorkspace cmdlet from AWS.Tools.WorkSpaces. It validates parameters and provides robust error handling.

.PARAMETER WorkspaceId
    The ID of the WorkSpace to reboot.

.EXAMPLE
    .\aws-ps-reboot-workspace.ps1 -WorkspaceId ws-abc12345

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpace to reboot (e.g. ws-abc12345ab).")]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$WorkspaceId
)

$ErrorActionPreference = 'Stop'

try {
    $result = Restart-WKSWorkspace -WorkspaceId $WorkspaceId 2>&1
    if ($?) {
        Write-Host "WorkSpace '$WorkspaceId' rebooted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Host "❌ Failed to reboot WorkSpace '$WorkspaceId': $result" -ForegroundColor Red
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
