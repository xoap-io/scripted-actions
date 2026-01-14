<#
.SYNOPSIS
    Create an Azure Virtual Network and Subnet.

.DESCRIPTION
    This script creates an Azure Virtual Network with a subnet using the Azure CLI.
    The script supports comprehensive VNet configuration including:
    - Address space and subnet configuration
    - DDoS protection settings
    - DNS server configuration
    - Network security group association
    - Encryption and VM protection options

    The script uses the Azure CLI command: az network vnet create

.PARAMETER Name
    The name of the Azure Virtual Network.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the VNet will be created.

.PARAMETER Location
    The Azure region where the Virtual Network will be created (e.g., 'eastus', 'westus2').

.PARAMETER AddressPrefixes
    The address space for the Virtual Network in CIDR notation (e.g., '10.0.0.0/16').

.PARAMETER SubnetName
    The name of the initial subnet to create within the VNet.

.PARAMETER SubnetPrefixes
    The address space for the subnet in CIDR notation (e.g., '10.0.1.0/24').

.PARAMETER DnsServers
    Space-separated list of DNS server IP addresses for the VNet.

.PARAMETER Tags
    Tags to apply to the Virtual Network in the format 'key1=value1 key2=value2'.

.PARAMETER EnableDdosProtection
    Enable DDoS protection for the Virtual Network.

.PARAMETER DdosProtectionPlan
    Resource ID of the DDoS protection plan to associate with the VNet.

.PARAMETER BgpCommunity
    BGP community attribute for the Virtual Network.

.PARAMETER EdgeZone
    Edge zone name for the Virtual Network.

.PARAMETER EnableEncryption
    Enable encryption for the Virtual Network.

.PARAMETER EncryptionEnforcementPolicy
    Enforcement policy for encryption.
    Valid values: 'AllowUnencrypted', 'DropUnencrypted'

.PARAMETER Flowtimeout
    Flow timeout value in minutes for the Virtual Network.

.PARAMETER NetworkSecurityGroup
    Network Security Group to associate with the subnet.

.PARAMETER NoWait
    Do not wait for the operation to complete.

.PARAMETER Subnets
    JSON string defining multiple subnets to create.

.PARAMETER EnableVmProtection
    Enable VM protection for the Virtual Network.

.PARAMETER VnetPrefixes
    Alternative parameter for address prefixes (use AddressPrefixes instead).

.PARAMETER VnetType
    Type of the Virtual Network (legacy parameter).

.PARAMETER Zones
    Availability zones for the Virtual Network.

.EXAMPLE
    .\az-cli-create-virtual-network.ps1 -Name "MyVNet" -ResourceGroup "MyResourceGroup" -Location "eastus" -AddressPrefixes "10.0.0.0/16" -SubnetName "default" -SubnetPrefixes "10.0.1.0/24"

    Creates a basic Virtual Network with a single subnet.

