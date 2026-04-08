<#
.SYNOPSIS
    Register a new Azure VM in XOAP using Azure CLI.

.DESCRIPTION
    This script registers a new Azure VM in XOAP. The script uses the Azure CLI to run a PowerShell script on the Azure VM.
    The PowerShell script downloads the DSC configuration from the XOAP platform and applies it to the Azure VM.

    The script uses the Azure CLI command: az vm run-command invoke

.PARAMETER ResourceGroup
    The name of the Azure Resource Group containing the VM.

.PARAMETER VmName
    The name of the Azure VM to register.

.PARAMETER WorkspaceId
    The ID of the XOAP Workspace to register this node in.

.PARAMETER GroupName
    The XOAP config.XO group name to assign the node to.

.PARAMETER CommandId
    The command ID for the run-command operation.

.PARAMETER Scripts
    The PowerShell script to run on the VM for XOAP registration.

.EXAMPLE
    .\az-cli-register-node.ps1 -ResourceGroup "myResourceGroup" -VmName "myVmName" -WorkspaceId "myWorkspaceId" -GroupName "myGroupName"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vm/run-command

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure VM to register")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the XOAP Workspace")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceId,

    [Parameter(Mandatory = $true, HelpMessage = "The XOAP config.XO group name to assign the node to")]
    [ValidateNotNullOrEmpty()]
    [string]$GroupName,

    [Parameter(Mandatory = $false, HelpMessage = "The command ID for the run-command operation")]
    [ValidateNotNullOrEmpty()]
    [string]$CommandId = "RunPowerShellScript",

    [Parameter(Mandatory = $false, HelpMessage = "The PowerShell script to run on the VM")]
    [ValidateNotNullOrEmpty()]
    [string]$Scripts = "Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://api.xoap.io/dsc/Policy/$WorkspaceId/Download/$GroupName'))"
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Build parameter array
    $azParams = @(
        'vm', 'run-command', 'invoke',
        '--resource-group', $ResourceGroup,
        '--name', $VmName,
        '--command-id', $CommandId,
        '--scripts', $Scripts
    )

    # Register VM in XOAP
    Write-Host "🔧 Registering VM '$VmName' in XOAP..." -ForegroundColor Cyan
    az @azParams

    if ($LASTEXITCODE -ne 0) { throw "az vm run-command invoke failed with exit code $LASTEXITCODE." }

    Write-Host "✅ Azure VM '$VmName' registered in XOAP successfully." -ForegroundColor Green

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
