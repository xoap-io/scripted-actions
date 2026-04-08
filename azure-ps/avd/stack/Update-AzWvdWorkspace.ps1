<#
.SYNOPSIS
    Updates an Azure Virtual Desktop Workspace.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop Workspace.
    Uses the Update-AzWvdWorkspace cmdlet from the Az.DesktopVirtualization module.

.PARAMETER Name
    The name of the workspace.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER ApplicationGroupReference
    References to application groups.

.PARAMETER Description
    The description of the workspace.

.PARAMETER FriendlyName
    The friendly name of the workspace.

.PARAMETER PublicNetworkAccess
    Specifies whether the workspace is accessible over a public network.

.PARAMETER Tags
    A hashtable of tags to assign to the workspace.

.EXAMPLE
    PS C:\> .\Update-AzWvdWorkspace.ps1 -Name "MyWorkspace" -ResourceGroup "MyResourceGroup" -Description "Updated Description"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvdworkspace?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the workspace to update.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false, HelpMessage = "References to application groups to include in the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationGroupReference,

    [Parameter(Mandatory=$false, HelpMessage = "The description of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false, HelpMessage = "The friendly display name of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false, HelpMessage = "The public network access setting for the workspace.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Enabled",
        "Disabled"
    )]
    [string]$PublicNetworkAccess,

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to assign to the workspace.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    Name              = $Name
    ResourceGroupName = $ResourceGroup
}

if ($ApplicationGroupReference) {
    $parameters['ApplicationGroupReference'] = $ApplicationGroupReference
}

if ($Description) {
    $parameters['Description'] = $Description
}

if ($FriendlyName) {
    $parameters['FriendlyName'] = $FriendlyName
}

if ($PublicNetworkAccess) {
    $parameters['PublicNetworkAccess'] = $PublicNetworkAccess
}

if ($Tags) {
    $parameters['Tag'] = $Tags
}

try {
    # Update the Azure Virtual Desktop Workspace and capture the result
    $result = Update-AzWvdWorkspace @parameters

    # Output the result
    Write-Host "✅ Azure Virtual Desktop Workspace updated successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
