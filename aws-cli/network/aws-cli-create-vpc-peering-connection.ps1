[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the VPC that will request the peering connection")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]+$', ErrorMessage = "VpcId must be a valid VPC ID (format: vpc-xxxxxxxxx)")]
    [string]$VpcId,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the VPC to peer with")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]+$', ErrorMessage = "PeerVpcId must be a valid VPC ID (format: vpc-xxxxxxxxx)")]
    [string]$PeerVpcId,

    [Parameter(Mandatory = $false, HelpMessage = "AWS account ID of the peer VPC (for cross-account peering)")]
    [ValidatePattern('^\d{12}$', ErrorMessage = "PeerOwnerId must be a 12-digit AWS account ID")]
    [string]$PeerOwnerId,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region of the peer VPC (for cross-region peering)")]
    [string]$PeerRegion,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Tags to apply to the VPC peering connection (Format: Key1=Value1,Key2=Value2)")]
    [string]$Tags,

    [Parameter(Mandatory = $false, HelpMessage = "Wait for the peering connection to be available")]
    [switch]$Wait
)

<#
.SYNOPSIS
Creates an AWS VPC peering connection.

.DESCRIPTION
This script creates a VPC peering connection between two VPCs. It supports same-region, cross-region, and cross-account peering connections.

.PARAMETER VpcId
The ID of the VPC that will request the peering connection.

.PARAMETER PeerVpcId
The ID of the VPC to peer with.

.PARAMETER PeerOwnerId
The AWS account ID that owns the peer VPC (required for cross-account peering).

.PARAMETER PeerRegion
The AWS region where the peer VPC is located (required for cross-region peering).

.PARAMETER Profile
The AWS CLI profile to use for the operation.

.PARAMETER Region
The AWS region where the requester VPC is located.

.PARAMETER Tags
Tags to apply to the VPC peering connection in the format Key1=Value1,Key2=Value2.

.PARAMETER Wait
Wait for the peering connection to reach the pending-acceptance or available state.

.EXAMPLE
.\aws-cli-create-vpc-peering-connection.ps1 -VpcId vpc-12345678 -PeerVpcId vpc-87654321

Creates a VPC peering connection between two VPCs in the same account and region.

.EXAMPLE
.\aws-cli-create-vpc-peering-connection.ps1 -VpcId vpc-12345678 -PeerVpcId vpc-87654321 -PeerOwnerId 123456789012

Creates a cross-account VPC peering connection.

.EXAMPLE
.\aws-cli-create-vpc-peering-connection.ps1 -VpcId vpc-12345678 -PeerVpcId vpc-87654321 -PeerRegion us-west-2

Creates a cross-region VPC peering connection.

.EXAMPLE
.\aws-cli-create-vpc-peering-connection.ps1 -VpcId vpc-12345678 -PeerVpcId vpc-87654321 -Tags "Environment=Production,Project=WebApp" -Wait

Creates a VPC peering connection with tags and waits for it to be ready.

.NOTES
Author: Your Name
Date: 2024
Requires: AWS CLI v2.16+ and appropriate IAM permissions

