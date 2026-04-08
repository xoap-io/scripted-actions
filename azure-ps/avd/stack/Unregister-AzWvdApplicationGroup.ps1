<#
.SYNOPSIS
    Unregisters an Azure Virtual Desktop Application Group.

.DESCRIPTION
    This script unregisters an Azure Virtual Desktop Application Group from a workspace.
    Uses the Unregister-AzWvdApplicationGroup cmdlet from the Az.DesktopVirtualization module.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER WorkspaceName
    The name of the workspace.

.PARAMETER ApplicationGroupPath
    The path of the application group.

.EXAMPLE
    PS C:\> .\Unregister-AzWvdApplicationGroup.ps1 -ResourceGroup "MyResourceGroup" -WorkspaceName "MyWorkspace" -ApplicationGroupPath "MyAppGroupPath"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/unregister-azwvdapplicationgroup?view=azps-12.2.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName,

    [Parameter(Mandatory=$true, HelpMessage = "The ARM path of the application group to unregister.")]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationGroupPath
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    ResourceGroupName    = $ResourceGroup
    WorkspaceName        = $WorkspaceName
    ApplicationGroupPath = $ApplicationGroupPath
}

try {
    # Unregister the Azure Virtual Desktop Application Group and capture the result
    $result = Unregister-AzWvdApplicationGroup @parameters

    # Output the result
    Write-Host "✅ Azure Virtual Desktop Application Group unregistered successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
