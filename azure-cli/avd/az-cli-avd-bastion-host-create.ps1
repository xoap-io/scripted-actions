<#
.SYNOPSIS
    Create an Azure Bastion Host with the Azure CLI.

.DESCRIPTION
    This script creates an Azure Bastion Host with the Azure CLI.
    The script uses the following Azure CLI command:
    az network bastion create --name $AzBastionName --public-ip-address $AzPublicIpAddress --resource-group $AzResourceGroup --vnet-name $AzVnetName --location $AzLocation

.PARAMETER BastionName
    Defines the name of the Azure Bastion Host.

.PARAMETER PublicIpAddress

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER VnetName
    Defines the name of the Azure Virtual Network.

.PARAMETER Location
    Defines the location of the Azure Bastion Host.

.PARAMETER DisableCopyPaste
    Disable copy and paste functionality.

.PARAMETER EnableIpConnect
    Enable IP Connect.

.PARAMETER EnableTunneling
    Enable tunneling.

.PARAMETER FileCopy
    Enable file copy.

.PARAMETER Kereberos
    Enable Kerberos.

.PARAMETER NoWait
    Do not wait for the long-running operation to finish.

.PARAMETER ScaleUnits
    The number of scale units.

.PARAMETER SessionRecording
    Enable session recording.

.PARAMETER ShareableLink
    Enable shareable link.

.PARAMETER Tags
    Tags for the Azure Bastion Host.

.PARAMETER Zones
    Availability zones.

.EXAMPLE
    .\az-cli-bastion-create.ps1 -AzBastionName "MyBastion" -AzPublicIpAddress "MyPublicIP" -AzResourceGroup "MyResourceGroup" -AzVnetName "MyVnet" -AzLocation "eastus2"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/bastion

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/bastion?view=azure-cli-latest

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$BastionName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$PublicIpAddress,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$VnetName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        '0',
        '1',
        'f',
        'false',
        'n',
        'no',
        't',
        'true',
        'y',
        'yes'
    )]
    [string]$DisableCopyPaste,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        '0',
        '1',
        'f',
        'false',
        'n',
        'no',
        't',
        'true',
        'y',
        'yes'
    )]
    [string]$EnableIpConnect,
    
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        '0',
        '1',
        'f',
        'false',
        'n',
        'no',
        't',
        'true',
        'y',
        'yes'
    )]
    [string]$EnableTunneling,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        '0',
        '1',
        'f',
        'false',
        'n',
        'no',
        't',
        'true',
        'y',
        'yes'
    )]
    [string]$FileCopy,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        '0',
        '1',
        'f',
        'false',
        'n',
        'no',
        't',
        'true',
        'y',
        'yes'
    )]
    [string]$Kereberos,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'eastus', 'eastus2', 'southcentralus', 'westus2',
        'westus3', 'australiaeast', 'southeastasia', 'northeurope',
        'swedencentral', 'uksouth', 'westeurope', 'centralus',
        'southafricanorth', 'centralindia', 'eastasia', 'japaneast',
        'koreacentral', 'canadacentral', 'francecentral', 'germanywestcentral',
        'italynorth', 'norwayeast', 'polandcentral', 'switzerlandnorth',
        'uaenorth', 'brazilsouth', 'israelcentral', 'qatarcentral',
        'asia', 'asiapacific', 'australia', 'brazil',
        'canada', 'europe', 'france',
        'global', 'india', 'japan', 'korea',
        'norway', 'singapore', 'southafrica', 'sweden',
        'switzerland', 'unitedstates', 'northcentralus', 'westus',
        'japanwest', 'centraluseuap', 'eastus2euap', 'westcentralus',
        'southafricawest', 'australiacentral', 'australiacentral2', 'australiasoutheast',
        'koreasouth', 'southindia', 'westindia', 'canadaeast',
        'francesouth', 'germanynorth', 'norwaywest', 'switzerlandwest',
        'ukwest', 'uaecentral', 'brazilsoutheast'
    )]
    [string]$Location,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        '0',
        '1',
        'f',
        'false',
        'n',
        'no',
        't',
        'true',
        'y',
        'yes'
    )]
    [string]$NoWait,

    [Parameter(Mandatory=$false)]
    [int]$ScaleUnits,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        '0',
        '1',
        'f',
        'false',
        'n',
        'no',
        't',
        'true',
        'y',
        'yes'
    )]
    [string]$SessionRecording,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        '0',
        '1',
        'f',
        'false',
        'n',
        'no',
        't',
        'true',
        'y',
        'yes'
    )]
    [string]$ShareableLink,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Basic',
        'Premium',
        'Standard'
    )]

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Tags,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Zones
)

# Splatting parameters for better readability
$parameters = `
    '--name', $BastionName
    '--public-ip-address', $PublicIpAddress
    '--resource-group', $ResourceGroup
    '--vnet-name', $VnetName

if ($DisableCopyPaste) {
    $parameters += '--disable-copy-paste', $DisableCopyPaste
}

if ($EnableIpConnect) {
    $parameters += '--enable-ip-connect', $EnableIpConnect
}

if ($EnableTunneling) {
    $parameters += '--enable-tunneling', $EnableTunneling
}

if ($FileCopy) {
    $parameters += '--file-copy', $FileCopy
}

if ($Kereberos) {
    $parameters += '--kerberos', $Kereberos
}

if ($Location) {
    $parameters += '--location', $Location
}

if ($NoWait) {
    $parameters += '--no-wait', $NoWait
}

if ($ScaleUnits) {
    $parameters += '--scale-units', $ScaleUnits
}

if ($SessionRecording) {
    $parameters += '--session-recording', $SessionRecording
}

if ($ShareableLink) {
    $parameters += '--shareable-link', $ShareableLink
}

if ($Tags) {
    $parameters += '--tags', $Tags
}

if ($Zones) {
    $parameters += '--zones', $Zones
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the Azure Bastion Host
    az network bastion create @parameters

    # Output the result
    Write-Output "Azure Bastion Host created successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to create the Azure Bastion Host: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
