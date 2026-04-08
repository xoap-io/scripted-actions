<#
.SYNOPSIS
    Delete an Azure Image Builder Template and the corresponding Azure Resource Group with the Azure PowerShell.

.DESCRIPTION
    This script deletes an Azure Image Builder Template and the corresponding Azure Resource Group with the
    Azure PowerShell. The script requires the following parameters:
    - AzResourceGroup: Defines the name of the Azure Resource Group.
    - AzImageTemplateName: Defines the name of the Azure Image Builder Template.

    The script will delete the Azure Image Builder Template and the Azure Resource Group with all its resources.
    Uses Remove-AzImageBuilderTemplate and Remove-AzResourceGroup.

.PARAMETER AzResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER AzImageTemplateName
    Defines the name of the Azure Image Builder Template.

.PARAMETER AzDebug
    Increase logging verbosity to show all debug logs.

.PARAMETER AzOnlyShowErrors
    Only show errors, suppressing warnings.

.PARAMETER AzOutput
    Output format.

.PARAMETER AzQuery
    JMESPath query string.

.PARAMETER AzVerbose
    Increase logging verbosity.

.EXAMPLE
    .\az-ps-image-builder-windows-cleanup.ps1 -AzResourceGroup "myResourceGroup" -AzImageTemplateName "myImageTemplate"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az)

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.imagebuilder/remove-azimagebuildertemplate

.COMPONENT
    Azure PowerShell Compute
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure Resource Group.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "myResourceGroup",

    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure Image Builder Template.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzImageTemplateName = "myImageTemplate",

    [Parameter(Mandatory = $false, HelpMessage = "Increase logging verbosity to show all debug logs.")]
    [switch]$AzDebug,

    [Parameter(Mandatory = $false, HelpMessage = "Only show errors, suppressing warnings.")]
    [switch]$AzOnlyShowErrors,

    [Parameter(Mandatory = $false, HelpMessage = "Output format.")]
    [string]$AzOutput,

    [Parameter(Mandatory = $false, HelpMessage = "JMESPath query string.")]
    [string]$AzQuery,

    [Parameter(Mandatory = $false, HelpMessage = "Increase logging verbosity.")]
    [switch]$AzVerbose
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    ResourceGroupName = $AzResourceGroup
    ImageTemplateName = $AzImageTemplateName
    Debug             = $AzDebug
    OnlyShowErrors    = $AzOnlyShowErrors
    Output            = $AzOutput
    Query             = $AzQuery
    Verbose           = $AzVerbose
}

try {
    # Remove the Image Builder Template
    Remove-AzImageBuilderTemplate @parameters -Force

    # Remove the Resource Group
    Remove-AzResourceGroup -Name $AzResourceGroup -Force

    # Output the result
    Write-Host "✅ Azure Image Builder Template and Resource Group '$($AzResourceGroup)' deleted successfully." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
