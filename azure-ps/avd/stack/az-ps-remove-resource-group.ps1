<#
.SYNOPSIS
    Deletes an Azure Resource Group.

.DESCRIPTION
    This script deletes an Azure Resource Group with all its resources using the Azure PowerShell.
    Uses the Remove-AzResourceGroup cmdlet from the Az.Resources module.

.PARAMETER AzResourceGroup
    Defines the name of the Azure Resource Group to delete.

.EXAMPLE
    .\Remove-AzResourceGroup.ps1 -AzResourceGroup "myResourceGroup"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.Resources

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.resources/remove-azresourcegroup?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Resources
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage = "The name of the Azure Resource Group to delete.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    Name = $AzResourceGroup
}

try {
    # Remove the Resource Group
    Remove-AzResourceGroup @parameters -Force

    # Output the result
    Write-Host "✅ Azure Resource Group '$AzResourceGroup' deleted successfully." -ForegroundColor Green

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
