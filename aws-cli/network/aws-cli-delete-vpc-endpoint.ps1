<#
.SYNOPSIS
    Deletes an AWS VPC endpoint.

.DESCRIPTION
    This script deletes a VPC endpoint in AWS. It provides options to view endpoint details before deletion
    and includes safety confirmation prompts. Uses aws ec2 delete-vpc-endpoints to perform the operation.

.PARAMETER VpcEndpointId
    The ID of the VPC endpoint to delete. Must be in the format 'vpce-xxxxxxxxx'.

.PARAMETER Profile
    The AWS CLI profile to use for the operation.

.PARAMETER Region
    The AWS region where the VPC endpoint is located.

.PARAMETER Force
    Skip the confirmation prompt and delete the VPC endpoint immediately.

.EXAMPLE
    .\aws-cli-delete-vpc-endpoint.ps1 -VpcEndpointId vpce-12345678

.EXAMPLE
    .\aws-cli-delete-vpc-endpoint.ps1 -VpcEndpointId vpce-12345678 -Force

.EXAMPLE
    .\aws-cli-delete-vpc-endpoint.ps1 -VpcEndpointId vpce-12345678 -Profile myprofile -Region us-west-2

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/delete-vpc-endpoints.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The VPC endpoint ID to delete")]
    [ValidatePattern('^vpce-[a-zA-Z0-9]+$')]
    [string]$VpcEndpointId,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompt")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Starting VPC endpoint deletion process..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @('ec2', 'describe-vpc-endpoints', '--vpc-endpoint-ids', $VpcEndpointId)

    if ($Profile) {
        $awsArgs += @('--profile', $Profile)
    }

    if ($Region) {
        $awsArgs += @('--region', $Region)
    }

    # First, get endpoint details for confirmation
    Write-Host "Retrieving VPC endpoint details..." -ForegroundColor Yellow
    $endpointDetails = & aws @awsArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve VPC endpoint details: $endpointDetails"
    }

    $endpointInfo = $endpointDetails | ConvertFrom-Json

    if ($endpointInfo.VpcEndpoints.Count -eq 0) {
        throw "VPC endpoint '$VpcEndpointId' not found"
    }

    $endpoint = $endpointInfo.VpcEndpoints[0]

    # Display endpoint information
    Write-Host "`nVPC Endpoint Details:" -ForegroundColor Cyan
    Write-Host "  Endpoint ID: $($endpoint.VpcEndpointId)" -ForegroundColor White
    Write-Host "  VPC ID: $($endpoint.VpcId)" -ForegroundColor White
    Write-Host "  Service Name: $($endpoint.ServiceName)" -ForegroundColor White
    Write-Host "  Type: $($endpoint.VpcEndpointType)" -ForegroundColor White
    Write-Host "  State: $($endpoint.State)" -ForegroundColor White
    Write-Host "  Creation Time: $($endpoint.CreationTimestamp)" -ForegroundColor White

    if ($endpoint.RouteTableIds) {
        Write-Host "  Route Tables: $($endpoint.RouteTableIds -join ', ')" -ForegroundColor White
    }

    if ($endpoint.SubnetIds) {
        Write-Host "  Subnets: $($endpoint.SubnetIds -join ', ')" -ForegroundColor White
    }

    if ($endpoint.NetworkInterfaceIds) {
        Write-Host "  Network Interfaces: $($endpoint.NetworkInterfaceIds -join ', ')" -ForegroundColor White
    }

    # Confirmation prompt unless Force is specified
    if (-not $Force) {
        Write-Host "`nWARNING: This action will permanently delete the VPC endpoint!" -ForegroundColor Red
        $confirmation = Read-Host "Are you sure you want to delete VPC endpoint '$VpcEndpointId'? (yes/no)"

        if ($confirmation -ne 'yes') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Delete the VPC endpoint
    Write-Host "`nDeleting VPC endpoint..." -ForegroundColor Yellow

    $deleteArgs = @('ec2', 'delete-vpc-endpoints', '--vpc-endpoint-ids', $VpcEndpointId)

    if ($Profile) {
        $deleteArgs += @('--profile', $Profile)
    }

    if ($Region) {
        $deleteArgs += @('--region', $Region)
    }

    $deleteResult = & aws @deleteArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to delete VPC endpoint: $deleteResult"
    }

    $deleteInfo = $deleteResult | ConvertFrom-Json

    Write-Host "`n✅ VPC endpoint deletion initiated successfully!" -ForegroundColor Green

    if ($deleteInfo.Unsuccessful -and $deleteInfo.Unsuccessful.Count -gt 0) {
        Write-Host "`nFailed deletions:" -ForegroundColor Red
        foreach ($failed in $deleteInfo.Unsuccessful) {
            Write-Host "  Endpoint ID: $($failed.ResourceId)" -ForegroundColor Red
            Write-Host "  Error: $($failed.Error.Message)" -ForegroundColor Red
        }
    }

    if ($deleteInfo.Successful -and $deleteInfo.Successful.Count -gt 0) {
        Write-Host "`nSuccessful deletions:" -ForegroundColor Green
        foreach ($success in $deleteInfo.Successful) {
            Write-Host "  Endpoint ID: $($success)" -ForegroundColor Green
        }
    }

    Write-Host "`nNOTE: VPC endpoint deletion may take a few minutes to complete." -ForegroundColor Cyan
    Write-Host "Use 'aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $VpcEndpointId' to check the deletion status." -ForegroundColor Cyan

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
