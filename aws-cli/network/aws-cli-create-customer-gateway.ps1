[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "BGP ASN for the customer gateway")]
    [ValidateRange(1, 4294967294)]
    [int]$BgpAsn,

    [Parameter(Mandatory = $true, HelpMessage = "Public IP address of the customer gateway")]
    [ValidatePattern('^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$', ErrorMessage = "IpAddress must be a valid IPv4 address")]
    [string]$IpAddress,

    [Parameter(Mandatory = $false, HelpMessage = "Name tag for the customer gateway")]
    [string]$Name,

    [Parameter(Mandatory = $false, HelpMessage = "Customer gateway type")]
    [ValidateSet('ipsec.1')]
    [string]$Type = 'ipsec.1',

    [Parameter(Mandatory = $false, HelpMessage = "Customer gateway device name")]
    [string]$DeviceName,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Additional tags (Format: Key1=Value1,Key2=Value2)")]
    [string]$Tags,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('json', 'table', 'text')]
    [string]$OutputFormat = 'table'
)

<#
.SYNOPSIS
Creates an AWS Customer Gateway.

.DESCRIPTION
This script creates a Customer Gateway for establishing VPN connections between your on-premises network and AWS VPC.

.PARAMETER BgpAsn
The Border Gateway Protocol (BGP) Autonomous System Number (ASN) for the customer gateway. Use 65000 for static routing.

.PARAMETER IpAddress
The public IPv4 address of your customer gateway device.

.PARAMETER Name
A name for the customer gateway (added as a Name tag).

.PARAMETER Type
The type of VPN connection that this customer gateway supports. Currently only 'ipsec.1' is supported.

.PARAMETER DeviceName
A name for the customer gateway device.

.PARAMETER Profile
The AWS CLI profile to use for the operation.

.PARAMETER Region
The AWS region where the customer gateway will be created.

.PARAMETER Tags
Additional tags to apply in the format Key1=Value1,Key2=Value2.

.PARAMETER OutputFormat
The output format for the results (json, table, text).

.EXAMPLE
.\aws-cli-create-customer-gateway.ps1 -BgpAsn 65000 -IpAddress 203.0.113.12 -Name "Office-Gateway"

Creates a customer gateway with static routing for an office connection.

.EXAMPLE
.\aws-cli-create-customer-gateway.ps1 -BgpAsn 65001 -IpAddress 203.0.113.12 -Name "DataCenter-Gateway" -DeviceName "Cisco-ASA-5500"

Creates a customer gateway with BGP routing and device information.

.EXAMPLE
.\aws-cli-create-customer-gateway.ps1 -BgpAsn 65000 -IpAddress 203.0.113.12 -Tags "Environment=Production,Department=IT"

Creates a customer gateway with additional tags.

.NOTES
Author: Your Name
Date: 2024
Requires: AWS CLI v2.16+ and appropriate IAM permissions

