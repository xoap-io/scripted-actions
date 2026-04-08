<#
.SYNOPSIS
    Creates an AWS WorkSpace using AWS.Tools.WorkSpaces.

.DESCRIPTION
    This script creates an AWS WorkSpace using the New-WKSWorkspace cmdlet from AWS.Tools.WorkSpaces. It validates parameters and provides robust error handling.

.PARAMETER BundleId
    The identifier of the bundle to create the WorkSpace from.

.PARAMETER DirectoryId
    The identifier of the directory for the WorkSpace.

.PARAMETER UserName
    The user name of the user for the WorkSpace.

.EXAMPLE
    .\aws-ps-create-workspace.ps1 -BundleId wsb-abc12345 -DirectoryId d-1234567890 -UserName myuser

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
    [Parameter(Mandatory = $true, HelpMessage = "The bundle ID to create the WorkSpace from (e.g. wsb-abc12345).")]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$BundleId,

    [Parameter(Mandatory = $true, HelpMessage = "The directory ID for the WorkSpace (e.g. d-1234567890ab).")]
    [ValidatePattern('^d-[a-zA-Z0-9]{8,}$')]
    [string]$DirectoryId,

    [Parameter(Mandatory = $true, HelpMessage = "The user name for the WorkSpace (alphanumeric, dots, dashes, up to 64 characters).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName
)

$ErrorActionPreference = 'Stop'

try {
    $workspaceRequest = New-Object Amazon.WorkSpaces.Model.WorkspaceRequest
    $workspaceRequest.BundleId = $BundleId
    $workspaceRequest.DirectoryId = $DirectoryId
    $workspaceRequest.UserName = $UserName
    $result = New-WKSWorkspace -Workspace $workspaceRequest 2>&1
    if ($?) {
        Write-Host "WorkSpace for user '$UserName' created successfully in directory '$DirectoryId' with bundle '$BundleId'." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Host "❌ Failed to create WorkSpace: $result" -ForegroundColor Red
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
