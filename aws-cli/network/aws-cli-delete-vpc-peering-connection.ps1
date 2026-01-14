[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the VPC peering connection to delete")]
    [ValidatePattern('^pcx-[a-zA-Z0-9]+$', ErrorMessage = "VpcPeeringConnectionId must be a valid VPC peering connection ID (format: pcx-xxxxxxxxx)")]
    [string]$VpcPeeringConnectionId,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompt")]
    [switch]$Force
)

<#
.SYNOPSIS
Deletes an AWS VPC peering connection.

.DESCRIPTION
This script deletes a VPC peering connection. The connection can be deleted by either the requester or accepter. Once deleted, traffic can no longer flow between the VPCs through this connection.

.PARAMETER VpcPeeringConnectionId
The ID of the VPC peering connection to delete. Must be in the format 'pcx-xxxxxxxxx'.

.PARAMETER Profile
The AWS CLI profile to use for the operation.

.PARAMETER Region
The AWS region where the VPC peering connection is located.

.PARAMETER Force
Skip the confirmation prompt and delete the peering connection immediately.

.EXAMPLE
.\aws-cli-delete-vpc-peering-connection.ps1 -VpcPeeringConnectionId pcx-12345678

Deletes the specified VPC peering connection with confirmation prompt.

.EXAMPLE
.\aws-cli-delete-vpc-peering-connection.ps1 -VpcPeeringConnectionId pcx-12345678 -Force

Deletes the peering connection without confirmation prompt.

.EXAMPLE
.\aws-cli-delete-vpc-peering-connection.ps1 -VpcPeeringConnectionId pcx-12345678 -Profile myprofile -Region us-west-2

Deletes the peering connection using a specific AWS profile and region.

.NOTES
Author: Your Name
Date: 2024
Requires: AWS CLI v2.16+ and appropriate IAM permissions

