
<#!
.SYNOPSIS
    Creates an AWS WorkSpace using AWS.Tools.WorkSpaces (2025).

.DESCRIPTION
    This script creates an AWS WorkSpace using the latest AWS PowerShell module. It validates parameters and provides robust error handling.

.PARAMETER BundleId
    The identifier of the bundle to create the WorkSpace from.
.PARAMETER DirectoryId
    The identifier of the directory for the WorkSpace.
.PARAMETER UserName
    The user name of the user for the WorkSpace.

.EXAMPLE
    .\aws-ps-create-workspace.ps1 -BundleId wsb-abc12345 -DirectoryId d-1234567890 -UserName myuser

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$BundleId,
    [Parameter(Mandatory)]
    [ValidatePattern('^d-[a-zA-Z0-9]{8,}$')]
    [string]$DirectoryId,
[Parameter(Mandatory)]
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
        Write-Error "Failed to create WorkSpace: $result"
        exit 1
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
