[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Description for the Transit Gateway")]
    [string]$Description = "Transit Gateway created via PowerShell script",

    [Parameter(Mandatory = $false, HelpMessage = "Amazon-side ASN for the Transit Gateway")]
    [ValidateRange(64512, 65534)]
    [int]$AmazonSideAsn = 64512,

    [Parameter(Mandatory = $false, HelpMessage = "Enable auto-accept shared attachments")]
    [ValidateSet('enable', 'disable')]
    [string]$AutoAcceptSharedAttachments = 'disable',

    [Parameter(Mandatory = $false, HelpMessage = "Enable auto-associate with default route table")]
    [ValidateSet('enable', 'disable')]
    [string]$DefaultRouteTableAssociation = 'enable',

    [Parameter(Mandatory = $false, HelpMessage = "Enable auto-propagate to default route table")]
    [ValidateSet('enable', 'disable')]
    [string]$DefaultRouteTablePropagation = 'enable',

    [Parameter(Mandatory = $false, HelpMessage = "Enable DNS support")]
    [ValidateSet('enable', 'disable')]
    [string]$DnsSupport = 'enable',

    [Parameter(Mandatory = $false, HelpMessage = "Enable multicast support")]
    [ValidateSet('enable', 'disable')]
    [string]$MulticastSupport = 'disable',

    [Parameter(Mandatory = $false, HelpMessage = "Name tag for the Transit Gateway")]
    [string]$Name,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Additional tags (Format: Key1=Value1,Key2=Value2)")]
    [string]$Tags,

    [Parameter(Mandatory = $false, HelpMessage = "Wait for the Transit Gateway to become available")]
    [switch]$Wait
)

<#
.SYNOPSIS
Creates an AWS Transit Gateway.

.DESCRIPTION
This script creates a Transit Gateway that acts as a cloud router to interconnect VPCs and on-premises networks through a central hub.

.PARAMETER Description
A description for the Transit Gateway.

.PARAMETER AmazonSideAsn
The Amazon-side ASN for the Transit Gateway. Must be between 64512 and 65534.

.PARAMETER AutoAcceptSharedAttachments
Enable automatic acceptance of shared attachments (cross-account).

.PARAMETER DefaultRouteTableAssociation
Enable automatic association with the default route table.

.PARAMETER DefaultRouteTablePropagation
Enable automatic propagation to the default route table.

.PARAMETER DnsSupport
Enable DNS support for the Transit Gateway.

.PARAMETER MulticastSupport
Enable multicast support for the Transit Gateway.

.PARAMETER Name
A name for the Transit Gateway (added as a Name tag).

.PARAMETER Profile
The AWS CLI profile to use for the operation.

.PARAMETER Region
The AWS region where the Transit Gateway will be created.

.PARAMETER Tags
Additional tags to apply in the format Key1=Value1,Key2=Value2.

.PARAMETER Wait
Wait for the Transit Gateway to become available.

.EXAMPLE
.\aws-cli-create-transit-gateway.ps1 -Name "Main-TGW" -Description "Primary Transit Gateway for hub-and-spoke architecture"

Creates a basic Transit Gateway with default settings.

.EXAMPLE
.\aws-cli-create-transit-gateway.ps1 -Name "Prod-TGW" -AmazonSideAsn 64513 -MulticastSupport enable

Creates a Transit Gateway with custom ASN and multicast support.

.EXAMPLE
.\aws-cli-create-transit-gateway.ps1 -Name "Shared-TGW" -AutoAcceptSharedAttachments enable -DefaultRouteTableAssociation disable

Creates a Transit Gateway for cross-account sharing with manual route table management.

.NOTES
Author: Your Name
Date: 2024
Requires: AWS CLI v2.16+ and appropriate IAM permissions

