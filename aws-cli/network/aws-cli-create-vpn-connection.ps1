<#
.SYNOPSIS
    Creates an AWS VPN connection.

.DESCRIPTION
    This script creates a VPN connection between a customer gateway and either a Virtual Private Gateway
    or Transit Gateway. It supports static routing configuration and optional wait for availability.
    Uses aws ec2 create-vpn-connection to perform the operation.

.PARAMETER CustomerGatewayId
    The ID of the customer gateway for the VPN connection.

.PARAMETER VpnGatewayId
    The ID of the Virtual Private Gateway. Cannot be used with TransitGatewayId.

.PARAMETER TransitGatewayId
    The ID of the Transit Gateway. Cannot be used with VpnGatewayId.

.PARAMETER Type
    The type of VPN connection. Currently only 'ipsec.1' is supported.

.PARAMETER StaticRoutes
    Comma-separated list of CIDR blocks for static routing (only applicable with VGW).

.PARAMETER Name
    A name for the VPN connection (added as a Name tag).

.PARAMETER Profile
    The AWS CLI profile to use for the operation.

.PARAMETER Region
    The AWS region where the VPN connection will be created.

.PARAMETER Tags
    Additional tags to apply in the format Key1=Value1,Key2=Value2.

.PARAMETER Wait
    Wait for the VPN connection to become available.

.EXAMPLE
    .\aws-cli-create-vpn-connection.ps1 -CustomerGatewayId cgw-12345678 -VpnGatewayId vgw-87654321 -Name "Office-VPN"

.EXAMPLE
    .\aws-cli-create-vpn-connection.ps1 -CustomerGatewayId cgw-12345678 -TransitGatewayId tgw-87654321 -Name "DataCenter-VPN"

