<#
.SYNOPSIS
    Install the Web Server feature on a Windows VM in Azure.

.DESCRIPTION
    This script installs the Web Server feature on a Windows VM in Azure. The script uses the Azure PowerShell
    to run a PowerShell script on the specified Azure VM.
    The script uses the following Azure PowerShell command:
    Invoke-AzVMRunCommand -ResourceGroupName $AzResourceGroup -VMName $AzVmName -CommandId 'RunPowerShellScript' -ScriptString 'Install-WindowsFeature -Name Web-Server -IncludeManagementTools'
    The script sets the ErrorActionPreference to Stop to handle errors properly.

.PARAMETER AzResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER AzVmName
    Defines the name of the Azure VM.

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
    .\az-ps-install-webserver-windows.ps1 -AzResourceGroup "myResourceGroup" -AzVmName "myVm"

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
    https://learn.microsoft.com/en-us/powershell/module/az.compute/invoke-azvmruncommand

.COMPONENT
    Azure PowerShell Compute
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure Resource Group.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "myResourceGroup",

    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmName = "myVm",

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
    Name              = $AzVmName
    Debug             = $AzDebug
    OnlyShowErrors    = $AzOnlyShowErrors
    Output            = $AzOutput
    Query             = $AzQuery
    Verbose           = $AzVerbose
}

try {
    # Install Web Server feature on the VM
    Invoke-AzVMRunCommand @parameters -CommandId 'RunPowerShellScript' -ScriptString 'Install-WindowsFeature -Name Web-Server -IncludeManagementTools'

    # Output the result
    Write-Host "✅ Web Server feature installed successfully on Azure VM '$($AzVmName)'." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