.EXAMPLE
    .\az-cli-create-virtual-network.ps1 -Name "MyVNet" -ResourceGroup "MyResourceGroup" -Location "eastus" -AddressPrefixes "10.0.0.0/16" -SubnetName "default" -SubnetPrefixes "10.0.1.0/24" -DnsServers "8.8.8.8 8.8.4.4" -EnableDdosProtection -Tags "environment=production team=networking"

    Creates a Virtual Network with custom DNS servers, DDoS protection, and tags.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/vnet

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Virtual Network")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where the VNet will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $true, HelpMessage = "The address space for the VNet in CIDR notation")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$', ErrorMessage = "Address prefix must be in CIDR notation (e.g., '10.0.0.0/16')")]
    [string]$AddressPrefixes,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the initial subnet")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName,

    [Parameter(Mandatory = $true, HelpMessage = "The address space for the subnet in CIDR notation")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$', ErrorMessage = "Subnet prefix must be in CIDR notation (e.g., '10.0.1.0/24')")]
    [string]$SubnetPrefixes,

    [Parameter(HelpMessage = "Space-separated list of DNS server IP addresses")]
    [string]$DnsServers,

    [Parameter(HelpMessage = "Tags in the format 'key1=value1 key2=value2'")]
    [string]$Tags,

    [Parameter(HelpMessage = "Enable DDoS protection")]
    [switch]$EnableDdosProtection,

    [Parameter(HelpMessage = "Resource ID of DDoS protection plan")]
    [string]$DdosProtectionPlan,

    [Parameter(HelpMessage = "BGP community attribute")]
    [string]$BgpCommunity,

    [Parameter(HelpMessage = "Edge zone name")]
    [string]$EdgeZone,

    [Parameter(HelpMessage = "Enable encryption for the VNet")]
    [switch]$EnableEncryption,

    [Parameter(HelpMessage = "Encryption enforcement policy")]
    [ValidateSet('AllowUnencrypted', 'DropUnencrypted')]
    [string]$EncryptionEnforcementPolicy,

    [Parameter(HelpMessage = "Flow timeout in minutes")]
    [ValidateRange(4, 30)]
    [int]$Flowtimeout,

    [Parameter(HelpMessage = "Network Security Group for the subnet")]
    [string]$NetworkSecurityGroup,

    [Parameter(HelpMessage = "Do not wait for operation completion")]
    [switch]$NoWait,

    [Parameter(HelpMessage = "JSON string defining multiple subnets")]
    [string]$Subnets,

    [Parameter(HelpMessage = "Enable VM protection")]
    [switch]$EnableVmProtection,

    [Parameter(HelpMessage = "Alternative address prefixes parameter")]
    [string]$VnetPrefixes,

    [Parameter(HelpMessage = "VNet type (legacy parameter)")]
    [string]$VnetType,

    [Parameter(HelpMessage = "Availability zones")]
    [string]$Zones
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

try {
    # Check if Azure CLI is available
    if (-not (Get-Command 'az' -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not found in PATH. Please install Azure CLI first."
    }

    # Check if user is logged in to Azure CLI
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $azAccount) {
        throw "Not logged in to Azure CLI. Please run 'az login' first."
    }

    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green
    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'vnet', 'create',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--location', $Location,
        '--address-prefixes', $AddressPrefixes,
        '--subnet-name', $SubnetName,
        '--subnet-prefixes', $SubnetPrefixes
    )

    # Add optional parameters
    if ($DnsServers) { $azParams += '--dns-servers', $DnsServers }
    if ($Tags) { $azParams += '--tags', $Tags }
    if ($EnableDdosProtection) { $azParams += '--ddos-protection', 'true' }
    if ($DdosProtectionPlan) { $azParams += '--ddos-protection-plan', $DdosProtectionPlan }
    if ($BgpCommunity) { $azParams += '--bgp-community', $BgpCommunity }
    if ($EdgeZone) { $azParams += '--edge-zone', $EdgeZone }
    if ($EnableEncryption) { $azParams += '--enable-encryption', 'true' }
    if ($EncryptionEnforcementPolicy) { $azParams += '--encryption-enforcement-policy', $EncryptionEnforcementPolicy }
    if ($Flowtimeout) { $azParams += '--flowtimeout', $Flowtimeout.ToString() }
    if ($NetworkSecurityGroup) { $azParams += '--network-security-group', $NetworkSecurityGroup }
    if ($NoWait) { $azParams += '--no-wait' }
    if ($Subnets) { $azParams += '--subnets', $Subnets }
    if ($EnableVmProtection) { $azParams += '--vm-protection', 'true' }
    if ($VnetPrefixes) { $azParams += '--address-prefixes', $VnetPrefixes }
    if ($Zones) { $azParams += '--zones', $Zones }

    Write-Host "Creating Virtual Network '$Name' in resource group '$ResourceGroup'..." -ForegroundColor Yellow
    Write-Host "  Address Space: $AddressPrefixes" -ForegroundColor Gray
    Write-Host "  Subnet: $SubnetName ($SubnetPrefixes)" -ForegroundColor Gray

    # Execute the Azure CLI command
    $result = & az @azParams --output json

    if ($LASTEXITCODE -eq 0 -and -not $NoWait) {
        $vnet = $result | ConvertFrom-Json

        Write-Host "✓ Virtual Network created successfully!" -ForegroundColor Green
        Write-Host "Virtual Network Details:" -ForegroundColor Cyan
        Write-Host "  Name: $($vnet.name)" -ForegroundColor White
        Write-Host "  Resource Group: $($vnet.resourceGroup)" -ForegroundColor White
        Write-Host "  Location: $($vnet.location)" -ForegroundColor White
        Write-Host "  Address Space: $($vnet.addressSpace.addressPrefixes -join ', ')" -ForegroundColor White

        if ($vnet.subnets -and $vnet.subnets.Count -gt 0) {
            Write-Host "Subnets:" -ForegroundColor Cyan
            foreach ($subnet in $vnet.subnets) {
                Write-Host "  - $($subnet.name): $($subnet.addressPrefix)" -ForegroundColor White
            }
        }

        if ($vnet.dhcpOptions -and $vnet.dhcpOptions.dnsServers) {
            Write-Host "DNS Servers: $($vnet.dhcpOptions.dnsServers -join ', ')" -ForegroundColor White
        }

        if ($vnet.enableDdosProtection) {
            Write-Host "DDoS Protection: Enabled" -ForegroundColor Green
        }

    } elseif ($NoWait) {
        Write-Host "✓ Virtual Network creation initiated (no-wait mode)" -ForegroundColor Green
        Write-Host "Use 'az network vnet show --name $Name --resource-group $ResourceGroup' to check status" -ForegroundColor Yellow
    } else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE"
    }

} catch {
    Write-Host "✗ Error creating Virtual Network: $($_.Exception.Message)" -ForegroundColor Red
    throw
} finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