.EXAMPLE
    .\aws-cli-create-vpn-connection.ps1 -CustomerGatewayId cgw-12345678 -VpnGatewayId vgw-87654321 -StaticRoutes "10.0.0.0/16,192.168.0.0/16"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

    IMPORTANT NOTES:
    - You must specify either VpnGatewayId or TransitGatewayId, but not both
    - Static routes are only supported with Virtual Private Gateways
    - VPN connections take several minutes to become available
    - Each VPN connection provides redundant tunnels for high availability

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/ec2/create-vpn-connection.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the customer gateway for the VPN connection")]
    [ValidatePattern('^cgw-[a-zA-Z0-9]+$')]
    [string]$CustomerGatewayId,

    [Parameter(Mandatory = $false, HelpMessage = "The ID of the Virtual Private Gateway")]
    [ValidatePattern('^vgw-[a-zA-Z0-9]+$')]
    [string]$VpnGatewayId,

    [Parameter(Mandatory = $false, HelpMessage = "The ID of the Transit Gateway")]
    [ValidatePattern('^tgw-[a-zA-Z0-9]+$')]
    [string]$TransitGatewayId,

    [Parameter(Mandatory = $false, HelpMessage = "The type of VPN connection")]
    [ValidateSet('ipsec.1')]
    [string]$Type = 'ipsec.1',

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated CIDR blocks for static routing")]
    [string]$StaticRoutes,

    [Parameter(Mandatory = $false, HelpMessage = "Name tag for the VPN connection")]
    [string]$Name,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Additional tags (Format: Key1=Value1,Key2=Value2)")]
    [string]$Tags,

    [Parameter(Mandatory = $false, HelpMessage = "Wait for the VPN connection to become available")]
    [switch]$Wait
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Creating AWS VPN connection..." -ForegroundColor Green

    # Validate that either VGW or TGW is specified, but not both
    if (-not $VpnGatewayId -and -not $TransitGatewayId) {
        throw "You must specify either VpnGatewayId or TransitGatewayId"
    }

    if ($VpnGatewayId -and $TransitGatewayId) {
        throw "You cannot specify both VpnGatewayId and TransitGatewayId"
    }

    # Validate static routes format if provided
    if ($StaticRoutes) {
        if ($TransitGatewayId) {
            Write-Host "WARNING: Static routes are not supported with Transit Gateway. They will be ignored." -ForegroundColor Yellow
            $StaticRoutes = $null
        } else {
            $routeArray = $StaticRoutes -split ','
            foreach ($route in $routeArray) {
                $route = $route.Trim()
                if ($route -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$') {
                    throw "Invalid CIDR format in static routes: $route"
                }
            }
        }
    }

    # Build AWS CLI arguments
    $awsArgs = @('ec2', 'create-vpn-connection')
    $awsArgs += @('--customer-gateway-id', $CustomerGatewayId)
    $awsArgs += @('--type', $Type)

    if ($VpnGatewayId) {
        $awsArgs += @('--vpn-gateway-id', $VpnGatewayId)
    }

    if ($TransitGatewayId) {
        $awsArgs += @('--transit-gateway-id', $TransitGatewayId)
    }

    # Add static routes if specified and valid
    if ($StaticRoutes -and $VpnGatewayId) {
        $routeArray = $StaticRoutes -split ','
        foreach ($route in $routeArray) {
            $awsArgs += @('--options', "StaticRoutesOnly=true")
            break  # Only need to set this once
        }
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
        $awsArgs += @('--tag-specifications', "ResourceType=vpn-connection,Tags=$($tagSpecs -join ',')")
    }

    if ($Profile) {
        $awsArgs += @('--profile', $Profile)
    }

    if ($Region) {
        $awsArgs += @('--region', $Region)
    }

    # Display configuration summary
    Write-Host "`nVPN Connection Configuration:" -ForegroundColor Cyan
    Write-Host "  Customer Gateway: $CustomerGatewayId" -ForegroundColor White

    if ($VpnGatewayId) {
        Write-Host "  VPN Gateway: $VpnGatewayId" -ForegroundColor White
        Write-Host "  Connection Type: Virtual Private Gateway" -ForegroundColor White
    }

    if ($TransitGatewayId) {
        Write-Host "  Transit Gateway: $TransitGatewayId" -ForegroundColor White
        Write-Host "  Connection Type: Transit Gateway" -ForegroundColor White
    }

    Write-Host "  Type: $Type" -ForegroundColor White

    if ($StaticRoutes -and $VpnGatewayId) {
        Write-Host "  Static Routes: $StaticRoutes" -ForegroundColor White
    }

    if ($Name) {
        Write-Host "  Name: $Name" -ForegroundColor White
    }

    # Create the VPN connection
    Write-Host "`nCreating VPN connection..." -ForegroundColor Yellow
    $result = & aws @awsArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create VPN connection: $result"
    }

    $vpnInfo = $result | ConvertFrom-Json
    $vpnConnection = $vpnInfo.VpnConnection

    Write-Host "`n✅ VPN connection created successfully!" -ForegroundColor Green
    Write-Host "  VPN Connection ID: $($vpnConnection.VpnConnectionId)" -ForegroundColor White
    Write-Host "  State: $($vpnConnection.State)" -ForegroundColor White
    Write-Host "  Type: $($vpnConnection.Type)" -ForegroundColor White
    Write-Host "  Customer Gateway: $($vpnConnection.CustomerGatewayId)" -ForegroundColor White

    if ($vpnConnection.VpnGatewayId) {
        Write-Host "  VPN Gateway: $($vpnConnection.VpnGatewayId)" -ForegroundColor White
    }

    if ($vpnConnection.TransitGatewayId) {
        Write-Host "  Transit Gateway: $($vpnConnection.TransitGatewayId)" -ForegroundColor White
    }

    # Display tunnel information
    if ($vpnConnection.VgwTelemetry -and $vpnConnection.VgwTelemetry.Count -gt 0) {
        Write-Host "`n  Tunnel Information:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $vpnConnection.VgwTelemetry.Count; $i++) {
            $tunnel = $vpnConnection.VgwTelemetry[$i]
            Write-Host "    Tunnel $($i + 1):" -ForegroundColor White
            Write-Host "      Outside IP: $($tunnel.OutsideIpAddress)" -ForegroundColor Gray
            Write-Host "      Status: $($tunnel.Status)" -ForegroundColor Gray
            Write-Host "      Accepted Route Count: $($tunnel.AcceptedRouteCount)" -ForegroundColor Gray
        }
    }

    # Add static routes if specified
    if ($StaticRoutes -and $VpnGatewayId) {
        Write-Host "`nAdding static routes..." -ForegroundColor Yellow
        $routeArray = $StaticRoutes -split ','

        foreach ($route in $routeArray) {
            $route = $route.Trim()
            Write-Host "  Adding route: $route" -ForegroundColor Gray

            $routeArgs = @('ec2', 'create-vpn-connection-route')
            $routeArgs += @('--vpn-connection-id', $vpnConnection.VpnConnectionId)
            $routeArgs += @('--destination-cidr-block', $route)

            if ($Profile) {
                $routeArgs += @('--profile', $Profile)
            }

            if ($Region) {
                $routeArgs += @('--region', $Region)
            }

            $routeResult = & aws @routeArgs 2>&1

            if ($LASTEXITCODE -ne 0) {
                Write-Host "    Failed to add route $route`: $routeResult" -ForegroundColor Red
            } else {
                Write-Host "    Route $route added successfully" -ForegroundColor Green
            }
        }
    }

    # Wait for VPN connection if requested
    if ($Wait) {
        Write-Host "`nWaiting for VPN connection to become available..." -ForegroundColor Yellow

        $waitArgs = @('ec2', 'wait', 'vpn-connection-available', '--vpn-connection-ids', $vpnConnection.VpnConnectionId)

        if ($Profile) {
            $waitArgs += @('--profile', $Profile)
        }

        if ($Region) {
            $waitArgs += @('--region', $Region)
        }

        & aws @waitArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "VPN connection is now available!" -ForegroundColor Green
        } else {
            Write-Host "Wait operation timed out. Check the connection status manually." -ForegroundColor Yellow
        }
    }

    # Display next steps
    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "1. Download the VPN configuration:" -ForegroundColor White
    Write-Host "   aws ec2 describe-vpn-connections --vpn-connection-ids $($vpnConnection.VpnConnectionId)" -ForegroundColor Gray

    Write-Host "`n2. Configure your on-premises VPN device with the provided settings" -ForegroundColor White

    if ($VpnGatewayId) {
        Write-Host "`n3. Attach the VPN Gateway to your VPC:" -ForegroundColor White
        Write-Host "   aws ec2 attach-vpn-gateway --vpn-gateway-id $VpnGatewayId --vpc-id <vpc-id>" -ForegroundColor Gray

        Write-Host "`n4. Update route tables to direct traffic through the VPN gateway" -ForegroundColor White
    }

    if ($TransitGatewayId) {
        Write-Host "`n3. Configure Transit Gateway route tables as needed" -ForegroundColor White
        Write-Host "`n4. Update VPC route tables to direct traffic to the Transit Gateway" -ForegroundColor White
    }

    Write-Host "`nImportant Notes:" -ForegroundColor Cyan
    Write-Host "- VPN connections provide redundant tunnels for high availability" -ForegroundColor Yellow
    Write-Host "- Configure both tunnels on your on-premises device for redundancy" -ForegroundColor Yellow
    Write-Host "- Monitor tunnel status and route propagation" -ForegroundColor Yellow
    Write-Host "- Ensure security groups and NACLs allow VPN traffic" -ForegroundColor Yellow

    # Output the VPN connection ID for scripting
    Write-Output $vpnConnection.VpnConnectionId

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