IMPORTANT NOTES:
- Cross-account peering requires the peer account to accept the connection
- Cross-region peering may have additional charges
- Ensure CIDR blocks don't overlap between VPCs
- Route tables need to be updated separately after connection is accepted
#>

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Starting VPC peering connection creation..." -ForegroundColor Green

    # Validate VPC IDs are different
    if ($VpcId -eq $PeerVpcId) {
        throw "VpcId and PeerVpcId cannot be the same"
    }

    # Build AWS CLI arguments
    $awsArgs = @('ec2', 'create-vpc-peering-connection', '--vpc-id', $VpcId, '--peer-vpc-id', $PeerVpcId)

    if ($PeerOwnerId) {
        $awsArgs += @('--peer-owner-id', $PeerOwnerId)
        Write-Host "Creating cross-account peering connection..." -ForegroundColor Yellow
    }

    if ($PeerRegion) {
        $awsArgs += @('--peer-region', $PeerRegion)
        Write-Host "Creating cross-region peering connection..." -ForegroundColor Yellow
    }

    if ($Profile) {
        $awsArgs += @('--profile', $Profile)
    }

    if ($Region) {
        $awsArgs += @('--region', $Region)
    }

    # Add tags if specified
    if ($Tags) {
        $tagSpecs = @()
        $tagPairs = $Tags -split ','
        foreach ($tagPair in $tagPairs) {
            $parts = $tagPair -split '=', 2
            if ($parts.Length -eq 2) {
                $tagSpecs += "Key=$($parts[0]),Value=$($parts[1])"
            }
        }

        if ($tagSpecs.Count -gt 0) {
            $awsArgs += @('--tag-specifications', "ResourceType=vpc-peering-connection,Tags=$($tagSpecs -join ',')")
        }
    }

    # Display configuration summary
    Write-Host "`nPeering Connection Configuration:" -ForegroundColor Cyan
    Write-Host "  Requester VPC: $VpcId" -ForegroundColor White
    Write-Host "  Peer VPC: $PeerVpcId" -ForegroundColor White

    if ($PeerOwnerId) {
        Write-Host "  Peer Account: $PeerOwnerId" -ForegroundColor White
    }

    if ($PeerRegion) {
        Write-Host "  Peer Region: $PeerRegion" -ForegroundColor White
    }

    # Create the VPC peering connection
    Write-Host "`nCreating VPC peering connection..." -ForegroundColor Yellow
    $result = & aws @awsArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create VPC peering connection: $result"
    }

    $peeringInfo = $result | ConvertFrom-Json
    $peeringConnection = $peeringInfo.VpcPeeringConnection

    Write-Host "`nVPC peering connection created successfully!" -ForegroundColor Green
    Write-Host "  Peering Connection ID: $($peeringConnection.VpcPeeringConnectionId)" -ForegroundColor White
    Write-Host "  Status: $($peeringConnection.Status.Code)" -ForegroundColor White
    Write-Host "  Message: $($peeringConnection.Status.Message)" -ForegroundColor White

    # Display VPC details
    Write-Host "`nConnection Details:" -ForegroundColor Cyan
    Write-Host "  Requester VPC:" -ForegroundColor White
    Write-Host "    VPC ID: $($peeringConnection.RequesterVpcInfo.VpcId)" -ForegroundColor Gray
    Write-Host "    CIDR Block: $($peeringConnection.RequesterVpcInfo.CidrBlock)" -ForegroundColor Gray
    Write-Host "    Owner ID: $($peeringConnection.RequesterVpcInfo.OwnerId)" -ForegroundColor Gray
    Write-Host "    Region: $($peeringConnection.RequesterVpcInfo.Region)" -ForegroundColor Gray

    Write-Host "  Accepter VPC:" -ForegroundColor White
    Write-Host "    VPC ID: $($peeringConnection.AccepterVpcInfo.VpcId)" -ForegroundColor Gray
    Write-Host "    CIDR Block: $($peeringConnection.AccepterVpcInfo.CidrBlock)" -ForegroundColor Gray
    Write-Host "    Owner ID: $($peeringConnection.AccepterVpcInfo.OwnerId)" -ForegroundColor Gray
    Write-Host "    Region: $($peeringConnection.AccepterVpcInfo.Region)" -ForegroundColor Gray

    # Check for CIDR block overlaps
    if ($peeringConnection.RequesterVpcInfo.CidrBlock -eq $peeringConnection.AccepterVpcInfo.CidrBlock) {
        Write-Host "`nWARNING: VPCs have identical CIDR blocks! This peering connection may not function properly." -ForegroundColor Red
    }

    # Wait for peering connection if requested
    if ($Wait) {
        Write-Host "`nWaiting for peering connection to be ready..." -ForegroundColor Yellow

        $waitArgs = @('ec2', 'wait', 'vpc-peering-connection-exists', '--vpc-peering-connection-ids', $peeringConnection.VpcPeeringConnectionId)

        if ($Profile) {
            $waitArgs += @('--profile', $Profile)
        }

        if ($Region) {
            $waitArgs += @('--region', $Region)
        }

        & aws @waitArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Peering connection is ready!" -ForegroundColor Green
        } else {
            Write-Host "Wait operation timed out or failed. Check the connection status manually." -ForegroundColor Yellow
        }
    }

    # Display next steps
    Write-Host "`nNext Steps:" -ForegroundColor Cyan

    if ($PeerOwnerId -or $PeerRegion) {
        Write-Host "1. The peer account owner must accept this peering connection:" -ForegroundColor White
        Write-Host "   aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $($peeringConnection.VpcPeeringConnectionId)" -ForegroundColor Gray
    } else {
        Write-Host "1. Accept the peering connection (same account):" -ForegroundColor White
        Write-Host "   aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $($peeringConnection.VpcPeeringConnectionId)" -ForegroundColor Gray
    }

    Write-Host "2. Update route tables in both VPCs to enable traffic routing" -ForegroundColor White
    Write-Host "3. Update security groups to allow traffic between VPCs" -ForegroundColor White
    Write-Host "4. Consider updating NACLs if using custom network ACLs" -ForegroundColor White

    Write-Host "`nMonitoring Commands:" -ForegroundColor Cyan
    Write-Host "Check status: aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids $($peeringConnection.VpcPeeringConnectionId)" -ForegroundColor Gray

    # Output the peering connection ID for scripting
    Write-Output $peeringConnection.VpcPeeringConnectionId

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
