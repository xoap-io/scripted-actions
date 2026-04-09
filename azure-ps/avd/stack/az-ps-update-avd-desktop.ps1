<#
.SYNOPSIS
    Updates an Azure Virtual Desktop Desktop.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop Desktop.
    Uses the Update-AzWvdDesktop cmdlet from the Az.DesktopVirtualization module.

.PARAMETER ApplicationGroupName
    The name of the application group.

.PARAMETER Name
    The name of the desktop.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER Description
    The description of the desktop.

.PARAMETER FriendlyName
    The friendly name of the desktop.

.PARAMETER Tags
    A hashtable of tags to assign to the desktop.

.EXAMPLE
    PS C:\> .\Update-AzWvdDesktop.ps1 -ApplicationGroupName "MyAppGroup" -Name "MyDesktop" -ResourceGroup "MyResourceGroup" -Description "Updated Description"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvddesktop?view=azps-12.2.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationGroupName,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the desktop to update.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false, HelpMessage = "The description of the desktop.")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false, HelpMessage = "The friendly display name of the desktop.")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to assign to the desktop.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    ApplicationGroupName = $ApplicationGroupName
    Name                 = $Name
    ResourceGroupName    = $ResourceGroup
}

if ($Description) {
    $parameters['Description'] = $Description
}

if ($FriendlyName) {
    $parameters['FriendlyName'] = $FriendlyName
}

if ($Tags) {
    $parameters['Tag'] = $Tags
}

try {
    # Update the Azure Virtual Desktop Desktop and capture the result
    $result = Update-AzWvdDesktop @parameters

    # Output the result
    Write-Host "✅ Azure Virtual Desktop Desktop updated successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
