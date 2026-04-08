<#
.SYNOPSIS
    Accepts an AWS VPC peering connection.

.DESCRIPTION
    This script accepts a VPC peering connection request. This action is required for the peering connection
    to become active and allow traffic to flow between the VPCs.
    Uses aws ec2 accept-vpc-peering-connection to perform the operation.

.PARAMETER VpcPeeringConnectionId
    The ID of the VPC peering connection to accept. Must be in the format 'pcx-xxxxxxxxx'.

.PARAMETER Profile
    The AWS CLI profile to use for the operation.

.PARAMETER Region
    The AWS region where the VPC peering connection is located.

.PARAMETER Wait
    Wait for the peering connection to reach the active state after acceptance.

.EXAMPLE
    .\aws-cli-accept-vpc-peering-connection.ps1 -VpcPeeringConnectionId pcx-12345678

.EXAMPLE
    .\aws-cli-accept-vpc-peering-connection.ps1 -VpcPeeringConnectionId pcx-12345678 -Wait

.EXAMPLE
    .\aws-cli-accept-vpc-peering-connection.ps1 -VpcPeeringConnectionId pcx-12345678 -Profile myprofile -Region us-west-2

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
    - You can only accept peering connections in the "pending-acceptance" state
    - You must have appropriate permissions in the accepter VPC's account
    - After acceptance, update route tables to enable traffic flow
    - Security groups and NACLs may also need updates

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/ec2/accept-vpc-peering-connection.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the VPC peering connection to accept")]
    [ValidatePattern('^pcx-[a-zA-Z0-9]+$')]
    [string]$VpcPeeringConnectionId,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Wait for the peering connection to be active")]
    [switch]$Wait
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Starting VPC peering connection acceptance..." -ForegroundColor Green

    # First, get current peering connection details
    $describeArgs = @('ec2', 'describe-vpc-peering-connections', '--vpc-peering-connection-ids', $VpcPeeringConnectionId)

    if ($Profile) {
        $describeArgs += @('--profile', $Profile)
    }

    if ($Region) {
        $describeArgs += @('--region', $Region)
    }

    Write-Host "Retrieving peering connection details..." -ForegroundColor Yellow
    $currentResult = & aws @describeArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve peering connection details: $currentResult"
    }

    $currentInfo = $currentResult | ConvertFrom-Json

    if ($currentInfo.VpcPeeringConnections.Count -eq 0) {
        throw "VPC peering connection '$VpcPeeringConnectionId' not found"
    }

    $currentConnection = $currentInfo.VpcPeeringConnections[0]

    # Display current peering connection information
    Write-Host "`nCurrent Peering Connection Details:" -ForegroundColor Cyan
    Write-Host "  Connection ID: $($currentConnection.VpcPeeringConnectionId)" -ForegroundColor White
    Write-Host "  Status: $($currentConnection.Status.Code)" -ForegroundColor White
    Write-Host "  Message: $($currentConnection.Status.Message)" -ForegroundColor White

    Write-Host "`n  Requester VPC:" -ForegroundColor White
    Write-Host "    VPC ID: $($currentConnection.RequesterVpcInfo.VpcId)" -ForegroundColor Gray
    Write-Host "    CIDR: $($currentConnection.RequesterVpcInfo.CidrBlock)" -ForegroundColor Gray
    Write-Host "    Owner: $($currentConnection.RequesterVpcInfo.OwnerId)" -ForegroundColor Gray
    Write-Host "    Region: $($currentConnection.RequesterVpcInfo.Region)" -ForegroundColor Gray

    Write-Host "`n  Accepter VPC:" -ForegroundColor White
    Write-Host "    VPC ID: $($currentConnection.AccepterVpcInfo.VpcId)" -ForegroundColor Gray
    Write-Host "    CIDR: $($currentConnection.AccepterVpcInfo.CidrBlock)" -ForegroundColor Gray
    Write-Host "    Owner: $($currentConnection.AccepterVpcInfo.OwnerId)" -ForegroundColor Gray
    Write-Host "    Region: $($currentConnection.AccepterVpcInfo.Region)" -ForegroundColor Gray

    # Check if peering connection is in the correct state
    if ($currentConnection.Status.Code -eq 'active') {
        Write-Host "`nPeering connection is already active!" -ForegroundColor Green
        return
    }

    if ($currentConnection.Status.Code -ne 'pending-acceptance') {
        Write-Host "`nWARNING: Peering connection is in '$($currentConnection.Status.Code)' state." -ForegroundColor Yellow
        Write-Host "It can only be accepted when in 'pending-acceptance' state." -ForegroundColor Yellow

        if ($currentConnection.Status.Code -eq 'rejected') {
            Write-Host "This connection has been rejected and cannot be accepted." -ForegroundColor Red
            exit 1
        }

        if ($currentConnection.Status.Code -eq 'expired') {
            Write-Host "This connection has expired and cannot be accepted." -ForegroundColor Red
            exit 1
        }

        Write-Host "Attempting to accept anyway..." -ForegroundColor Yellow
    }

    # Build AWS CLI arguments for acceptance
    $awsArgs = @('ec2', 'accept-vpc-peering-connection', '--vpc-peering-connection-id', $VpcPeeringConnectionId)

    if ($Profile) {
        $awsArgs += @('--profile', $Profile)
    }

    if ($Region) {
        $awsArgs += @('--region', $Region)
    }

    # Accept the VPC peering connection
    Write-Host "`nAccepting VPC peering connection..." -ForegroundColor Yellow
    $result = & aws @awsArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to accept VPC peering connection: $result"
    }

    $acceptInfo = $result | ConvertFrom-Json
    $acceptedConnection = $acceptInfo.VpcPeeringConnection

    Write-Host "`nVPC peering connection accepted successfully!" -ForegroundColor Green
    Write-Host "  Connection ID: $($acceptedConnection.VpcPeeringConnectionId)" -ForegroundColor White
    Write-Host "  New Status: $($acceptedConnection.Status.Code)" -ForegroundColor White
    Write-Host "  Message: $($acceptedConnection.Status.Message)" -ForegroundColor White

    # Wait for the connection to become active if requested
    if ($Wait) {
        Write-Host "`nWaiting for peering connection to become active..." -ForegroundColor Yellow

        $maxAttempts = 30
        $attempt = 0
        $isActive = $false

        while ($attempt -lt $maxAttempts -and -not $isActive) {
            Start-Sleep -Seconds 10
            $attempt++

            Write-Host "  Checking status (attempt $attempt/$maxAttempts)..." -ForegroundColor Gray

            $checkResult = & aws @describeArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                $checkInfo = $checkResult | ConvertFrom-Json
                $currentStatus = $checkInfo.VpcPeeringConnections[0].Status.Code

                if ($currentStatus -eq 'active') {
                    $isActive = $true
                    Write-Host "`nPeering connection is now active!" -ForegroundColor Green
                } elseif ($currentStatus -eq 'failed') {
                    Write-Host "`nPeering connection failed to become active!" -ForegroundColor Red
                    break
                } else {
                    Write-Host "    Current status: $currentStatus" -ForegroundColor Gray
                }
            }
        }

        if (-not $isActive -and $attempt -eq $maxAttempts) {
            Write-Host "`nTimeout waiting for peering connection to become active." -ForegroundColor Yellow
            Write-Host "Check the status manually with: aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids $VpcPeeringConnectionId" -ForegroundColor Gray
        }
    }

    # Display next steps
    Write-Host "`nNext Steps to Enable Traffic Flow:" -ForegroundColor Cyan
    Write-Host "1. Update route tables in both VPCs:" -ForegroundColor White
    Write-Host "   - Add routes pointing to the peer VPC's CIDR block" -ForegroundColor Gray
    Write-Host "   - Use the peering connection as the target" -ForegroundColor Gray

    Write-Host "`n2. Update security groups:" -ForegroundColor White
    Write-Host "   - Add inbound/outbound rules to allow traffic from peer VPC" -ForegroundColor Gray
    Write-Host "   - Reference the peer VPC's CIDR block or security groups" -ForegroundColor Gray

    Write-Host "`n3. Update Network ACLs (if using custom NACLs):" -ForegroundColor White
    Write-Host "   - Add inbound/outbound rules for peer VPC traffic" -ForegroundColor Gray

    Write-Host "`n4. Test connectivity between instances in both VPCs" -ForegroundColor White

    Write-Host "`nExample route creation commands:" -ForegroundColor Cyan
    Write-Host "aws ec2 create-route --route-table-id rtb-xxxxxxxx --destination-cidr-block $($currentConnection.AccepterVpcInfo.CidrBlock) --vpc-peering-connection-id $VpcPeeringConnectionId" -ForegroundColor Gray
    Write-Host "aws ec2 create-route --route-table-id rtb-yyyyyyyy --destination-cidr-block $($currentConnection.RequesterVpcInfo.CidrBlock) --vpc-peering-connection-id $VpcPeeringConnectionId" -ForegroundColor Gray

    # Output the peering connection ID for scripting
    Write-Output $VpcPeeringConnectionId

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
