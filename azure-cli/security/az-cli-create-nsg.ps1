<#
.SYNOPSIS
    Create a new Azure Network Security Group (NSG) rule with the Azure CLI.

.DESCRIPTION
    This script creates a new Azure Network Security Group (NSG) rule with the Azure CLI.
    The script uses the following Azure CLI command:
    az network nsg rule create --resource-group $AzResourceGroupName --nsg-name $AzNsgName --name $AzNsgRuleName --priority $AzNsgPriority --source-address-prefixes $AzSourceAddressPrefixes --source-port-ranges $AzSourcePortRanges --destination-address-prefixes $AzDestinationAddressPrefixes --destination-port-ranges $AzDestinationPortRanges --access $AzAccess --protocol $AzProtocol --description $AzDescription

.PARAMETER Name
    Defines the name of the Azure Network Security Group rule.

.PARAMETER NsgName
    Defines the name of the Azure Network Security Group.

.PARAMETER Priority
    Defines the priority of the Azure Network Security Group rule.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER Access
    Defines the access of the Azure Network Security Group rule.

.PARAMETER Description
    Defines the description of the Azure Network Security Group rule.

.PARAMETER DestinationAddressPrefixes
    Defines the destination address prefixes of the Azure Network Security Group rule.

.PARAMETER DestinationAsgs
    Defines the destination ASGs of the Azure Network Security Group rule.

.PARAMETER Direction
    Defines the direction of the Azure Network Security Group rule.

.PARAMETER NoWait
    Defines the no-wait status of the Azure Network Security Group rule.

.PARAMETER Protocol
    Defines the protocol of the Azure Network Security Group rule.

.PARAMETER SourceAddressPrefixes
    Defines the source address prefixes of the Azure Network Security Group rule.

.PARAMETER SourceAsgs
    Defines the source ASGs of the Azure Network Security Group rule.

.PARAMETER SourcePortRanges
    Defines the source port ranges of the Azure Network Security Group rule.

.EXAMPLE
    .\az-cli-create-nsg-rule.ps1 -AzResourceGroupName "MyResourceGroup" -AzNsgName "MyNsg" -AzNsgRuleName "MyNsgRule" -AzNsgPriority 100 -AzSourceAddressPrefixes "208.130.28.0/24" -AzSourcePortRanges "80" -AzDestinationAddressPrefixes "*" -AzDestinationPortRanges "80 8080" -AzAccess "Deny" -AzProtocol "Tcp" -AzDescription "Deny from specific IP address ranges on 80 and 8080."

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/nsg/rule

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/nsg/rule?view=azure-cli-latest

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$NsgName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [int]$Priority,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Allow',
        'Deny'
    )]
    [string]$Access,
    
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationAddressPrefixes,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationAsgs,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Inbound',
        'Outbound'
    )]
    [string]$Direction,

    [Parameter(Mandatory=$false)]
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
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        '*',
        'Ah',
        'Esp',
        'Icmp',
        'Tcp',
        'Udp'
    )]
    [string]$Protocol,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceAddressPrefixes,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceAsgs,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePortRanges
)

# Splatting parameters for better readability
$parameters = @{
    '--name' = $Name
    '--nsg-name' = $NsgName
    '--priority' = $Priority
    '--resource-group' = $ResourceGroup
}

if ($Access) {
    $parameters += '--access', $Access
}

if ($Description) {
    $parameters += '--description', $Description
}

if ($DestinationAddressPrefixes) {
    $parameters += '--destination-address-prefixes', $DestinationAddressPrefixes
}

if ($DestinationAsgs) {
    $parameters += '--destination-asgs', $DestinationAsgs
}

if ($DestinationPortRanges) {
    $parameters += '--destination-port-ranges', $DestinationPortRanges
}

if ($Direction) {
    $parameters += '--direction', $Direction
}

if ($NoWait) {
    $parameters += '--no-wait', $NoWait
}

if ($Protocol) {
    $parameters += '--protocol', $Protocol
}

if ($SourceAddressPrefixes) {
    $parameters += '--source-address-prefixes', $SourceAddressPrefixes
}

if ($SourceAsgs) {
    $parameters += '--source-asgs', $SourceAsgs
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create a new NSG rule
    az network nsg rule create @parameters

    # Output the result
    Write-Output "Azure Network Security Group rule created successfully."

} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"
    Write-Error "Failed to create the Azure Network Security Group rule: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