IMPORTANT NOTES:
- Transit Gateways incur hourly charges plus data processing charges
- Each Transit Gateway can connect up to 5,000 VPCs and VPN connections
- Transit Gateway creation takes several minutes
- Route tables can be customized for advanced routing scenarios
#>

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Creating AWS Transit Gateway..." -ForegroundColor Green

    # Build options object
    $options = @{
        "AmazonSideAsn" = $AmazonSideAsn
        "AutoAcceptSharedAttachments" = $AutoAcceptSharedAttachments
        "DefaultRouteTableAssociation" = $DefaultRouteTableAssociation
        "DefaultRouteTablePropagation" = $DefaultRouteTablePropagation
        "DnsSupport" = $DnsSupport
        "MulticastSupport" = $MulticastSupport
    }

    # Build AWS CLI arguments
    $awsArgs = @('ec2', 'create-transit-gateway')
    $awsArgs += @('--description', $Description)
    
    # Add options
    $optionString = ($options.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ','
    $awsArgs += @('--options', $optionString)
    
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
        $awsArgs += @('--tag-specifications', "ResourceType=transit-gateway,Tags=$($tagSpecs -join ',')")
    }
    
    if ($Profile) {
        $awsArgs += @('--profile', $Profile)
    }
    
    if ($Region) {
        $awsArgs += @('--region', $Region)
    }

    # Display configuration summary
    Write-Host "`nTransit Gateway Configuration:" -ForegroundColor Cyan
    Write-Host "  Description: $Description" -ForegroundColor White
    Write-Host "  Amazon-side ASN: $AmazonSideAsn" -ForegroundColor White
    Write-Host "  Auto Accept Shared Attachments: $AutoAcceptSharedAttachments" -ForegroundColor White
    Write-Host "  Default Route Table Association: $DefaultRouteTableAssociation" -ForegroundColor White
    Write-Host "  Default Route Table Propagation: $DefaultRouteTablePropagation" -ForegroundColor White
    Write-Host "  DNS Support: $DnsSupport" -ForegroundColor White
    Write-Host "  Multicast Support: $MulticastSupport" -ForegroundColor White
    
    if ($Name) {
        Write-Host "  Name: $Name" -ForegroundColor White
    }

    # Cost information
    Write-Host "`nCost Information:" -ForegroundColor Cyan
    Write-Host "  - Hourly charge for Transit Gateway operation" -ForegroundColor Yellow
    Write-Host "  - Data processing charges for traffic through the gateway" -ForegroundColor Yellow
    Write-Host "  - Additional charges for VPN attachments" -ForegroundColor Yellow

    # Create the Transit Gateway
    Write-Host "`nCreating Transit Gateway..." -ForegroundColor Yellow
    Write-Host "This operation may take several minutes..." -ForegroundColor Gray
    
    $result = & aws @awsArgs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create Transit Gateway: $result"
    }

    $tgwInfo = $result | ConvertFrom-Json
    $transitGateway = $tgwInfo.TransitGateway

    Write-Host "`nTransit Gateway created successfully!" -ForegroundColor Green
    Write-Host "  Transit Gateway ID: $($transitGateway.TransitGatewayId)" -ForegroundColor White
    Write-Host "  State: $($transitGateway.State)" -ForegroundColor White
    Write-Host "  Owner ID: $($transitGateway.OwnerId)" -ForegroundColor White
    Write-Host "  Creation Time: $($transitGateway.CreationTime)" -ForegroundColor White

    # Display configuration options
    if ($transitGateway.Options) {
        Write-Host "`n  Configuration Options:" -ForegroundColor Cyan
        Write-Host "    Amazon-side ASN: $($transitGateway.Options.AmazonSideAsn)" -ForegroundColor White
        Write-Host "    Auto Accept Shared Attachments: $($transitGateway.Options.AutoAcceptSharedAttachments)" -ForegroundColor White
        Write-Host "    Default Route Table Association: $($transitGateway.Options.DefaultRouteTableAssociation)" -ForegroundColor White
        Write-Host "    Default Route Table Propagation: $($transitGateway.Options.DefaultRouteTablePropagation)" -ForegroundColor White
        Write-Host "    DNS Support: $($transitGateway.Options.DnsSupport)" -ForegroundColor White
        Write-Host "    Multicast Support: $($transitGateway.Options.MulticastSupport)" -ForegroundColor White
    }

    # Display default route table information
    if ($transitGateway.Options.AssociationDefaultRouteTableId) {
        Write-Host "`n  Default Route Tables:" -ForegroundColor Cyan
        Write-Host "    Association Route Table: $($transitGateway.Options.AssociationDefaultRouteTableId)" -ForegroundColor White
        Write-Host "    Propagation Route Table: $($transitGateway.Options.PropagationDefaultRouteTableId)" -ForegroundColor White
    }

    # Display tags if present
    if ($transitGateway.Tags -and $transitGateway.Tags.Count -gt 0) {
        Write-Host "`n  Tags:" -ForegroundColor Cyan
        foreach ($tag in $transitGateway.Tags) {
            Write-Host "    $($tag.Key): $($tag.Value)" -ForegroundColor Gray
        }
    }

    # Wait for Transit Gateway if requested
    if ($Wait) {
        Write-Host "`nWaiting for Transit Gateway to become available..." -ForegroundColor Yellow
        
        $maxAttempts = 60  # 10 minutes with 10-second intervals
        $attempt = 0
        $isAvailable = $false
        
        while ($attempt -lt $maxAttempts -and -not $isAvailable) {
            Start-Sleep -Seconds 10
            $attempt++
            
            Write-Host "  Checking status (attempt $attempt/$maxAttempts)..." -ForegroundColor Gray
            
            $checkArgs = @('ec2', 'describe-transit-gateways', '--transit-gateway-ids', $transitGateway.TransitGatewayId)
            
            if ($Profile) {
                $checkArgs += @('--profile', $Profile)
            }
            
            if ($Region) {
                $checkArgs += @('--region', $Region)
            }
            
            $checkResult = & aws @checkArgs 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $checkInfo = $checkResult | ConvertFrom-Json
                $currentState = $checkInfo.TransitGateways[0].State
                
                if ($currentState -eq 'available') {
                    $isAvailable = $true
                    Write-Host "`nTransit Gateway is now available!" -ForegroundColor Green
                } elseif ($currentState -eq 'failed') {
                    Write-Host "`nTransit Gateway creation failed!" -ForegroundColor Red
                    break
                } else {
                    Write-Host "    Current state: $currentState" -ForegroundColor Gray
                }
            }
        }
        
        if (-not $isAvailable -and $attempt -eq $maxAttempts) {
            Write-Host "`nTimeout waiting for Transit Gateway to become available." -ForegroundColor Yellow
            Write-Host "Check the status manually with: aws ec2 describe-transit-gateways --transit-gateway-ids $($transitGateway.TransitGatewayId)" -ForegroundColor Gray
        }
    }

    # Display next steps
    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "1. Create VPC attachments to connect VPCs to the Transit Gateway:" -ForegroundColor White
    Write-Host "   aws ec2 create-transit-gateway-vpc-attachment --transit-gateway-id $($transitGateway.TransitGatewayId) --vpc-id <vpc-id> --subnet-ids <subnet-id>" -ForegroundColor Gray
    
    Write-Host "`n2. Create VPN attachments for on-premises connectivity:" -ForegroundColor White
    Write-Host "   aws ec2 create-vpn-connection --customer-gateway-id <cgw-id> --transit-gateway-id $($transitGateway.TransitGatewayId) --type ipsec.1" -ForegroundColor Gray
    
    Write-Host "`n3. Configure route tables for traffic routing:" -ForegroundColor White
    Write-Host "   aws ec2 create-route --route-table-id <rt-id> --destination-cidr-block <cidr> --transit-gateway-id $($transitGateway.TransitGatewayId)" -ForegroundColor Gray
    
    Write-Host "`n4. (Optional) Create custom Transit Gateway route tables for advanced routing" -ForegroundColor White

    Write-Host "`nUseful Management Commands:" -ForegroundColor Cyan
    Write-Host "View attachments: aws ec2 describe-transit-gateway-attachments --filters Name=transit-gateway-id,Values=$($transitGateway.TransitGatewayId)" -ForegroundColor Gray
    Write-Host "View route tables: aws ec2 describe-transit-gateway-route-tables --filters Name=transit-gateway-id,Values=$($transitGateway.TransitGatewayId)" -ForegroundColor Gray
    Write-Host "Monitor status: aws ec2 describe-transit-gateways --transit-gateway-ids $($transitGateway.TransitGatewayId)" -ForegroundColor Gray

    Write-Host "`nArchitecture Benefits:" -ForegroundColor Cyan
    Write-Host "- Simplifies network architecture with hub-and-spoke design" -ForegroundColor White
    Write-Host "- Scales to thousands of VPCs and connections" -ForegroundColor White
    Write-Host "- Supports advanced routing with multiple route tables" -ForegroundColor White
    Write-Host "- Enables multicast traffic distribution (if enabled)" -ForegroundColor White
    Write-Host "- Facilitates cross-account and cross-region connectivity" -ForegroundColor White

    # Output the Transit Gateway ID for scripting
    Write-Output $transitGateway.TransitGatewayId

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
