<#
.SYNOPSIS
    This script deletes an Azure Image Builder Template and the corresponding Azure Resource Group with the Azure PowerShell.

.DESCRIPTION
    This script deletes an Azure Image Builder Template and the corresponding Azure Resource Group with the Azure PowerShell. The script requires the following parameters:
    - AzResourceGroupName: Defines the name of the Azure Resource Group.
    - AzImageTemplateName: Defines the name of the Azure Image Builder Template.

    The script will delete the Azure Image Builder Template and the Azure Resource Group with all its resources.

.PARAMETER AzResourceGroupName
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

.PARAMETER WhatIf
    Shows what would happen if the cmdlet runs. The cmdlet is not run.

.PARAMETER Confirm
    Prompts you for confirmation before running the cmdlet.

.EXAMPLE
    .\az-ps-image-builder-windows-cleanup.ps1 -AzResourceGroupName "myResourceGroup" -AzImageTemplateName "myImageTemplate"

.NOTES
    Ensure that Azure PowerShell is installed and authenticated before running the script.
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Azure PowerShell

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroupName = "myResourceGroup",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzImageTemplateName = "myImageTemplate",

    [Parameter(Mandatory=$false)]
    [switch]$AzDebug,

    [Parameter(Mandatory=$false)]
    [switch]$AzOnlyShowErrors,

    [Parameter(Mandatory=$false)]
    [string]$AzOutput,

    [Parameter(Mandatory=$false)]
    [string]$AzQuery,

    [Parameter(Mandatory=$false)]
    [switch]$AzVerbose,


)

# Splatting parameters for better readability
$parameters = @{
    ResourceGroupName    = $AzResourceGroupName
    ImageTemplateName    = $AzImageTemplateName
    Debug                = $AzDebug
    OnlyShowErrors       = $AzOnlyShowErrors
    Output               = $AzOutput
    Query                = $AzQuery
    Verbose              = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Remove the Image Builder Template
    Remove-AzImageBuilderTemplate @parameters -Force

    # Remove the Resource Group
    Remove-AzResourceGroup @parameters -Force

    # Output the result
    Write-Output "Azure Image Builder Template and Resource Group '$($AzResourceGroupName)' deleted successfully."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to delete Azure Image Builder Template and Resource Group: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}