<#
.SYNOPSIS
    Detaches Internet Gateways from VPCs using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script safely detaches Internet Gateways from VPCs with validation and impact analysis.
    Provides warnings for potentially disruptive detachments.

.PARAMETER InternetGatewayId
    The ID of the Internet Gateway to detach.

.PARAMETER VpcId
    The ID of the VPC from which to detach the Internet Gateway.

.PARAMETER DryRun
    Perform a dry run to validate parameters without detaching the gateway.

.PARAMETER Force
    Skip confirmation prompts for potentially disruptive detachments.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-detach-internet-gateway.ps1 -InternetGatewayId "igw-12345678" -VpcId "vpc-12345678"

.EXAMPLE
    .\aws-cli-detach-internet-gateway.ps1 -InternetGatewayId "igw-12345678" -VpcId "vpc-12345678" -Force

.EXAMPLE
    .\aws-cli-detach-internet-gateway.ps1 -InternetGatewayId "igw-12345678" -VpcId "vpc-12345678" -DryRun

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/ec2/detach-internet-gateway.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the Internet Gateway to detach")]
    [ValidatePattern('^igw-[a-zA-Z0-9]{8,}$')]
    [string]$InternetGatewayId,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the VPC from which to detach the Internet Gateway")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId,

    [Parameter(Mandatory = $false, HelpMessage = "Perform a dry run to validate parameters without detaching the gateway")]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts for potentially disruptive detachments")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    # Build base AWS CLI arguments
    $awsArgs = @()
    if ($Region) { $awsArgs += @('--region', $Region) }
    if ($Profile) { $awsArgs += @('--profile', $Profile) }
    if ($DryRun) { $awsArgs += @('--dry-run') }

    Write-Output "🔌 Detaching Internet Gateway: $InternetGatewayId from VPC: $VpcId"
    if ($DryRun) { Write-Output "Mode: DRY RUN - No changes will be made" }

    # Verify Internet Gateway exists and get current attachments
    Write-Output "`n🔍 Verifying Internet Gateway..."
    $igwResult = aws ec2 describe-internet-gateways --internet-gateway-ids $InternetGatewayId @awsArgs --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Internet Gateway $InternetGatewayId not found or not accessible: $igwResult"
    }

    $igwData = $igwResult | ConvertFrom-Json
    $internetGateway = $igwData.InternetGateways[0]

    Write-Output "✅ Internet Gateway verified:"
    Write-Output "  Internet Gateway ID: $($internetGateway.InternetGatewayId)"
    Write-Output "  State: $($internetGateway.State)"
    Write-Output "  Current attachments: $($internetGateway.Attachments.Count)"

    # Check if IGW is attached to the specified VPC
    $targetAttachment = $internetGateway.Attachments | Where-Object { $_.VpcId -eq $VpcId }

    if (-not $targetAttachment) {
        Write-Error "Internet Gateway $InternetGatewayId is not attached to VPC $VpcId"
    }

    Write-Output "`n📋 Current Attachment:"
    Write-Output "  VPC ID: $($targetAttachment.VpcId)"
    Write-Output "  State: $($targetAttachment.State)"

    if ($targetAttachment.State -ne "available") {
        Write-Warning "⚠️  Attachment is in '$($targetAttachment.State)' state - detachment may not be possible"
    }

    # Verify VPC exists
    Write-Output "`n🔍 Verifying VPC..."
    $vpcResult = aws ec2 describe-vpcs --vpc-ids $VpcId @awsArgs --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "VPC $VpcId not found or not accessible: $vpcResult"
    }

    $vpcData = $vpcResult | ConvertFrom-Json
    $vpc = $vpcData.Vpcs[0]

    Write-Output "✅ VPC verified:"
    Write-Output "  VPC ID: $($vpc.VpcId)"
    Write-Output "  State: $($vpc.State)"
    Write-Output "  CIDR Block: $($vpc.CidrBlock)"

    # Check for routes that reference this Internet Gateway
    Write-Output "`n🔍 Checking for routes that reference this Internet Gateway..."
    $routeResult = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VpcId" @awsArgs --output json 2>&1

    $referencingRoutes = @()
    if ($LASTEXITCODE -eq 0) {
        $routeData = $routeResult | ConvertFrom-Json

        foreach ($routeTable in $routeData.RouteTables) {
            $igwRoutes = $routeTable.Routes | Where-Object { $_.GatewayId -eq $InternetGatewayId }
            if ($igwRoutes) {
                foreach ($route in $igwRoutes) {
                    $referencingRoutes += [PSCustomObject]@{
                        RouteTableId = $routeTable.RouteTableId
                        Destination = "$($route.DestinationCidrBlock)$($route.DestinationIpv6CidrBlock)"
                        State = $route.State
                        Associations = $routeTable.Associations.Count
                        SubnetAssociations = ($routeTable.Associations | Where-Object { $_.SubnetId }).SubnetId -join ", "
                    }
                }
            }
        }

        if ($referencingRoutes.Count -gt 0) {
            Write-Output "⚠️  Found $($referencingRoutes.Count) route(s) referencing this Internet Gateway:"
            foreach ($route in $referencingRoutes) {
                Write-Output "  - Route Table: $($route.RouteTableId)"
                Write-Output "    Destination: $($route.Destination), State: $($route.State)"
                if ($route.SubnetAssociations) {
                    Write-Output "    Associated Subnets: $($route.SubnetAssociations)"
                }
            }
            Write-Output ""
            Write-Output "🚨 WARNING: Detaching this Internet Gateway will make these routes invalid!"
            Write-Output "   This will cause loss of internet connectivity for associated subnets."
        } else {
            Write-Output "✅ No routes found referencing this Internet Gateway"
        }
    }

    # Check for public IP addresses that would be affected
    Write-Output "`n🔍 Checking for resources with public IP addresses..."
    $instanceResult = aws ec2 describe-instances --filters "Name=vpc-id,Values=$VpcId" "Name=instance-state-name,Values=running,pending,stopping,stopped" @awsArgs --output json 2>&1

    $publicInstances = @()
    if ($LASTEXITCODE -eq 0) {
        $instanceData = $instanceResult | ConvertFrom-Json

        foreach ($reservation in $instanceData.Reservations) {
            foreach ($instance in $reservation.Instances) {
                if ($instance.PublicIpAddress -or $instance.PublicDnsName) {
                    $publicInstances += [PSCustomObject]@{
                        InstanceId = $instance.InstanceId
                        PublicIp = $instance.PublicIpAddress
                        PublicDns = $instance.PublicDnsName
                        SubnetId = $instance.SubnetId
                        State = $instance.State.Name
                    }
                }
            }
        }

        if ($publicInstances.Count -gt 0) {
            Write-Output "⚠️  Found $($publicInstances.Count) instance(s) with public IP addresses:"
            foreach ($instance in $publicInstances) {
                Write-Output "  - Instance: $($instance.InstanceId) (State: $($instance.State))"
                Write-Output "    Public IP: $($instance.PublicIp)"
                Write-Output "    Subnet: $($instance.SubnetId)"
            }
            Write-Output ""
            Write-Output "🚨 WARNING: These instances will lose internet connectivity!"
        } else {
            Write-Output "✅ No instances with public IP addresses found"
        }
    }

    # Impact assessment
    $isDisruptive = ($referencingRoutes.Count -gt 0) -or ($publicInstances.Count -gt 0)

    if ($isDisruptive) {
        Write-Output "`n🚨 IMPACT ANALYSIS:"
        Write-Output "• Internet connectivity will be lost for resources in this VPC"
        Write-Output "• Any applications requiring outbound internet access will stop working"
        Write-Output "• Remote access to public instances will be interrupted"
        Write-Output "• Consider creating alternative internet access before detaching"
    }

    # Confirmation prompt for disruptive detachments
    if ($isDisruptive -and -not $Force -and -not $DryRun) {
        Write-Output "`n❓ This detachment will disrupt internet connectivity. Do you want to continue? (y/N)"
        $confirmation = Read-Host
        if ($confirmation -notmatch '^[Yy]') {
            Write-Output "❌ Internet Gateway detachment cancelled by user."
            exit 0
        }
    }

    # Detach the Internet Gateway
    if (-not $DryRun) {
        Write-Output "`n🔌 Detaching Internet Gateway..."
        $detachResult = aws ec2 detach-internet-gateway --internet-gateway-id $InternetGatewayId --vpc-id $VpcId @awsArgs --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Output "✅ Internet Gateway detachment initiated successfully!"

            # Verify detachment
            Write-Output "`n🔍 Verifying detachment..."
            $verifyResult = aws ec2 describe-internet-gateways --internet-gateway-ids $InternetGatewayId @awsArgs --output json 2>&1

            if ($LASTEXITCODE -eq 0) {
                $verifyData = $verifyResult | ConvertFrom-Json
                $verifiedIgw = $verifyData.InternetGateways[0]

                $remainingAttachment = $verifiedIgw.Attachments | Where-Object { $_.VpcId -eq $VpcId }

                if (-not $remainingAttachment) {
                    Write-Output "✅ Internet Gateway successfully detached from VPC"
                } else {
                    Write-Output "⚠️  Attachment still exists with state: $($remainingAttachment.State)"
                    if ($remainingAttachment.State -eq "detaching") {
                        Write-Output "   Detachment is in progress..."
                    }
                }

                Write-Output "`n📋 Updated Internet Gateway Status:"
                Write-Output "  Current attachments: $($verifiedIgw.Attachments.Count)"
                foreach ($attachment in $verifiedIgw.Attachments) {
                    Write-Output "  - VPC: $($attachment.VpcId), State: $($attachment.State)"
                }
            }

            Write-Output "`n💡 Post-Detachment Tasks:"
            Write-Output "• Clean up routes that referenced this Internet Gateway:"

            if ($referencingRoutes.Count -gt 0) {
                foreach ($route in $referencingRoutes) {
                    Write-Output "  aws ec2 delete-route --route-table-id $($route.RouteTableId) --destination-cidr-block $($route.Destination)"
                }
            }

            Write-Output "• Verify that all applications handle the loss of internet connectivity"
            Write-Output "• Consider alternative internet access methods if needed:"
            Write-Output "  - NAT Gateway for outbound-only access"
            Write-Output "  - VPC endpoints for AWS service access"
            Write-Output "  - VPN connections for secure connectivity"
            Write-Output "• The Internet Gateway can be reattached later if needed"
            Write-Output "• Delete the Internet Gateway if it's no longer needed to avoid charges"

        } else {
            Write-Error "Failed to detach Internet Gateway: $detachResult"
        }
    } else {
        Write-Output "`n✅ DRY RUN: Internet Gateway detachment command validated successfully"
        Write-Output "Command that would be executed:"
        Write-Output "aws ec2 detach-internet-gateway --internet-gateway-id $InternetGatewayId --vpc-id $VpcId"

        if ($isDisruptive) {
            Write-Output "`n⚠️  DRY RUN: This detachment would disrupt internet connectivity - review impact above"
        }

        Write-Output "`n📋 DRY RUN: Cleanup commands that would be needed:"
        if ($referencingRoutes.Count -gt 0) {
            foreach ($route in $referencingRoutes) {
                Write-Output "aws ec2 delete-route --route-table-id $($route.RouteTableId) --destination-cidr-block $($route.Destination)"
            }
        }
    }

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