IMPORTANT NOTES:
- Deleting a peering connection immediately stops traffic flow between VPCs
- Route table entries pointing to the peering connection become inactive
- Consider removing related routes and security group rules
- This action cannot be undone
#>

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Starting VPC peering connection deletion process..." -ForegroundColor Green

    # Build AWS CLI arguments for describing the connection
    $describeArgs = @('ec2', 'describe-vpc-peering-connections', '--vpc-peering-connection-ids', $VpcPeeringConnectionId)

    if ($Profile) {
        $describeArgs += @('--profile', $Profile)
    }

    if ($Region) {
        $describeArgs += @('--region', $Region)
    }

    # First, get peering connection details for confirmation
    Write-Host "Retrieving VPC peering connection details..." -ForegroundColor Yellow
    $connectionDetails = & aws @describeArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve VPC peering connection details: $connectionDetails"
    }

    $connectionInfo = $connectionDetails | ConvertFrom-Json

    if ($connectionInfo.VpcPeeringConnections.Count -eq 0) {
        throw "VPC peering connection '$VpcPeeringConnectionId' not found"
    }

    $connection = $connectionInfo.VpcPeeringConnections[0]

    # Display peering connection information
    Write-Host "`nVPC Peering Connection Details:" -ForegroundColor Cyan
    Write-Host "  Connection ID: $($connection.VpcPeeringConnectionId)" -ForegroundColor White
    Write-Host "  Status: $($connection.Status.Code)" -ForegroundColor White
    Write-Host "  Message: $($connection.Status.Message)" -ForegroundColor White

    Write-Host "`n  Requester VPC:" -ForegroundColor White
    Write-Host "    VPC ID: $($connection.RequesterVpcInfo.VpcId)" -ForegroundColor Gray
    Write-Host "    CIDR Block: $($connection.RequesterVpcInfo.CidrBlock)" -ForegroundColor Gray
    Write-Host "    Owner ID: $($connection.RequesterVpcInfo.OwnerId)" -ForegroundColor Gray
    Write-Host "    Region: $($connection.RequesterVpcInfo.Region)" -ForegroundColor Gray

    Write-Host "`n  Accepter VPC:" -ForegroundColor White
    Write-Host "    VPC ID: $($connection.AccepterVpcInfo.VpcId)" -ForegroundColor Gray
    Write-Host "    CIDR Block: $($connection.AccepterVpcInfo.CidrBlock)" -ForegroundColor Gray
    Write-Host "    Owner ID: $($connection.AccepterVpcInfo.OwnerId)" -ForegroundColor Gray
    Write-Host "    Region: $($connection.AccepterVpcInfo.Region)" -ForegroundColor Gray

    # Display tags if present
    if ($connection.Tags -and $connection.Tags.Count -gt 0) {
        Write-Host "`n  Tags:" -ForegroundColor White
        foreach ($tag in $connection.Tags) {
            Write-Host "    $($tag.Key): $($tag.Value)" -ForegroundColor Gray
        }
    }

    # Check if connection is already deleted or deleting
    if ($connection.Status.Code -eq 'deleted') {
        Write-Host "`nPeering connection is already deleted!" -ForegroundColor Yellow
        return
    }

    if ($connection.Status.Code -eq 'deleting') {
        Write-Host "`nPeering connection is already being deleted!" -ForegroundColor Yellow
        return
    }

    # Warning about impact
    Write-Host "`nIMPACT ANALYSIS:" -ForegroundColor Red
    Write-Host "- Traffic between VPCs will be immediately interrupted" -ForegroundColor Yellow
    Write-Host "- Route table entries pointing to this connection will become inactive" -ForegroundColor Yellow
    Write-Host "- Applications relying on cross-VPC connectivity may fail" -ForegroundColor Yellow
    Write-Host "- This action cannot be undone" -ForegroundColor Yellow

    # Confirmation prompt unless Force is specified
    if (-not $Force) {
        Write-Host "`nWARNING: This action will permanently delete the VPC peering connection!" -ForegroundColor Red
        $confirmation = Read-Host "Are you sure you want to delete peering connection '$VpcPeeringConnectionId'? (yes/no)"

        if ($confirmation -ne 'yes') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Build AWS CLI arguments for deletion
    $deleteArgs = @('ec2', 'delete-vpc-peering-connection', '--vpc-peering-connection-id', $VpcPeeringConnectionId)

    if ($Profile) {
        $deleteArgs += @('--profile', $Profile)
    }

    if ($Region) {
        $deleteArgs += @('--region', $Region)
    }

    # Delete the VPC peering connection
    Write-Host "`nDeleting VPC peering connection..." -ForegroundColor Yellow
    $deleteResult = & aws @deleteArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to delete VPC peering connection: $deleteResult"
    }

    $deleteInfo = $deleteResult | ConvertFrom-Json

    Write-Host "`nVPC peering connection deletion initiated successfully!" -ForegroundColor Green
    Write-Host "  Connection ID: $($deleteInfo.VpcPeeringConnection.VpcPeeringConnectionId)" -ForegroundColor White
    Write-Host "  Status: $($deleteInfo.VpcPeeringConnection.Status.Code)" -ForegroundColor White

    # Display cleanup recommendations
    Write-Host "`nRecommended Cleanup Actions:" -ForegroundColor Cyan
    Write-Host "1. Remove routes that reference this peering connection:" -ForegroundColor White
    Write-Host "   aws ec2 describe-route-tables --filters Name=route.vpc-peering-connection-id,Values=$VpcPeeringConnectionId" -ForegroundColor Gray

    Write-Host "`n2. Review and remove security group rules that reference peer VPC CIDRs:" -ForegroundColor White
    Write-Host "   - Requester VPC CIDR: $($connection.RequesterVpcInfo.CidrBlock)" -ForegroundColor Gray
    Write-Host "   - Accepter VPC CIDR: $($connection.AccepterVpcInfo.CidrBlock)" -ForegroundColor Gray

    Write-Host "`n3. Review Network ACL rules if using custom NACLs" -ForegroundColor White

    Write-Host "`n4. Update application configurations that relied on cross-VPC connectivity" -ForegroundColor White

    Write-Host "`nMonitoring Commands:" -ForegroundColor Cyan
    Write-Host "Check deletion status: aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids $VpcPeeringConnectionId" -ForegroundColor Gray
    Write-Host "Find affected routes: aws ec2 describe-route-tables --filters Name=route.vpc-peering-connection-id,Values=$VpcPeeringConnectionId" -ForegroundColor Gray

    Write-Host "`nNOTE: The peering connection will be deleted immediately, but route table cleanup may be needed." -ForegroundColor Cyan

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