IMPORTANT NOTES:
- The IP address must be static and publicly accessible
- BGP ASN 65000 is typically used for static routing
- Customer gateways are region-specific resources
- There are no charges for customer gateways themselves
#>

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Creating AWS Customer Gateway..." -ForegroundColor Green

    # Validate IP address format
    try {
        [System.Net.IPAddress]::Parse($IpAddress) | Out-Null
    } catch {
        throw "Invalid IP address format: $IpAddress"
    }

    # Build AWS CLI arguments
    $awsArgs = @('ec2', 'create-customer-gateway')
    $awsArgs += @('--bgp-asn', $BgpAsn.ToString())
    $awsArgs += @('--public-ip', $IpAddress)
    $awsArgs += @('--type', $Type)
    
    if ($DeviceName) {
        $awsArgs += @('--device-name', $DeviceName)
    }
    
    # Build tag specifications
    $tagSpecs = @()
    
    if ($Name) {
        $tagSpecs += "Key=Name,Value=$Name"
    }
    
    if ($Tags) {
        $tagPairs = $Tags -split ','
        foreach ($tagPair in $tagPairs) {
            $parts = $tagPair -split '=', 2
            if ($parts.Length -eq 2) {
                $tagSpecs += "Key=$($parts[0]),Value=$($parts[1])"
            }
        }
    }
    
    if ($tagSpecs.Count -gt 0) {
        $awsArgs += @('--tag-specifications', "ResourceType=customer-gateway,Tags=$($tagSpecs -join ',')")
    }
    
    if ($Profile) {
        $awsArgs += @('--profile', $Profile)
    }
    
    if ($Region) {
        $awsArgs += @('--region', $Region)
    }

    # Display configuration summary
    Write-Host "`nCustomer Gateway Configuration:" -ForegroundColor Cyan
    Write-Host "  BGP ASN: $BgpAsn" -ForegroundColor White
    Write-Host "  Public IP: $IpAddress" -ForegroundColor White
    Write-Host "  Type: $Type" -ForegroundColor White
    
    if ($DeviceName) {
        Write-Host "  Device Name: $DeviceName" -ForegroundColor White
    }
    
    if ($Name) {
        Write-Host "  Name: $Name" -ForegroundColor White
    }

    # BGP ASN guidance
    if ($BgpAsn -eq 65000) {
        Write-Host "`nNote: BGP ASN 65000 is typically used for static routing." -ForegroundColor Cyan
    } else {
        Write-Host "`nNote: Using BGP ASN $BgpAsn for dynamic routing." -ForegroundColor Cyan
    }

    # Create the customer gateway
    Write-Host "`nCreating customer gateway..." -ForegroundColor Yellow
    $result = & aws @awsArgs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create customer gateway: $result"
    }

    $cgwInfo = $result | ConvertFrom-Json
    $customerGateway = $cgwInfo.CustomerGateway

    if ($OutputFormat -eq 'json') {
        $result
        return
    }

    Write-Host "`nCustomer Gateway created successfully!" -ForegroundColor Green
    Write-Host "  Customer Gateway ID: $($customerGateway.CustomerGatewayId)" -ForegroundColor White
    Write-Host "  State: $($customerGateway.State)" -ForegroundColor White
    Write-Host "  BGP ASN: $($customerGateway.BgpAsn)" -ForegroundColor White
    Write-Host "  IP Address: $($customerGateway.IpAddress)" -ForegroundColor White
    Write-Host "  Type: $($customerGateway.Type)" -ForegroundColor White
    
    if ($customerGateway.DeviceName) {
        Write-Host "  Device Name: $($customerGateway.DeviceName)" -ForegroundColor White
    }

    # Display tags if present
    if ($customerGateway.Tags -and $customerGateway.Tags.Count -gt 0) {
        Write-Host "`n  Tags:" -ForegroundColor Cyan
        foreach ($tag in $customerGateway.Tags) {
            Write-Host "    $($tag.Key): $($tag.Value)" -ForegroundColor Gray
        }
    }

    # Next steps information
    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "1. Create a Virtual Private Gateway (VGW) or use Transit Gateway" -ForegroundColor White
    Write-Host "2. Create a VPN connection using this customer gateway:" -ForegroundColor White
    Write-Host "   aws ec2 create-vpn-connection --customer-gateway-id $($customerGateway.CustomerGatewayId) --type ipsec.1 --vpn-gateway-id <vgw-id>" -ForegroundColor Gray
    Write-Host "3. Configure your on-premises device with the VPN connection details" -ForegroundColor White
    Write-Host "4. Update route tables to enable traffic routing" -ForegroundColor White

    Write-Host "`nImportant Configuration Notes:" -ForegroundColor Cyan
    Write-Host "- Ensure your on-premises firewall allows IPSec traffic (UDP 500, 4500)" -ForegroundColor Yellow
    Write-Host "- Configure your device to support the IPSec parameters AWS provides" -ForegroundColor Yellow
    Write-Host "- Plan your IP address ranges to avoid conflicts with VPC CIDRs" -ForegroundColor Yellow

    if ($BgpAsn -ne 65000) {
        Write-Host "- Configure BGP with ASN $BgpAsn on your on-premises device" -ForegroundColor Yellow
    } else {
        Write-Host "- Configure static routes on your on-premises device" -ForegroundColor Yellow
    }

    # Output the customer gateway ID for scripting
    Write-Output $customerGateway.CustomerGatewayId

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
